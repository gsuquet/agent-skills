---
name: interview
description: Interview the user in rounds of numbered questions, each with a recommended answer, until every decision of a plan, design or idea is settled, then end with a decision summary and wait for confirmation. Use only when the user asks to be grilled or interviewed, or to stress-test or challenge a plan, design or decision. Do not start it on your own for a task that merely needs planning.
metadata:
  version: 0.2.0
---

# Interview

Reach a shared understanding of a plan before anyone acts on it. The user makes the decisions; you
find the facts.

## Model

- A **decision** is a question with one answer the user must choose.
- A decision is **ready** when every decision it depends on is settled and every fact it needs is
  known.
- A decision is **settled** when the user has answered it. Each answer can add, remove or change
  decisions: recompute the ready list after every round.
- A decision is **deferred** when the user keeps it open ("keep it open"). Record what would settle
  it, and do not ask it again. The decisions that depend on it are deferred too.
- A question is **open** when it was asked and its decision is neither settled nor deferred.

## Steps

1. Restate the goal of the interview in one sentence. Then list the decisions you can already see.
   Do not show this list unless the user asks.
2. Find the facts. For each fact a decision needs (files, configuration, tool output, docs), look it
   up: delegate to sub-agents when the agent has them, otherwise look it up yourself. Never ask the
   user for a fact you can find. A decision that waits for a fact is not ready.
3. Ask a round. Pick at most **5** ready decisions: the open questions of earlier rounds, oldest
   first, then those that unblock the most other decisions.
   Read [assets/round.md](assets/round.md) and follow it exactly. Leave the other ready decisions for
   a later round.
4. Stop and wait for the answers. Do not act on the plan between rounds.
5. Check each answer before you record it. If it contradicts a settled decision, or adds a security
   or correctness risk, say so at the start of the next message, with the specific problem and a fix,
   and ask again. Record the decision only when the user confirms or changes the answer.
6. Repeat steps 2 to 5 until no decision is left: no ready decision, no open question, no decision
   waiting for a fact, and nothing assumed in silence.
7. End. Read [assets/summary.md](assets/summary.md) and follow it exactly. Write it to a file only
   when the user asks.
8. Act on the plan only after the user confirms the summary. If the user corrects it, go back to
   step 2.

## Rules

- Ask in plain text in the chat, not with a question tool: the format stays the same in every agent.
- Give one recommended answer per question, never "it depends". Pick a default and name the
  alternatives in the question body.
- Word each question so that "yes" accepts the recommended answer.
- Accept short answers: `yes`, `no`, an option letter, or `Q3 b`. An unanswered question
  stays open: ask it again under the same number.
- When the answer is a question, answer it first, then ask again under the same number.
- Number questions without restarting: the first question of round 2 follows the last question of
  round 1. The user refers to decisions by number. Keep the numbers in the interview and its summary: a
  document or ticket written from it states the decision instead.
- When the user says to stop, go to step 7 with the decisions settled so far and list the open ones
  as assumptions.

## Gotchas

- Before recommending a location, name or convention, check the user's instruction files
  (AGENTS.md / CLAUDE.md chain) for an existing one.
- Don't assume the issue tracker is the forge: ask which trackers the user works with before
  designing detection.
