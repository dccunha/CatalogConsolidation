# T08: Preserve identity and decisions across reruns

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Complete importer behavior for repeated, changed, pending, and resolved seller identities within a file and across runs. Own AC6/AC7 and the importer side of AC11. Exclude reviewer commands and UI; later tasks create the decisions whose replay behavior is established here.

## Required context

- [T07 importer](07-import-processing.md#handoff), [T06 persistence](06-intake-persistence.md#handoff), and [T04 normalization](04-row-validation-and-normalization.md#handoff).
- [RFC seller identity table](../rfcs/0001-import-review-lifecycle.md#seller-identity-and-row-outcomes) and [verification sequences](../rfcs/0001-import-review-lifecycle.md#examples-to-verify-during-implementation).
- [PRD AC6/AC7/AC11](../prds/catalog-consolidation-importer.md#9-acceptance-criteria).

## Deliverables and acceptance checks

- [x] Same key/identity with an active pending case yields another pending row result pointing to the same case, with no new case or Catalog write.
- [x] Same key/identity already linked, created, or resolved yields already imported with the retained product/decision and reason. Declined/displaced IDs remain unlinked.
- [x] A material source change opens a new pending case, preserves any current association, and supersedes the old pending version. Only the latest version remains actionable.
- [x] Compare against the active original source tuple after reviewer correction. A historical identity returning later is a new change, not permission to restore an old association.
- [x] Test accent/whitespace equivalents, repeated keys in one array, pending reruns, resolved reruns, correction reruns, multiple successive changes, and historical reversion.
- [x] Use explicit persisted fixtures for review decisions until T11–T13 provide commands; record this boundary. Those tasks and T14 must repeat journeys using real decision operations.
- [x] Run the supplied array through the service and verify 269 outcomes per run and no duplicate associations/cases for equivalent repeats, without prescribing category totals.

## Current checkpoint

- Completed: existing-key import transitions, original-source comparison, atomic supersession, fixture-based decision replay, sequence specs, supplied-file double run, and passing Docker CI on base `5c3631c` plus the T08 working tree.
- Remaining: independent correctness and test reviews; T11–T13 will provide real reviewer commands, and T14 will repeat the full journeys through them.
- Next action: orchestrator commits the candidate and assigns independent reviews.

## Problems

- **T08-P01 — 2026-09-30:** The first focused run found a test-fixture mismatch: the displaced seller item stored an incomplete comparison but the rerun supplied a complete brand. Aligning the fixture's source with its comparison made all 24 examples pass. The isolated run then exited 2 only because repository-wide branch coverage was 79.75% with the rest of the application unexercised; full CI exceeded both floors.
- **T08-P02 — 2026-09-30:** First full CI passed 146 RSpec examples and coverage but Sorbet rejected dereferencing a nullable review case after a safe-navigation comparison. An explicit nonnil guard fixed it; the next full CI passed.

## Decisions

- **T08-D01 — 2026-09-30:** After validation, the importer selects the exact seller key under a row lock and compares its persisted `active_source_comparison` to the incoming normalized tuple. Equivalent pending input produces another immutable row result referring to the existing pending case; equivalent linked/created/resolved/declined/displaced input produces `already_imported`. Its reason includes the retained resolution and, when present, decision ID/result/reason. A displaced key locates the decision that names it as displaced. Unlinked declined/displaced keys return no product reference and cause no Catalog write.
- **T08-D02 — 2026-09-30:** A changed tuple supersedes an active pending **or resolved** case, updates the seller item's original source snapshot and comparison, then opens a new pending case with fresh matcher evidence. Superseding a resolved case preserves its decision as historical while satisfying T06's single-active-version index. The entire transition and row result use T07's row transaction; a failure rolls it back and records a failed row separately. Existing Catalog association and product reference remain untouched until a later reviewer command. An old tuple returning after a newer one follows this same changed-source path, even when the old tuple had a decision.

## Validation evidence

- **2026-09-30 — Focused behavior on base `5c3631c` plus T08 working tree:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/services/import_processor_spec.rb` ran 24 examples, 0 failures. The isolated process exited 2 because whole-application SimpleCov measured 79.75% branch coverage against the 80% floor; full CI below passed. The examples cover exact seller keys, accent/whitespace equivalent comparison, repeated keys in one array and across runs, pending reuse, resolved decision replay, correction/source separation, successive changes, historical reversion, association retention, supersession rollback, declined/displaced identities, and two supplied-array runs. The `docs/refs/ProductEntry.json` source was read without modification; each run yielded exactly 269 ordered row outcomes, and equivalent repeat left seller-item, review-case, and Catalog-association counts unchanged. No outcome category totals are prescribed.
- **2026-09-30 — Full gate on the same base plus final T08 working tree:** `docker compose run --rm web bin/ci` passed Ruby/ERB/JS lint, Sorbet and concept sigils, gem/Rails RBI freshness, gem/importmap/Brakeman audits, database preparation/consistency, seeds, 146 RSpec examples (0 failures), and 1 Vitest test (0 failures). Ruby coverage was 772/775 lines (99.61%) and 148/161 branches (91.92%); JavaScript statements, lines, and functions were 100% (no branches). `git diff --check` passed. No RBI updates were needed.
- **Acceptance evidence boundary:** The decision replay and correction cases use persisted fixtures because reviewer operations do not exist yet. T11–T13 must repeat them through actual commands; T14 must verify end-to-end upload/review journeys. The supplied-file check verifies reconciliation and duplicate prevention, without assuming match-category totals.

## Handoff

T09 may expose `Intake::Services::ImportProcessor.call(json:, source_name:)` and `.fetch(batch_id:)` with the unchanged `Result` shape. Each valid existing key is compared to `SellerItem.active_source_comparison`, not the latest correction, Catalog product attributes, or a historical case. An equivalent pending row reuses the active pending case; an equivalent resolved or linked/created row reports `already_imported` and its retained product/decision; declined/displaced rows report no product. A material change atomically supersedes the former active case, installs a new pending case and evidence revision 1, and preserves any existing Catalog association. The new case is the only actionable version. T11–T13 reviewer commands must retain `active_source_input`/`active_source_comparison` when correcting or resolving; record decisions on resolved cases and keep historical decisions after later supersession. A reviewer command that displaces a seller item must clear its product reference, set `resolution: "displaced"`, and retain a decision referencing it. The importer never auto-links or creates a changed-source row.
