# Categories

Match each moment to every category whose trigger it meets. "Targets" names the rows of
[knowledge-placement.md](../../write-for-agents/references/knowledge-placement.md) a candidate of that category usually takes; step 5 of `SKILL.md` still
picks the first matching row.

## Navigation

- **Trigger:** a long search: a `SEARCH` line of the script, or many reads before the agent found a
  file, a command or a fact.
- **Look for:** the file the agent read first that could have pointed to the answer, and hidden
  links between files (a change in one needs a change in another).
- **Change:** a one-line pointer, with its "read when" condition, in a file the agent already reads.
- **Targets:** 6, 7, 8.

## Automated checks

- **Trigger:** a mistake a tool could have caught (failed build, wrong format, unpinned version,
  forbidden word, broken link), found late, by the user or in CI.
- **Look for:** the repo's own check command first (`mise` tasks, `Makefile`, `package.json`
  scripts, `.pre-commit-config.yaml`, CI workflows). A check that exists but is not wired, or is
  silently broken, is the finding. A repo with no guardrail at all (no pre-commit hook and no CI job
  running lint and tests) is a finding too, once a moment shows a mistake it would have caught.
- **Change:** a lint rule, a pre-commit hook, a CI job or a script, whichever the repo's existing
  tooling makes cheapest; or the wiring of an existing one.
- **Targets:** 3.

## Coding standards

- **Trigger:** the user corrected a judgement call in the code (naming, consistency with the
  surrounding code, design, error handling), or a review let one through.
- **Look for:** whether a check could decide it. When one can, the candidate belongs to Automated
  checks instead.
- **Change:** one rule in `CODING_STANDARDS.md`, with the reason; or a clarified or deleted rule.
- **Targets:** 1, 4.

## Instruction files

- **Trigger:** a rule in an instruction file (repo, hub or user level) was ignored, applied where it
  did not fit, or contradicted another one; or the file fails the checklist's structure items.
- **Look for:** steering that belongs elsewhere: a mechanical rule (to a check), a review rule (to
  `CODING_STANDARDS.md`), a long fact (to docs or the wiki). An instruction file keeps conventions,
  gotchas and pointers.
- **Change:** move the line to its target and leave a pointer only when every session needs it.
- **Targets:** 1, 3, 4, 6, 7, 8.

## Tool economy

- **Trigger:** a tool call whose output was large for what the agent used (truncated or persisted
  output, a rerun with a filter), slow, or repeated with the same input (`RETRY`).
- **Look for:** a flag that narrows the output, a script that does the repeated sequence once, a
  token-heavy tool or MCP server that a plain command replaces.
- **Change:** a script in the repo, a documented flag, or a skill step that uses the narrow command.
- **Targets:** 3, 5, 6.

## No-ops

- **Trigger:** a loaded line that changed nothing in the session: the agent would have done the same
  without it, or the situation it covers came up and the line did not apply.
- **Look for:** lines that fail the checklist's pruning items: they repeat another file, restate a
  command's output or `--help`, or tell the agent its default behaviour.
- **Change:** delete the line. Quote the line and the moment where it was loaded or should have
  applied.
- **Targets:** 1.

## Information access

- **Trigger:** the agent guessed, asked the user, or stopped because it could not read something: a
  log, a service, a doc on a blocked domain, a denied command (`DENIED`).
- **Look for:** the smallest access that removes the guess: a log written to a file, a read-only
  credential, an allowed domain, a documented command.
- **Change:** the access, written where the agent finds it next time.
- **Targets:** 6, 7, 9.

## Skill quality

- **Trigger:** a skill used in the session misled the agent: a step was skipped or misread, a step
  had no end condition, its script failed, its output template was not followed, or the user
  corrected its output. Also: `scripts/feedback.sh rework` lists the skill (3 lines or more at its
  current version).
- **Look for:** the checklist item the skill fails. Consider renaming, splitting, reworking or
  deleting the skill, not only adding a line.
- **Change:** the edit to the skill, applied later through the write-skill skill.
- **Targets:** 1, 5.
