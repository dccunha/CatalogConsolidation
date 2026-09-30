# T09: Add web upload and batch results

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Let a local user upload the seller JSON and inspect batch summaries and row outcomes in the browser. Use synchronous processing and a clear, modestly styled Rails interface. Support AC1/AC10 visibility; exclude background jobs, seller-import CLI, authentication, and review actions.

## Required context

- [T08 importer handoff](08-reruns-and-source-identity.md#handoff), [T07 runner contract](07-import-processing.md#handoff), and [T01 Rails integration](01-concepts-and-catalog-persistence.md#handoff).
- [PRD output](../prds/catalog-consolidation-importer.md#8-import-output).
- [Agreed delivery choices](README.md#agreed-delivery-choices) and [ADR layout](../adrs/0001-organize-by-concepts.md#decision).
- Existing [routes](../../config/routes.rb) and [application layout](../../app/views/layouts/application.html.erb).

## Deliverables and acceptance checks

- [x] Add Intake-owned upload and batch-result pages with a discoverable application entry point.
- [x] Submit the uploaded content to the existing importer synchronously. Show clear errors for missing, malformed, or non-array input and a results page for valid arrays containing individual failures.
- [x] Show batch identity and reconciled totals, plus row numbers, seller keys, outcomes, product/case IDs, and reasons. Render source text safely, including HTML-like and quoted values.
- [x] Provide navigation to recorded batches/results. Only link to implemented routes; show review-case IDs until T10 supplies case pages.
- [x] Retain persisted row audit data after request completion. Keep upload handling limited to this local demonstration rather than adding file-management infrastructure.
- [x] Add request/form journey tests for successful upload, invalid file, mixed row outcomes, and reupload. The request interaction tests do not require a browser runtime inside Docker.
- [x] Verify readable labels, validation messages, empty states, and keyboard form use. Include screenshots and update the local run instructions.

## Current checkpoint

- Completed: Intake upload, batch history, and result routes/views; synchronous importer integration; request journeys; local run instructions; upload/result screenshots; generated route-helper RBIs; both independent approvals; exact-commit Docker CI; and [PR #19](https://github.com/dccunha/CatalogConsolidation/pull/19) merged at `3f464aa8242778301b3aaef5b6f547395f6de960`.
- Remaining: none for T09; final integrated browser QA remains in T14.
- Next action: T10 consumes the browser handoff below.

## Problems

- **T09-P01 — 2026-09-30:** The first full CI found missing generated route-helper RBIs and a Catalog concept-view fixture that replaced application routes while still rendering the new global navigation. Regenerated DSL RBIs and made that narrow fixture render without the application layout; subsequent full CI passed 155 examples. The fixture still verifies concept-owned view lookup.
- **T09-P02 — 2026-09-30:** The in-app browser file-chooser operation stalled during manual upload inspection and the browser surface became unavailable after interruption. Request specs cover real multipart uploads. The upload screenshot was captured before interruption; a local development batch was created through the same importer service and its result page was captured with installed headless Chromium. No application behavior depends on that browser session.
- **T09-P03 — 2026-09-30:** First-round test review T09-TEST-01 found that the mixed-results request spec checked only page-wide substrings, so a swapped row or incorrect count could pass. The spec now parses the rendered summary and row table to assert exact totals, positions, seller keys, outcomes, product/case IDs, and row-specific reasons. It also checks six zero totals for an empty array. Both reviewers approved the fix in round 2.

## Decisions

- **T09-D01 — 2026-09-30:** `GET /` and `GET /import/new` show the upload form, `POST /import` reads the multipart file and invokes `Intake::Services::ImportProcessor.call(json:, source_name:)` synchronously, `GET /batches` lists recorded batches newest first, and `GET /batches/:id` shows immutable row results. A missing upload or importer `FileError` renders the form with an alert and HTTP 422; a valid JSON array redirects to the persisted result, including arrays with failed individual rows. Existing CSRF protection remains active. No file is stored beyond the import's audit records.
- **T09-D02 — 2026-09-30:** The result page obtains reconciled totals through `ImportProcessor.fetch(batch_id:)` and reads `Batch#row_results` ordered by source position for `input_json`. Rails ERB escapes seller keys, filenames, reasons, and source JSON; source is behind keyboard-accessible native details/summary. Case IDs are text until T10 adds case routes. Request specs exercise the form and server responses, so adding a browser-test runtime to Docker would add a dependency without improving these journeys.

## Validation evidence

- **2026-09-30 — Focused request journeys:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/controllers/imports_controller_spec.rb` ran 7 examples, 0 failures before the empty-history assertion was added. The isolated process exited 2 because whole-application SimpleCov measured 76.13% lines and 52.14% branches when only this file ran. The full suite below exceeds both floors. The specs cover discoverable form/label/required input, successful multipart upload, missing/malformed/non-array files, mixed linked/failed/pending rows with escaped HTML-like and quoted seller text, reupload preserving the first audit, and a valid empty array. The subsequent added example covers empty batch history.
- **2026-09-30 — First full gate:** `docker compose run --rm web bin/ci` failed on Sorbet and Rails RBI freshness for new route helpers, plus one Catalog view-lookup fixture failure caused by the global layout expecting the new routes. All other checks passed; 155 RSpec examples ran with 1 failure and Ruby coverage was 810/813 lines (99.63%) and 150/163 branches (92.02%). Those defects were fixed before the next run.
- **2026-09-30 — Final full gate on the T09 working tree:** `docker compose run --rm web bin/ci` passed Ruby/ERB/JS lint, Sorbet and concept sigils, gem/Rails RBI freshness, gem/importmap/Brakeman audits, database preparation/consistency, seeds, 156 RSpec examples (0 failures), and 1 Vitest test (0 failures). Ruby coverage was 810/813 lines (99.63%) and 150/163 branches (92.02%); JavaScript coverage was 100% statements/lines/functions (no application branches). `git diff --check` passed. No Docker browser runtime was needed because the form journeys are request specs.
- **2026-09-30 — Review-fix focused run on candidate `4c89f0d` plus working tree:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/controllers/imports_controller_spec.rb` ran 8 examples, 0 failures. The isolated process exited 2 because whole-application SimpleCov measured 76.13% lines and 52.14% branches with only this file loaded; the full gate below must verify the coverage floors. The upload screenshot was recaptured with installed headless Chromium after the wording correction and visually inspected.
- **2026-09-30 — Review-fix full gate on candidate `4c89f0d` plus working tree:** `docker compose run --rm web bin/ci` passed Ruby/ERB/JS lint, Sorbet and concept sigils, gem/Rails RBI freshness, gem/importmap/Brakeman audits, database preparation/consistency, seeds, 156 RSpec examples (0 failures), and 1 Vitest test (0 failures). Ruby coverage was 810/813 lines (99.63%) and 150/163 branches (92.02%); JavaScript coverage was 100% statements/lines/functions (no application branches). `git diff --check` passed.
- **2026-09-30 — Visual inspection:** [Upload form screenshot](screenshots/t09-upload.png) at a 1280 px desktop viewport and [batch results screenshot](screenshots/t09-results.png) at 1280 px show the labeled file input, global navigation, summary cards, ordered row table, review-case ID as text, and created/pending/failed outcomes. The results screenshot uses a three-row local development batch (one created, one pending, one failed), seeded through `ImportProcessor.call` only for visual inspection; it is not a test fixture. The upload page was first inspected in the in-app browser; both current screenshots were captured with installed headless Chromium after that browser surface became unavailable.

### Review rounds

- **Round 1, candidate `4c89f0d608ae498b57ef29046b24827a0bb3078a` (2026-09-30):** correctness reviewer approved the code and visual behavior, and suggested replacing upload copy that incorrectly said the import runs while the page loads. Test reviewer raised **T09-TEST-01 (P2)**: the mixed-results request spec asserted only page-wide substrings and could miss misplaced row data or unreconciled visible totals. Exact-commit Docker CI passed 156 RSpec examples, Ruby 99.63% lines/92.02% branches, and all other gates. The review-fix commit adds parsed summary and table assertions, corrects copy, and recaptures the screenshot.
- **Round 2, candidate `a015ebb028a3ca23831d30d114efc975cfc1e18b` (2026-09-30):** correctness reviewer approved the full diff and refreshed 1280 px screenshot with no blocking issue. Test reviewer approved T09-TEST-01 after inspecting exact rendered totals, ordered row references, and empty-array totals, and reran `docker compose run --rm web bin/ci` on this exact clean commit: 156 RSpec examples, 0 failures, Ruby 99.63% line/92.02% branch coverage, one passing Vitest test, and all other gates passed. `git diff --check` passed. Real-browser keyboard/file-chooser interaction was not independently executed; native labelled controls, multipart request journeys, and screenshots are the current verification evidence.
- **2026-09-30 — Merge verification:** both reviewers approved documentation-only follow-ups through PR head `817f85b7768f5fecbe5f66e66f89d2751564688f`. GitHub reported PR #19 `MERGEABLE`/`CLEAN` at that exact head with no required hosted checks, then `MERGED` at `3f464aa8242778301b3aaef5b6f547395f6de960`; main pointed to that merge commit. T10 is unblocked.

## Handoff

T10 may reuse `Intake::Controllers::BaseController` and its `app/concepts/intake/views` lookup. Browser routes are `root_path`/`new_import_path`, `import_path` (POST), `batches_path`, and `batch_path(id)`; global navigation is in `app/views/layouts/application.html.erb`. The upload accepts the `file` multipart field and invokes `ImportProcessor.call`, handling `FileError` as HTTP 422. `BatchesController#show` uses `.fetch(batch_id:)` for totals and ordered `Batch#row_results` for source JSON and display fields. Review-case IDs in `app/concepts/intake/views/batches/show.html.erb` are plain text; T10 can make them links when a case detail route exists. `spec/concepts/intake/controllers/imports_controller_spec.rb` exercises request/form journeys with Rack::Test inside Docker; no browser runtime was added. The standard `docker compose run --rm web bin/ci` runs those journeys. The local run instructions are in `README.md`.
