# Spec template

Write this to `spec.md` in the draft folder. Replace each `<...>` field. Keep every section; write
`None.` in a section that has nothing. The first line is the issue title: `scripts/publish-tickets.sh`
reads it.

```markdown
# <spec title: the outcome, 4 to 10 words>

## Problem

<what is wrong or missing today, and who or what it affects, in 2 to 5 sentences>

## Behaviour

<what is observable once all tickets are done: commands, API responses, resources, pages, alerts>

- <one observable behaviour per line>

## Decisions

- <a decision already settled, with its reason in one clause>
- <link to each ADR, RFC or issue that holds a decision>

## Test seams

- <seam confirmed with the user>: <what a test drives there and what it checks>

## Out of scope

- <work this spec does not do, and where it goes instead when known>
```

- Name modules, interfaces, resources and contracts. Leave out file paths and code: they go stale.
  A schema, state machine or type shape a prototype produced may stay, trimmed to the lines that
  carry the decision, with the note `(from a prototype)`.
- Write no "Tickets" section: on GitLab the script appends the ticket task list itself.
