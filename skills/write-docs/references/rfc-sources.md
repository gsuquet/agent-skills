# RFC sources

Read this only when the user asks why the RFC template or lifecycle is shaped this way, or wants to
change it. Rows marked **[from memory] (unverified)** were not checked against their source:
verify them before quoting them.

## Compared templates

| Template | Lifecycle | Where the decision lives | Idea taken |
|---|---|---|---|
| Rust RFC (`github.com/rust-lang/rfcs`, `0000-template.md`, `README.md`) | PR open, final comment period of 10 days with a disposition (merge, close, postpone), then merged or closed | The merged file and the disposition comment; a tracking issue holds the implementation | Review timebox; terminal states; implementation tracked apart from the decision; no rewritten review history |
| MADR 4.0 (`github.com/adr/madr`, `template/`) | proposed, rejected, accepted, deprecated, superseded by ADR-NNNN | The ADR itself: "Chosen option: X, because Y" | Decision drivers; considered options with good and bad points; Confirmation; one template in full and minimal variants |
| Nygard ADR and Y-statement (`adr.github.io`) | proposed, accepted, superseded | The ADR | The one-sentence decision: in the context of, facing, we decided for, and against, to achieve, accepting |
| AWS Prescriptive Guidance, ADR process | proposed, then accepted or rejected with the reason, then superseded; accepted records are append-only | The ADR | Rejections are recorded so the question is not asked again; only the status of an old record changes |
| Microsoft Azure Well-Architected, ADR | proposed, accepted, superseded | The ADR, linked to its supporting docs | The decision stands alone; record the confidence; one record per phase; records only for choices that are hard to reverse |
| Go proposal **[from memory] (unverified)** | Issue labels: active, likely accept or decline after a final week, accepted, declined, hold | A committee comment on the issue | Most proposals need no design doc; compatibility is a fixed concern |
| Kubernetes KEP **[from memory] (unverified)** | provisional, implementable, implemented, deferred, rejected, withdrawn, replaced; stages alpha, beta, stable | `kep.yaml` approvers and a production readiness file per stage | Operational questions asked as fixed lines; rollback and monitoring always answered |
| Oxide RFD **[from memory] (unverified)** | prediscussion, ideation, discussion, published, committed, abandoned | The state in the doc header | A number reserved at draft time |
| Google design doc **[from memory] (unverified)** | Informal | The doc | Goals and non-goals; cross-cutting concerns as a fixed section; a 1 to 3 page mini variant |
| HashiCorp RFC **[from memory] (unverified)** | WIP, in review, approved, obsolete | Approvers in the header | Background that stands alone for a newcomer; abandoned ideas kept |

## Choices and their reasons

- **Problem before solution, summary first:** every compared template does it.
- **Non-goals required:** the cheapest guard against scope creep (KEP, Google design doc).
- **Do nothing is always an option:** Rust asks for the impact of not doing it; single-option
  proposals hide the trade-off.
- **Operational impact as 7 fixed lines, N/A only with a reason, Rollback never N/A:** the KEP
  production readiness idea, kept to one line each because a long questionnaire collects
  boilerplate N/A answers (KEP, from memory).
- **Decision status apart from implementation:** an RFC whose status tracks delivery never closes
  (KEP `implementable`, from memory); Implementation is a list of links.
- **No postponed state:** postponing is withdrawn with a reason, reopened as a new RFC; a deferred
  state becomes a limbo (KEP `deferred`, from memory).
- **Rejected RFCs are merged:** a closed PR/MR disappears from the repository, and the question
  comes back (AWS).
- **The ADR is a copy of the Decision section:** decision records are not design guides; the
  decision stands alone and links to the supporting doc (Microsoft). MADR, Nygard and AWS use the
  ADR itself as the proposal; this skill keeps deliberation (RFC) and outcome (ADR) apart, so
  every ADR has the same provenance.
- **One template, two tracks:** what triggers an RFC is how hard the change is to reverse and how
  much it can break; size only picks the track. MADR ships variants of one template; Rust routes
  minor changes to a lighter process; the one-way and two-way door idea comes from Amazon's 2015
  shareholder letter **[from memory] (unverified)**.
- **Review window of 2 or 5 business days:** a shorter form of the Rust final comment period,
  sized to the track.
