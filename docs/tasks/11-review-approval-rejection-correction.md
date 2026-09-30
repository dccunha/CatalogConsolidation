# T11: Approve, reject, and correct review cases

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Enable ordinary candidate approval, individual rejection, and correction of comparison metadata through the review screen. Implement the first real reviewer-command journeys for AC11. Explicit creation belongs to T12; reassignment and choosing between same-seller IDs belong to T13. Cases requiring those operations remain pending with a clear explanation.

## Required context

- [T10 UI/reviewer contract](10-review-queue-and-details.md#handoff), [T08 replay contract](08-reruns-and-source-identity.md#handoff), and [T03 write operations](03-catalog-public-writes.md#handoff).
- [T06 persistence handoff](06-intake-persistence.md#handoff).
- [RFC review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle), especially explicit actions, freshness, and atomic decisions.
- [PRD review actions](../prds/catalog-consolidation-importer.md#6-review-workflow).

## Deliverables and acceptance checks

- [ ] Approve a candidate for an eligible active pending case after checking current Catalog evidence and constraints. Use `Catalog::Public`; commit association and decision together without changing product attributes.
- [ ] Reject candidates individually with reviewer, timestamp, and reason, exposing the next candidate while preserving prior rejections. Rejecting the last candidate never creates a product.
- [ ] Correct comparison fields separately from original source values and rerun matching. Keep the case pending even with one exact match or no candidates; preserve the active original source tuple for reruns.
- [ ] Capture the configured reviewer at action time. Corrections do not edit the stable seller-name/item-ID key.
- [ ] Recheck actionability and current evidence on submission. Resolved/superseded cases, repeated submissions, stale evidence, and uniqueness conflicts cannot silently apply another decision.
- [ ] Add supported forms and clear outcomes to the case page. Until T12/T13 land, do not offer unsupported creation or conflict-resolution actions.
- [ ] Test actual approval/rejection/correction followed by unchanged source reruns, corrected exact/no-candidate cases staying pending, stale actions, and forced decision-write rollback of Catalog changes.

## Current checkpoint

- Completed: task brief only.
- Remaining: commands, action forms, atomicity/replay tests, and screenshots.
- Next action: inspect case actionability, transaction contracts, and configured reviewer access.

## Problems

None recorded.

## Decisions

None recorded. Record command results/errors and freshness checks that T12/T13 will reuse. The RFC already requires explicit final actions and unchanged original source identity.

## Validation evidence

Not run. Record command/request/journey specs, screenshots, and CI. Replace fixture-only replay evidence for these operations with actual command sequences under AC11.

## Handoff

Not implemented. Publish command and UI contracts, actionability checks, transaction boundaries, and how candidate rejections survive correction/rematching. Identify deferred creation and reassignment paths for T12/T13.
