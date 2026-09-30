# T12: Create explicitly and recheck evidence

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Let a reviewer explicitly create a new product for an eligible complete case, with current candidate evidence and atomic persistence. Cover the creation and stale-candidate parts of AC11. Exclude changing an existing association and selecting between conflicting seller IDs; T13 completes those paths.

## Required context

- [T11 review commands](11-review-approval-rejection-correction.md#handoff), [T05 candidate evidence](05-matching-and-candidate-evidence.md#handoff), and [T03 writes](03-catalog-public-writes.md#handoff).
- [T08 source identity contract](08-reruns-and-source-identity.md#handoff).
- [RFC review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle) and [new-candidate example](../rfcs/0001-import-review-lifecycle.md#examples-to-verify-during-implementation).

## Deliverables and acceptance checks

- [ ] Add a separate explicit create command/form for complete reviewed input with no remaining unrejected credible candidates. Rejecting or correcting alone never creates a product.
- [ ] Incomplete input cannot create. A corrected complete case with no candidate can become eligible but still requires the separate action.
- [ ] Requery current Catalog candidates before committing creation. Preserve earlier rejections; newly credible candidates keep the case pending and must be shown before creation can proceed.
- [ ] Leave stale/conflicting cases pending with refreshed evidence and a visible reason. Reuse the current-evidence/actionability checks established in T11.
- [ ] Commit product, association, and final decision atomically. Preserve original input, corrections, and decision history; unchanged reruns report the retained decision.
- [ ] Test last rejection without creation, explicit creation, missing metadata, a new candidate appearing between rejection and creation, repeated submissions, and forced rollback.
- [ ] Verify the browser distinguishes pending, ready for explicit creation, and resolved outcomes. These may be derived UI states; do not add a persistent state solely for display.

## Current checkpoint

- Completed: task brief only.
- Remaining: creation command/UI, freshness sequences, and verification.
- Next action: inspect T11's rejection/actionability behavior and T05's current-candidate query.

## Problems

None recorded.

## Decisions

None recorded. Record the creation eligibility/result contract and refreshed evidence behavior. Do not weaken the RFC's explicit-action or candidate-recheck requirements.

## Validation evidence

Not run. Record command/request/journey specs, stale-candidate regression tests, screenshots, and CI.

## Handoff

Not implemented. Publish creation and candidate-refresh contracts for T13/T14, including the exact remaining restrictions when a case already has an association requiring reassignment.
