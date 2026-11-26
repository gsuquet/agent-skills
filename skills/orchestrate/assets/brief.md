# Brief template

Copy the block below into one file per task, outside the repository. Replace each `<...>` field and
keep every section: write `None.` in a section that has nothing, except Goal, Finish condition and
Report format. Write literal angle brackets (a `<hub>` placeholder, a command argument) inside
backticks: `scripts/check-brief.sh` reads a bare `<...>` as an unfilled field. Write for an agent
that has not seen this session: no "as discussed", no "the above".

````markdown
# Brief: <task name>

## Goal

<what the task produces and why, in 1 to 3 sentences>

## Settled decisions (do not reopen)

- <decision>: <reason>

## Facts already found

- <fact> (source: <path, URL or command that shows it>)

## Rules for the content you write

- <rule for the files, text or code the agent produces: conventions, forbidden words, format>

## Rules for your own commands

- Run Git only in the worktree below, with `git -C <worktree path>` or after a `cd` in the same command.
- Never bypass a hook (`SKIP=`, `--no-verify`): when one fails, stop and report its full output.
- No push and no Git `--force` or `-f`, in the worktree and in every repository you create, a
  scratch or bare one included: list a step that needs one under Requests.
- <rule for the commands the agent runs: allowed tools, network, installs>

## Files you may and may not touch

- May touch: <paths, or a folder>
- May not touch: <paths: shared files the main session integrates>
- Worktree: <path, already created> on branch <branch>, created from <base commit>

## Finish condition

1. <checkable condition: a command that exits 0, a grep that finds nothing>

## Report format

Send this as your final message, not as a file. Write `None.` in a section that has nothing.

```markdown
## Outcome

<done, partly done or blocked, and why, in one sentence>

## Links and paths

- <branch, worktree, commit SHA, PR/MR URL, each file changed or source read>

## Checks

- `<command>` -> <pass | fail: the exact failing output>

## Judgement calls

- <decision the brief did not cover, and the choice made>

## Unverified

- <claim not checked, and why>

## Requests

- <action you were refused or could not take, for the main session to raise with the user>
```
````

- Rules for the content you write and Rules for your own commands stay two sections: a rule that
  only allows a command in the agent's shell, written next to content rules, leaks into the content.
- The Finish condition names at least one check the main session can re-run itself in seconds.
- Facts already found saves the agent from finding them again: give each one its source.
