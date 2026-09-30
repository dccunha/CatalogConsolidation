# T11: Approve, reject, and correct review cases

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Enable ordinary candidate approval, individual rejection, and correction of comparison metadata through the review screen. Implement the first real reviewer-command journeys for AC11. Explicit creation belongs to T12; reassignment and choosing between same-seller IDs belong to T13. Cases requiring those operations remain pending with a clear explanation.

## Required context

- [T10 UI/reviewer contract](10-review-queue-and-details.md#handoff), [T08 replay contract](08-reruns-and-source-identity.md#handoff), and [T03 write operations](03-catalog-public-writes.md#handoff).
- [T06 persistence handoff](06-intake-persistence.md#handoff).
- [RFC review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle), especially explicit actions, freshness, and atomic decisions.
- [PRD review actions](../prds/catalog-consolidation-importer.md#6-review-workflow).

## Deliverables and acceptance checks

- [x] Approve a candidate for an eligible active pending case after checking current Catalog evidence and constraints. Use `Catalog::Public`; commit association and decision together without changing product attributes.
- [x] Reject candidates individually with reviewer, timestamp, and reason, exposing the next candidate while preserving prior rejections. Rejecting the last candidate never creates a product.
- [x] Correct comparison fields separately from original source values and rerun matching. Keep the case pending even with one exact match or no candidates; preserve the active original source tuple for reruns.
- [x] Capture the configured reviewer at action time. Corrections do not edit the stable seller-name/item-ID key.
- [x] Recheck actionability and current evidence on submission. Resolved/superseded cases, repeated submissions, stale evidence, and uniqueness conflicts cannot silently apply another decision.
- [x] Add supported forms and clear outcomes to the case page. Until T12/T13 land, do not offer unsupported creation or conflict-resolution actions.
- [x] Test actual approval/rejection/correction followed by unchanged source reruns, corrected exact/no-candidate cases staying pending, stale actions, and forced decision-write rollback of Catalog changes.

## Current checkpoint

- Completed: typed reviewer commands, action routes and forms, stale evidence refresh, append-only rejection/correction history, atomic approval, behavior and request specs, generated route RBIs, and an inspected action-page screenshot.
- Remaining: independent reviews, PR, and merge verification.
- Next action: orchestrator commits this stable candidate and requests both independent reviews.

## Problems

- **T11-P01 — 2026-09-30, resolved:** The first full CI run passed 179 RSpec examples and coverage but reported RuboCop ABC size in `ReviewActions.approve` and Sorbet's nullable `seller_item` association type. Extracting the final approval write and fetching `SellerItem` by its nonnullable foreign key fixed both. Targeted RuboCop and Sorbet checks passed; the second full CI passed.
- **T11-P02 — 2026-09-30, resolved:** Isolated focused specs passed their examples but exited 2 because SimpleCov counts the whole application. The full suite exceeded both Ruby coverage floors; no floor or exclusion changed.

## Decisions

- **T11-D01 — 2026-09-30:** `Intake::Services::ReviewActions.approve`, `.reject`, and `.correct` return a typed result with `status`, `message`, and `success?`. Statuses are `approved`, `rejected`, `corrected`, `stale`, `invalid`, `conflict`, or `not_actionable`. They lock the seller item and case in one transaction, then verify the case is the active pending version and compare the submitted evidence revision. Approval and rejection recompute current Catalog matching, including candidate values, ranking, differences, score, and same-seller conflicts; changed evidence appends a revision and leaves the case pending with a visible reason. Candidate products rejected on any prior revision cannot be approved or rejected again. Only an unassociated seller item and a candidate without same-seller conflict can use ordinary approval. Catalog uniqueness remains enforced by `Catalog::Public::Writes.link` and its database constraints.
- **T11-D02 — 2026-09-30:** Approval calls `Catalog::Public::Writes.link`, inserts one `ReviewDecision`, updates seller-item resolution/product, and resolves the case in one transaction. A decision insert failure rolls back the Catalog association. Rejection appends one `ReviewRejection` with the configured reviewer, timestamp, and reason; it never creates a product or resolves the case. Correction overlays only `Name`, `Brand`, and `Category` on the latest comparison input, validates it with `RowValidator`, stores the full corrected input and normalized comparison in `ReviewCorrection`, then appends new candidate evidence. It never changes `SellerName`, `Id`, the immutable original source snapshots, or the seller item's active source tuple. It never auto-resolves, even after exact or empty rematching.
- **T11-D03 — 2026-09-30:** The case page offers approval only for an ordinary, unrejected candidate, rejection with a required reason for each unrejected candidate, and a correction form while pending. It omits action forms on resolved or superseded cases, displays previously rejected candidates after rematching, and explains that explicit creation and same-seller conflict resolution arrive in later review steps. POST actions redirect back to the case with a success or error message. Hidden evidence-revision fields prevent stale forms from silently applying. `config.x.intake.reviewer_name` is read at action time through `Intake::Reviewer.name`; saved history displays the stored reviewer.

## Validation evidence

- **Focused behavior, 2026-09-30:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/services/review_actions_spec.rb spec/concepts/intake/controllers/review_cases_controller_spec.rb` ran 21 examples, 0 failures. The isolated process exited 2 on whole-application SimpleCov (80.66% lines, 61.64% branches); complete CI passed the floors below. Service specs use real import, reviewer commands, and rerun sequences for approval, rejection, exact/no-candidate correction, stale Catalog changes, same-seller conflict, repeated/superseded actions, and forced decision-insert failure with Catalog rollback. Request specs check action forms, POST redirect/results, rejected and corrected display, stale feedback, and unsupported conflict approval omission. Two further service examples were added after this focused run and are included in the final full CI rerun below.
- **First full gate, 2026-09-30:** `docker compose run --rm web bin/ci` ran 179 RSpec examples, 0 failures, with Ruby 1015/1019 lines (99.60%) and 197/219 branches (89.95%); Vitest and all audits/database checks passed. Overall gate failed only RuboCop ABC size and Sorbet nullable-seller typing in the new service (T11-P01).
- **Second full gate, 2026-09-30:** `docker compose run --rm web bin/ci` passed Ruby/ERB/JS lint, Sorbet and concept sigils, gem/Rails RBI freshness, gem/importmap/Brakeman audits, database preparation/consistency, seeds, 180 RSpec examples (0 failures), and 1 Vitest test (0 failures). Ruby coverage was 1020/1024 lines (99.60%) and 197/219 branches (89.95%); JavaScript coverage was 100% statements/lines/functions (no application branches). A final test-only change then added explicit unchanged rerun after rejection and stale-rejection evidence, verified by the gate below.
- **Final implementation gate, 2026-09-30, T11 working tree based on `fc08892`:** `docker compose run --rm web bin/ci` passed all stages: Ruby/ERB/JS lint, Sorbet and concept sigils, gem/Rails RBI freshness, gem/importmap/Brakeman audits, database preparation/consistency, seeds, 181 RSpec examples (0 failures), and 1 Vitest test (0 failures). Ruby coverage was 1020/1024 lines (99.60%) and 198/219 branches (90.41%); JavaScript coverage was 100% statements/lines/functions (no application branches). `git diff --check` passed. No migration or gem RBI change was needed; `bin/tapioca dsl` updated the two generated route-helper RBIs, which passed freshness verification.
- **Browser visual inspection, 2026-09-30:** Headless Chromium captured and I inspected [T11 review action controls](screenshots/t11-review-actions.png) at a 1280 px desktop width. The local development case was made through `ImportProcessor.call` with one candidate. The screenshot shows approval, rejection with reason, correction fields, candidate evidence, and preserved original row. Request specs cover the server journeys; T14 owns final interactive browser QA.

## Handoff

T12/T13 should add creation and conflict-resolution commands to `Intake::Services::ReviewActions` or a sibling service, preserving its typed `Result` contract and the seller-item/case lock plus evidence-revision pattern. The public T11 signatures are `.approve(review_case_id:, candidate_id:, evidence_revision:)`, `.reject(review_case_id:, candidate_id:, evidence_revision:, reason:)`, and `.correct(review_case_id:, evidence_revision:, name:, brand:, category:)`. Case action routes are `POST /review_cases/:id/approve`, `/reject`, and `/correct`; `show` renders only currently supported controls. Existing candidate rejection history is read across **all** evidence revisions by product ID, so rematching never re-enables a rejected product. A correction increments `evidence_revision` and appends candidate snapshots; it does not alter the original seller source tuple used by import reruns. Approval is intentionally limited to an unassociated seller item and a candidate with no same-seller conflict. Existing association reassignment, keeping/declining another ID, replacing a listing, and explicit creation remain for T12/T13. Final browser click/keyboard journeys remain for T14.
