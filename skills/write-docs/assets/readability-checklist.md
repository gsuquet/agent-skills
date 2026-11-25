# Readability checklist

The script cannot check these. Mark each item pass or fail; every item must pass.

## Repetition

- [ ] Each fact (number, decision, reason, name of a risk) is written once; every other place links
      to its heading. Exceptions: the front matter, the Summary table and the Decision section of
      an RFC.
- [ ] No text repeats what a visual or a table next to it shows.
- [ ] No section opens by announcing what it holds or closes by summing it up.

## Order

- [ ] RFC, ADR and concept: the decision, or the answer the reader came for, is on the first screen.
- [ ] Each piece of evidence, work package and design detail is one line and a link that was opened
      or created.
- [ ] Decision history (dates of sub-decisions, earlier drafts) is left to Git.

## Visuals

- [ ] Each visual answers one question, and no sentence of 25 words or fewer answers it.
- [ ] Each state, class, ER, Gantt, architecture, D2, SVG or Excalidraw diagram meets the node, edge
      and label limits of a flowchart, counted by hand.
- [ ] Each caption states a takeaway that can be wrong. "Architecture of the system" fails; "One
      queue separates the shop from the carrier" passes.
- [ ] Each colored diagram has a one-line legend with the words new, changed, removed, unchanged,
      external, and the colors match.

## Names

- [ ] Each code allowed with `--allow-code` or an allow-code comment is a real name.
- [ ] Each cross-reference is a link to a heading with a readable name.
