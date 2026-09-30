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

- [ ] Require nonempty string `Id`, `SellerName`, and `Name`, using trimming only to check key emptiness. Preserve the exact supplied seller name and opaque item ID; no integer/UUID conversion.
- [ ] Represent missing/blank brand or category as absent comparison metadata requiring review. Keep source values separate from normalized values.
- [ ] Normalize comparison fields using Unicode case folding, diacritic removal, trimming, and whitespace collapse. Preserve punctuation, numbers, units, models, and variant words.
- [ ] Handle malformed array elements as invalid rows without raising a file-stopping error. Define the validation result and error contract, including malformed field types.
- [ ] Test null/blank required fields, case-distinct seller keys, nonnumeric IDs, accent/whitespace equivalence, Unicode case folding, punctuation differences, and material variants.
- [ ] Document the reusable comparison contract for catalog values so T05 applies the same normalization to both sides.

## Current checkpoint

- Completed: task brief only.
- Remaining: validation/normalization behavior and tests.
- Next action: inspect sample field shapes and implement isolated comparison behavior under Intake.

## Problems

None recorded.

## Decisions

None recorded. Record the normalized-value representation, validation outcomes, and handling of malformed field types. Do not coerce seller keys to repair input.

## Validation evidence

Not run. Record focused examples and CI results; link relevant acceptance evidence in the index.

## Handoff

Not implemented. Publish validator/normalizer interfaces, absent-value representation, preserved source data, and errors for T05–T08. Note Unicode behavior with concrete passing examples.
