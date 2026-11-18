---
name: handoff
description: Compact the current session into a handoff document that a new agent session, in Claude Code, Antigravity or another agent, continues from. Use when the user asks for a handoff, to hand over the work, or to continue in a new session.
---

# Handoff

Write a document from which a new agent, with no access to this session, continues the work without
asking what was already decided.

## Steps

1. **Focus.** When the user named what the next session will do, write it down as the focus and
   keep only what serves it. Otherwise the focus is the whole remaining work. Done when the focus is
   one sentence.
2. **Collect.** Gather the state: `git status`, `git log --oneline -5`, the branch, the
   PR/MR link, the last test or lint result, the decisions taken in this session, and the files and
   links that hold the details (specs, plans, ADRs, issues, commits). Done when each field of the
   template has a value or `None.`.
3. **Write.** Run [scripts/handoff-path.sh](scripts/handoff-path.sh) and use the path it prints.
   Read [assets/handoff.md](assets/handoff.md) and fill it exactly into that file. Done when the file
   is written.
4. **Check secrets.** Run [scripts/check-secrets.sh](scripts/check-secrets.sh) `<path>`. On a
   finding, replace the secret with `<REDACTED>` and run it again. Done when it exits 0.
5. **Finish.** Print the path, then one line the user pastes into the next agent:
   `Read <path> and continue from its Next steps.` Done when both lines are sent.

## Gotchas

- Link artifacts by path or URL. A copy of a spec or diff in the handoff goes stale and doubles the
  reading.
- Write decisions as settled facts with their reason, so the next agent does not reopen them.
- Personal data (names, emails, customer identifiers) is redacted like a secret, even when
  check-secrets.sh passes.
