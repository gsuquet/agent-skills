---
name: write-tickets
description: Break a plan, RFC, issue or the current conversation into vertical tickets with blocking edges, with an optional spec as their parent, and publish them to GitHub, GitLab or Jira. Use when the user asks for a spec, or to break work into tickets or issues.
metadata:
  version: 0.1.0
---

# Write tickets

Turn settled work into **tickets**: vertical slices that each fit one fresh agent context, each
naming the tickets that **block** it. A **spec** is the parent issue that holds what every ticket
shares. Tickets state behaviour and acceptance criteria, never user stories: infrastructure work has
no users.

## Steps

1. **Gather the source.** Read what the user points to: the conversation, an RFC (from
   [write-docs](../write-docs/SKILL.md)), or an issue with its comments (`gh issue view <n>
   --comments`, `glab issue view <n> --comments`). Read the ADRs and the code in the area the work
   touches. List the decisions the source leaves open. When one is open, stop: list them and tell
   the user to settle them with [interview](../interview/SKILL.md) first. Done when the work fits in
   one sentence and no decision is open.
2. **Decide the spec.** Write a spec when the work spans more than one session (more than one
   ticket), or when the user asks for one. Done when the answer, yes or no, is written down.
3. **Confirm the test seams.** A seam is the point where a test drives the behaviour: prefer an
   existing seam, and the highest one (an API call over a function, `terraform plan` on the root
   module over a submodule). Propose the fewest seams that cover the work, then stop and ask the user
   to confirm them. Done when the user has confirmed or corrected every seam.
4. **Draft the spec.** Skip this step when step 2 said no. Read [assets/spec.md](assets/spec.md) and
   fill it from the source and the confirmed seams. Done when every section is filled or `None.`.
5. **Slice.** Read [references/slicing.md](references/slicing.md) and cut the work into tickets.
   Done when every ticket has a title, its blockers, the behaviour it delivers, and acceptance
   criteria that each fail at the base commit.
6. **Show the breakdown.** Read [assets/breakdown.md](assets/breakdown.md) and fill it exactly.
   Stop and wait for the user. On corrections, go back to step 5. Done when the user answers `ok`.
7. **Write the drafts.** Write them to `$(git rev-parse --git-common-dir)/tickets/<slug>/`, `<slug>`
   naming the work in kebab-case: `spec.md` from step 4, and one `NN-<slug>.md` per ticket from
   [assets/ticket.md](assets/ticket.md), `NN` being its breakdown number. When the user wants no
   tracker, print the folder path and stop. Done when the folder holds one file per ticket, and
   `spec.md` when step 2 said yes.
8. **Publish.** From the repository root, run
   [scripts/publish-tickets.sh](scripts/publish-tickets.sh) `--dry-run <folder>`. Add `--tracker`
   (and `--project` for Jira) only when the user named a tracker, and `--label` only for labels the
   user named. For Jira, add `--config <file>` when the user has one (custom fields, epic link,
   label rules: [references/trackers.md](references/trackers.md)), and publish with `--max 1`
   first, then ask the user to check that ticket on Jira before the full run. On exit 2, ask the user which tracker to use, then run again with `--tracker`. Check
   that the dry run creates one issue per draft with the blocking edges of the approved breakdown;
   when it does not, fix the drafts and dry-run again. Then run the same command without
   `--dry-run`. Read
   [references/trackers.md](references/trackers.md) when the script exits 3 or 4, or prints a
   warning. Done when the script exits 0 without `--dry-run`.
9. **Finish.** Show the issue list the script printed last, then each warning it printed, one line
   each. Done when the list is sent.

## Gotchas

- Publishing is hard to undo: issues stay, and their numbers are burnt. Run `--dry-run` first every
  time, and never publish a breakdown the user has not answered `ok` to in step 6.
- Work from the local drafts. Never fetch the spec back from the tracker: the tracker can truncate or
  reformat it. A re-run skips every draft listed in `map.tsv`, so a change to a published issue is
  made on the tracker by hand.
- Apply no label the user did not name. A label such as `ready-for-agent` makes automated agents pick
  up the issues; `--label` never reaches the spec, so no agent picks the spec up as a task.
- On GitLab, the script rewrites the spec description from `spec.md` whenever the ticket task list
  changes: edits made to the spec on GitLab are lost then.
