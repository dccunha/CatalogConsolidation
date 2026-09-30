# T13: Resolve reassignment and seller-listing conflicts

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Complete AC7/AC8 and the remaining AC11 journeys: explicitly reassign changed seller identities and choose the surviving item ID when one seller offers a product twice. This task finishes the required user actions. Exclude automatic relinking and production-scale concurrency infrastructure.

## Required context

- [T03 association writes](03-catalog-public-writes.md#handoff), [T08 retained decisions](08-reruns-and-source-identity.md#handoff), and [T06 identity/history persistence](06-intake-persistence.md#handoff).
- [T11 commands](11-review-approval-rejection-correction.md#handoff) and [T12 explicit creation](12-review-creation-and-freshness.md#handoff).
- [RFC seller identity](../rfcs/0001-import-review-lifecycle.md#seller-identity-and-row-outcomes) and [review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle).
- [PRD AC7/AC8/AC11](../prds/catalog-consolidation-importer.md#9-acceptance-criteria).

## Deliverables and acceptance checks

- [ ] Let a changed-identity case explicitly approve a candidate or create a product after satisfying the rejection/creation rules. Preserve the old association until the final atomic decision.
- [ ] Show both item IDs in a same-seller conflict and offer explicit keep-existing or replace-existing choices after rechecking current evidence and uniqueness.
- [ ] Keeping the existing ID records the incoming ID as declined. Replacing it records the displaced ID and updates both affected identities' retained outcomes as needed.
- [ ] Ensure unchanged reruns of declined/displaced IDs remain unlinked, and later materially changed source identities enter review rather than restoring historical associations.
- [ ] Commit Catalog association changes and all affected Intake history/identity decisions together. Existing product fields remain unchanged and both database uniqueness rules hold throughout committed states.
- [ ] Surface stale association changes as pending with refreshed evidence. Historical/superseded cases and repeated submissions cannot overwrite a newer decision.
- [ ] Test both conflict choices, changed-identity approval/creation, returning old source identities, displaced-ID reruns, stale submissions, and rollback of all affected records.
- [ ] Complete corresponding UI forms and validate actual decision-command/import sequences, replacing remaining fixture-only coverage from T08.

## Current checkpoint

- Completed: task brief only.
- Remaining: reassignment/conflict commands, UI, and sequence verification.
- Next action: inspect integrated finalization and replay contracts before extending the supported actions.

## Problems

None recorded.

## Decisions

None recorded. Record the multi-identity transaction boundary and retained outcomes for both conflict choices. Interview before changing previously recorded public contracts.

## Validation evidence

Not run. Record command/request/journey specs, rerun and rollback evidence, screenshots, and CI; update AC7/AC8/AC11 evidence.

## Handoff

Not implemented. Publish the completed review interface/commands, conflict outcomes, and regression-test entry points for T14. Identify any remaining acceptance gaps honestly; milestone completion requires all listed actions to work.
