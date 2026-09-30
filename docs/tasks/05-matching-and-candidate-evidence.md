# T05: Implement matching and candidate evidence

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Return an explainable matching recommendation and ranked evidence without writing Catalog data. Own core matching coverage for AC3, AC4, and AC12 and support AC2/AC5/AC9. Exclude row orchestration, persistent review state, and UI.

## Required context

- [T04 handoff](04-row-validation-and-normalization.md#handoff), [T03 handoff](03-catalog-public-writes.md#handoff), and [T02 handoff](02-reference-catalog-loading.md#handoff).
- [PRD matching order](../prds/catalog-consolidation-importer.md#52-matching-policy).
- [RFC candidate formula and ranking](../rfcs/0001-import-review-lifecycle.md#matching-and-candidate-evidence).

## Deliverables and acceptance checks

- [x] Recommend automatic linking only for one complete exact normalized name/brand/category match that is the sole credible candidate and has no seller/product conflict. Multiple or additional credible candidates, incomplete metadata, or conflicting associations require review.
- [x] Include identical normalized names regardless of metadata. Otherwise require an equal nonblank brand and normalized-name similarity of at least 0.80.
- [x] Compute normalized Levenshtein similarity over Unicode characters. Rank by score, matching brand, matching category, then ascending product ID.
- [x] Retain product IDs, scores, original/normalized values, differing fields, and association-conflict information. Ranking itself never authorizes linking.
- [x] A complete new row with no credible candidate is eligible for creation; lifecycle callers must still enforce whether it previously entered review.
- [x] Test one/multiple exact matches, brand/category conflicts, absent metadata, threshold boundaries, ranking ties, and variant differences. Include the specified Galaxy, iPad, Canon camera, and router examples where relevant.
- [x] Query Catalog read-only through documented entry points; ensure later imports can evaluate current Catalog state rather than an obsolete snapshot.

## Current checkpoint

- Completed: round-one findings resolved in code candidate `aff3e41a26dbbfb7a0d22812646c5906d31d6f7b`; both independent reviewers approved. The matcher has 21 focused examples, and full Docker CI passed on the equivalent pre-commit code/test tree.
- Remaining: none. The task index owns status.
- Next action: T06 persists Intake history using this task's evidence contract.

## Problems

- The first focused RSpec run passed 16 examples but exited 2 because SimpleCov evaluates the whole application and an isolated file does not meet repository-wide coverage floors. Full CI later passed both floors.
- The first CI run found RuboCop method-complexity offenses and Sorbet's nilable array-index typing in the Levenshtein loop. Signed helper extraction and `Array#fetch` resolved these. The second CI run found one remaining complexity offense and spacing; both were fixed before the passing final run.
- Round-one correctness review found T05-COR-01: an exact product plus a credible conflicting product could still auto-link because recommendation considered only the number of exact matches. The test review also identified this as T05-TEST-01, requested a direct Catalog immutability assertion (T05-TEST-02), and requested source-backed iPad/router evidence (T05-TEST-03). All are addressed in the review-fix code and examples. The first review-fix CI run found only a RuboCop complexity offense after adding the new review reason; extracting signed candidate-reason logic resolved it.

## Decisions

- **T05-D01 — 2026-09-30:** `Intake::Services::ProductMatcher.call(valid: RowValidator::Valid) -> ProductMatcher::Result` takes only a validated T04 row. `recommendation` is `:link`, `:review`, or `:create`; `product_id` is populated only for `:link`. `:create` means a complete row has no credible candidate and no existing exact seller key, and is only eligibility for a lifecycle caller, not authorization to write. Any existing exact seller key makes this matcher return `:review`; T07/T08 must identify idempotent reruns or changed identities before using this recommendation.
- **T05-D02 — 2026-09-30:** Each call queries `Catalog::Models::SellerProduct` for the exact supplied seller name and scans current `Catalog::Models::Product` rows with `find_each`; neither Catalog table is written. Evidence snapshots the source and normalized identity, sorted candidates with product ID, score, original and normalized fields, normalized differing fields, and any same-seller/product conflicting association. The result separately exposes an association for the exact `(SellerName, Id)` key. Association evidence carries its ID, product ID, exact seller name, and exact seller item ID. This is a current-state read for each call, not a cached snapshot or a lock; callers must recheck before final writes.
- **T05-D03 — 2026-09-30:** An identical normalized name is credible regardless of metadata. Otherwise an equal nonblank normalized brand and score at least 0.80 is required. Score is the accepted `1 - distance / maximum name length` over Ruby Unicode characters after T04 normalization. The fixed ranking uses descending score, matching nonblank brand, matching nonblank category, then ascending product ID. Missing metadata cannot count as a matching brand/category ranking advantage. Candidate evidence never independently promotes a review row to `:link`.
- **T05-D04 — 2026-09-30, review fix:** An exact product may recommend `:link` only when it is the *sole credible candidate*. A second identical normalized name with conflicting metadata or a credible near-name product makes the row `:review` with reason `:additional_candidates`, and all candidates remain in ranked evidence. This follows the PRD's review path for plausible near matches and prevents the rank of an exact product from authorizing a link when another credible product exists.

## Validation evidence

- **2026-09-30 — Focused behavior on base `5dcdab913e3f6491f06d4af383cfbd1a9a63be8c` plus T05 working tree:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/services/product_matcher_spec.rb` ran 16 examples, 0 failures. The process exited 2 only because isolated-file SimpleCov had 51.95% lines and 60.78% branches over the whole application. Two further examples were added for canonical reference product 2 and a Unicode-character threshold boundary; the final full CI below ran all 18 matcher examples.
- **2026-09-30 — Full gate on the same base plus final T05 working tree:** `docker compose run --rm web bin/ci` passed every stage: Ruby/ERB/JS lint, Sorbet (`No errors`), concept sigils, both RBI freshness checks, gem/importmap/Brakeman security audits, database preparation/consistency, seeds, 103 RSpec examples (0 failures), and Vitest (1 test, 0 failures). Ruby coverage was 449/451 lines (99.55%) and 97/102 branches (95.09%); JavaScript statements, lines, and functions were 100% (no branches). No RBI changes were needed. The matcher examples verify AC3's iPad punctuation review, AC4's visible Canon category difference, AC12's capacity/color variant separation, RFC router score about 0.826, the inclusive 0.80 threshold, rankings and ties, missing metadata, exact seller identity, same-seller/product conflicts, current Catalog requery, and the AC2 Galaxy link to reference product ID 2.
- **2026-09-30 — Review-fix focused behavior on clean candidate `439312969a6415f64c2840118c4a8a6a549aae40` plus the review-fix working tree:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/services/product_matcher_spec.rb` ran 21 examples, 0 failures, including the final strengthened full-attribute snapshot. Its exit code 2 came only from whole-application SimpleCov on the isolated file (71.61% lines and 68.26% branches); full CI below passed both floors. New examples assert review with both ranked candidates for exact-plus-metadata-conflict and exact-plus-near-name cases, compare all Catalog product and seller-association attributes before and after matching, and use reference products 14 (`Tablet iPad Pro 12.9"` / `Apple` / `Tablets`) and 21 (`Router WiFi 6 TP-Link` / `TP-Link` / `Networking`) for AC3/RFC evidence.
- **2026-09-30 — Review-fix full gate on the same clean candidate plus final review-fix working tree:** `docker compose run --rm web bin/ci` passed Ruby/ERB/JS lint, Sorbet, concept sigils, both RBI freshness checks, gem/importmap/Brakeman audits, database preparation/consistency, seeds, 106 RSpec examples (0 failures), and 1 Vitest test (0 failures). Ruby coverage was 456/458 lines (99.56%) and 99/104 branches (95.19%); JavaScript statements, lines, and functions were 100% (no branches). No RBI updates were needed; `git diff --check` passed.

### Review rounds

- **Round 1, candidate `4393129` (2026-09-30):** correctness review withdrew approval for T05-COR-01 (one exact match plus another credible candidate could auto-link). Test review requested T05-TEST-01 (mixed exact/conflict regression), T05-TEST-02 (prove Catalog reads leave records/attributes unchanged), and T05-TEST-03 (reference-backed iPad/router evidence). The test reviewer ran passing full Docker CI on this original commit with 103 examples. The review-fix implementation and three added examples addressed all findings.
- **Round 2, candidate `aff3e41a26dbbfb7a0d22812646c5906d31d6f7b` (2026-09-30):** correctness reviewer approved, confirming T05-COR-01 resolved, no matching-policy regression, and read-only `git diff --check` passed. Test reviewer approved T05-TEST-01/02/03 after inspecting the mixed-candidate, full Catalog snapshot, and real reference evidence assertions. It did not rerun Docker on the commit; the implementer's final `bin/ci` evidence above is from the equivalent pre-commit code/test tree (106 examples, 99.56% lines, 95.19% branches). No open finding remains.
- **Final head and merge (2026-09-30):** both reviewers approved documentation-only deltas through final PR head `2c60b0351a09c72572babbeca6c2bcb2590fba4d`. GitHub reported [PR #15](https://github.com/dccunha/CatalogConsolidation/pull/15) `MERGEABLE`/`CLEAN` at that head and base `5dcdab9`, with no reported status checks or remote reviews. GitHub confirmed it merged at `443f5e28a0b562deb337e99996e8f734a81835e6` on 2026-09-30T05:40:11Z; main pointed to that merge commit.

## Handoff

Call `Intake::Services::ProductMatcher.call(valid:)` with a `RowValidator::Valid` result. Its typed `Result` provides frozen-copy `source` and `comparison`, `recommendation`, nullable `product_id`, ordered `reasons`, sorted `candidates`, and nullable `seller_item_association`. Each `Candidate` provides `product_id`, `score`, `original` product fields, normalized `comparison`, `differing_fields` (`:name`, `:brand`, `:category`), nonblank `brand_matches`/`category_matches`, and nullable `seller_product_conflict`. Reasons are `:incomplete_metadata`, `:seller_item_taken`, `:multiple_exact_matches`, `:seller_product_taken`, `:additional_candidates`, and `:candidate_review`; multiple reasons can apply. `:link` appears only for one complete exact match that is the sole credible candidate with no conflicting association. `:create` appears only for a complete no-candidate row with no exact seller key. Otherwise the result recommends `:review`.

T06–T13 own source-identity/idempotency checks, persistent review and rejection state, reviewer decisions, whether a row has ever entered review, final rechecks against current Catalog, uniqueness races, and Catalog writes through `Catalog::Public::Writes`. A corrected row or a previously reviewed row must remain in review even if this stateless matcher later returns `:link` or `:create`. The matcher does not lock Catalog records, and unusual paraphrases below the threshold can still be missed. It reads the current catalog on every call; callers should requery just before a final decision. The current 975-product reference fits a full `find_each` scan per row; a larger catalog may need indexed candidate retrieval without changing this policy.
