# Ticket template

Write one file per ticket, `NN-<slug>.md` in the draft folder, `NN` being its number in the approved
breakdown, on two digits. Replace each `<...>` field. `scripts/publish-tickets.sh` reads the first
line as the issue title and rewrites the `Blocked by:` line with the issue references: keep both
lines exactly in this shape.

```markdown
# <title: the behaviour this ticket makes work, 4 to 10 words>

Blocked by: <draft numbers, comma-separated, for example 01, 03; or None>

## Behaviour

<the end-to-end behaviour that works once this ticket is done, in 1 to 4 sentences>

## Acceptance criteria

- [ ] <a check that fails at the base commit and passes once this ticket is done>

## Notes

<decisions, constraints and seams from the spec that this ticket needs, or None.>
```

- Each blocker has a smaller number than the ticket it blocks.
- Write each acceptance criterion as a command, test or observation an agent runs, with the result
  it expects.
- Leave out file paths and code, as in the spec.
