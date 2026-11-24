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
- Name another ticket of the batch as `ticket NN` (`tickets 02 and 05`): the script rewrites it to
  the issue reference once every ticket is published, so the drafts stay tracker-neutral.
- Write a reference outside the batch (a merge request, an existing issue) as a Markdown link with
  its full URL, for example
  `[MR !12](https://gitlab.example.com/example-group/app/-/merge_requests/12)`: a short form such as
  `!12` or `#12` links only on its own forge.
