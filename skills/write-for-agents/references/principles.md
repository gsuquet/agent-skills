# Principles

Read the section that a failing checklist item names. Each section gives the concept, then the fix.

## Pointers

A **pointer** is a line that stays in the agent's context and names material outside it: a skill
description, or a line in `AGENTS.md` that links to a doc. The wording of the pointer, not the
content of the target, decides whether the agent reads the target. A needed doc behind a vague
pointer is read on some runs and skipped on others.

- State what the material is, then list each distinct case that should trigger it. A case is a
  different path through the material, not another word for the same path.
- Put the task word first: it does the triggering.
- A pointer loads on every turn, so prune it harder than any body text. Cut what the body already
  says.
- Fix a skipped target by sharpening the pointer first. Move the material inline only when a sharper
  pointer still fails.

## Context load and cognitive load

Every file and pointer costs one of two budgets:

- **Context load**: text that sits in the agent's context on every turn (instruction files, skill
  descriptions), whether it applies or not.
- **Cognitive load**: what the human must remember (which docs exist, when to invoke what). Spend it
  where human judgement matters, nowhere else.

Material behind a pointer costs only the pointer line. Material without any pointer relies on the
human to remember it.

## Hierarchy

Text holds two kinds of content: **steps** (ordered actions) and **reference** (definitions, rules,
facts read on demand). Place each piece on a ladder, from most to least immediately needed:

1. Steps in the main file.
2. Reference in the main file. A flat list of rules on one level is fine.
3. Reference in a linked file, read only when its pointer fires.

**Progressive disclosure** moves reference down the ladder to keep the steps visible. The test is
branching: keep in the main file what every run needs; link what only some runs need. Reference left
inline buries the steps, and the agent follows them on some runs only.

**Co-location**: once a piece has its level, keep its definition, rules and exceptions together
under one heading. Scattering one idea over several sections is a different failure from repeating
it.

**Sprawl** is a file too long even when every line is useful: attention thins. Fix it with the
ladder: link reference out, or split by branch.

## Completion criteria

Every step ends on a **completion criterion**: the condition that tells the agent the step is done.

- **Clarity**: the agent can tell done from not done. A vague criterion ("once you understand the
  issue") invites premature completion, because the later steps pull the agent forward. Sharpen the
  criterion first. When it cannot be sharpened and the agent still rushes, split the later steps into
  another file or a sub-agent, behind a real context boundary.
- **Demand**: how much work the criterion asks for. "Every changed file reviewed" forces the work;
  "a list of changes" does not. Demand also binds reference: "every rule applied" makes a flat rule
  list exhaustive.

The best criterion is both checkable and exhaustive.

## When to split

Splitting a file in two adds a pointer (context load) or a thing to remember (cognitive load). Split
only when it pays:

- **By sequence**: when later steps make the agent rush the current one, move them out of view.
  Merging two sequences has the opposite effect.
- **By trigger**: make a separate skill when a distinct trigger word should load it on its own, or
  another skill must link to it.

## Leading words

A **leading word** is a short word the model already understands that stands for a whole behaviour:
*tight* for a fast, deterministic loop, *red* for a check that fails on the bug. Reuse the word, not
a paraphrase, every time the idea comes back. It costs fewer tokens and the agent applies the same
behaviour at each use. Prefer an existing word to a coined one: a coined word must be defined.

Look for a phrase repeated in several places, or a sentence that circles one idea: replace it with
one leading word.

## Positive instructions

A prohibition names the unwanted behaviour and makes it more likely. Write the target behaviour
instead ("write one-line comments"). Keep a prohibition only for a hard guardrail that has no
positive form, and put the action to take next to it.

## Pruning

- **Single source of truth**: each rule lives in one place. A copy costs tokens, drifts, and makes
  the rule look more important than it is.
- **The environment is a source of truth**: `package.json`, config files, the directory layout and
  `--help` already hold their facts. Restating them creates a cache that goes stale. Write down only
  what looking does not reveal: the unwritten convention, the reason for a choice, the gotcha.
- **Relevance**: each line must still apply to what the text does today. Lines that no longer apply
  pile up as sediment, because adding feels safe and deleting feels risky. Delete them.
- **No-ops**: a sentence that tells the model what it already does changes nothing. Test it against
  the default behaviour, by running the text when in doubt. Delete the whole sentence. When a leading
  word is too weak to change the default, replace it with a stronger word.
