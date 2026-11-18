---
name: diagnose
description: Diagnose a bug, regression, flaky test, Terraform drift or failing Kubernetes workload by first building a check that reproduces it. Use when the user says debug or diagnose, or reports something broken, failing or slow.
metadata:
  version: 0.1.0
---

# Diagnose

Find the cause of a problem with a **loop**: one command that goes **red** on the problem and green
once it is fixed. Every later phase consumes the loop. Run the phases in order and finish each one
before you start the next.

## Redact

Before you show any command, output or captured file, replace every secret (token, password, key,
cookie, auth header, connection string) with `<REDACTED>`. Loops read credentials from environment
variables, never from literals. Quote only the lines that carry the signal. When the redacted output
is not enough to diagnose, say so and ask the user.

## Phases

1. **Scope.** Ask the user, in plain text, what you cannot find yourself: the expected behaviour,
   the actual behaviour, when it started, and who or what is affected (users, environments,
   clusters, workspaces). Note whether the user asked you to run unattended. When a monitoring tool
   is reachable (for example Datadog), pull logs, metrics and deploy markers around the start time.
   Done when the four answers are written down.
2. **Build the loop.** Read [references/loops.md](references/loops.md) and pick the recipe for the
   stack. The loop is:
   - **red**: it drives the real code path and checks the user's exact symptom, not "it runs";
   - **tight**: seconds, not minutes; same verdict on every run (for a flaky problem, a pinned,
     high failure rate: repeat the trigger, add parallelism or stress until it fails often);
   - **agent-runnable**: you run it alone. When a human must act, copy
     [assets/hitl-loop.sh](assets/hitl-loop.sh), edit its steps, ask the user to run the copy in a
     terminal, and read the `KEY=VALUE` lines it prints at the end.

   Done when you have run one command at least once and shown it with its output, redacted. Without
   that command, stop: list what you tried and ask the user for access to an environment that shows
   the problem, a redacted capture (logs, HAR, dump), or permission to add temporary
   instrumentation.
3. **Reproduce and minimise.** Run the loop until it goes red with the user's symptom, not a nearby
   failure. Then remove inputs, config, data, callers and steps one at a time, re-running the loop
   after each cut. Done when every remaining element is load-bearing: removing any one turns the loop
   green.
4. **Hypothesise.** First list what changed shortly before the start time: `git
   log --since=<date> --oneline`, deploys (Argo CD app history, `helm history <release>`), config
   changes, the Terraform state serial (`terraform state pull | jq .serial`), dependency bumps and
   merged Renovate PRs. Then write 3 to 5 hypotheses, ranked, the recent changes first. Each is
   falsifiable: "If <X> is the cause, then <changing Y> turns the loop green." Discard any you cannot
   phrase this way. Done when the ranked list is shown to the user.
5. **Stop.** Wait for the user to re-rank, rule out or add hypotheses. Skip this stop only when the
   user asked in phase 1 to run unattended. Done when the user answers, or immediately when
   unattended.
6. **Instrument.** Test the hypotheses in rank order. Each probe tests one prediction and changes
   one variable. Prefer a debugger, then targeted logs at the boundaries that separate hypotheses.
   Tag every debug log `[DEBUG-<4 hex>]` with one tag per session (for example `[DEBUG-7c1e]`). For a
   performance problem, measure a baseline with the loop before any change, and compare every probe
   to it. Done when one hypothesis is confirmed and the others are refuted or untested.
7. **Fix.** Find a correct seam: a test point where the minimised repro runs through the same path as
   in the real failure. When one exists, write the regression test there, watch it go red, apply the
   fix, watch it go green, then re-run the original loop. When none exists, record it as a finding:
   the architecture blocks locking the bug down. Then apply the fix and re-run the loop. Done when the
   original loop is green.
8. **Clean up.** Done when every item passes:
   - [ ] The phase 2 loop is green on the original scenario.
   - [ ] The regression test passes, or the missing seam is recorded.
   - [ ] `grep -rn --exclude-dir=.git '\[DEBUG-<tag>\]' .` finds nothing.
   - [ ] Throwaway scripts and harnesses are deleted, or moved to a marked debug folder.
   - [ ] The confirmed hypothesis is stated in the commit message or the PR/MR body.
9. **Report.** Read [assets/report.md](assets/report.md) and fill it. Done when the report is sent.

## Gotchas

- Reading code to build a theory before phase 2 has a command is the failure this skill prevents.
- For drift, a green `terraform plan` on your machine proves nothing about another workspace,
  backend or provider version: run the loop against the affected one.
- A regression test at a shallow seam (one caller when the bug needs two) gives false confidence:
  record it as no seam instead.
