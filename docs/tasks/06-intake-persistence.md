# T06: Persist Intake history and lifecycle state

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Persist the Intake records needed to audit every row and preserve review/version history. Support AC1, AC6–AC8, AC10, and AC11. Exclude importer orchestration and reviewer commands; establish their persistence contract without building speculative infrastructure.

## Required context

- [T01 handoff](01-concepts-and-catalog-persistence.md#handoff), [T04 handoff](04-row-validation-and-normalization.md#handoff), and [T05 handoff](05-matching-and-candidate-evidence.md#handoff).
- [RFC identity/version rules](../rfcs/0001-import-review-lifecycle.md#seller-identity-and-row-outcomes), [review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle), and [persistence contract](../rfcs/0001-import-review-lifecycle.md#persistence-and-ownership-contract).
- [PRD output](../prds/catalog-consolidation-importer.md#8-import-output).

## Deliverables and acceptance checks

- [ ] Persist batches and position-addressable row results, including invalid input elements that have no valid seller key. Store original input, outcome, reason, and applicable product/case references.
- [ ] Track each exact seller key's active original source identity independently of corrected reviewer values and current Catalog association.
- [ ] Persist pending, resolved, and superseded cases with at most one active case per key. Retain history rather than overwriting or deleting superseded records.
- [ ] Store candidate evidence, individual rejections, corrections, conflicting associations, and append-only decisions including reviewer, time, result, and displaced/declined identities as applicable.
- [ ] Preserve import-time row outcomes when linked review cases later change. Support a retained resolved decision even when the seller ID remains unlinked.
- [ ] Add appropriate constraints/indexes and explicit model spec types. Test invalid-key auditability, active-case uniqueness, source/correction separation, and historical references.
- [ ] Document actual state representations and query contracts without introducing Catalog-to-Intake dependencies.

## Current checkpoint

- Completed: task brief only.
- Remaining: schema, models, invariants, and verification.
- Next action: map RFC persistence responsibilities to a minimal physical schema using the existing contracts.

## Problems

None recorded.

## Decisions

None recorded. Record physical schema, state representation, append-only enforcement, and constraint choices. The RFC fixes behavior, not table names.

## Validation evidence

Not run. Record migration/model/constraint specs and CI results. These are persistence checks, not proof of completed review journeys.

## Handoff

Not implemented. Publish models, columns, relationships, constraints, history rules, and queries needed by T07–T13. Explain how a seller ID without a current association retains its active source identity and final decision.
