---
name: write-skill
description: Write or change an agent skill in the agent-skills repository so that it works in Claude Code, Antigravity and other agents that read SKILL.md. Use when the user asks to add, edit, split or review a skill there.
metadata:
  version: 0.1.0
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
metadata:
  version: 0.1.0        # semantic version: a new skill starts at 0.1.0
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
- Link another skill with a relative path to its `SKILL.md` (`../<name>/SKILL.md`):
  `install.sh` installs the linked skills too, and lint fails on a link to a missing skill.
- Do not hard-code a path of one machine or one agent: use paths relative to the skill folder.
- Never write a client or employer name, a secret, or personal data: the repository is public.
- Keep the evidence for improving a skill in `skills/<name>/FEEDBACK.md`, one line per correction:
  `YYYY-MM-DD | <version> | <what went wrong> | <PR, MR or commit URL, or ->` (the repository is
  public: never a session URL or a local path). [run-retro](../run-retro/SKILL.md) appends these lines. A change to a skill cites, in its commit message
  and PR description, the FEEDBACK lines it addresses.

## Finish

1. Update `.claude-plugin/marketplace.json`:
   - New skill: run `mise run marketplace`.
   - Changed skill: run `mise run bump -- <name> --level <patch|minor|major>` (`minor` for a
     `feat`, `major` for a breaking change), which raises `metadata.version` and regenerates the
     marketplace. Commit the bump with the change.
2. Run `mise run lint`.
3. Try the skill: `./install.sh --agent claude <name>`, then start a new session.
