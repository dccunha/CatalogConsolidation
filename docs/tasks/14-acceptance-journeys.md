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

- [ ] Map each AC to concrete passing assertions and mark remaining gaps in the index. Reuse focused coverage; add cross-component tests where they can reveal integration failures.
- [ ] From a clean test database, load reference products and import all 269 rows. Verify outcome count and summary reconciliation without hard-coding unapproved totals for each matching category.
- [ ] Reimport and verify no duplicate associations or equivalent pending cases. Resolve cases using real commands/UI, then rerun the original input to verify retained decisions.
- [ ] Exercise automatic link/create, near-match review, missing/conflicting metadata, invalid rows between valid rows, material variants, changed identities, and both listing-conflict choices.
- [ ] Include correction followed by original-source rerun; all candidates rejected followed by a newly appearing candidate; and superseded/displaced/declined identities remaining non-actionable as defined by the RFC.
- [ ] Verify per-row failures and failed final decisions roll back partial writes, while historical row results remain stable after review.
- [ ] Exercise browser upload/results and representative complete review journeys. Add any missing browser runtime inside Docker and check actual Turbo/Stimulus interactions if used.
- [ ] Run the full required CI and confirm reference inputs remain unchanged. Capture representative UI evidence and record limitations or outstanding failures explicitly.

## Current checkpoint

- Completed: task brief only.
- Remaining: acceptance audit, missing journey tests/fixes, and final integration evidence.
- Next action: inspect the matrix's implemented evidence and integrated T13 handoff for coverage gaps.

## Problems

None recorded. Record discovered defects with reproducible evidence; add bounded follow-up tasks if repairs exceed this task instead of silently broadening it.

## Decisions

None recorded. Any proposed policy change found during acceptance testing requires the user's answer and a PRD/RFC update; matching observations alone do not authorize it.

## Validation evidence

Not run. Record clean-database commands, reference checks, scenario results, actual aggregate observations, browser evidence, and CI. Link final passing specs/examples from the index.

## Handoff

Not implemented. Publish the completed AC/RFC evidence map, reproducible test setup, observed limitations, and unresolved issues for T15. Do not describe a journey as passing when only its individual service tests ran.
