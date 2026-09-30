# T07: Process imports with failure isolation

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Process a valid JSON array into persistent, explainable row outcomes and a reconciled batch summary. Own AC1, AC2, AC5, AC9, and AC10's core behavior. This task handles new seller identities; T08 completes duplicate/rerun semantics before any public upload interface is exposed.

## Required context

- [T03 write contract](03-catalog-public-writes.md#handoff), [T04 validation](04-row-validation-and-normalization.md#handoff), [T05 matching](05-matching-and-candidate-evidence.md#handoff), and [T06 persistence](06-intake-persistence.md#handoff).
- [PRD import behavior](../prds/catalog-consolidation-importer.md#5-import-behavior) and [output](../prds/catalog-consolidation-importer.md#8-import-output).
- [RFC row outcomes](../rfcs/0001-import-review-lifecycle.md#seller-identity-and-row-outcomes) and [ownership](../rfcs/0001-import-review-lifecycle.md#persistence-and-ownership-contract).

## Deliverables and acceptance checks

- [ ] Reject malformed JSON and non-array top-level input with a clear file error. A valid array gets one outcome per element, including non-object or invalid rows.
- [ ] Validate and match new identities, then link/create through `Catalog::Public` or persist a pending case with evidence and reason.
- [ ] Use row-level transactions for successful Catalog/Intake changes. A failed Catalog write leaves no partial product/association; persist the failure result outside the rolled-back unit and continue.
- [ ] Return the batch ID and totals for linked, created, already imported, pending review, and failed outcomes, with row number, seller key, references, and readable reasons.
- [ ] Ensure later rows see Catalog changes from earlier rows. Do not create duplicates by matching against a frozen pre-import catalog.
- [ ] Test exact linking to product 2, no-candidate creation, incomplete metadata, invalid elements between valid rows, forced write rollback, and SQL-like strings stored as data.
- [ ] Verify totals reconcile for each tested array. Keep the service internal until T08 handles repeated keys; a complete supplied-file/rerun journey is verified later.

## Current checkpoint

- Completed: task brief only.
- Remaining: parsing, row orchestration, reporting, and verification.
- Next action: inspect dependency contracts and define the batch runner/result interface.

## Problems

None recorded.

## Decisions

None recorded. Record runner input/output, file-error behavior, transaction boundaries, and row-error handling. Do not conflate a failed individual row with a malformed file.

## Validation evidence

Not run. Record focused orchestration/rollback specs and CI results; update applicable AC evidence. Do not claim complete rerun support before T08.

## Handoff

Not implemented. Publish the importer entry point, summary/query interface, error handling, and lifecycle integration points for T08/T09. Identify remaining repeated-key behavior precisely.
