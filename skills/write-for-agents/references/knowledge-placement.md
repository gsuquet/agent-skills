# Knowledge placement

A **durable fact** is something a later session needs and cannot find by looking: a convention, a
user correction, a gotcha, a decision and its reason. Place each durable fact, rule or proposed
change in one row of the table, and in one place only: take the **first row that matches**.

The **hub** is the nearest ancestor directory of the repository, outside it and below the home
directory, that holds a `CLAUDE.md` or `AGENTS.md`. It groups the repositories of one context. Write
`<hub>` for it in public text. With no hub, rows 7 and 8 fall back to row 6, in the repository that
owns the work.

| # | The item is | Place it in | How |
|---|---|---|---|
| 1 | A deletion: a rule or check that never fired, or a line that changes nothing | The file that holds it | Propose removing it; pruning is a change like any other |
| 2 | Session state: progress, open items, next steps | A handoff document through [handoff](../../handoff/SKILL.md) | Only when the work continues in another session |
| 3 | A mechanical rule a tool can check | An automated check: linter config, pre-commit hook, CI job, script | Add the check, not a sentence. When the check exists but is not wired, the target is the wiring |
| 4 | A review rule that needs judgement | `CODING_STANDARDS.md` at the repository root | See [Coding standards](#coding-standards) |
| 5 | An improvement to a skill | That skill's folder, through [write-skill](../../write-skill/SKILL.md) | Plus a `FEEDBACK.md` line when the skill is in the skills repository |
| 6 | A fact about one repository | That repository's docs: README, `docs/`, an RFC/ADR through [write-docs](../../write-docs/SKILL.md) | Propose the edit; add a one-line pointer in its `AGENTS.md` only when every session needs the fact |
| 7 | A fact about several repositories of one hub | The hub's instruction file | A one-line rule, or a one-line pointer to the doc that holds the detail |
| 8 | Too long for one line, and owned by no repository | `<hub>/wiki/<topic>.md`, created on first need | Link the page from the hub's instruction file with one line that says when to read it |
| 9 | A rule for every context on the machine (safety, shell, tooling) that no check can enforce | The user-level instruction file | One line; prefer a check (row 3) when one is possible |

## Coding standards

`CODING_STANDARDS.md` holds the judgement-call rules a reviewer applies to a diff. It stays out of
`AGENTS.md`: the implementing agent already carries the most context, while the reviewer reads the
diff. When the file does not exist yet, also add this line to the repository's `AGENTS.md`, so a
review command that reads `CLAUDE.md` (which imports `AGENTS.md`) finds the standards:

```text
Review changes against `CODING_STANDARDS.md`.
```

## Rules

- Propose every edit to the user and apply it only when the user agrees.
- Agent memory (a per-machine or per-agent memory file) is none of these places: other agents and
  other machines never read it. Use it only when the user asks for it.
- In a wiki page, date each claim about code, or cite the commit it held at: the page goes stale
  while the code moves.
- Follow [../SKILL.md](../SKILL.md) for the wording of every line you add.
