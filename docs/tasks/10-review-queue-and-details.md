# T10: Add review queue and case details

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Make pending/resolved cases, matching evidence, and history understandable in the browser. Introduce the configured local reviewer identity that later decisions will capture. Support AC3–AC5 and AC11 visibility; exclude decision-changing actions until their services exist.

## Required context

- [T09 web handoff](09-web-upload-and-results.md#handoff), [T06 persistence](06-intake-persistence.md#handoff), and [T05 evidence](05-matching-and-candidate-evidence.md#handoff).
- [PRD review workflow](../prds/catalog-consolidation-importer.md#6-review-workflow) and [filters/output](../prds/catalog-consolidation-importer.md#8-import-output).
- [RFC lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle) and [agreed delivery choices](README.md#agreed-delivery-choices).

## Deliverables and acceptance checks

- [x] Add queue filters for pending/resolved state, batch, and seller, with clear empty states and links from batch row results.
- [x] Filtering by a later rerun batch includes cases referenced by that batch's rows, even if the case originated in an earlier batch.
- [x] Show source values, corrected values, comparison evidence, reasons, ranked candidates, scores/differences, and conflicting seller IDs. Preserve access to historical/superseded cases without presenting them as actionable.
- [x] Distinguish immutable import-time outcomes from a case's current decision. Show reviewer/time/reason/result history where available.
- [x] Configure a local reviewer name through documented application configuration, with a usable local default. Later commands must snapshot that name into decisions rather than reading it dynamically when displaying history.
- [x] Add no authentication or browser-entered reviewer selection. Do not display operative action controls before T11–T13 supply them.
- [x] Test filters, reused-case batch membership, original/corrected comparison, history, absent candidates, and safe source rendering. Check query behavior with the repository's existing tooling and capture screenshots.

## Current checkpoint

- Completed: queue/details pages, batch and global navigation, local reviewer configuration, request/configuration specs, generated route RBIs, visual screenshots, and first-round fixes for chronological review history and status-aware empty evidence. Both independent reviewers approved corrected commit `9d88d25`; exact-commit Docker CI passes.
- Remaining: PR and verified merge. The task index owns status.
- Next action: open the T10 PR, verify merge gates, and merge.

## Problems

- **T10-P01 — 2026-09-30, resolved:** The first full gate found `ReviewCasesController#index` over RuboCop's ABC limit, stale route-helper RBIs, and the T09 batch-result spec still expecting a plain case ID. Small filter methods, `bin/tapioca dsl`, and a link-aware request assertion resolved these. A later gate exposed a remaining small ABC overage, resolved by extracting filter setup. Final full CI passed.
- **T10-P02 — 2026-09-30, resolved:** A focused spec process passed its examples but exited 2 because isolated-file SimpleCov counts the whole application. The complete suite passed both required coverage floors. No coverage threshold was changed.
- **T10-P03 — 2026-09-30, resolved in review-fix candidate:** First-round correctness and test reviews found that the history list grouped all corrections before rejections, obscuring the actual sequence (T10-COR-01 / T10-TEST-01). Correctness review also found that no-candidate copy asked for a decision even on superseded and resolved cases (T10-COR-02). The detail loader now sorts corrections, rejections, and the decision by stored timestamp, then event type and ID for stable ties. Empty evidence copy reflects pending, superseded, or resolved state. Interleaved-time and all three status examples cover the behavior. First fix CI ran 166 passing RSpec examples but failed RuboCop ABC size in `show`; extracting evidence/history loaders resolved it, and final CI passed.

## Decisions

- **T10-D01 — 2026-09-30:** `GET /review_cases` defaults to pending and accepts `status=pending|resolved|superseded|all`, `batch_id`, and exact `seller_name`. The batch predicate uses `intake_row_results.review_case_id`, so a later rerun batch finds an older case; an unknown batch yields an empty result without casting untrusted text to a PostgreSQL ID. The queue orders newest first and eager loads seller, opening batch, and decision. `GET /review_cases/:id` remains accessible for resolved and superseded cases. No action routes were added.
- **T10-D02 — 2026-09-30, review fix:** The case page shows original and corrected values separately, latest-revision candidate snapshots with score, normalized values, differing fields, and conflicting listing IDs, plus all recorded corrections/rejections and a final decision where present. History events sort by stored occurrence time; equal times sort corrections, rejections, then decisions, followed by record ID. An empty candidate revision describes the case's current status without asking historical or resolved cases for another decision. Import-time row outcomes are displayed in their own table with batch links. Case details eager load candidate rejections and row batches; repository Bullet checks run in request specs. JSON and seller-supplied text use normal Rails escaped ERB output.
- **T10-D03 — 2026-09-30:** `config.x.intake.reviewer_name` reads `INTAKE_REVIEWER_NAME` at boot, defaulting to `Local reviewer`; Docker Compose passes the environment value to web. `Intake::Reviewer.name` returns the configured trimmed name or the same default if blank. `README.md` and `.env.example` document the setting. T11–T13 should read this interface when saving each reviewer action, while history always renders the saved name.

## Validation evidence

- **Focused specs, 2026-09-30:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/controllers/review_cases_controller_spec.rb spec/concepts/intake/reviewer_unit_spec.rb` ran 8 examples, 0 failures. The standalone process exited 2 on whole-application coverage (67.56% lines/39.76% branches), as expected with only these specs loaded; full CI below passed. Request specs cover filter/status/batch/seller combinations, rerun membership, invalid batch IDs, source and candidate comparisons, conflict IDs, escaped text, corrections, rejections, final decision versus two immutable row outcomes, historical superseded access, and absent candidates. The updated T09 request spec checks the real case link.
- **First-candidate implementation gate, 2026-09-30:** `docker compose run --rm web bin/ci` passed on first candidate `5100bea`: Ruby/ERB/JS lint, Sorbet and concept sigils, gem/Rails RBI freshness, gem/importmap/Brakeman audits, database preparation/consistency, seeds, 164 RSpec examples (0 failures), and 1 Vitest test (0 failures). Ruby coverage: 848/851 lines (99.64%) and 157/171 branches (91.81%); JavaScript coverage: 100% statements/lines/functions (no application branches). `git diff --check` passed. `env INTAKE_REVIEWER_NAME='Demo Reviewer' docker compose run --rm web bin/rails runner 'puts Intake::Reviewer.name'` printed `Demo Reviewer`, confirming the Compose override reaches Rails.
- **Browser visual inspection, 2026-09-30:** Headless Chromium against the running local Rails server captured and inspected [batch result links](screenshots/t10-batch-links.png), [rerun-batch queue filter](screenshots/t10-review-queue.png), and [case comparison/evidence/history](screenshots/t10-case-detail.png) at 1280 px width. The local preview data used `ImportProcessor.call` for a candidate-review row and its rerun, plus direct development-only correction/rejection model inserts to show existing history records. Screenshots are visual evidence; the request specs verify server behavior. Browser click and keyboard journeys remain for T14.
- **Review-fix focused specs, 2026-09-30:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/controllers/review_cases_controller_spec.rb` ran 8 examples, 0 failures. Its exit 2 was solely the whole-application SimpleCov floor with one file loaded (67.01% lines/40.57% branches); final full CI below passed. New examples assert exact rendered correction/rejection/decision order across interleaved times and same-time ties, including reviewer, reason, result, and status-aware no-candidate text for pending, superseded, and resolved cases.
- **Review-fix full gate, 2026-09-30:** `docker compose run --rm web bin/ci` passed on corrected commit `9d88d25`, rerun by the independent test reviewer: all Ruby/ERB/JS lint, Sorbet and concept sigils, gem/Rails RBI freshness, security audits, database preparation/consistency, seeds, 166 RSpec examples (0 failures), and 1 Vitest test (0 failures). Ruby coverage was 859/862 lines (99.65%) and 160/175 branches (91.42%); JavaScript coverage remained 100% statements/lines/functions (no application branches). `git diff --check` passed. Existing screenshots show a candidate and a correction/rejection with the same timestamp, so the review fix does not change their visible state; request specs verify new chronology and empty-state wording.

### Review rounds

- **Round 1, candidate `5100bea` (2026-09-30):** Correctness review raised T10-COR-01 (history event misordering) and T10-COR-02 (no-candidate copy inaccurate for resolved/superseded cases). Test review raised overlapping T10-TEST-01 (missing interleaved chronology assertion). The review-fix working tree addresses all three with time-ordered events, deterministic ties, status-aware text, and exact request assertions. A first full run passed 166 examples but failed only RuboCop complexity; the refactored candidate passed the full gate above.
- **Round 2, corrected candidate `9d88d25` (2026-09-30):** Correctness reviewer approved with T10-COR-01/02 resolved at controller lines 30–35 and 62–67, view lines 51–60 and 85–101, and regression specs. Test reviewer independently approved with T10-TEST-01 resolved, reran exact-commit Docker `bin/ci` successfully, and inspected three stored screenshots. No new findings or blockers. T10 browser visibility milestone passed; actual browser click and keyboard journeys remain for T14.

## Handoff

T11–T13 can add supported action forms to `app/concepts/intake/views/review_cases/show.html.erb` after implementing server commands and routes. The existing `GET /review_cases` filters and `GET /review_cases/:id` detail route provide navigation; `ReviewCasesController#show` loads the current case, latest evidence revision, corrections, rejections, final decision, and all referenced import rows. History is ordered by saved occurrence times with deterministic ties. `Intake::Reviewer.name` is the server-side identity to snapshot into new action records at write time. Historical pages display each stored reviewer, never the current configured name. The case page deliberately has no action controls or browser reviewer selector yet. The T09 upload/results flow links to case pages, and batch-filter links find cases reused by later batches through row results. Final browser action journeys remain for T11–T14.
