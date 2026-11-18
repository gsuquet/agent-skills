# Targets

Pick the target of each candidate: take the first row whose "The candidate is" matches. `<hub>` is
the hub directory found in step 4 of `SKILL.md`. With no hub, rows 7 and 8 fall back to row 6, in
the repo that owns the work.

| # | The candidate is | Target |
|---|---|---|
| 1 | A deletion: a rule or check that never fired, or a line that changes nothing | The file that holds it |
| 2 | Session state: what is in progress, decided, or next | Not a rule. A handoff, through the handoff skill |
| 3 | A mechanical rule: a check decides pass or fail | An automated check: a lint rule, a pre-commit hook, a CI job or a script in the repo. When the check exists but is not wired, the target is the wiring (pre-commit config, CI workflow, lint task) |
| 4 | A judgement-call rule for code review | `CODING_STANDARDS.md` at the repo root. See [Coding standards](#coding-standards) |
| 5 | An improvement to a skill | That skill's folder, changed through the write-skill skill. Also a `FEEDBACK.md` line (step 8) when the skill is in the skills repository |
| 6 | A fact about one repo | That repo's docs: `README.md`, `docs/`, an ADR. A one-line pointer in its `AGENTS.md` only when every session in the repo needs the fact |
| 7 | A fact spanning repos of one context | A pointer line in the hub's instruction file (`<hub>/AGENTS.md` or `<hub>/CLAUDE.md`), linking where the fact lives |
| 8 | A long fact owned by no repo | `<hub>/wiki/<topic>.md`, plus a pointer line in the hub's instruction file that says when to read it |
| 9 | A rule for every context on the machine (safety, shell, tooling) that no check can enforce | The user-level instruction file |

## Coding standards

`CODING_STANDARDS.md` holds the judgement-call rules a reviewer applies to a diff. It stays out of
`AGENTS.md`: the implementing agent already carries the most context, the reviewer reads only the
diff. When the file does not exist yet, the candidate also adds this line to the repo's `AGENTS.md`:

```text
Review changes against `CODING_STANDARDS.md`.
```

A code-review command that reads `CLAUDE.md` (which imports `AGENTS.md`) then finds the standards.
