# T04: Validate and normalize seller rows

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Turn one input element into validated source data and comparison values without performing persistence or matching. Preserve the original seller key and source values. This supports AC5, AC6, AC10, and AC12; file parsing and result persistence belong to later tasks.

## Required context

- [T01 handoff](01-concepts-and-catalog-persistence.md#handoff) for concept/spec conventions.
- [PRD validation](../prds/catalog-consolidation-importer.md#51-row-validation-and-idempotency).
- [RFC seller identity](../rfcs/0001-import-review-lifecycle.md#seller-identity-and-row-outcomes) and [normalization](../rfcs/0001-import-review-lifecycle.md#matching-and-candidate-evidence).
- [Sample input](../refs/ProductEntry.json), kept unchanged.

## Deliverables and acceptance checks

- [x] Require nonempty string `Id`, `SellerName`, and `Name`, using trimming only to check key emptiness. Preserve the exact supplied seller name and opaque item ID; no integer/UUID conversion.
- [x] Represent missing/blank brand or category as absent comparison metadata requiring review. Keep source values separate from normalized values.
- [x] Normalize comparison fields using Unicode case folding, diacritic removal, trimming, and whitespace collapse. Preserve punctuation, numbers, units, models, and variant words.
- [x] Handle malformed array elements as invalid rows without raising a file-stopping error. Define the validation result and error contract, including malformed field types.
- [x] Test null/blank required fields, case-distinct seller keys, nonnumeric IDs, accent/whitespace equivalence, Unicode case folding, punctuation differences, and material variants.
- [x] Document the reusable comparison contract for catalog values so T05 applies the same normalization to both sides.

## Current checkpoint

- Completed: Intake row validator, reusable comparison normalizer, 18 focused examples, and passing full Docker CI on the implementation working tree.
- Remaining: independent reviews, PR, and merge verification; the task index owns status.
- Next action: parent records the candidate revision and sends this implementation for correctness and test review.

## Problems

- The first `bin/ci` run found a lint complexity issue, multi-expectation unit examples, and Sorbet's incomplete signature for Ruby's `String#downcase(:fold)`. The implementation and examples were revised; the final `bin/ci` passed.

## Decisions

- **T04-D01 — 2026-09-30:** `Intake::Services::RowValidator.call(element)` returns `Valid(source:, comparison:)` or `Invalid(input:, errors:)`. It does not raise for a malformed array element. Each `Error` has `field` (`nil` for a non-object element) and `code` (`:not_an_object`, `:required`, or `:invalid_type`), in field order. Missing, null, or Unicode-whitespace-only required fields receive `:required`; a nonstring required or optional field receives `:invalid_type`. Optional brand/category may be missing, null, or blank and then require review. Invalid input is retained in `Invalid#input` for later row-result audit.
- **T04-D02 — 2026-09-30:** `Valid#source` contains exactly supplied `Id` as `seller_product_id`, `SellerName` as `seller_name`, and `Name`, `Brand`, and `Category` values, including their whitespace and case. `Valid#comparison` is an immutable `ComparisonNormalizer::Identity` with normalized `name`, nullable `brand`, and nullable `category`. Blank optional text normalizes to `nil`; `Valid#review_required?` is true when either normalized metadata value is absent. The seller key is never normalized or coerced.
- **T04-D03 — 2026-09-30:** `ComparisonNormalizer.call(name:, brand:, category:)` is the reusable contract for both seller and Catalog product values. `normalize` uses Ruby full Unicode case folding, NFD canonical decomposition for diacritic removal, Unicode whitespace collapse, and trim; punctuation, numbers, units, models, and variant words remain. Compatibility decomposition is deliberately avoided because it can rewrite number and punctuation characters. `Identity` compares and hashes by its three normalized values. Ruby supports `String#downcase(:fold)`, while Sorbet's core RBI declares only zero arguments, so one narrow `T.unsafe` call is immediately cast back to `String`; the rest of the normalizer is typed.

## Validation evidence

- **2026-09-30 — Focused behavior:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/services` ran 18 examples, 0 failures. Its exit code was 2 because SimpleCov measures the whole application and focused specs did not exercise Catalog; this is not a focused behavior failure. The full suite below passed the required coverage floors. [Validator examples](../../spec/concepts/intake/services/row_validator_unit_spec.rb) cover opaque IDs, exact seller/source preservation, case-distinct keys, absent metadata, null/blank/missing required values, malformed types and elements, and continuation. [Normalizer examples](../../spec/concepts/intake/services/comparison_normalizer_unit_spec.rb) cover accent/whitespace equivalence, `Straße`/`STRASSE` case folding, punctuation, capacity, and Unicode compatibility-character differences, and reuse for catalog-shaped values.
- **2026-09-30 — Passed on HEAD `dae05cca17d2507a6bc627b91603e2de75a12108` plus the T04 implementation working tree:** `docker compose run --rm web bin/ci` passed Ruby/ERB/JS lint, Sorbet and concept sigils, RBI freshness, gem/importmap/Brakeman audits, database preparation/consistency, seeds, 75 RSpec examples (0 failures), and Vitest (1 test, 0 failures). Ruby coverage was 284/287 lines (98.95%) and 39/40 branches (97.50%); JavaScript coverage was 100% of statements, lines, and functions (no branches). `docker compose run --rm web bundle exec srb tc` also passed independently. No RBI updates were needed.

## Handoff

T05 should call `Intake::Services::ComparisonNormalizer.call(name:, brand:, category:)` for every Catalog product and compare its `Identity` with `Valid#comparison` from `Intake::Services::RowValidator.call`. `Identity` has value equality and hashing. `"Câmera"` and `"Camera"` compare equal, as do `"Straße"` and `"STRASSE"`; `12.9''` differs from `12.9"`, and `128GB` differs from `256GB`. `nil`, missing, and whitespace-only brand/category normalize to `nil`, and `Valid#review_required?` signals review. Do not pass seller keys through this normalizer: `Valid#source.seller_name` and `seller_product_id` are the exact strings needed for persistence and rerun identity.

T06–T08 can call `RowValidator.call` on each parsed array element independently. A `Valid` result has typed `source` and `comparison`; an `Invalid` result retains `input` and ordered field/code errors for a failed row. Non-object elements return `field: nil, code: :not_an_object`; required fields use `:required` or `:invalid_type`; nonstring brand/category use `:invalid_type`. This task does not parse the file, match products, or persist outcomes.
