# agent-skills

Agent skills in the [Agent Skills](https://agentskills.io) format, one folder per skill in
[`skills/`](skills/). The same folders work in Claude Code, Antigravity and other agents that read
`SKILL.md`.

## Skills

| Skill | Use it to |
| ----- | --------- |
| [`interview`](skills/interview/SKILL.md) | settle every decision of a plan in rounds of questions |
| [`orchestrate`](skills/orchestrate/SKILL.md) | run a session as an orchestrator of subagents |
| [`diagnose`](skills/diagnose/SKILL.md) | find a bug's cause from a check that reproduces it |
| [`describe-change`](skills/describe-change/SKILL.md) | write a PR or MR body |
| [`write-tickets`](skills/write-tickets/SKILL.md) | split work into tickets on GitHub, GitLab or Jira |
| [`write-docs`](skills/write-docs/SKILL.md) | write human docs, RFCs and ADRs |
| [`write-for-agents`](skills/write-for-agents/SKILL.md) | write anything an agent reads |
| [`write-skill`](skills/write-skill/SKILL.md) | add or change a skill in this repository |
| [`handoff`](skills/handoff/SKILL.md) | hand a session over to another agent |
| [`run-retro`](skills/run-retro/SKILL.md) | propose improvements after a session |

## Install in Claude Code

The repository is a plugin marketplace named `gsuquet`. Each skill is a plugin with its own version,
and the `gs` plugin installs them all.

```bash
claude plugin marketplace add gsuquet/agent-skills

claude plugin install gs@gsuquet           # every skill
claude plugin install write-skill@gsuquet  # one skill
```

Both ways, a skill is invoked as `/gs:<skill>`, for example `/gs:write-skill`. `claude plugin list`
shows the version of each skill. A skill installed by `gs` cannot be disabled alone: to leave some
out, install single skills instead.

Update every installed skill: in `/plugin` > Marketplaces > `gsuquet`, choose **Update marketplace**, or
turn on auto-update (off by default for third-party marketplaces such as this one). From a shell,
`claude plugin update gs@gsuquet` only adds new skills; to update the skills too:

```bash
claude plugin marketplace update gsuquet
claude plugin list --json | jq -r '.[].id | select(endswith("@gsuquet"))' | xargs -n 1 claude plugin update
```

Uninstall everything: `claude plugin uninstall gs@gsuquet`, then `claude plugin prune`.

### Migrate from `gsuquet-skills`

The marketplace was named `gsuquet-skills`, its bundle `all`, and skills were invoked as
`/all:<skill>` or `/<skill>:<skill>`. Replace it; removing the marketplace uninstalls its plugins:

```bash
claude plugin marketplace remove gsuquet-skills
claude plugin marketplace add gsuquet/agent-skills
claude plugin install gs@gsuquet
```

Then rename `gsuquet-skills` in settings you keep elsewhere, such as dotfiles or a project's
`enabledPlugins`, and `/all:<skill>` in your own prompts and permission rules.

## Install in other agents

Clone the repository, then link the skills into the agent's skills folder:

```bash
git clone https://github.com/gsuquet/agent-skills.git ~/agent-skills
cd ~/agent-skills

./install.sh --list                           # available skills
./install.sh --all                            # every skill, Antigravity (default agent)
./install.sh --agent antigravity write-skill  # one skill
./install.sh --agent ~/.codex/skills --all    # any other skills folder
./install.sh --uninstall --all                # remove what install.sh installed
```

| `--agent` | Folder |
| --------- | ------ |
| `antigravity` | `~/.gemini/config/skills` (Antigravity App, CLI and IDE) |
| `claude` | `~/.claude/skills` (local development; prefer the marketplace) |
| `<dir>` | any folder that holds one folder per skill |

Installing a skill also installs the skills it links to, recursively: `write-skill` brings
`write-for-agents`. `--uninstall` removes only the skills you name.

Links follow `git pull`. Use `--copy` when an agent does not follow symbolic links. The script never
replaces a folder that it did not install.

## Add a skill

Follow [`skills/write-skill/SKILL.md`](skills/write-skill/SKILL.md), then:

```bash
mise run marketplace  # regenerate the plugin manifests
mise run lint
```

## Versions

Each skill carries a [semantic version](https://semver.org) in its frontmatter, the single source of
its version:

```yaml
metadata:
  version: 0.1.0
```

`mise run marketplace` copies it into the skill's plugin in `.claude-plugin/marketplace.json`, and
Claude Code updates that plugin only when the version changes
([version resolution](https://code.claude.com/docs/en/plugins/loading.md#versions-and-updates)). The
version of `gs` ends with a hash of the skill names: it changes only when a skill is added, renamed
or removed.

The `gs:` prefix is the `name` in the root `.claude-plugin/plugin.json`, which every skill plugin
shares ([entry name and manifest name](https://code.claude.com/docs/en/plugins/loading.md#entry-name-and-manifest-name)).
That file must not set a `version`: it would override the version of every skill.

Each skill plugin caches the whole repository, so a link to another skill resolves to that skill as
it was when the linking skill was last updated.

To bump a changed skill, run `mise run bump -- <skill>` (`--help` for the rules). It derives the
level from the Conventional Commits that changed the skill since `origin/main`: `fix` is a patch,
`feat(<skill>)` a minor, `!` or `BREAKING CHANGE` a major. `mise run lint` fails when a skill changed
but its version did not rise.

## Credits

The visual summary of `describe-change` follows the idea of Dex Horthy's [`show-me`](https://github.com/humanlayer/skills) skill.

## License

[MIT](LICENSE)
