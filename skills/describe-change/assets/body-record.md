# Body template for docs and decision records

The title and the rules before the body are those of [body.md](body.md): read it first. Use the
`docs` type in the title. Name the doc or record by its path in backticks instead of copying its
text.

````markdown
## Summary

<one or two sentences: what a reader can now do or know, or what is decided; the path of the doc or record>

<the visual from references/visuals.md>

## Decision

**Status:** <status in the record, and the status after merge when it differs>

**Deciders:** <who accepts or rejects>, <"by <YYYY-MM-DD>", "no deadline" or "decided on <YYYY-MM-DD>">

**Asked of the reviewer:** <the choice to approve, in one line>

## Evidence

- **Checked:** <each check with its result: commands of the doc you ran, claims compared with the source, links, lint>
- **Not checked:** <commands marked untested, figures without a source, assumptions>

## Merge danger

**Door:** <one-way | two-way>: <what undoing the decision once applied takes, in one line>

**Blast radius:** <who acts on this text, and what breaks for them if it is wrong>

**Rollback:** <for a doc or an undecided record: "Revert the PR."; for a decided record: "Supersede with a new record."; then the steps that undo the decision once applied>
````

- A change with no decision record (a how-to, a README, a runbook) has no Decision section and no
  Door line: remove both. A change to a record that leaves the decision as it is (typo, link,
  implementation log) removes them too.
- The door is that of the decision, not of the file: take it from the record (`reversibility:` in an
  RFC) when it says so.
- Lint proves the format only: list it last.
