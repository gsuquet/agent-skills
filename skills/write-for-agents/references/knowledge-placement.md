# Knowledge placement

A **durable fact** is something a later session needs and cannot find by looking: a convention, a
user correction, a gotcha, a decision and its reason. Place each durable fact in one row of the
table, and in one place only:

1. When the fact is session state, a review rule or a mechanical rule, rows 4 to 6 decide, whatever
   its scope.
2. Otherwise its scope decides: rows 1 to 3.

The **hub** is the nearest ancestor directory of the repository, outside it, that holds a
`CLAUDE.md` or `AGENTS.md`. It groups the repositories of one context. Write `<hub>` for it in
public text.

| # | The fact is | Place it in | How |
|---|---|---|---|
| 1 | About one repository | That repository's docs: README, `AGENTS.md`, or an ADR through [write-docs](../../write-docs/SKILL.md) | Propose the edit to the user; apply it when the user agrees |
| 2 | About several repositories of one hub | The hub's instruction file | A one-line rule, or a one-line pointer to the doc that holds the detail |
| 3 | Too long for one line, and owned by no repository | `<hub>/wiki/<topic>.md`, created on first need | Link the page from the hub's instruction file with one line that says when to read it |
| 4 | Session state: progress, open items, next steps | A handoff document through [handoff](../../handoff/SKILL.md) | Only when the work continues in another session |
| 5 | A review rule that needs judgement | `CODING_STANDARDS.md` in the repository | The first time, add one pointer line to `AGENTS.md` that says when to read it |
| 6 | A mechanical rule a tool can check | An automated check: linter config, pre-commit hook, CI job, script | Add the check, not a sentence: the check runs on every change |

## Rules

- Agent memory (a per-machine or per-agent memory file) is none of these places: other agents and
  other machines never read it. Use it only when the user asks for it.
- In a wiki page, date each claim about code, or cite the commit it held at: the page goes stale
  while the code moves.
- Follow [../SKILL.md](../SKILL.md) for the wording of every line you add.
