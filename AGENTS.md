# AGENTS.md

This file is the single set of instructions for all coding agents in this repository. `CLAUDE.md`
and `GEMINI.md` import it. Do not put instructions in those files.

## About this repository

Agent skills in the [Agent Skills](https://agentskills.io) format (`skills/<name>/SKILL.md`),
installable in Claude Code (plugin marketplace) and in other agents (`install.sh`). See `README.md`.

## Rules

1. This repository is public. Never write a client or employer name, a secret or personal data, in
   files, commit messages or PR text. `scripts/check-skills.sh` checks a private word list.
2. Follow the `write-skill` skill (`skills/write-skill/SKILL.md`) to add or change a skill.
3. Do not edit `.claude-plugin/*.json` or `plugins/`, they are generated: run `mise run marketplace`.
4. Bump the skill's version (`mise run bump -- <skill>`) in every change to a skill; lint enforces it.
5. Run `mise run lint` before you commit. The `Lint` workflow runs the same task.
6. Write commit messages and PR titles as Conventional Commits (`feat(write-skill): ...`).
7. Pin each dependency to an exact version: a commit SHA for GitHub Actions and pre-commit hooks.

## Push and merge limits

- Push only branch refs, and only to `github.com/gsuquet/`. Never push to `main`.
- Never merge a PR (`gh pr merge`), also not with `--auto`.
- Never force-push in any form, never push tags, never delete remote refs, never use `--no-verify`.
- When a hook or a check refuses an action, stop and report it.
