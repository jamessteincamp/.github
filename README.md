# .github

Shared defaults for every repository on this account.

## Issue templates

`.github/ISSUE_TEMPLATE/` applies to any repo here that has no `ISSUE_TEMPLATE` folder of its own. Each form sets the built-in **Type** and assigns `jamessteincamp`. Blank issues are off, so the web UI always goes through a form.

## Issue defaults workflow

Templates only cover issues filed on the web. Issues filed with `gh issue create` or by a tool skip them, so each repo runs a workflow that fills in what is missing when an issue is opened:

- **No assignee** → the repo’s default assignee.
- **No Type** → guessed from the labels (`bug` → Bug, `question`/`decision` → Question, `docs` → Documentation, `enhancement`/`feature` → Feature), otherwise Task.

It never overwrites an assignee or a Type that is already set. The logic is in [`scripts/issue-defaults.sh`](scripts/issue-defaults.sh), which can also be run by hand to back-fill an old issue:

```bash
REPO=jamessteincamp/money-go-round NUMBER=58 DEFAULT_ASSIGNEE=jamessteincamp scripts/issue-defaults.sh
```

To switch it on in a repo, add `.github/workflows/issue-defaults.yml`:

```yaml
name: Issue defaults
on:
  issues:
    types: [opened]
permissions:
  issues: write
jobs:
  defaults:
    uses: jamessteincamp/.github/.github/workflows/issue-defaults.yml@main
    with:
      default-assignee: jamessteincamp
```
