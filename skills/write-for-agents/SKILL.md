---
name: write-for-agents
description: Write or review any text an agent reads, so that every run takes the same path through it. Use when writing or editing a skill, an AGENTS.md or CLAUDE.md, or a doc an agent reaches through a link.
metadata:
  version: 0.1.0
---

# Write for agents

The agent reads the text the same way whatever its packaging: a skill, an instruction file, or a doc
reached by a link. Write it so that the agent follows the same process on every run.

## Steps

1. **Draft.** Write the text. Put the ordered actions first as numbered steps, each with an end
   condition. Put definitions and rules that only some runs need in a separate file under
   `references/`, and fixed output formats under `assets/`. Done when every action the agent must
   take is written down.
2. **Review.** Read [assets/checklist.md](assets/checklist.md) and check the draft against every
   item. Read [references/principles.md](references/principles.md) only when an item fails and the
   fix is not obvious, or when the user asks why an item exists. Done when you have a verdict, pass or
   fail, for every item.
3. **Fix.** Fix each failing item, then go back to step 2. Done when every item passes.
4. **Prune.** Read every sentence and delete the ones that do not change what the agent does: they
   repeat another file, restate what a command or config shows, or tell the agent what it does by
   default. Delete the whole sentence, not words from it. Done when no sentence is left to delete.
5. **Recheck.** Run step 2 again on the pruned text. Done when every item still passes.

## Instruction files

- `AGENTS.md` is the single instruction file of a repository. `CLAUDE.md` and `GEMINI.md` hold one
  line, `@AGENTS.md`, and nothing else, so every agent reads the same rules.
- Keep an instruction file to what the agent cannot find by looking: conventions, reasons, gotchas.
  Link each longer doc with one line that says when to read it.
- Read [references/knowledge-placement.md](references/knowledge-placement.md) when you decide where a durable fact goes: a repository doc, a hub instruction file, a wiki page, a handoff, review rules or a check.

## Gotchas

- When the text is a skill, also follow [write-skill](../write-skill/SKILL.md) for the frontmatter
  and the folder layout.
- A link without a "when to read" condition is read on every run or on none. Both are bugs.
