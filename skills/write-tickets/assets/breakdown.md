# Breakdown template

Send this as one message, then stop and wait for the user's corrections. Replace each `<...>` field.
Write nothing before the first line.

```markdown
**<spec title, or the work in one line when there is no spec>** - tracker: <github | gitlab | jira <KEY> | none yet>

1. **<ticket title>**
   - Blocked by: <ticket numbers, or None>
   - Behaviour: <what works once it is done, one sentence>
   - Fails at base: <the acceptance criterion that proves it, one line>

2. **<ticket title>**
   - ...

Check: granularity (merge or split?), blocking edges (does each one really gate the ticket?),
anything missing. Answer `ok` to write the drafts, or give corrections by number.
```

- Number tickets from 1 in dependency order: each blocker comes before the tickets it blocks.
- Mark a prefactor ticket with `(prefactor)` after its title, and the tickets of an expand-contract
  sequence with `(expand)`, `(migrate)` or `(contract)`.
