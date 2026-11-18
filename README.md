# agent-skills

Agent skills in the [Agent Skills](https://agentskills.io) format, one folder per skill in
[`skills/`](skills/). The same folders work in Claude Code, Antigravity and other agents that read
`SKILL.md`.

## Install in Claude Code

The repository is a plugin marketplace. Each skill is a plugin, and the `all` plugin holds every skill.

```bash
claude plugin marketplace add gsuquet/agent-skills

claude plugin install all@gsuquet-skills          # every skill
claude plugin install write-skill@gsuquet-skills  # one skill
```

Install `all` or single skills, not both: a skill would load twice. Plugin skills are invoked as
`/<plugin>:<skill>`, for example `/all:write-skill`.

Update: `claude plugin update <plugin>@gsuquet-skills`, or enable auto-update for the marketplace in
`/plugin` > Marketplaces.

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
mise run marketplace  # regenerate .claude-plugin/marketplace.json
mise run lint
```

## Credits

The visual summary of `describe-change` follows the idea of Dex Horthy's [`show-me`](https://github.com/humanlayer/skills) skill.

## License

[MIT](LICENSE)
