# T05: Implement matching and candidate evidence

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Return an explainable matching recommendation and ranked evidence without writing Catalog data. Own core matching coverage for AC3, AC4, and AC12 and support AC2/AC5/AC9. Exclude row orchestration, persistent review state, and UI.

## Required context

- [T04 handoff](04-row-validation-and-normalization.md#handoff), [T03 handoff](03-catalog-public-writes.md#handoff), and [T02 handoff](02-reference-catalog-loading.md#handoff).
- [PRD matching order](../prds/catalog-consolidation-importer.md#52-matching-policy).
- [RFC candidate formula and ranking](../rfcs/0001-import-review-lifecycle.md#matching-and-candidate-evidence).

## Deliverables and acceptance checks

- [x] Recommend automatic linking only for one complete exact normalized name/brand/category match without a seller/product conflict. Multiple exact matches, incomplete metadata, or conflicting associations require review.
- [x] Include identical normalized names regardless of metadata. Otherwise require an equal nonblank brand and normalized-name similarity of at least 0.80.
- [x] Compute normalized Levenshtein similarity over Unicode characters. Rank by score, matching brand, matching category, then ascending product ID.
- [x] Retain product IDs, scores, original/normalized values, differing fields, and association-conflict information. Ranking itself never authorizes linking.
- [x] A complete new row with no credible candidate is eligible for creation; lifecycle callers must still enforce whether it previously entered review.
- [x] Test one/multiple exact matches, brand/category conflicts, absent metadata, threshold boundaries, ranking ties, and variant differences. Include the specified Galaxy, iPad, Canon camera, and router examples where relevant.
- [x] Query Catalog read-only through documented entry points; ensure later imports can evaluate current Catalog state rather than an obsolete snapshot.

## Current checkpoint

- Completed: read-only matching service and 18 focused examples, including a reference-catalog match to product 2; full Docker CI passed on the working tree.
- Remaining: independent reviews and parent-owned PR/merge workflow. The task index owns status.
- Next action: hand the candidate to the correctness and test reviewers.

## Problems

- The first focused RSpec run passed 16 examples but exited 2 because SimpleCov evaluates the whole application and an isolated file does not meet repository-wide coverage floors. Full CI later passed both floors.
- The first CI run found RuboCop method-complexity offenses and Sorbet's nilable array-index typing in the Levenshtein loop. Signed helper extraction and `Array#fetch` resolved these. The second CI run found one remaining complexity offense and spacing; both were fixed before the passing final run.

## Decisions

- **T05-D01 — 2026-09-30:** `Intake::Services::ProductMatcher.call(valid: RowValidator::Valid) -> ProductMatcher::Result` takes only a validated T04 row. `recommendation` is `:link`, `:review`, or `:create`; `product_id` is populated only for `:link`. `:create` means a complete row has no credible candidate and no existing exact seller key, and is only eligibility for a lifecycle caller, not authorization to write. Any existing exact seller key makes this matcher return `:review`; T07/T08 must identify idempotent reruns or changed identities before using this recommendation.
- **T05-D02 — 2026-09-30:** Each call queries `Catalog::Models::SellerProduct` for the exact supplied seller name and scans current `Catalog::Models::Product` rows with `find_each`; neither Catalog table is written. Evidence snapshots the source and normalized identity, sorted candidates with product ID, score, original and normalized fields, normalized differing fields, and any same-seller/product conflicting association. The result separately exposes an association for the exact `(SellerName, Id)` key. Association evidence carries its ID, product ID, exact seller name, and exact seller item ID. This is a current-state read for each call, not a cached snapshot or a lock; callers must recheck before final writes.
- **T05-D03 — 2026-09-30:** An identical normalized name is credible regardless of metadata. Otherwise an equal nonblank normalized brand and score at least 0.80 is required. Score is the accepted `1 - distance / maximum name length` over Ruby Unicode characters after T04 normalization. The fixed ranking uses descending score, matching nonblank brand, matching nonblank category, then ascending product ID. Missing metadata cannot count as a matching brand/category ranking advantage. Candidate evidence never independently promotes a review row to `:link`.

## Validation evidence

- **2026-09-30 — Focused behavior on base `5dcdab913e3f6491f06d4af383cfbd1a9a63be8c` plus T05 working tree:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/services/product_matcher_spec.rb` ran 16 examples, 0 failures. The process exited 2 only because isolated-file SimpleCov had 51.95% lines and 60.78% branches over the whole application. Two further examples were added for canonical reference product 2 and a Unicode-character threshold boundary; the final full CI below ran all 18 matcher examples.
- **2026-09-30 — Full gate on the same base plus final T05 working tree:** `docker compose run --rm web bin/ci` passed every stage: Ruby/ERB/JS lint, Sorbet (`No errors`), concept sigils, both RBI freshness checks, gem/importmap/Brakeman security audits, database preparation/consistency, seeds, 103 RSpec examples (0 failures), and Vitest (1 test, 0 failures). Ruby coverage was 449/451 lines (99.55%) and 97/102 branches (95.09%); JavaScript statements, lines, and functions were 100% (no branches). No RBI changes were needed. The matcher examples verify AC3's iPad punctuation review, AC4's visible Canon category difference, AC12's capacity/color variant separation, RFC router score about 0.826, the inclusive 0.80 threshold, rankings and ties, missing metadata, exact seller identity, same-seller/product conflicts, current Catalog requery, and the AC2 Galaxy link to reference product ID 2.

## Handoff

Call `Intake::Services::ProductMatcher.call(valid:)` with a `RowValidator::Valid` result. Its typed `Result` provides frozen-copy `source` and `comparison`, `recommendation`, nullable `product_id`, ordered `reasons`, sorted `candidates`, and nullable `seller_item_association`. Each `Candidate` provides `product_id`, `score`, `original` product fields, normalized `comparison`, `differing_fields` (`:name`, `:brand`, `:category`), nonblank `brand_matches`/`category_matches`, and nullable `seller_product_conflict`. Reasons are `:incomplete_metadata`, `:seller_item_taken`, `:multiple_exact_matches`, `:seller_product_taken`, and `:candidate_review`; multiple reasons can apply. `:link` appears only for one complete exact match with no conflicting association. `:create` appears only for a complete no-candidate row with no exact seller key. Otherwise the result recommends `:review`.

T06–T13 own source-identity/idempotency checks, persistent review and rejection state, reviewer decisions, whether a row has ever entered review, final rechecks against current Catalog, uniqueness races, and Catalog writes through `Catalog::Public::Writes`. A corrected row or a previously reviewed row must remain in review even if this stateless matcher later returns `:link` or `:create`. The matcher does not lock Catalog records, and unusual paraphrases below the threshold can still be missed. It reads the current catalog on every call; callers should requery just before a final decision. The current 975-product reference fits a full `find_each` scan per row; a larger catalog may need indexed candidate retrieval without changing this policy.
