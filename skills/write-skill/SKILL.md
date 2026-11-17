---
name: write-skill
description: Write or change an agent skill in the agent-skills repository so that it works in Claude Code, Antigravity and other agents that read SKILL.md. Use when the user asks to add, edit, split or review a skill there.
---

# Write a skill

A skill is a folder `skills/<name>/` with a `SKILL.md` file. Every supported agent reads the same
folder, so keep the skill portable.

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

- Give the steps, the rules and the expected output. Do not explain what the agent already knows.
- Keep `SKILL.md` short. Move long references to `references/`, templates to `assets/`, and code to
  `scripts/`, and link them with a relative path. Scripts print `--help` and fail with a clear message.
- Do not hard-code a path of one machine or one agent: use paths relative to the skill folder.
- Never write a client or employer name, a secret, or personal data: the repository is public.

## Finish

1. Run `mise run marketplace` to add the skill to `.claude-plugin/marketplace.json`.
2. Run `mise run lint`.
3. Try the skill: `./install.sh --agent claude <name>`, then start a new session.
