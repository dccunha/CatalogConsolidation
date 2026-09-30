# T16: Block SQL control syntax from Catalog writes

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Future imports reject defined SQL control syntax before matching or Catalog writes. The failed row retains its full source in Intake, but creates no seller item, review case, product, or Catalog association. This changes [AC9](../prds/catalog-consolidation-importer.md#9-acceptance-criteria) and the [review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle). Do not edit `docs/refs/`, clean historical batch #1, or modify the existing QA product #976 or its association.

This is a defined syntax filter, not a universal SQL injection detector. Downstream consumers must still treat Catalog text as untrusted and use safe queries and output encoding.

## Required context

- [T15 handoff](15-delivery-and-demo.md#handoff), [quality gates](quality-gates.md), [ADR 0001](../adrs/0001-organize-by-concepts.md), [PRD AC9](../prds/catalog-consolidation-importer.md#9-acceptance-criteria), and [RFC review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle).
- Import entry points: `app/concepts/intake/services/row_validator.rb`, `import_processor.rb`, and `review_actions.rb` in the same directory.
- Catalog public boundary: `app/concepts/catalog/public/writes.rb`.
- Existing behavior specs: `spec/concepts/intake/services/`, `spec/concepts/catalog/public/writes_spec.rb`, and `spec/concepts/intake/acceptance_journeys_spec.rb`.

## Deliverables and acceptance checks

- [x] Before matching or a Catalog write, inspect incoming `Id`, `SellerName`, `Name`, `Brand`, and `Category`. Reject a string containing `;`, `--`, `/*`, `*/`, or control characters. Ordinary apostrophes and product punctuation remain valid.
- [x] Record a flagged import row as **Failed**, keep the full original source in Intake audit, and display the offending field and clear reason in batch results. Create no seller item, review case, product, or Catalog association. The failed row has no review action; a corrected value requires a new import.
- [x] Guard newly supplied string values at `Catalog::Public::Writes`, including reviewer corrections; reject atomically. Handle an older unsafe pending case without a server error. Do not inspect existing target-product fields during link or reassignment.
- [x] Update PRD AC9, RFC lifecycle, README, and index acceptance evidence. Preserve `docs/refs/` and historical QA data.
- [x] Test all five fields and blocked syntax forms, valid apostrophes and punctuation, Intake audit retention, absence of Catalog writes, later-row continuation, reruns, correction handling, legacy pending cases, and atomic rejection by Catalog's public API. Update prior tests that expected SQL-like values to create a product.
- [x] On a clean import of the supplied 269-row file, verify row 181 is **Failed**, its payload exists only in Intake, and batch totals reconcile.
- [x] Run focused Docker checks and full Docker `bin/ci`, with coverage and Sorbet gates. Record actual evidence and any UI screenshot if the batch display visibly changes.

## Current checkpoint

- Completed: T15 merge verified as [PR #25](https://github.com/dccunha/CatalogConsolidation/pull/25), commit `ac839ef7b5382e216a4933c7f71886824bf59b0f`; T16 implementation, focused specs, clean import, visible screenshot, and full isolated Docker CI passed on the working-tree candidate. The parent owns the index and Git/PR record.
- Remaining: candidate commit, two independent reviews, PR, merge, and final QA handoff.
- Next action: parent freezes the candidate, commits it, and dispatches correctness and test reviewers.

## Problems

- **Resolved during implementation:** Initial full CI had two RuboCop ABC-size offenses in `ReviewActions`; extraction of the correction save method and reuse of the active-case predicate cleared them. All 235 RSpec examples already passed in that first run; the final full CI rerun passed every gate.
- **Audit constraint:** The original `input_json::jsonb` constraint rejected valid JSON containing escaped NUL, which prevented full Intake retention. T16 changes only that check to `input_json IS JSON`. Rollback restores the old check when all rows are compatible and raises an explicit irreversible-migration error if escaped-NUL audit rows exist; it never deletes source data.

## Decisions

- **T16-D01 — 2026-09-30:** Reject only the defined control syntax in incoming fields and Catalog public writes. Preserve original source in Intake; do not create a review case for a failed row. Allow ordinary apostrophes. The user approved this behavior in the T16 plan; update the PRD and RFC in this task.
- **T16-D02 — 2026-09-30:** Do not inspect stored fields of an existing target product when linking/reassigning. Existing QA product #976, its association, and historical batch #1 remain untouched; the new rule applies to future inputs.
- **T16-D03 — 2026-09-30:** Use isolated Compose project `t16_guard` for tests and clean acceptance verification. The existing main-branch QA database remains in use and must not be reset.
- **T16-D04 — 2026-09-30:** Centralize the defined syntax rule in typed `Catalog::Public::TextPolicy` so Intake validation and Catalog public writes use the same token/control-character detection. `Catalog::Public::Writes::UnsafeTextError` names the field and violation before a write transaction. Existing target-product values and non-persisted expected-state strings are outside the rule.
- **T16-D05 — 2026-09-30:** Use PostgreSQL 18's `IS JSON` text predicate for the Intake audit constraint. This retains JSON-valid escaped NUL without coercing the source into jsonb, while continuing to reject malformed JSON. The migration preserves existing rows and has guarded rollback behavior.

## Validation evidence

- **2026-09-30 — Focused behavior on T16 working tree based on `a081718`:** In isolated project `t16_guard`, the validator/Catalog/review/request command ran 93 examples with zero assertion failures; the importer/acceptance command ran 30 examples with zero assertion failures, including two clean transactional 269-row journeys; the audit migration command ran two examples with zero assertion failures. Each partial RSpec invocation exited 2 solely because whole-application SimpleCov floors are enforced even on a subset. Full CI below passed those floors. The tests cover five fields and all control forms, apostrophes, batch isolation and continuation, Intake-only audit payload, repeated failed rows, legacy pending-case rendering and safe correction, atomic Catalog rejection, and the migration's existing-row and rollback behavior.
- **2026-09-30 — Final full gate on the completed application/spec working tree based on `a081718`:** `docker compose -p t16_guard run --rm web bin/ci` exited 0 in 2m17.97s. Ruby, ERB, and JavaScript lint; Sorbet (`No errors`), concept sigils, gem/Rails RBI freshness, gem/importmap/Brakeman audits, test DB prepare and consistency, and seeds all passed. RSpec: 235 examples, zero failures; Ruby lines 1335/1350 (98.88%) and branches 309/353 (87.53%). Vitest: one test, zero failures, 100% applicable statements/lines/functions, no measured branches. No RBI regeneration was needed. A prior full run exited 1 solely for the two resolved RuboCop offenses; its test/coverage checks had passed.
- **2026-09-30 — Clean supplied-file verification:** Before importing, isolated `t16_guard` development DB had zero products and zero batches. `Catalog::Services::ReferenceCatalogLoader.call` loaded 975 products; `ImportProcessor.call` on unchanged `docs/refs/ProductEntry.json` recorded all 269 positions with totals `linked=247`, `created=0`, `already_imported=1`, `pending_review=20`, `failed=1`. Row 181 is **Failed** with reason `Brand contains prohibited semicolon (;)`, its exact original JSON is in the Intake row result, its `product_id` and `review_case_id` are null, and seller-item/association/payload-brand-product queries each returned zero. An unchanged rerun yielded `already_imported=248`, `pending_review=20`, `failed=1` and row 181 remained **Failed** with no product or case. These totals reconcile to 269 on each run.
- **2026-09-30 — Visual and integrity evidence:** The isolated web app on port 3116 displayed [row 181 as Failed](screenshots/t16-row-181-failed.png), with no product/case ID and the Brand reason; headless Chromium captured the page at 1280×900 and the screenshot was visually inspected. `git diff --check` exited 0. Unchanged reference hashes: `ProductEntry.json` `1b0c861fe568c19e8b1cebcf774ee3d1d95baf8c42e35129e4ae806ece04b8f6`; `catalog.db` `733ff1d9cc20253da48a9f8b33d7241503e4a06e7c68f65f7fa00ef14466c404`. The default main-branch QA project and historical batch #1/product #976 were not modified.

### Review rounds

No review yet. Record each independent verdict, findings, resolution, and final reviewed PR head here.

## Handoff

`Catalog::Public::TextPolicy.violation(String)` returns a violation description or nil. `RowValidator.call` uses it before seller-key lookup; `ImportProcessor` stores invalid rows in Intake and omits unsafe seller keys from scalar audit columns when necessary, retaining the full JSON text. The migration changes the audit constraint from a jsonb cast to `IS JSON` so escaped NUL can be retained. `Catalog::Public::Writes` checks new persisted strings for link, create, reassign, and create-for-association before starting a transaction and raises `UnsafeTextError` naming the field; existing target-product fields are not checked. Legacy invalid pending cases render with no decision forms, action attempts return an invalid result instead of a server error, and a safe Name/Brand/Category correction can restore reviewability. This is a defined syntax filter; downstream systems still need safe queries and output encoding. No historical QA data was changed. The parent must bind this evidence to a candidate commit, obtain two independent reviews, create/merge the PR after gates, and record verified merge evidence before closing T16.
