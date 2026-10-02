# T19: Select matching fields for seller imports

Status, sequencing gate, PR, and current blocker live in [the index](README.md). This follow-up starts after merged T18; creating this brief does not begin implementation.

## Outcome and boundaries

Let a seller-file uploader independently include or ignore Brand and Category during product matching, with the current both-enabled policy as the default. Apply one policy to the whole batch and retain it through review. Own the new AC14 behavior while preserving default-path AC2–AC12 behavior. Do not change source validation, seller-key identity, Catalog ownership, reference inputs, or existing Catalog product values.

## Required context

- [PRD import and matching policy](../prds/catalog-consolidation-importer.md#5-import-behavior), [AC14](../prds/catalog-consolidation-importer.md#9-acceptance-criteria), and [RFC matching and review lifecycle](../rfcs/0001-import-review-lifecycle.md#matching-and-candidate-evidence).
- [T05 matcher handoff](05-matching-and-candidate-evidence.md#handoff), [T08 rerun handoff](08-reruns-and-source-identity.md#handoff), [T09 upload handoff](09-web-upload-and-results.md#handoff), [T12 review creation handoff](12-review-creation-and-freshness.md#handoff), and [T13 conflict handoff](13-reassignment-and-listing-conflicts.md#handoff).
- Current entry points: [upload form](../../app/concepts/intake/views/imports/new.html.erb), [upload controller](../../app/concepts/intake/controllers/imports_controller.rb), [import processor](../../app/concepts/intake/services/import_processor.rb), [matcher](../../app/concepts/intake/services/product_matcher.rb), [review actions](../../app/concepts/intake/services/review_actions.rb), and [batch model](../../app/concepts/intake/models/batch.rb).
- [Implementation quality gates](quality-gates.md) and [task workflow](README.md#working-a-task).

## Deliverables and acceptance checks

- [ ] Add independent **Use Brand for matching** and **Use Category for matching** upload controls, both enabled by default. Apply their submitted values to the whole batch, persist them for audit and later review, and show the retained policy on batch results and review details. Existing batches and service callers without an explicit choice must retain both-enabled behavior.
- [ ] Always match on normalized Name. Include only selected metadata in exact identity, completeness checks, and candidate ranking. A unique exact match may link despite differences in ignored fields only when it is the sole credible candidate and seller association rules permit it. Multiple exact or other credible candidates and seller conflicts remain review cases.
- [ ] Include equal normalized names as candidates regardless of metadata. For near names, retain the inclusive 0.80 similarity threshold and matching nonblank Brand gate when Brand is selected; when Brand is ignored, include near names regardless of Brand or Category, including when Category remains selected. Ignored fields must not influence candidate ordering, but source and catalog values remain visible as evidence and the UI identifies which fields were ignored.
- [ ] Permit automatic linking or creation when an ignored field is missing, provided selected fields and other safety rules allow it. Still validate supplied ignored fields for type and prohibited text. Preserve supplied values in Intake and on newly created Catalog products; never overwrite attributes of an existing product.
- [ ] Keep exact `(SellerName, Id)` lookup and full normalized source tuple for rerun identity. An unchanged source reuses its prior pending or final result even when switches change. A materially changed source enters review using its new batch's policy. Corrections, candidate refreshes, approvals, rejections, and explicit creation use the originating case's persisted batch policy; earlier batches behave as both enabled.
- [ ] Add focused matcher, importer, review, request, and browser coverage for all four switch combinations, default compatibility, missing and conflicting metadata, near-name candidates, seller conflicts, changed-source and unchanged-source reruns with different choices, older batches, and stale candidate refresh. Include a screenshot of the visible upload/results/review change.
- [ ] Run the [quality gates](quality-gates.md): focused behavior checks, Sorbet on new concept Ruby code, coverage floors, and `docker compose run --rm web bin/ci` before review. Record actual outcomes, screenshots, typing/RBI effects, and limitations in this brief; a planned check is not passing evidence.

## Current checkpoint

- Completed: T18 merge `f1340d5` was verified as an ancestor of this checkout. The user approved the matching choices recorded below, and the PRD/RFC have been updated as requirements. No application implementation has begun.
- Remaining: implement AC14, run focused and full gates, capture UI evidence, and prepare one reviewed PR.
- Next action: start a fresh implementation chat for T19, verify the T18 merge gate again, and follow the required context above. Keep this task `ready` until implementation actually begins.

## Problems

None recorded.

## Decisions

- **T19-D01 — 2026-10-02:** The upload has independent Brand and Category matching choices, both enabled by default. Name always participates. The choices apply to the batch and are retained for review; earlier batches use both-enabled behavior. This preserves existing acceptance scenarios unless the uploader opts out.
- **T19-D02 — 2026-10-02:** Ignored fields do not gate exact matching, candidate ordering, or completeness. A unique safe match can link when ignored values differ; missing ignored values may still allow automatic outcomes. Supplied values remain validated and preserved, including on new products. Existing products are not overwritten.
- **T19-D03 — 2026-10-02:** With Brand ignored, near-name products meeting the inclusive 0.80 threshold remain candidates regardless of Brand or Category. This applies even if Category is selected, so plausible duplicates are reviewed before creation. With Brand selected, the existing matching nonblank Brand gate remains.
- **T19-D04 — 2026-10-02:** Matching choices do not alter source identity. An unchanged seller row retains its prior outcome when uploaded with different choices; a changed source enters review under the new batch policy. A pending case keeps its originating batch policy through corrections and decisions.

These user-approved behavior changes are recorded in the [PRD](../prds/catalog-consolidation-importer.md#5-import-behavior) and [RFC](../rfcs/0001-import-review-lifecycle.md#matching-and-candidate-evidence); implementation details such as schema shape and service signatures remain owned by this task.

## Validation evidence

Not run. No implementation, focused tests, full Docker CI, Sorbet check, screenshot, or PR exists for T19 yet. Record actual evidence here as the task progresses.

## Handoff

Not implemented. Before review, replace this with the implemented interfaces, persistence and transaction behavior, error handling, actual checks, remaining limitations, and PR reference. Record merge evidence only after verifying a merge.
