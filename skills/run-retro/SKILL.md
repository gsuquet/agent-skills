---
name: run-retro
description: Review an agent session for the moments where the agent struggled, and propose ranked changes to instruction files, skills and automated checks, each backed by a session moment. Use when the user asks for a retro, or asks what to improve after a session. Proposes only.
metadata:
  version: 0.1.0
---

# Run a retro

Find what in the agent's environment (instruction files, skills, checks, tools, access) let the
session go wrong, and propose the change that prevents it next time. A **moment** is one point in
the session where the agent struggled. A **candidate** is one proposed change, backed by at least
one moment.

## Steps

1. **Load the yardstick.** Read [write-for-agents](../write-for-agents/SKILL.md) and its
   `assets/checklist.md`. They judge every instruction file and skill in step 4. Done when both are
   read.
2. **Pick the session.** Take the current session, unless the user names a past one. For a past
   Claude Code session, run `scripts/session-moments.sh list [<dir>]`, pick the session with the
   user, then run `scripts/session-moments.sh moments <file>`. For the current Claude Code session
   after a compaction, run `moments` on its file too: the summary drops the struggles. In
   Antigravity, only the current session is readable. Done when the session is fixed and, when the
   script applies, its output is read.
3. **Extract moments.** Read the whole session and list every moment: a correction by the user, a
   failed tool call, a retry of the same call, a long search (many reads or searches before the
   agent found a file or a fact), a wrong assumption the agent later reversed. A user message is a
   correction when it rejects, changes or adds to what the agent proposed or did just before it:
   read each `USER` line of the script against its `after:` line, and the session around it when
   300 characters are not enough. Number the moments M1, M2..., with the timestamp or turn and a
   quote of one line at most, redacted. Done when the session is read to its end and each moment
   has a number.
4. **Scan.** Read, judging each against the checklist:
   - the repo's `AGENTS.md` / `CLAUDE.md` and the files they import;
   - the user-level instruction file (Claude Code: `~/.claude/CLAUDE.md` and its `@` imports);
   - the hub's instruction file: the nearest ancestor of the repo root, outside the repo and below
     `$HOME`, that holds a `CLAUDE.md` or an `AGENTS.md`;
   - each skill used in the session, and the files of it the session read;
   - the output of `scripts/feedback.sh rework` (exit 3: the skills are not a clone, skip it).

   Then read [references/categories.md](references/categories.md) and match each moment to the
   categories whose trigger it meets. Done when every file above is read and every moment has a
   category or is marked "no change".
5. **Classify.** Write one candidate per change. Mark it **mechanical** when a check can decide
   pass or fail without judgement, **judgement** otherwise. Read
   `../write-for-agents/references/knowledge-placement.md` (from
   [write-for-agents](../write-for-agents/SKILL.md)) and take the first row that matches as the
   target. Skill changes go through [write-skill](../write-skill/SKILL.md), session state through
   [handoff](../handoff/SKILL.md). Done when every candidate has a kind and a target.
6. **Rank.** Sort by severity, then by number of moments, then by lower effort first. Severity is
   **high** when a wrong change was committed or shipped, a secret or data was at risk, or the user
   corrected the same thing twice; **medium** when it cost a correction, a failed run or ten wasted
   calls; **low** otherwise. Done when the list is ordered.
7. **Report.** Read [assets/report.md](assets/report.md) and fill it exactly. Done when the report
   is printed.
8. **Log feedback.** For each candidate whose target is a skill, run
   `scripts/feedback.sh append <skill> "<what went wrong>" <link>`. `<link>` is the URL of the
   PR, MR or commit that showed the problem, or `-`: never a session URL or a local path, which the
   script refuses. Exit 4 means the skill is not in the skills repository: skip it. Exit 3 means
   the skills are not a clone: print `Not written:` and the line instead. Done when each such
   candidate has its line appended, skipped or printed.
9. **Stop.** End the turn after step 8, with every candidate still unapplied: the user picks the
   ones to apply, in a later turn or session.

## Gotchas

- No moment, no candidate. Generic advice ("add more tests", "document the architecture") is
  dropped, however true.
- Never edit an instruction file, a skill, a check or a config: write the change into the report.
  `FEEDBACK.md` is the only write.
- Prune as well as add: a rule or check that never fired, or a line that changes nothing per the
  checklist, gets a deletion candidate. Each added line weighs on every later session.
- A check that exists but is not wired (not in pre-commit, not in CI, not in the lint task) is the
  candidate, not a new check.
- `FEEDBACK.md` is committed to a public repository: write what went wrong in the skill's terms,
  with no customer or employer name, private path, personal data or secret.
