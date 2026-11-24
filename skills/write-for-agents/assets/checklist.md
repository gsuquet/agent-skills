# Review checklist

Check the text against every item. Mark each one pass or fail. The text is done when every item
passes. The section in brackets names the part of
[../references/principles.md](../references/principles.md) that explains the item.

## Pointers [Pointers]

- [ ] The description, or the line that links to this text, starts with the task it covers, then
      lists each distinct case that should trigger it, once.
- [ ] The description holds no synonym that names a case already listed.
- [ ] Every linked file has a condition that says when to read it ("Read X when Y").

## Structure [Hierarchy]

- [ ] The ordered actions come first, as numbered steps.
- [ ] What every run needs is in the main file. What only some runs need is in a linked file.
- [ ] Fixed output formats are in `assets/`, long references in `references/`, repeated logic in
      `scripts/`, one level deep.
- [ ] Each concept has its definition, rules and exceptions under one heading.
- [ ] The main file fits on one screen of headings: no section is long enough to hide the steps.

## Steps [Completion criteria]

- [ ] Every step ends with an end condition the agent can check (a command run, a file written, a
      list with no item left).
- [ ] Each end condition asks for all of the work ("every changed file", "each hypothesis"), not a
      part of it.
- [ ] The skill ends on an explicit final step: an output template filled, a message sent, a stop.

## Wording [Leading words, Positive instructions]

- [ ] One word names each recurring idea, and the text reuses that word instead of rephrasing it.
- [ ] Rules say what to do. A prohibition appears only as a hard guardrail, and next to the action
      to take instead.

## Pruning [Pruning]

- [ ] Each rule lives in one file. Other files link to it instead of repeating it.
- [ ] The text does not restate what a command, a config file or `--help` already shows.
- [ ] Every sentence still applies to the current behaviour of the tool or the repository.
- [ ] Every sentence changes what the agent would do without it.
