# Report template

Print this as the report of step 7. Replace each `<...>` field. Keep every section; write `None.` in
a section that has nothing. Redact every secret as `<REDACTED>`.

````markdown
## Retro: <repo or folder> - <session id, or "current session">

**Agent:** <Claude Code | Antigravity> · **Moments:** <n> · **Candidates:** <n>

**Scanned:** <each instruction file and skill read in step 4, by path>

## Moments

| # | When | Kind | Quote |
|---|---|---|---|
| M1 | <timestamp or turn> | <correction / failed / denied / retry / search / interrupt / wrong assumption> | <one line, redacted> |

## Candidates

### 1. <one-line title>

- **Category:** <a heading of references/categories.md>
- **Evidence:** <M1, M4>: "<the quote that shows the problem>"
- **Change:** <add / change / move / delete>: <the exact line, rule or check as it would be written>
- **Target:** `<file path>` (targets row <n>)
- **Kind:** <mechanical | judgement>
- **Severity:** <high | medium | low>: <why, in one clause>
- **Effort:** <S: under 15 minutes | M: under 2 hours | L: more>

## Skills to rework

| Skill | Version | Feedback lines at this version |
|---|---|---|
| <skill> | <version> | <n> |

## Feedback lines

- `<skill>`: `<what went wrong>` | `<PR, MR or commit URL, or ->`
````

- One candidate block per candidate, numbered in the rank order of step 6.
- Every candidate cites at least one moment of the Moments table.
- Skills to rework holds the output of `scripts/feedback.sh rework`.
- Feedback lines holds one line per candidate that step 8 logs.
