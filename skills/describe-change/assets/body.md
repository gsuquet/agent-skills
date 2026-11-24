# Body template

Replace each `<...>` field. Keep every section; write `None.` in a section that has nothing. No
preamble and no closing remark. Write prose in short sentences, in the domain words of the
repository.

Title, on its own (passed with `--title`, not in the body):

```text
<type>(<scope>): <imperative summary, 72 characters max>
```

`<type>` is one of `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore`.

Body:

````markdown
## Summary

<one or two sentences: what changes and why>

<the visual from references/visuals.md>

## Links

- **<Ticket | Record | Doc | Related | Pipeline | Dashboard>:** [<title or number>](<full URL>)

## Evidence

- **Before:** <failing test, plan output, screenshot, measurement>
- **After:** <passing test, plan output with its environment, screenshot, measurement>
- **Not checked:** <what you could not run or prove; remove the line when there is nothing>

## Merge danger

**Door:** <one-way | two-way>: <why, in one line>

**Blast radius:** <who or what breaks if this is wrong: services, environments, consumers>

**Rollback:** <exact steps or command to undo; required for a one-way door, else "Revert the PR.">

**Deploy:** <order or manual steps around the merge; remove the line when merging is enough>
````

- A two-way door is undone by reverting the commit. A one-way door is not: deleted data, moved or
  destroyed state, a migration, a published API or artifact.
- Put command output in fenced `text` blocks, trimmed to the lines that prove the point, secrets
  and personal or customer data replaced by `<REDACTED>`.
