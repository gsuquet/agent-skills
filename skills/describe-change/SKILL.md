---
name: describe-change
description: Write the title and body of a pull request or merge request for a code, documentation, ADR or RFC change, with a visual summary, before/after evidence and the merge danger. Use when the user asks to open, describe or update a PR or MR.
metadata:
  version: 0.2.0
---

# Describe a change

Write a PR/MR body a reviewer understands in one minute: one visual, the links, the evidence, the
danger.

## Steps

1. **Collect.** Read the change: `git log --oneline <base>..HEAD`, `git diff <base>...HEAD
   --stat`, then the diff of the files that carry the change. `<base>` is the target branch, or the
   parent branch in a stack. From outside the branch of an existing PR/MR, read
   `gh pr view <n>` and `gh pr diff <n>`, or `glab mr view <n>` and `glab mr diff <n>`. Collect the
   evidence that exists: test output, `terraform plan`, `kubectl diff`, screenshots. Collect the
   links: the ticket (branch name, commit messages, the user's request), the open PRs/MRs of the
   stack, the record or doc behind the change, the pipeline or dashboard that shows the evidence.
   Done when you can say in one sentence what the change does and why, and each kind of link is
   found or known to be absent.
2. **Pick the visual.** Read [references/visuals.md](references/visuals.md) and pick the smallest
   visual that explains the change. Done when the visual is drawn.
3. **Write the body.** When every file that carries the change is a doc or a decision record (ADR,
   RFC) for human readers, read [assets/body-record.md](assets/body-record.md); otherwise read
   [assets/body.md](assets/body.md). A skill or an agent instruction file counts as code. Fill the
   asset exactly, then apply [Every body](#every-body). Write it to a file outside the repository,
   for example `${TMPDIR:-/tmp}/pr-body.md`. Done when every section is filled, every rule of Every
   body is applied and the file is written.
4. **Print the command.** Run `scripts/forge.sh create --title "<title>" <file>` for a new PR/MR
   (add `--base <branch>` when the base is not the default branch), or `scripts/forge.sh update
   <file>` for the existing one of the current branch (add `--number <n>` for any other one). It
   prints the `gh` or `glab` command for the forge of `origin`. Done when the command is printed.
5. **Finish.** When the user asked to open or update the PR/MR, run the printed command and show the
   URL. Otherwise show the title, the body and the printed command. Done when one of the two is sent.

## Every body

- **Repository template** (`pull_request_template.md` or `PULL_REQUEST_TEMPLATE/` in the root,
  `.github/` or `docs/`; `.gitlab/merge_request_templates/`): pick the one for the type of change.
  Keep its headings, checklists and quick actions, in order, and follow its comments, then remove
  them: they win over the asset, so leave out a field the template says not to copy. Put each section
  of the asset under the template heading with the same meaning, without repeating what another
  heading holds, and the remaining sections after the template. Tick a box only for what you did.
  For an update, take the template part from the current body, so ticked boxes stay ticked.
- **Links:** write each one as a full Markdown link, with a URL you read in a command output, a file
  or the user's message. For a ticket with no known URL, ask the user; without an answer, write its
  key in backticks. Write a closing keyword with the bare reference of the forge (`Closes #12`), and
  only when this change finishes the issue. Keep the kinds that exist, one line each.
- **Open points:** when you need an answer from the reviewer, end the sections with `## Open points`,
  one line each: `- <question>: <your default if nobody answers>`.
- **Stack:** when the change depends on an open PR/MR or one depends on it, start Links with
  `- **Stack:** merge after <link>, before <link>.` and keep only the halves that apply. When the
  target is not the parent branch, the diff shows the parent's files too: add `Review only <files or
  commits>.` Every section describes this change alone.
- **Quick actions:** GitLab runs a line that starts with `/` outside code. Reword the line or put the
  text in backticks, unless the repository template has it.

## Gotchas

- Run `scripts/forge.sh` with the repository as the current directory: it reads `origin` there. For
  a GitLab host without `gitlab` in its name, set `GITLAB_HOST=<host>`.
- Push the branch before you run a printed create command.
- Evidence is output you ran or captured for this change. When there is none, write `None.` and say
  what would provide it.
- A one-way door (data deletion, state move, schema migration, destroyed resource, public API
  removal) has no merge without a Rollback line.
