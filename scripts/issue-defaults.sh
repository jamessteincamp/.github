#!/usr/bin/env bash
# Give one issue an assignee and a built-in Type if it has none.
#
#   REPO=owner/name NUMBER=123 DEFAULT_ASSIGNEE=login scripts/issue-defaults.sh
#
# Needs `gh` signed in with issues:write on REPO (GH_TOKEN in Actions).
# Never overwrites: an issue that already has an assignee or a type keeps it.
# The type is guessed from the labels, first match wins, and only types the
# repo actually offers are used. No match falls back to Task.
set -euo pipefail
: "${REPO:?}" "${NUMBER:?}"

issue=$(gh api "repos/$REPO/issues/$NUMBER")

if [ "$(jq '.pull_request != null' <<<"$issue")" = true ]; then
  echo "#$NUMBER is a pull request; nothing to do."
  exit 0
fi

if [ "$(jq '.assignees | length' <<<"$issue")" -eq 0 ] && [ -n "${DEFAULT_ASSIGNEE:-}" ]; then
  gh api -X POST "repos/$REPO/issues/$NUMBER/assignees" -f "assignees[]=$DEFAULT_ASSIGNEE" --silent
  echo "#$NUMBER: assigned $DEFAULT_ASSIGNEE"
fi

if [ -n "$(jq -r '.type.name // empty' <<<"$issue")" ]; then
  echo "#$NUMBER: type already $(jq -r '.type.name' <<<"$issue")"
  exit 0
fi

labels=$(jq -r '.labels[].name | ascii_downcase' <<<"$issue")
types=$(gh api graphql \
  -f query='query($o:String!,$n:String!){repository(owner:$o,name:$n){issueTypes(first:50){nodes{name isEnabled}}}}' \
  -f o="${REPO%/*}" -f n="${REPO#*/}" \
  --jq '.data.repository.issueTypes.nodes[] | select(.isEnabled) | .name')

has_type()  { grep -qxF "$1" <<<"$types"; }
has_label() { local l; for l in "$@"; do grep -qxF "$l" <<<"$labels" && return 0; done; return 1; }

# Type | labels that imply it (lower case, space-separated). Order matters.
pick=""
while IFS='|' read -r type match; do
  # shellcheck disable=SC2086  # $match is a word list on purpose
  if has_type "$type" && has_label $match; then pick=$type; break; fi
done <<'RULES'
Bug|bug type:bug
Question|question open-question decision type:decision type:question
Documentation|docs documentation type:docs type:documentation
Feature|enhancement feature type:feature
RULES

if [ -z "$pick" ] && has_type Task; then pick=Task; fi
if [ -z "$pick" ]; then
  echo "#$NUMBER: no matching type in $REPO; left blank."
  exit 0
fi

gh api -X PATCH "repos/$REPO/issues/$NUMBER" -f type="$pick" --silent
echo "#$NUMBER: type set to $pick"
