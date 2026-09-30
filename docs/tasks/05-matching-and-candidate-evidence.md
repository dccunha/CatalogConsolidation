# T05: Implement matching and candidate evidence

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Return an explainable matching recommendation and ranked evidence without writing Catalog data. Own core matching coverage for AC3, AC4, and AC12 and support AC2/AC5/AC9. Exclude row orchestration, persistent review state, and UI.

## Required context

- [T04 handoff](04-row-validation-and-normalization.md#handoff), [T03 handoff](03-catalog-public-writes.md#handoff), and [T02 handoff](02-reference-catalog-loading.md#handoff).
- [PRD matching order](../prds/catalog-consolidation-importer.md#52-matching-policy).
- [RFC candidate formula and ranking](../rfcs/0001-import-review-lifecycle.md#matching-and-candidate-evidence).

## Deliverables and acceptance checks

- [ ] Recommend automatic linking only for one complete exact normalized name/brand/category match without a seller/product conflict. Multiple exact matches, incomplete metadata, or conflicting associations require review.
- [ ] Include identical normalized names regardless of metadata. Otherwise require an equal nonblank brand and normalized-name similarity of at least 0.80.
- [ ] Compute normalized Levenshtein similarity over Unicode characters. Rank by score, matching brand, matching category, then ascending product ID.
- [ ] Retain product IDs, scores, original/normalized values, differing fields, and association-conflict information. Ranking itself never authorizes linking.
- [ ] A complete new row with no credible candidate is eligible for creation; lifecycle callers must still enforce whether it previously entered review.
- [ ] Test one/multiple exact matches, brand/category conflicts, absent metadata, threshold boundaries, ranking ties, and variant differences. Include the specified Galaxy, iPad, Canon camera, and router examples where relevant.
- [ ] Query Catalog read-only through documented entry points; ensure later imports can evaluate current Catalog state rather than an obsolete snapshot.

## Current checkpoint

- Completed: task brief only.
- Remaining: matching service, evidence contract, and verification.
- Next action: inspect T04's comparison values and T03's read/write boundary.

## Problems

None recorded.

## Decisions

None recorded. The 0.80 threshold and ranking are fixed by the accepted RFC. Record implementation/query choices without changing matching policy.

## Validation evidence

Not run. Record candidate/decision examples and CI results. Update acceptance evidence for AC3, AC4, and AC12.

## Handoff

Not implemented. Publish recommendation/evidence structures, read-only query usage, and edge cases for T06–T13. State explicitly which lifecycle checks remain the caller's responsibility.
