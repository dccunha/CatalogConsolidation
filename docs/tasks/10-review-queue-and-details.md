# T10: Add review queue and case details

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Make pending/resolved cases, matching evidence, and history understandable in the browser. Introduce the configured local reviewer identity that later decisions will capture. Support AC3–AC5 and AC11 visibility; exclude decision-changing actions until their services exist.

## Required context

- [T09 web handoff](09-web-upload-and-results.md#handoff), [T06 persistence](06-intake-persistence.md#handoff), and [T05 evidence](05-matching-and-candidate-evidence.md#handoff).
- [PRD review workflow](../prds/catalog-consolidation-importer.md#6-review-workflow) and [filters/output](../prds/catalog-consolidation-importer.md#8-import-output).
- [RFC lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle) and [agreed delivery choices](README.md#agreed-delivery-choices).

## Deliverables and acceptance checks

- [ ] Add queue filters for pending/resolved state, batch, and seller, with clear empty states and links from batch row results.
- [ ] Filtering by a later rerun batch includes cases referenced by that batch's rows, even if the case originated in an earlier batch.
- [ ] Show source values, corrected values, comparison evidence, reasons, ranked candidates, scores/differences, and conflicting seller IDs. Preserve access to historical/superseded cases without presenting them as actionable.
- [ ] Distinguish immutable import-time outcomes from a case's current decision. Show reviewer/time/reason/result history where available.
- [ ] Configure a local reviewer name through documented application configuration, with a usable local default. Later commands must snapshot that name into decisions rather than reading it dynamically when displaying history.
- [ ] Add no authentication or browser-entered reviewer selection. Do not display operative action controls before T11–T13 supply them.
- [ ] Test filters, reused-case batch membership, original/corrected comparison, history, absent candidates, and safe source rendering. Check query behavior with the repository's existing tooling and capture screenshots.

## Current checkpoint

- Completed: task brief only.
- Remaining: queue/details pages, reviewer configuration, and verification.
- Next action: inspect batch/case relationships and the existing web navigation.

## Problems

None recorded.

## Decisions

The user selected one configured local reviewer without authentication. Record the configuration key/default and actual query/navigation contracts here.

## Validation evidence

Not run. Record filter/detail specs, browser checks, screenshots, and CI results.

## Handoff

Not implemented. Publish review routes, evidence/history rendering, filter semantics, and the server-side reviewer configuration interface for T11–T13. Identify the locations where supported action forms will be added.
