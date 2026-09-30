# T17: Export the current catalog as SQLite

Status, sequencing gate, PR, and current blocker live in [the index](README.md). This task follows T16; reconcile its links and contracts against T16's merged handoff before implementation.

## Outcome and boundaries

Let a local user download the current, committed Catalog as a SQLite database. PostgreSQL remains the application's operational database, and the supplied `docs/refs/catalog.db` remains an unchanged reference input. The download contains the original `Product` and `SellerProduct` tables, not Intake batches or review history. This adds a deliverable for the [assignment's SQLite output request](../prds/catalog-consolidation-importer.md#11-assignment-context); the implementation task must record the approved behavior in the PRD and add an export acceptance criterion. Exclude changes to matching, import decisions, review resolution, and the existing reference file.

The user chose a full-catalog snapshot, not a batch-specific export. Any active pending review case blocks download until resolved. Historical failed row outcomes do not block download; the interface explains that failed rows are absent unless a later successful import added them.

## Required context

- [T15 delivery handoff](15-delivery-and-demo.md#handoff) and the T16 handoff at `docs/tasks/16-block-sql-control-syntax.md` after T16 merges. Verify T16's actual merge and contract before work begins.
- [PRD assignment context](../prds/catalog-consolidation-importer.md#11-assignment-context), [Catalog and Intake ownership](../adrs/0001-organize-by-concepts.md#dependencies-and-public-surface), and [implementation quality gates](quality-gates.md).
- [Reference-loader handoff](02-reference-catalog-loading.md#handoff), the unchanged [SQLite source](../refs/catalog.db), Catalog product and seller-association models, Intake review-case model, current routes, and application navigation.

## Deliverables and acceptance checks

- [ ] Add a discoverable export page showing current Product and SellerProduct counts, pending review count, and a link to the review queue when pending cases exist. Show a notice if historical failed row outcomes exist; those outcomes may have been corrected by a later import. Enable the download only when no active `pending` review case exists. Resolved and superseded cases do not block it.
- [ ] Add a separate download request that rechecks pending cases server-side and refuses the request with a clear conflict response if any are pending. A direct URL must not bypass the gate. A successful response is an attachment named `catalog-updated.db` containing a SQLite database, with no persistent exported copy on the server.
- [ ] Export every current PostgreSQL `products` and `seller_products` row from one consistent read snapshot. Preserve IDs, exact text, and nullable Product values. Use the source's `Product` and `SellerProduct` table and column names; declare `SellerProductId` as `TEXT` so opaque seller IDs round-trip. Preserve the Catalog's seller-key and seller/product uniqueness rules and product foreign key in the exported schema. Include no Intake tables. Do not filter or rewrite existing Catalog text, including values that T16 would reject for a new write.
- [ ] Keep Catalog-owned snapshot construction independent of Intake. Let the Intake-owned web action check review state and request a read-only Catalog export through an explicit interface; keep the pending check and Catalog reads in the same PostgreSQL snapshot. Generate SQLite in temporary storage with bound values, verify integrity and foreign keys before returning bytes, and clean up on success or failure. A generation failure returns no partial download and leaves operational data unchanged.
- [ ] Add focused service and request tests that open the downloaded bytes with SQLite and compare all rows and associations, including the 975 reference IDs, string seller IDs, a newly created product, nullable values, and stored punctuation. Cover pending blocking on both page and direct URL, release after resolution, nonblocking historical failures, repeated downloads, generated-file integrity, failure cleanup, and an unchanged reference-file hash. Add a browser journey and screenshot for the visible export action.
- [ ] Update the PRD's delivery/output contract and add an export acceptance criterion; update the README with download steps and the pending/failure rules. Add the new criterion's evidence to the task index. Run focused Docker checks and full `docker compose run --rm web bin/ci`; record actual results, coverage, Sorbet/RBI changes, screenshots, and remaining limits in this brief.

## Current checkpoint

- Completed: the T17 brief and index entry were prepared after a successful `git fetch origin main`; remote main was `a081718` on 2026-09-30. User decisions on scope, contents, pending reviews, and failed rows are recorded below. No export implementation or test has run.
- Remaining: T16 merge verification, implementation, focused checks, independent reviews, full Docker CI, one T17 PR, merge, and final QA handoff.
- Next action: after T16 merges, reconcile this brief and the index with its final handoff, then let the orchestrator start T17 from updated main.

## Problems

None recorded. T16 is active in a separate worktree, so its unmerged files and index were not edited by this task-planning change.

## Decisions

- **T17-D01 — 2026-09-30:** Export the full current Catalog at download time, not a selected batch's historical state. PostgreSQL remains operational; the downloaded SQLite file is the catalog deliverable. Preserve `docs/refs/catalog.db` unchanged.
- **T17-D02 — 2026-09-30:** Include only the original two catalog tables. Retain their external names and IDs, but use text storage for `SellerProductId` because supplied seller IDs are opaque strings.
- **T17-D03 — 2026-09-30:** Require resolution of every active pending review case before download. Permit historical failed rows, with a notice that the export contains committed Catalog data only. These are explicit user choices from the T17 planning dialog.
- **T17-D04 — 2026-09-30:** Keep the export read-only with respect to application and reference data. Catalog owns SQLite construction; Intake owns the pending-review gate and web action, preserving ADR 0001's dependency direction. Use a consistent PostgreSQL snapshot so the gate and exported rows describe the same state.

## Validation evidence

Not run. This is a task description only. Record each implementation command, revision, result, coverage summary, typing/RBI changes, screenshot, and remaining limitation here. Do not treat planned checks as passing checks.

### Review rounds

No implementation review has occurred. Record two independent reviewer verdicts and the final reviewed PR head when T17 is executed through the orchestrator.

## Handoff

Not implemented. Before review, replace this with the actual routes, Catalog export interface, schema and transaction behavior, errors, tests, limits, and integration notes. Add PR/commit references and verified merge evidence only after they exist.
