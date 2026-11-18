---
name: write-skill
description: Write or change an agent skill in the agent-skills repository so that it works in Claude Code, Antigravity and other agents that read SKILL.md. Use when the user asks to add, edit, split or review a skill there.
---

# Write a skill

A skill is a folder `skills/<name>/` with a `SKILL.md` file. Every supported agent reads the same
folder, so keep the skill portable. Follow the
[Agent Skills best practices](https://agentskills.io/skill-creation/best-practices).

## First step

Before anything else, read [write-for-agents](../write-for-agents/SKILL.md) and follow it for everything the agent reads:
the description, `SKILL.md` and the linked files. This skill adds only the rules specific to the
skill format.

## Frontmatter

```yaml
---
name: <name>            # equals the folder name: kebab-case, 64 characters max
description: <one line> # what the skill does, then "Use when ...": 1024 characters max
---
```

- Write the description on one line. The agent reads only the description to decide when to load
  the skill: name the task, the trigger words and the limits.
- Add an agent-specific field (for example Claude Code `allowed-tools`) only when the skill needs it.
  Other agents ignore unknown fields, so the skill must still work without it.

## Body

- Put templates in `assets/`, long references in `references/` and code in `scripts/`, one level
  deep, and link them with a relative path. Scripts print `--help` and fail with a clear message.
- Keep gotchas in `SKILL.md`, under `## Gotchas`.
- Link another skill with a relative path to its `SKILL.md` (`../<name>/SKILL.md`).
- Do not hard-code a path of one machine or one agent: use paths relative to the skill folder.
- Never write a client or employer name, a secret, or personal data: the repository is public.

## Finish

1. Run `mise run marketplace` to add the skill to `.claude-plugin/marketplace.json`.
2. Run `mise run lint`.
3. Try the skill: `./install.sh --agent claude <name>`, then start a new session.
