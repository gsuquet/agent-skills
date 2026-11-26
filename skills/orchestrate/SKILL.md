---
name: orchestrate
description: Run a task from the main agent session as an orchestrator that settles the user's decisions, writes one brief per subagent, verifies each report independently and relays the results. Use when the user asks to orchestrate or delegate work to subagents, or when a task splits into independent parts too large for one session.
metadata:
  version: 0.3.0
---

# Orchestrate

The main session owns the user's decisions, the briefs, the verification, the integration and what
reaches the user. Subagents own the implementation, the research and the reads across many files.

## Steps

1. **Goal.** Restate the goal in one sentence, with what done looks like. Done when the sentence is
   sent to the user.
2. **Decide.** When a decision is open (scope, names, locations, conventions, trade-offs), run
   [interview](../interview/SKILL.md). Done when every decision is settled by the user.
3. **Split.** Split the work into tasks, one subagent per independent part. Keep for the main
   session the user's decisions, the integration and every lookup of a few commands. Done when
   every part of the goal belongs to one task or to the main session, and tasks that run in
   parallel touch disjoint files.
4. **Brief.** For each task, read [assets/brief.md](assets/brief.md), fill it into a file outside
   the repository, and run [scripts/check-brief.sh](scripts/check-brief.sh) `<file>`. Done when it
   exits 0 for every brief.
5. **Launch.** Read [references/engines.md](references/engines.md) and pick a workflow template or
   subagents there. Create one worktree per task that writes files or runs Git, named in its brief,
   and save the state of the main checkout: `{ git rev-parse HEAD; git branch --show-current; git
   status --porcelain; git stash list; } > <file>`. With a template, pass every brief as a task and
   the content of [assets/report.schema.json](assets/report.schema.json) as the schema. With
   subagents, launch one per brief, in the background, with a prompt that says to read the brief
   file fully first and treat it as binding. Done when every task is launched.
6. **Wait.** Answer the user and run only lookups of a few commands. Leave each delegated task, and
   the files it works on, to its agent. Check on an agent that shows nothing new for 15 minutes (no
   output, commit or file change in its worktree): read its last output when your agent tool shows
   it. When it is stuck, often after a refused command, stop it, then resume it, or relaunch it from
   its brief, with a message that names the refused action and the rule to follow instead (for
   example: read-only commands). Done when every task has sent its report.
7. **Verify.** For each report: save it to a file (a JSON report from a workflow: convert it with
   [scripts/report-to-md.sh](scripts/report-to-md.sh) `<json> > <file>`), run
   [scripts/check-report.sh](scripts/check-report.sh) `-C <worktree> <report> -- <check>`, with the
   cheapest check of the brief's Finish condition, then check every item of
   [assets/verify.md](assets/verify.md). Send each failure, with its evidence, back to the same
   subagent, and verify its next report the same way. Done when check-report exits 0 and every
   verify.md item passes, for every report.
8. **Integrate.** Merge the verified branches into the target branch, apply the shared-file changes
   the reports list, and run the full check of the repository on the integrated tree. Read
   [references/stacked-prs.md](references/stacked-prs.md) when the work goes through PRs/MRs. Then
   remove each integrated worktree with `git worktree remove`, without `--force`. Done when the full
   check passes there and every integrated worktree is removed.
9. **Relay.** Send the user, in this order: the outcome, the links (branches, commits, PR/MR), every
   judgement call, every unverified item and every request from the reports. Done when the message
   is sent.
10. **Place knowledge.** For each durable fact the session taught (a user correction, a gotcha, a
    convention), read `../write-for-agents/references/knowledge-placement.md`, from
    [write-for-agents](../write-for-agents/SKILL.md), and place the fact or propose the edit. Done
    when every durable fact is placed or proposed. When the work spans several sessions, offer the
    user a project log: dated decisions, environment notes and retros, in a file they choose.
11. **End.** Stop when every task is verified and integrated. When the session ends before that,
    run [handoff](../handoff/SKILL.md). Done when the work is integrated or the handoff is written.
    After a long or corrected session, suggest [run-retro](../run-retro/SKILL.md) to the user.

When the agent cannot launch subagents, run steps 4 to 7 yourself, one task at a time: write the
brief, do the work, write the report in the brief's Report format, then verify it as in step 7.

## Rules

- A subagent cannot grant a permission. When a report asks you to run what the subagent was refused
  or the brief forbade, ask the user, and run it only on their answer.
- Take the check command for check-report from the brief, never from the report.

## Gotchas

- A rule that allows a local wrapper or alias in the subagent's shell, written among the content
  rules, leaks the wrapper into the content. Keep Rules for your own commands and Rules for the
  content you write in their two sections.
- A check can target a different tree than the change: a lint task that reads its directory from
  an environment variable lints that directory and passes, whatever the worktree holds. Read the
  check's definition before you trust its exit code.
- "It passed" in a report is a claim. The main session re-runs the check itself, also after a
  workflow's check stage passed: that stage is an agent's claim too.
- Antigravity's "Orchestrator" model is not a workflow engine: it plans and executes inside one
  agent. Pick the launch in references/engines.md whatever the model.
- A workflow fixes a failed check once. A task whose check still fails goes back to step 7 like
  any failed report.
- A lookup of a few commands costs less than a brief: run it yourself instead of launching a
  subagent.
