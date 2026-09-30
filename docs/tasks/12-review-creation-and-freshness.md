# T12: Create explicitly and recheck evidence

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Let a reviewer explicitly create a new product for an eligible complete case, with current candidate evidence and atomic persistence. Cover the creation and stale-candidate parts of AC11. Exclude changing an existing association and selecting between conflicting seller IDs; T13 completes those paths.

## Required context

- [T11 review commands](11-review-approval-rejection-correction.md#handoff), [T05 candidate evidence](05-matching-and-candidate-evidence.md#handoff), and [T03 writes](03-catalog-public-writes.md#handoff).
- [T08 source identity contract](08-reruns-and-source-identity.md#handoff).
- [RFC review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle) and [new-candidate example](../rfcs/0001-import-review-lifecycle.md#examples-to-verify-during-implementation).

## Deliverables and acceptance checks

- [x] Add a separate explicit create command/form for complete reviewed input with no remaining unrejected credible candidates. Rejecting or correcting alone never creates a product.
- [x] Incomplete input cannot create. A corrected complete case with no candidate can become eligible but still requires the separate action.
- [x] Requery current Catalog candidates before committing creation. Preserve earlier rejections; newly credible candidates keep the case pending and must be shown before creation can proceed.
- [x] Leave stale/conflicting cases pending with refreshed evidence and a visible reason. Reuse the current-evidence/actionability checks established in T11.
- [x] Commit product, association, and final decision atomically. Preserve original input, corrections, and decision history; unchanged reruns report the retained decision.
- [x] Test last rejection without creation, explicit creation, missing metadata, a new candidate appearing between rejection and creation, repeated submissions, and forced rollback.
- [x] Verify the browser distinguishes pending, ready for explicit creation, and resolved outcomes. These may be derived UI states; do not add a persistent state solely for display.

## Current checkpoint

- Completed: typed explicit creation command, derived readiness state and form, candidate refresh before write, atomic Catalog and Intake persistence, service/request regression specs, generated route RBIs, and inspected screenshot. Both independent reviewers approved candidate `7a52f08`; exact-commit Docker CI passed.
- Remaining: verified merge of [PR #22](https://github.com/dccunha/CatalogConsolidation/pull/22).
- Next action: verify PR head and merge gates, then merge.

## Problems

- **T12-P01 — 2026-09-30, resolved:** The first focused run exposed two page expectation mismatches. The ready summary now says the case is still pending, and the refreshed-candidate request assertion checks all ranked cards. Rerun: 23 examples, 0 failures. The focused command exits 2 on whole-app SimpleCov because unrelated files are unloaded; full CI exceeds both floors.
- **T12-P02 — 2026-09-30, resolved:** First full CI ran 195 RSpec examples with no failures and coverage above floor, but found RuboCop complexity in the new service, Sorbet's nullable association typing, and stale generated route RBIs. Small signed helpers, a nonnullable seller-item lookup by foreign key, and `bin/tapioca dsl` resolved these. Targeted RuboCop/Sorbet and the second full CI passed.

## Decisions

- **T12-D01 — 2026-09-30:** `Intake::Services::ReviewActions.creation_state(review_case:)` derives `:ready`, `:candidates`, `:incomplete`, `:association_conflict`, or `:not_actionable` from the active pending case, complete current comparison, current evidence revision, rejections across all revisions by product ID, and the current seller-item association. A rejected candidate's association conflict with another seller ID does not block creating a distinct product. This is a display/actionability calculation, not a persisted status. The case remains `pending` until creation commits.
- **T12-D02 — 2026-09-30:** `Intake::Services::ReviewActions.create(review_case_id:, evidence_revision:)` uses T11's seller-item/case lock and current evidence revision check, reruns `ProductMatcher` against current Catalog, and appends a fresh evidence revision when candidate values, ranking, or association conflict change. A new unrejected credible candidate keeps the case pending and removes creation readiness; earlier rejections remain effective. With complete input and no unrejected candidates, it calls `Catalog::Public::Writes.create_with_association`, appends a `ReviewDecision(result: "created")`, updates the seller item, and resolves the case inside one outer transaction. The result contract adds `:created` as a success; repeated and stale submissions return `:not_actionable` or `:stale`. Existing seller-item associations requiring reassignment remain blocked for T13.
- **T12-D03 — 2026-09-30:** `POST /review_cases/:id/create_product` has a separate evidence-revision form. The pending page distinguishes incomplete, remaining-candidate, association-conflict, and ready states; resolved pages show the final decision and no create control. No source tuple, correction, or rejection history is rewritten.

## Validation evidence

- **Focused specs, 2026-09-30, T12 working tree atop `1353a7c`:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/services/review_creation_spec.rb spec/concepts/intake/controllers/review_cases_controller_spec.rb` ran 24 examples, 0 failures after the last regression addition. The process exited 2 solely because focused whole-app SimpleCov measured 876/1090 lines (80.36%) and 136/245 branches (55.51%); the full suite passed coverage. Service specs prove last rejection does not create, explicit creation and retained rerun, incomplete metadata corrected to readiness, newly credible candidate refresh with preserved rejection, same-key association refresh, repeated/stale submissions, rejected same-seller candidate conflict, existing-key reassignment boundary, and forced final-decision failure rolling back both Catalog records. Request specs prove pending/ready/resolved controls, corrected readiness, new-candidate visibility, and create-form removal after refresh.
- **First full gate, 2026-09-30:** `docker compose run --rm web bin/ci` ran 195 RSpec examples, 0 failures; Ruby 1072/1078 lines (99.44%) and 221/245 branches (90.20%); Vitest, ERB/JS lint, security/database/seed checks passed. Overall gate failed on the three style, typing, and RBI issues in T12-P02. `docker compose run --rm web bin/tapioca dsl` generated both route-helper RBIs. Targeted Docker `bin/rubocop app/concepts/intake/services/review_actions.rb` and `bundle exec srb tc` then passed.
- **Final implementation gate, 2026-09-30, candidate `7a52f08`:** `docker compose run --rm web bin/ci` passed every stage after the same-key association regression, rerun by the independent test reviewer on the exact clean commit: Ruby/ERB/JS lint; Sorbet, concept sigils, gem/Rails RBI freshness; gem/importmap/Brakeman audits; database preparation/consistency and seeds; 196 RSpec examples (0 failures); and 1 Vitest test (0 failures). Ruby coverage was 1084/1090 lines (99.44%) and 221/245 branches (90.20%); JavaScript statements/lines/functions were 100% (no application branches). `git diff --check` passed. No migration or gem RBI update was required.
- **Browser visual inspection, 2026-09-30:** Headless Chromium captured and I inspected [T12 ready for creation](screenshots/t12-ready-for-creation.png) at 1280 px. A local development import created one candidate, then a separate rejection made the still-pending case ready. The screenshot shows original seller values, retained rejected candidate evidence, ready state, and a distinct create form. Request specs cover the POST/redirect journeys; T14 owns final interactive browser QA.

### Review rounds

- **Round 1, candidate `7a52f08` (2026-09-30):** Correctness reviewer approved with no blocking findings after tracing the explicit gate, current-evidence refresh, Catalog public write, transaction rollback, replay, and UI contracts. Test reviewer independently approved with no findings after inspecting service/request assertions and the screenshot and rerunning exact-commit Docker `bin/ci` successfully. The full matcher scan under READ COMMITTED cannot exclude an unrelated concurrent product creation after its query; this is the existing architecture's practical concurrency limit, not a new T12 rule. Final interactive browser journeys remain T14.

## Handoff

T13 may extend `ReviewActions` with reassignment/conflict commands. It should reuse the seller-item/case lock, exact evidence-revision guard, `ProductMatcher` refresh, all-revision rejection exclusion, and outer transaction pattern in `.create` and T11's `.approve`. The public creation interface and result states are in T12-D01/D02. T12 creation is restricted to seller items with no existing association for their exact key; a changed identity with an existing association must use T03's `Catalog::Public::Writes.create_for_association` through a separate explicit T13 decision. A second seller ID associated with a candidate product may be rejected without blocking creation of a distinct product. New candidate evidence appears after a stale create submission, with the form withheld until every new candidate is reviewed or rejected. T14 should exercise the pending, ready, stale, and resolved page states with a browser.
