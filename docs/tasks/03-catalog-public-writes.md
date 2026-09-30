# T03: Implement Catalog public writes

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Provide the synchronous `Catalog::Public` operations Intake will use to link, create, and reassign seller associations. Catalog owns these writes and has no Intake dependency. This establishes atomicity for AC8/AC9 and later review decisions; it does not implement matching or review authorization.

## Required context

- [T01 handoff](01-concepts-and-catalog-persistence.md#handoff) and [T02 handoff](02-reference-catalog-loading.md#handoff).
- [ADR public surface](../adrs/0001-organize-by-concepts.md#dependencies-and-public-surface).
- [PRD write isolation](../prds/catalog-consolidation-importer.md#53-failure-isolation-and-catalog-writes) and [review actions](../prds/catalog-consolidation-importer.md#6-review-workflow).
- [RFC review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle).

## Deliverables and acceptance checks

- [ ] Implement bounded operations for linking an existing product, creating a product with its association, and changing associations for explicit review decisions.
- [ ] Keep existing product attributes unchanged on link or reassignment. Route all supplied strings through Active Record/bound SQL parameters.
- [ ] Respect both uniqueness constraints; report useful conflict information without silently selecting a surviving seller ID.
- [ ] Support an enclosing Intake transaction so Catalog writes and an Intake decision can commit or roll back together. Do not introduce independent commits or callbacks across the ownership boundary.
- [ ] Test successful writes, constraint failures, create/association rollback, reassignment rollback, quoted/SQL-like values, and unchanged product fields.
- [ ] Record exact operation signatures, return values, expected exceptions/conflicts, and transaction behavior for downstream tasks.

## Current checkpoint

- Completed: task brief only.
- Remaining: public operations, contract documentation, and verification.
- Next action: inspect integrated Catalog constraints and design the smallest write surface needed by the RFC.

## Problems

None recorded.

## Decisions

None recorded. Choose initial signatures within this task; subsequent incompatible downstream-contract changes require an interview.

## Validation evidence

Not run. Record focused operation/rollback specs and CI results. Add applicable evidence to AC8/AC9 in the index without claiming the complete importer exists.

## Handoff

Not implemented. Publish callable contracts and transaction examples for T07 and T11–T13, plus permitted read-only Catalog queries. Distinguish persistence constraints from Intake's matching/review decisions.
