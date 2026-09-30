# T14: Verify complete acceptance journeys

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Verify AC1–AC12 and the RFC lifecycle through the integrated application, closing gaps between earlier focused tests. This is integration verification, not the first testing phase. Exclude expanding matching policy, production deployment, or substituting demo screenshots for regression coverage.

## Required context

- [PRD acceptance criteria](../prds/catalog-consolidation-importer.md#9-acceptance-criteria) and [RFC verification sequences](../rfcs/0001-import-review-lifecycle.md#examples-to-verify-during-implementation).
- [Acceptance evidence matrix](README.md#acceptance-coverage): follow implemented test links rather than reading every completed brief.
- [T13 completed actions](13-reassignment-and-listing-conflicts.md#handoff), [T09 browser/runtime setup](09-web-upload-and-results.md#handoff), and [T02 loader](02-reference-catalog-loading.md#handoff).
- [Reference JSON](../refs/ProductEntry.json) and [SQLite catalog](../refs/catalog.db), both unchanged.

## Deliverables and acceptance checks

- [x] Map each AC to concrete passing assertions in the [index](README.md#acceptance-coverage). Reuse focused coverage and add cross-component tests where integration failures could hide.
- [x] From a clean test database, load reference products and import all 269 rows. Verify outcome count and summary reconciliation without prescribing category totals.
- [x] Reimport without duplicate associations or equivalent pending cases; resolve cases through real commands/UI and rerun original input to verify retained decisions.
- [x] Exercise automatic link/create, near-match review, missing/conflicting metadata, invalid rows between valid rows, material variants, changed identities, and both listing-conflict choices.
- [x] Include correction followed by original-source rerun, newly appearing candidate after all earlier rejections, and superseded/displaced/declined identity replay.
- [x] Verify per-row and final-decision rollback through the linked focused specs, with immutable historical row results in integrated and browser journeys.
- [x] Exercise browser upload/results and complete review journeys with click/keyboard input in Docker Chromium; check loaded Turbo and Stimulus globals.
- [x] Run the final full required CI, confirm reference inputs remain unchanged, inspect representative UI evidence, and record limitations.

## Current checkpoint

- Completed: AC1–AC12 and RFC evidence audit, four integrated examples, four real Chromium browser examples, clean reference aggregate run, screenshot capture and inspection, unchanged reference hashes, index acceptance-matrix update, and passing full Docker CI on this working tree.
- Remaining: two independent reviews, PR, and merge belong to the orchestrator; no implementation blocker remains.
- Next action: orchestrator commits the stable candidate and assigns correctness and test reviewers against that exact revision.

## Problems

No application acceptance defect found. Initial T14 assertions assumed the Canon category appeared in the row reason (it is in persisted candidate evidence) and that the `256GB` variant stayed pending (it was safely created as a distinct product). Corrected those assertions to the agreed AC4/AC12 contracts. The first full CI run found RuboCop `Lint/Debugger` on the screenshot helper; replaced it with a WebDriver PNG write, pending final rerun.

## Decisions

Added Debian Chromium and chromedriver to the Docker development image so Capybara/Selenium can exercise the application with JavaScript enabled inside Docker. This is test runtime setup; no matching, review, architecture, or product policy changed. The original reference-input aggregate is observed data, not a prescribed category distribution.

## Validation evidence

- **2026-09-30 — Reference aggregate, clean test database:** `docker compose run --rm -e RAILS_ENV=test web bin/rails runner tmp/t14_aggregate.rb` began with zero Catalog products and Intake batches, loaded 975 canonical products, and processed the unchanged 269-element JSON twice in a transaction that rolled back. First run observed `linked=247`, `created=1`, `already_imported=1`, `pending_review=20`, `failed=0`; second observed `linked=0`, `created=0`, `already_imported=249`, `pending_review=20`, `failed=0`. Both sum to 269. After each run, entity counts were identical: 976 products, 248 seller associations, 268 Intake seller items, 20 review cases. These totals describe this reference input and current matching implementation; tests assert reconciliation and stable counts rather than baking category totals into policy.
- **2026-09-30 — Reference integrity:** `sha256sum docs/refs/ProductEntry.json docs/refs/catalog.db` returned `1b0c861fe568c19e8b1cebcf774ee3d1d95baf8c42e35129e4ae806ece04b8f6` and `733ff1d9cc20253da48a9f8b33d7241503e4a06e7c68f65f7fa00ef14466c404` respectively; `git diff -- docs/refs/ProductEntry.json docs/refs/catalog.db` was empty.
- **2026-09-30 — Integrated and browser scenarios:** [four integrated examples](../../spec/concepts/intake/acceptance_journeys_spec.rb) passed in the first full CI run, covering canonical load/rerun, mixed invalid/incomplete/variant/SQL-like input, correction→approval→source replay→changed-identity reassignment, and candidate refresh after rejection. [Four Selenium/Chromium system examples](../../spec/system/acceptance_journeys_spec.rb) passed with actual click/keyboard interactions for upload/results, Turbo/Stimulus load, correction/approval/rerun, rejection/correction/creation, and both listing-conflict choices/reruns. Their isolated focused run reported four examples, zero failures, then exited 2 solely because a subset cannot meet whole-application SimpleCov floors; the full suite below met them. Screenshots: [mixed batch results](screenshots/t14-browser-results.png), [resolved decision](screenshots/t14-browser-decision.png), [keep existing](screenshots/t14-browser-keep-conflict.png), and [replace existing](screenshots/t14-browser-replace-conflict.png).
- **2026-09-30 — First full CI run, superseded:** `docker compose run --rm web bin/ci` completed 222 RSpec examples with zero failures, Ruby lines 1283/1298 (98.84%) and branches 280/325 (86.15%), one Vitest test with 100% applicable coverage, Sorbet `No errors`, both RBI freshness checks, audits, database/seed checks. It exited 1 solely for RuboCop `Lint/Debugger` on the screenshot helper. The helper has been repaired and requires a fresh full gate; this first run is not recorded as a pass.
- **2026-09-30 — Final full gate passed on the completed T14 working tree based on `b5b75e5`:** `docker compose run --rm web bin/ci` exited 0 in 2m19.54s. Ruby/ERB/JavaScript lint, Sorbet (`No errors`), concept sigils, gem/Rails RBI freshness, gem/importmap/Brakeman security audits, test database preparation/consistency, and seed replant all passed. RSpec: 222 examples, zero failures; Ruby lines 1283/1298 (98.84%), branches 280/325 (86.15%). Vitest: one test, zero failures, 100% applicable JavaScript statements/lines/functions (no measured branches). No new concept Ruby files, schema, or RBI changes. `git diff --check` was clean. The four screenshots were visually inspected for legible results and decision state.

## Handoff

T15 can use the [AC1–AC12/RFC evidence matrix](README.md#acceptance-coverage), four integrated and four real-browser examples, and the screenshots linked above. Build the Docker web image to obtain Chromium/chromedriver, then run the standard CI command. The clean reference aggregate above is reproducible from the canonical loader and importer, but its category totals are observations only. The browser system specs are automated in Docker and exercise actual Turbo form navigation and Stimulus loading with file selection, keyboard entry, filter selection, and button/link clicks. Existing focused specs remain the source for forced partial-write rollback and history edge cases. No production deployment or production-scale performance claim is made. Full CI passed; independent reviews and merge are orchestrator work.
