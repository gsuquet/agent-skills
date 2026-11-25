# RFC template

Copy the block below into the path that `scripts/next-number.sh rfc <slug>` printed. Replace each
`<...>` field with text that follows its rule. Keep every heading, in this order. A section marked
*optional* holds its content or exactly `N/A: <one-line reason>`. `scripts/check-rfc.sh` enforces
the rules written here, and `scripts/check-readability.sh` the Decision table and the limits.

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

| Decision | Why | Cost | Reversible |
|---|---|---|---|
| <one decision, one row per decision> | <reason, one line> | <what it costs or gives up> | <yes or no, and how or why> |

<before and after, when something is replaced or removed and the 25-word rule of references/visuals.md does not waive them: two flowcharts, each with a caption and a legend; else delete this line>

## Context

<the current state, the problem, and the constraint that forces a decision now; one line and a link for each piece of evidence. 15 lines max.>

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

<how the decisions of the Summary work together, and a link to the design page for the detail. Lightweight track: 20 lines max. Full track: add a diagram of parts or interactions.>

## Operational impact

- Blast radius: <what breaks, and for whom, if this goes wrong: clusters, namespaces, environments, tenants, state files>
- Rollout: <ordered steps and environments, the gate between steps, the feature flag if any; link the tickets for the work packages>
- Rollback: <exact steps and the time to restore; "irreversible after step N" when one-way>
- Migration: <data, state or API migration and its compatibility window, or "None: <why nothing persisted changes>">
- Security: <changed trust boundaries, IAM or RBAC, secrets, network exposure, supply chain; or N/A: reason>
- Cost: <monthly delta and its basis, or N/A: reason>
- Observability: <the metric, log or alert that proves it works and detects failure; the SLO it touches>

## Drawbacks and risks

| Risk | Severity | Mitigation |
|---|---|---|
| <risk, worst severity first> | <high, medium or low> | <mitigation> |

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

- **Summary:** the decision table holds every decision the deciders accept, in short form; the
  Decision section records them in full. Only a draft may say open under Reversible, as a link to
  `#open-questions`.
- **Options considered:** each option is a `### ` heading; `### Do nothing` is always one of
  them. Lightweight track: 1 option plus Do nothing at least. Full track: 2 options plus Do nothing
  at least.
- **Operational impact:** keep all 7 lines. A line holds text or `N/A: <reason>`, except Blast
  radius, Rollback and Migration, which always hold text, and Observability, which always holds
  text on the full track.
- **Open questions:** `None.` to accept the RFC: settle each question, or move it to Future work.
- **Decision:** `Pending.` until the deciders decide. It is copied verbatim into the ADR, so it
  stands alone: no "see above". Replace `Pending.` with one of these blocks.

  Accepted (every line required; one Decision line per row of the Summary table, in its order):

  ```markdown
  - Status: accepted on <YYYY-MM-DD> by <deciders>
  - Context: <scope and problem, 3 lines max>
  - Decision: <one sentence: we decided for "option" and against "other options", to achieve "goals", accepting "main downside">
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
