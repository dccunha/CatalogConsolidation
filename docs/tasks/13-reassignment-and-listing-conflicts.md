# T13: Resolve reassignment and seller-listing conflicts

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Complete AC7/AC8 and the remaining AC11 journeys: explicitly reassign changed seller identities and choose the surviving item ID when one seller offers a product twice. This task finishes the required user actions. Exclude automatic relinking and production-scale concurrency infrastructure.

## Required context

- [T03 association writes](03-catalog-public-writes.md#handoff), [T08 retained decisions](08-reruns-and-source-identity.md#handoff), and [T06 identity/history persistence](06-intake-persistence.md#handoff).
- [T11 commands](11-review-approval-rejection-correction.md#handoff) and [T12 explicit creation](12-review-creation-and-freshness.md#handoff).
- [RFC seller identity](../rfcs/0001-import-review-lifecycle.md#seller-identity-and-row-outcomes) and [review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle).
- [PRD AC7/AC8/AC11](../prds/catalog-consolidation-importer.md#9-acceptance-criteria).

## Deliverables and acceptance checks

- [x] Let a changed-identity case explicitly approve a candidate or create a product after satisfying the rejection/creation rules. Preserve the old association until the final atomic decision.
- [x] Show both item IDs in a same-seller conflict and offer explicit keep-existing or replace-existing choices after rechecking current evidence and uniqueness.
- [x] Keeping the existing ID records the incoming ID as declined. Replacing it records the displaced ID and updates both affected identities' retained outcomes as needed.
- [x] Ensure unchanged reruns of declined/displaced IDs remain unlinked, and later materially changed source identities enter review rather than restoring historical associations.
- [x] Commit Catalog association changes and all affected Intake history/identity decisions together. Existing product fields remain unchanged and both database uniqueness rules hold throughout committed states.
- [x] Surface stale association changes as pending with refreshed evidence. Historical/superseded cases and repeated submissions cannot overwrite a newer decision.
- [x] Test both conflict choices, changed-identity approval/creation, returning old source identities, displaced-ID reruns, stale submissions, and rollback of all affected records.
- [x] Complete corresponding UI forms and validate actual decision-command/import sequences, replacing remaining fixture-only coverage from T08.

## Current checkpoint

- Completed: typed reassignment, creation, keep, and replace commands; Catalog retirement operation for a linked incoming ID; case forms and routes; import/decision sequence and rollback specs; generated route RBIs; visual inspection of two screenshots; passing Docker CI on the implementation working tree.
- Remaining: independent correctness and test review, exact-revision CI reassessment, PR and merge verification.
- Next action: parent creates a stable implementation commit and requests two independent reviews.

## Problems

- **T13-P01 — 2026-09-30:** The persistent local development database used for screenshots still had an older T06 seller-item check constraint that disallowed `pending` with a retained `product_id`. The checked-in migration/schema and test database already allow that state; full CI passed. For preview only, I changed that single development constraint in place to match `db/schema.rb`, preserving existing data, then created fresh isolated import cases. No repository migration was required.
- **T13-P02 — 2026-09-30:** The first full CI run found RuboCop method-size issues, two Sorbet nullable association refinements, stale generated route RBIs, and one T11 request expectation that still described conflict choices as unavailable. These were corrected. The final full gate below passed.
- A focused three-file RSpec run passed 63 examples but exited 2 because global SimpleCov included application files those focused examples never loaded. Full CI passed both coverage floors.

## Decisions

- **T13-D01 — 2026-09-30:** `Intake::Services::ReviewActions` adds `.reassign_candidate(review_case_id:, candidate_id:, evidence_revision:)`, `.create_for_reassignment(review_case_id:, evidence_revision:)`, `.keep_existing(review_case_id:, candidate_id:, evidence_revision:)`, and `.replace_existing(review_case_id:, candidate_id:, evidence_revision:)`, all returning the existing typed `Result`. They reuse the active-case, exact revision, live matcher refresh, and all-revision candidate rejection guards. An approval uses T03 `.reassign`; reassignment creation uses `.create_for_association`. Source identity never changes on a reviewer command.
- **T13-D02 — 2026-09-30:** The Intake transaction locks affected `SellerItem` rows in ascending ID order, then the case; conflict actions lock both current Catalog associations in ascending ID order and compare them with the evidence snapshot before a public write. `.reassign` keeps its T03 signature: Intake read-locks and verifies the association before calling it on the same connection and outer transaction. Catalog writes and all Intake decisions/resolutions commit or roll back together. A changed Catalog snapshot refreshes evidence and returns `:stale`; a late Catalog conflict triggers another locked refresh before reporting conflict.
- **T13-D03 — 2026-09-30:** Keeping the old ID leaves its association in place and resolves the incoming `SellerItem` as `declined` with no product and a `kept_existing` decision referencing it. When the incoming ID already has another association, the new additive `Catalog::Public::Writes.retire_listing(association_id:, expected_product_id:, expected_seller_product_id:)` checks and removes only that incoming association inside Catalog's savepoint; the product remains. Replacing uses T03 `.reassign` when the incoming ID is unassociated or `.replace_listing` when both IDs have associations, records the exact displaced ID in the decision reason and its `SellerItem` FK when one exists, marks that old item `displaced` without a product, and supersedes its active case. A preexisting Catalog association with no Intake source record has no invented `SellerItem` history or displaced FK; its ID is in the decision reason, and a later import of that old key enters review instead of relinking automatically.

## Validation evidence

- **Focused behavior, 2026-09-30, working tree atop integrated T12 main `1b61471`:** `docker compose run --rm web bundle exec rspec spec/concepts/intake/services/review_conflicts_spec.rb spec/concepts/intake/controllers/review_cases_controller_spec.rb spec/concepts/catalog/public/writes_spec.rb` ran 63 examples, 0 failures. The process exited 2 solely on whole-application SimpleCov floors for a three-file subset. [Conflict command specs](../../spec/concepts/intake/services/review_conflicts_spec.rb) drive actual import → decision → rerun sequences for changed identity approval and creation, both conflict choices with one or two linked IDs, changed/returning identities, stale and superseded forms, and transaction failure rollback. [Request specs](../../spec/concepts/intake/controllers/review_cases_controller_spec.rb) assert both IDs/forms, POST redirects, persisted outcomes, and repeated-submit blocking. [Catalog write specs](../../spec/concepts/catalog/public/writes_spec.rb) cover retirement success, expected-state mismatch, and outer rollback.
- **Final full gate, 2026-09-30, implementation working tree atop `1b61471`:** `docker compose run --rm web bin/ci` passed in 1m20.98s: 214 RSpec examples, 0 failures; Ruby 1283/1298 lines (98.84%) and 280/325 branches (86.15%); one Vitest test, 0 failures, with 100% statements/lines/functions; Ruby/ERB/JS lint; Sorbet (`No errors`), concept sigils, gem/Rails RBI freshness; gem/importmap/Brakeman audits; test DB preparation/consistency; seeds. The two generated route-helper RBIs changed; no new model RBI or migration was needed. `git diff --check` is required before the parent commits.
- **Browser visual inspection, 2026-09-30:** Headless Chromium at 1280px captured and I inspected [same-seller conflict choices](screenshots/t13-listing-conflict.png) and [changed-identity reassignment](screenshots/t13-reassignment.png). Both pages used isolated development cases created through real `ImportProcessor.call` sequences. The conflict screenshot shows old and incoming IDs with explicit keep/replace forms; the reassignment screenshot shows the retained product and candidate decision. Request specs cover actual POST/redirect behavior; T14 owns final browser click and keyboard journeys.

## Handoff

T14 can use the four typed T13 commands and corresponding `POST /review_cases/:id/reassign_candidate`, `/create_for_reassignment`, `/keep_existing`, and `/replace_existing` routes. Use `ReviewActions.reassignment_creation_state(review_case:)` for the changed-identity creation gate; ordinary `creation_state` remains restricted to unassociated seller items. Cases use exact `evidence_revision` and candidate IDs from the current page. Decisions update Catalog and Intake in one transaction. `kept_existing` means the incoming ID is declined/unlinked; replacement means the old ID is displaced/unlinked. The immutable original source tuple remains the import replay key. Regression entry points are the three spec files named above and the two screenshots. Final real-browser click/keyboard acceptance is T14; a Catalog association manually inserted without an Intake source record has no source tuple to replay as `already_imported`, so its old ID's first later import enters review without linking.
