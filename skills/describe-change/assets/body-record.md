# Body template for docs and decision records

The title and the rules before the body are those of [body.md](body.md): read it first. Use the
`docs` type in the title. Name the doc or record by its path in backticks instead of copying its
text.

````markdown
## Summary

<one or two sentences: what a reader can now do or know, or what is decided, and why; the path of the doc or record>

<the visual from references/visuals.md>

## Decision

**Status:** <status in the record; what must change before the merge while it is undecided>

**Deciders:** <who accepts or rejects>, <"by <YYYY-MM-DD>", "no deadline" or "decided on <YYYY-MM-DD>">

**Asked of the reviewer:** <the choice to approve, in one line>

## Links

- **<Ticket | Record | Doc | Related | Pipeline | Dashboard>:** [<title or number>](<full URL>)

## Evidence

- **Checked:** <each check with its result: commands of the doc you ran, claims compared with the source, rendered page, links (also inbound ones to a moved or deleted page), index or navigation entry, lint>
- **Not checked:** <commands marked untested, figures without a source, assumptions; remove the line when there is nothing>

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
- The record that this one supersedes is a `Record` link.
- Lint proves the format only: list it last.
