# Workflow engines

Read this in step 5 to pick how to launch the briefs. Both engines run a script that starts agents
outside the main session's context, with a JSON Schema per agent. The skill's own scripts
(`check-brief.sh`, `check-report.sh`, `report-to-md.sh`) are the same under every engine.

## Pick

1. 3 or more independent tasks and the agent has a workflow engine: run the template for it.
2. Otherwise, when the agent can launch subagents: launch them (below). Below 3 tasks, a workflow
   costs more tokens than subagents for the same work.
3. Otherwise: run the tasks yourself, one at a time (SKILL.md, after step 11).

## Claude Code: dynamic workflows

- Template: [../assets/workflow.js](../assets/workflow.js). Run it with the Workflow tool, `scriptPath`
  set to the template's absolute path, `args` set to `{schema, tasks}` as its header says. Pass
  `args` as a JSON value, not a string.
- The script runs JavaScript with `agent()`, `pipeline()`, `parallel()`, `phase()`, `log()` and
  `args`. It has no file system: the schema travels in `args`.
- `pipeline()` runs items concurrently, each through all its stages.
- Opt-in: a skill that tells the agent to run a workflow counts as the user's opt-in. On the Pro
  plan, the user turns workflows on in `/config`.
- The template does not set `isolation: 'worktree'`: the brief names the worktree, so the main
  session knows the path to pass to `check-report.sh -C`.
- Docs: <https://code.claude.com/docs/en/workflows>.

## Antigravity: dynamic workflows (unverified)

Taken from <https://antigravity.google/docs/dynamic-workflows>; the template has not run yet.

- Template: [../assets/workflow.py](../assets/workflow.py). Run it with
  `/run-workflow Run <path of workflow.py>` and pass `{schema, tasks}` as its args. How the main
  agent passes `args` is not stated in the docs (unverified).
- The script runs Python with `agent()`, `parallel()`, `pipeline()`, `phase()`, `log()` and an
  `args` dict, with no import line. Available on the Google AI Pro and Ultra plans.
- `pipeline()` runs items one at a time; `parallel()` runs them concurrently and cancels every item
  when one raises. The template catches each task's errors for that reason.
- How a script returns a value is not stated: the template logs one `RESULT <json>` line per task.
- `workspace` is `inherit` (default), `branch` (one git worktree per agent) or `share`. Whether the
  worktree path is reported back is not stated, so the template leaves the worktree to the brief.
- The "Orchestrator" model (Neon, Carbon, Argon) is not a workflow engine: it pairs a planner and an
  executor model inside one agent. It changes nothing in this skill.

## Wake timer

Read this in step 6. The main session gets a turn only when the user writes or a background task
ends, so a stalled agent goes unnoticed without a timer. Keep one timer: start it at the first
launch, and start it again only on the wake its own end causes, while a task runs. A wake from the
user or from a finished agent leaves the running timer alone.

- Claude Code: run `sleep 900` with the Bash tool's `run_in_background` and a `timeout` of 960000
  ms. The session gets a turn when it exits. In an unattended session (`-p`, Agent SDK, cloud), a
  background command stops at its time limit: 30 minutes by default, 10 minutes in a `-p` run with a
  text prompt, or the `timeout` passed, up to 2 hours
  (<https://code.claude.com/docs/en/tools-reference#time-limit-for-background-commands>). A stop
  notice at that limit is the timer's end too.
- Antigravity (unverified): no wake mechanism was checked. Without one, check on quiet agents at each
  user turn, and tell the user that the check runs only then.

## Subagents

- Claude Code: the Agent tool, in the background; one per brief.
- Antigravity: the `invoke_subagent` tool; subagents run concurrently and start with a clean
  context (<https://antigravity.google/docs/subagents>).
- The subagent's final message is its report in the brief's markdown Report format.
