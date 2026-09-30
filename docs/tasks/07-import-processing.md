# T07: Process imports with failure isolation

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Process a valid JSON array into persistent, explainable row outcomes and a reconciled batch summary. Own AC1, AC2, AC5, AC9, and AC10's core behavior. This task handles new seller identities; T08 completes duplicate/rerun semantics before any public upload interface is exposed.

## Required context

- [T03 write contract](03-catalog-public-writes.md#handoff), [T04 validation](04-row-validation-and-normalization.md#handoff), [T05 matching](05-matching-and-candidate-evidence.md#handoff), and [T06 persistence](06-intake-persistence.md#handoff).
- [PRD import behavior](../prds/catalog-consolidation-importer.md#5-import-behavior) and [output](../prds/catalog-consolidation-importer.md#8-import-output).
- [RFC row outcomes](../rfcs/0001-import-review-lifecycle.md#seller-identity-and-row-outcomes) and [ownership](../rfcs/0001-import-review-lifecycle.md#persistence-and-ownership-contract).

## Deliverables and acceptance checks

- [x] Reject malformed JSON and non-array top-level input with a clear file error. A valid array gets one outcome per element, including non-object or invalid rows.
- [x] Validate and match new identities, then link/create through `Catalog::Public` or persist a pending case with evidence and reason.
- [x] Use row-level transactions for successful Catalog/Intake changes. A failed Catalog write leaves no partial product/association; persist the failure result outside the rolled-back unit and continue.
- [x] Return the batch ID and totals for linked, created, already imported, pending review, and failed outcomes, with row number, seller key, references, and readable reasons.
- [x] Ensure later rows see Catalog changes from earlier rows. Do not create duplicates by matching against a frozen pre-import catalog.
- [x] Test exact linking to product 2, no-candidate creation, incomplete metadata, invalid elements between valid rows, forced write rollback, and SQL-like strings stored as data.
- [x] Verify totals reconcile for each tested array. Keep the service internal until T08 handles repeated keys; a complete supplied-file/rerun journey is verified later.

## Current checkpoint

- Completed: internal `Intake::Services::ImportProcessor`, 13 focused examples, and a passing full Docker CI gate on the T07 implementation working tree based on `72c89afb05e8dc79039d88c16c7245ba2389f3eb`.
- Remaining: independent correctness and test reviews, any review fixes, PR, and merge. T08 owns repeated-key and rerun semantics before web upload is exposed.
- Next action: independent review of the candidate.

## Problems

- The first focused run had three test assertion/fault-injection issues; the corrected focused examples passed. Focused RSpec exits 2 because its repository-wide SimpleCov denominator misses unrelated files, while full CI passes both coverage floors.
- The first full CI run found two RuboCop method-size offenses and one Sorbet nilability error in candidate persistence. Signed helper extraction resolved them; the final full CI passed.

## Decisions

- **T07-D01 — 2026-09-30:** `Intake::Services::ImportProcessor.call(json: String, source_name: String) -> Result` is an internal entry point. It parses before creating a batch and raises `FileError` for malformed JSON or a non-array top level; no batch is created for those file errors. An empty array creates a zero-row batch. `Result` contains `batch_id`, `input_count`, totals for all five outcomes, and one ordered `Row` per one-based source position. Each row has the exact seller key when valid, outcome, readable reason, and nullable product/review-case references. `.fetch(batch_id:)` reconstructs the same report from persisted row results and rejects any gap in the exact `1..input_count` sequence.
- **T07-D02 — 2026-09-30:** Each valid new-key row calls the T04 validator and T05 matcher against current Catalog state. A sole safe exact candidate links through `Catalog::Public::Writes.link`; a complete row with no candidate creates through `.create_with_association`; all other recommendations open a pending case with the original JSON, normalized source comparison, reason, revision 1 candidate snapshots, and same-seller association conflict. A new `SellerItem` records the original source and current resolution. No Intake code writes Catalog models directly.
- **T07-D03 — 2026-09-30:** Catalog and Intake success writes share one row transaction. A row exception rolls back that unit; the failed `RowResult` is then saved outside the rollback and processing continues. Validation failures never enter Catalog writes. An unpersistable audit result remains a batch-stopping error rather than silently reporting an incomplete batch. Existing keys currently fall through to a failed row on Intake uniqueness; T08 will replace that provisional outcome with the accepted pending/already-imported/changed-source lifecycle before the service is public.

## Validation evidence

- **2026-09-30 — Focused behavior on base `72c89afb05e8dc79039d88c16c7245ba2389f3eb` plus the T07 working tree:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/services/import_processor_spec.rb` ran 13 examples, 0 failures. The process exited 2 only because isolated-file SimpleCov measured 87.03% lines and 71.85% branches over the whole application; full CI below passed both floors. The examples cover file errors, empty arrays, reference product 2, new-product creation and live later-row linking, incomplete metadata with and without candidates, persisted conflict/candidate evidence, invalid middle elements and source positions, forced Catalog/Intake rollback with later-row continuation, SQL-like strings as data, report reconstruction, and detection of missing positions despite a matching count.
- **2026-09-30 — Full gate on the same base plus final T07 working tree:** `docker compose run --rm web bin/ci` passed Ruby/ERB/JS lint, Sorbet, concept sigils, gem and Rails RBI freshness, gem/importmap/Brakeman audits, database preparation/consistency, seeds, 135 RSpec examples (0 failures), and 1 Vitest test (0 failures). Ruby coverage was 721/725 lines (99.44%) and 125/135 branches (92.59%); JavaScript statements, lines, and functions were 100% (no branches). The new concept service is `# typed: true` with signatures for its public interface and nontrivial helpers; no RBI updates were needed. `git diff --check` passed.
- **Acceptance evidence boundary:** T07 directly verifies AC2's exact product-2 link, AC5's incomplete metadata, AC9's atomic no-candidate creation and SQL-like text, and AC10's invalid-row continuation. It verifies the one-result-per-element and reconciliation core of AC1 on constructed arrays. The supplied 269-row journey and all repeated-key outcomes remain for T08/T14.

## Handoff

T08 should extend `Intake::Services::ImportProcessor.call(json:, source_name:)` after validation and before any new-key match/write. `SellerItem.find_exact` plus `active_source_comparison` determine unchanged pending, unchanged resolved, and changed-source outcomes; lock and supersede an old active case atomically as T06 describes. The current new-key branch is internal and deliberately treats existing keys as failed when Intake uniqueness rejects them, so T08 must change that before T09 exposes upload. Keep the existing `RowResult` one-per-position audit, its failure isolation, and `.fetch(batch_id:) -> Result` report shape for T09. `FileError` is for malformed/non-array files only; a failed row remains inside a completed valid-array batch. Candidate snapshots use revision 1 and the T05 ranking/evidence fields. T08 should preserve prior decisions and active original-source comparisons, then verify the supplied-file and rerun journeys.
