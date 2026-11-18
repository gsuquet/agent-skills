# Slicing rules

How to cut work into tickets. Apply the sections in order; the first that fits a piece of work
decides how it is cut.

## Ticket size

A ticket fits one fresh agent context: an agent that starts from the ticket, the spec and the
repository finishes it, tests included, without a second session. A ticket that needs more is two
tickets. A ticket that only makes sense together with another is one ticket.

## Prefactor first

When the change is hard to make in the current structure, first cut a prefactor ticket: it reshapes
the code (extract a module, add a seam, move a resource) and changes no behaviour. Its acceptance
criterion is the test suite, or `terraform plan` / `kubectl diff`, unchanged and green, plus the new
seam existing. Every ticket that uses the new structure is blocked by it.

## Vertical slices

Every other ticket is a tracer bullet: a narrow path through every layer the behaviour needs
(schema, API, UI, tests; or module, variables, pipeline, monitoring) that works end to end on its
own.

- Cut by behaviour, never by layer: "list buckets with their retention" is a ticket; "add the
  retention column" is not.
- The first ticket is the thinnest path that proves the layers connect. Later tickets widen it.
- For infrastructure, a slice is one resource or capability deployed and checked in one environment:
  "the staging cluster exposes the service through the gateway", not "write the gateway module".

## Expand-contract

Use it for a wide refactor: one mechanical change (rename a column, retype a shared symbol, move a
Terraform resource address, change a Helm value key) whose blast radius breaks callers across the
codebase, so that no vertical slice lands green.

1. **Expand**: add the new form beside the old one. Nothing breaks.
2. **Migrate**: move callers to the new form in batches sized by blast radius (per package, module,
   directory or environment). One ticket per batch, each blocked by the expand ticket. Each batch
   keeps CI green because the old form still exists.
3. **Contract**: delete the old form, in one ticket blocked by every migrate ticket. Its criterion:
   a search for the old form returns nothing.

When a batch cannot stay green alone, keep the sequence on a shared integration branch, and add a
final integrate-and-verify ticket blocked by every batch: only that ticket promises green.

## Acceptance criteria fail at the base commit

Each criterion is a check an agent runs (a test, a command, a request, a plan) with the result it
expects. Run it in your head against the base commit, the commit the ticket starts from: it must
fail there. A criterion that already passes proves nothing; rewrite it or drop it. For a
prefactor, the failing part is the seam that does not exist yet.

## Blocking edges

A ticket is blocked by another only when it cannot start before that one is done: it uses what the
other builds. Shared topic or file is not a reason. Keep the graph shallow: tickets with no blocker
can run in parallel.
