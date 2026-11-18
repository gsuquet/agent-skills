# RFC template

Copy the block below into the path that `scripts/next-number.sh rfc <slug>` printed. Replace each
`<...>` field with text that follows its rule. Keep every heading, in this order. A section marked
*optional* holds its content or exactly `N/A: <one-line reason>`. `scripts/check-rfc.sh` enforces
every rule written here.

````markdown
---
rfc: <the 4 digits of the file name>
title: <imperative phrase naming the change, 60 characters max>
status: draft
track: <lightweight | full, from the track table in SKILL.md>
reversibility: <one-way when undoing needs a data migration, downtime or another team; else two-way>
author: <git handle>
deciders: <handles who accept or reject; may be the author alone>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD of the last status change>
review: <URL of the PR/MR that carries this RFC>
adr: null
supersedes: <number of the RFC this one replaces, or null>
superseded-by: null
---

# RFC <NNNN>: <title>

## Summary

<2 or 3 sentences: what changes, for whom, and the expected outcome. No background.>

## Context

<the current state, the problem, and the constraint that forces a decision now; link issues, incidents and dashboards. 15 lines max.>

## Goals and non-goals

Goals:

- <measurable goal>

Non-goals:

- <adjacent work this RFC excludes>

## Decision drivers

- <criterion used to judge every option, most important first: 2 to 5 bullets>

## Options considered

### <Option name>

<one line: what this option does>

- Good: <advantage, naming the driver it serves>
- Bad: <cost, naming the driver it hurts>

### Do nothing

<one line: what happens if nothing changes>

- Good: <advantage>
- Bad: <cost>

## Proposal

<the design of the chosen option: components, interfaces, config snippets, data flow. Lightweight track: 20 lines max. Full track: add a diagram or a sequence.>

## Operational impact

- Blast radius: <what breaks, and for whom, if this goes wrong: clusters, namespaces, environments, tenants, state files>
- Rollout: <ordered steps and environments, the gate between steps, the feature flag if any>
- Rollback: <exact steps and the time to restore; "irreversible after step N" when one-way>
- Migration: <data, state or API migration and its compatibility window, or "None: <why nothing persisted changes>">
- Security: <changed trust boundaries, IAM or RBAC, secrets, network exposure, supply chain; or N/A: reason>
- Cost: <monthly delta and its basis, or N/A: reason>
- Observability: <the metric, log or alert that proves it works and detects failure; the SLO it touches>

## Drawbacks and risks

- <risk, the strongest argument against the proposal first> -> <mitigation>

## Open questions

- <question to settle before the decision, or "None.">

## Decision

Pending.

## Implementation

N/A: not accepted yet.

## References

<optional: links to external docs, prior art and related RFCs or ADRs, one per line>

## Future work

<optional: follow-ups raised but out of scope; listing them here accepts none of them>
````

## Rules by section

- **Options considered:** each option is a `### ` heading; `### Do nothing` is always one of
  them. Lightweight track: 1 option plus Do nothing at least. Full track: 2 options plus Do nothing
  at least.
- **Operational impact:** keep all 7 lines. A line holds text or `N/A: <reason>`, except Blast
  radius, Rollback and Migration, which always hold text, and Observability, which always holds
  text on the full track.
- **Open questions:** `None.` to accept the RFC: settle each question, or move it to Future work.
- **Decision:** `Pending.` until the deciders decide. It is copied verbatim into the ADR, so it
  stands alone: no "see above". Replace `Pending.` with one of these blocks.

  Accepted (every line required):

  ```markdown
  - Status: accepted on <YYYY-MM-DD> by <deciders>
  - Decision: In the context of <scope>, facing <problem>, we decided for <option> and against <other options>, to achieve <goals>, accepting <main downside>.
  - Consequences:
    - Good: <positive consequence, one bullet each>
    - Bad: <accepted cost or risk, one bullet each>
  - Confidence: <high | medium | low>, <one-line reason>
  - Confirmation: <how compliance is checked: CI check, policy, test, alert or review checklist>
  - Revisit when: <observable trigger that reopens the decision, for example cost above X or version Y end of life>
  ```

  Rejected (Status and Decision required):

  ```markdown
  - Status: rejected on <YYYY-MM-DD> by <deciders>
  - Decision: <why the change is rejected, standing alone, so the question is not asked again>
  ```

  Withdrawn: one line, `Withdrawn on <YYYY-MM-DD>: <reason>`.
- **Implementation:** once accepted, an append-only list of `- <YYYY-MM-DD> <PR/MR URL>` lines. It
  never changes the status.
