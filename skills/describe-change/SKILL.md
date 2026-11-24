---
name: describe-change
description: Write the title and body of a pull request or merge request, with a visual summary, before/after evidence and the merge danger. Use when the user asks to open, describe or update a PR or MR.
metadata:
  version: 0.1.0
---

# Describe a change

Write a PR/MR body a reviewer understands in one minute: one visual, the evidence, the danger.

## Steps

1. **Collect.** Read the change: `git log --oneline <base>..HEAD`, `git diff <base>...HEAD
   --stat`, then the diff of the files that carry the change. Collect the evidence that exists: test
   output, `terraform plan`, `kubectl diff`, screenshots. Done when you can say in one sentence what
   the change does and why.
2. **Pick the visual.** Read [references/visuals.md](references/visuals.md) and pick the smallest
   visual that explains the change. Done when the visual is drawn.
3. **Write the body.** Read [assets/body.md](assets/body.md) and fill it exactly. Write it to a file
   outside the repository, for example `${TMPDIR:-/tmp}/pr-body.md`. Done when every section is
   filled and the file is written.
4. **Print the command.** Run `scripts/forge.sh create --title "<title>" <file>` for a new PR/MR
   (add `--base <branch>` when the base is not the default branch), or `scripts/forge.sh update
   <file>` for the existing one of the current branch. It prints the `gh` or `glab` command for the
   forge of `origin`. Done when the command is printed.
5. **Finish.** When the user asked to open or update the PR/MR, run the printed command and show the
   URL. Otherwise show the title, the body and the printed command. Done when one of the two is sent.

## Gotchas

- Run `scripts/forge.sh` with the repository as the current directory: it reads `origin` there. For
  a GitLab host without `gitlab` in its name, set `GITLAB_HOST=<host>`.
- Push the branch before you run a printed create command.
- Evidence is output you ran or captured for this change. When there is none, write `None.` and say
  what would provide it.
- A one-way door (data deletion, state move, schema migration, destroyed resource, public API
  removal) has no merge without a Rollback line.
