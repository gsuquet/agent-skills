# Handoff template

Replace each `<...>` field. Keep every section; write `None.` in a section that has nothing. Write
for a reader who has not seen this session: no "as discussed", no "the above".

````markdown
# Handoff: <repo> - <one-line goal>

## Goal

<what the work is for and what done looks like, in 1 to 3 sentences; the focus of the next session
when the user gave one>

## State

- **Repository:** <path or URL>
- **Branch:** <branch> (<pushed | local only>)
- **PR/MR:** <URL> | None.
- **Tests and lint:** <command> -> <pass | fail: the failing test or error>
- **Uncommitted changes:** <files> | None.

## Decisions made (do not reopen)

- <decision>: <reason>

## Next steps

1. <action> - done when <checkable end condition>

## Open items

- <question or risk not settled, and who can settle it>

## Artifacts

- <path or URL> - <what it holds>

## Skills to read

- `<skill>/SKILL.md` in the skills folder, for example `diagnose/SKILL.md` - <when to use it>
````

- Next steps are ordered; each one has an end condition the next agent can check.
- Artifacts are links and paths only, never copied content.
- Skills to read lists only skills the next steps need.
