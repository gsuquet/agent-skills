---
name: write-docs
description: Write or update a technical doc for human readers from a fixed template - README, how-to, tutorial, reference, concept, runbook, or an RFC with the ADR generated from it once accepted. Use when the user asks to document something, write one of these docs, propose a design or record a technical decision. Not for text agents read or for PR/MR bodies.
metadata:
  version: 0.3.0
---

# Write docs

Write one doc, of one type, for one reader need, from the template of that type, in the place where
its readers look.

## Steps

1. **Scope.** When agents read the text (AGENTS.md, CLAUDE.md, a skill, a doc reached from one),
   follow [write-for-agents](../write-for-agents/SKILL.md) instead and stop. When the text is a
   PR/MR body, follow [describe-change](../describe-change/SKILL.md) instead and stop. Done when
   humans read the doc.
2. **Pick the type.** Go down the table; the first row that matches what the reader needs picks
   the type. When no row matches, or the request fits two rows, read
   [references/doc-types.md](references/doc-types.md). When it still does not decide, ask the user
   one question in plain text that names the two candidate types, and wait. Done when one type is
   picked.

   | The reader needs to | Type | Template |
   |---|---|---|
   | decide on a change that is one-way or breaks more than what it changes, or record a decision | RFC | [assets/rfc.md](assets/rfc.md) |
   | bring a running system back after an alert or a symptom | runbook | [assets/runbook.md](assets/runbook.md) |
   | find out what a repository or folder is, and start using it | README | [assets/readme.md](assets/readme.md) |
   | learn by doing, new to the subject, along one guided path | tutorial | [assets/tutorial.md](assets/tutorial.md) |
   | complete one task they already understand | how-to | [assets/how-to.md](assets/how-to.md) |
   | look up exact facts: commands, flags, fields, defaults, limits | reference | [assets/reference.md](assets/reference.md) |
   | understand how or why something works, with no task to do | concept | [assets/concept.md](assets/concept.md) |

   An ADR is never written directly: a request for one is an RFC (see [RFC](#rfc)).
3. **Place it.** Done when the path is chosen.
   - The team has a docs repository, a template or an RFC/ADR process (check the instruction files
     and the target repository): its place, template, numbering and states replace this skill's, and
     the scripts of this skill run only on documents from its own templates, except
     `scripts/check-readability.sh`, which runs on every doc. [Readability](#readability) applies on
     top of a team template: keep its headings and add to its Summary what is missing. The rules
     below and [RFC](#rfc) cover what the team leaves open.
   - The doc is about one repository: it goes in that repository. A README is `README.md` in the
     folder it describes. An RFC is the path `scripts/next-number.sh rfc <slug>` prints. Any other
     type is `docs/<folder>/<slug>.md`, with `<folder>` one of `how-to`, `tutorials`, `reference`,
     `concepts`, `runbooks`, or the folder the repository already uses for that type.
   - The doc spans several repositories of one context: it goes in `<hub>/`, with the same layout.
     `<hub>` is the nearest ancestor of the repository, outside it, that holds a CLAUDE.md or an
     AGENTS.md; `$HOME` and its ancestors never count. For an RFC, add `--root <hub>`. When there
     is no `<hub>`, ask the user where the doc goes.
   - When a doc of the same type and subject exists, the path is that doc: update it.

   For an RFC, the steps of [RFC](#rfc) replace steps 4 and 5.
4. **Write.** Read the template and fill it exactly into the path. Apply
   [Readability](#readability). Run each command the doc shows when it is read-only, and use its
   real output with secrets replaced by `<REDACTED>`; mark each command you did not run `(untested)`. Done when no `<...>` placeholder is
   left and the doc passes the [readability gate](#readability).
5. **Finish.** When the doc fails the readability gate, go back to step 4. Link the doc from the
   README of its repository, or of `<hub>` when it has one; a README needs no link. Reply with the path, one sentence on what the doc covers, the
   untested commands, one verdict per checklist item and the visuals not rendered. Done when the reply is sent.

## Readability

Decisions come first, each fact is written once, and a visual replaces text.

- **Visuals.** Before you draw or change a visual, read
  [references/visuals.md](references/visuals.md).
- **Detail.** The doc keeps one line and a link for each: evidence goes to the study, work packages
  to the tracker, implementation design to a design page. When that place does not exist, ask the
  user where the detail goes: never write a link you did not open or create. A doc longer than its
  limit has detail to move; `--help` of `scripts/check-readability.sh` lists every limit.
- **Names.** Link to a heading with a readable name instead of a code invented for the doc (D7,
  WP2). Real ticket, PR/MR and ADR references stay.
- **Decisions.** An RFC has a table `Decision | Why | Cost | Reversible` in its Summary, one row per
  decision. Above the limit, write peer RFCs: each stands alone, and none is the parent. One peer
  carries `supersedes:`; the others link the old RFC in References. Reversible starts with yes or
  no, then how or why. When you do not know it, ask the user; only a draft may say open, with a link
  to Open questions.
- **Change.** An RFC that replaces or removes something shows before and after in its Summary, as
  two charts, unless the 25-word rule of [references/visuals.md](references/visuals.md) waives them.

The **readability gate**, run on every doc:

1. Run `scripts/check-readability.sh --type <type> <file>` and fix each finding in the doc. The type
   is the one of step 2, `adr`, `study-index` (the landing page of a study), or `other` when none
   fits. When you update a doc, add `--base <default branch>`: an existing finding does not block.
   Allow a code only when it is a real name. Done when it exits 0.
2. Read [assets/readability-checklist.md](assets/readability-checklist.md) and check the doc against
   every item. Done when every item passes and the script still exits 0.
3. Follow "Render and look" of [references/visuals.md](references/visuals.md) when the doc holds a
   visual you drew or changed. Done when each one was opened, or is listed as not rendered.

## RFC

Write an RFC when the change is **one-way** (undoing it needs a data migration, downtime or
another team) or its blast radius goes beyond what it changes, or when the user asks for one.
Otherwise reply that a PR/MR is enough and stop. The size of the change never decides.

Track: **full** when any of these holds, else **lightweight**: it changes more than one
environment or cluster at once; it migrates persisted state or data; it changes an IAM, RBAC or
network trust boundary; it adds a recurring cost that needs budget approval; another team or a
published API depends on what it changes. The review window is 2 business days on the lightweight
track and 5 on the full track; it ends early when every decider has approved.

1. **Draft.** Read [assets/rfc.md](assets/rfc.md) and fill what you know into the path, with
   `status: draft`; run commands as in step 4. Run the readability gate, then open a draft
   PR/MR with [describe-change](../describe-change/SKILL.md). Done when `scripts/check-rfc.sh <file>`
   exits 0 and the gate passes.
2. **Review.** Set `review:` to the PR/MR URL and fill every field. Done when
   `scripts/check-rfc.sh <file> --target review` exits 0 and the readability gate passes with
   `--status review`, then `status: review` and `updated:` are set and the PR/MR is ready for review.
3. **Decide.** After the review window, record what the deciders decided, with the Decision block
   of [assets/rfc.md](assets/rfc.md). Run `scripts/check-rfc.sh <file> --target <decided status>`
   until it exits 0, then set `status:` and `updated:`.
   - accepted: then run `scripts/rfc-to-adr.sh <file>` and commit the ADR in the same PR/MR. The ADR
     passes the readability gate; fix a finding in the RFC and run `rfc-to-adr.sh` again.
   - rejected: the PR/MR is merged anyway, so the reason stays in the repository.
   - withdrawn: from draft or review; the PR/MR is merged or closed with the reason.

   Done when `scripts/check-rfc.sh <file>` exits 0.
4. **Supersede.** When an accepted RFC replaces an older one (`supersedes: <number>`), run
   `scripts/supersede.sh <old-file> <new-file>` after its ADR exists, in the same PR/MR. Done when
   `scripts/check-rfc.sh` exits 0 on both files.
5. **Finish.** When an RFC or ADR you wrote in this run (not one `supersede.sh` updated) fails the readability gate, fix it first. Reply with
   the RFC path, its status, the ADR path when there is one, the last `check-rfc.sh` and
   `check-readability.sh` output, one verdict per checklist item, and the visuals not rendered. Done when the reply is sent.

Each script prints its rules and exit codes with `--help`. Read
[references/rfc-sources.md](references/rfc-sources.md) only when the user asks why the template or
the lifecycle is shaped this way, or wants to change it.

## Gotchas

- An ADR is never edited by hand. To change it, fix the RFC and re-run `scripts/rfc-to-adr.sh`;
  `check-rfc.sh` fails when the two differ.
- The Decision section of an RFC stands alone: no "see above", no "as discussed". It is copied
  verbatim into the ADR, where the rest of the RFC is not.
- An accepted RFC changes only through Implementation links and `supersede.sh`. Any other change
  is a new RFC that supersedes it.
- Push review fixes to an RFC as new commits: a rebase or a force-push erases the review history.
- One doc, one type: steps found in a concept doc, or tables in a tutorial, move to a how-to or a
  reference that the doc links to.
