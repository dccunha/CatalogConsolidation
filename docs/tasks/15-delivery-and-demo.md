# T15: Prepare delivery and demo

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Make the completed local application easy to run, evaluate, and explain using verified setup instructions and a reproducible demonstration. Close delivery documentation after T14 validates behavior. Exclude publishing/deploying the application, emailing the assessment, changing reference inputs, or claiming completion with unresolved acceptance failures.

## Required context

- [T14 acceptance handoff](14-acceptance-journeys.md#handoff) and [index evidence](README.md#acceptance-coverage).
- [PRD delivery expectations](../prds/catalog-consolidation-importer.md#10-delivery-expectations-and-known-trade-offs) and [assignment context](../prds/catalog-consolidation-importer.md#11-assignment-context).
- [RFC threshold rationale](../rfcs/0001-import-review-lifecycle.md#matching-and-candidate-evidence).
- Existing [README](../../README.md); follow T02/T09/T10 handoff links only for commands/configuration not already documented there.

## Deliverables and acceptance checks

- [x] Update the README from foundation-only status to the verified application: Docker setup, migration/reference loading, browser upload, reviewer configuration, review workflow, and test commands.
- [x] Rehearse instructions in an isolated clean local/test environment without deleting the user's existing database or altering the reference files.
- [x] Document a short repeatable demo showing import summary, a known automatic link, a new product, and an explicitly resolved review case, followed by an unchanged rerun preserving that decision.
- [x] Include useful screenshots of the finished UI and explain how to reach each demonstrated state. Use separate demo fixtures when needed; keep supplied references unchanged.
- [x] Explain the conservative matching policy, the 0.80 review threshold, observed misses/limitations, material-variant handling, and PostgreSQL's deliberate replacement of the assignment's SQLite output target.
- [x] Link PRD/RFC/ADR and acceptance evidence; report any outstanding problems honestly. Update milestone/status records based on verified merges only.
- [x] Run final required checks, verify documentation commands and links, and prepare the final review handoff. T15 becomes `done` only after its own PR merge is verified and recorded.

## Current checkpoint

- Completed: the [README runbook and demo](../../README.md), separate [three-row fixture](../demo/delivery-sample.json), clean isolated Compose rehearsal, browser upload/approval/rerun, three inspected screenshots, final Docker CI, 34 local Markdown link/anchor checks, valid demo JSON, and unchanged reference hashes. No application behavior changed.
- Remaining: independent review, PR, and merge verification. The task index owns status and the parent's orchestration checkpoint.
- Next action: parent commits the stable working tree for exact-revision review and records the resulting PR/merge evidence. Do not mark T15 `done` before verified merge.

## Problems

No application or delivery blocker found. The separate assignment Guideline Document remains unavailable unless supplied later; the README does not claim compliance with unknown contents. No exhaustive semantic-duplicate audit was performed, so the candidate miss rate cannot be quantified. The current full catalog scan per seller row, synchronous import, and unauthenticated local review UI are documented limits rather than production claims.

## Decisions

- **T15-D01 — 2026-09-30:** Use a separate Compose project `t15_delivery`, host port 3105, reviewer name `T15 Demo Reviewer`, and its own `t15_delivery_postgres_data` volume for the clean rehearsal. This preserves the existing default `vtex` volume and reference inputs. The parent retains Git/PR/status ownership. No behavior, schema, or architecture contract changed.
- **T15-D02 — 2026-09-30:** Add [delivery-sample.json](../demo/delivery-sample.json) with three distinct `DeliveryDemo` seller IDs: exact Galaxy S23 for known product #2, a new AsterGlow lamp, and the iPad punctuation near match for product #14. Keeping it separate from `docs/refs/` gives a short repeatable demo. The README describes UI action order and notes that batch/case IDs and newly allocated product IDs depend on database state.
- **T15-D03 — 2026-09-30:** Document the RFC's 0.80 candidate-review threshold and its router rationale, observed pending/near-match evidence, and the unquantified paraphrase miss risk. The 20 pending rows in T14's reference aggregate are not labeled as 20 duplicates. State explicitly that PostgreSQL is the application output target while the supplied SQLite file is loaded read-only. No separately imposed submission deadline or external submission is authorized.

## Validation evidence

- **2026-09-30 — Clean isolated setup:** `WEB_PORT=3105 INTAKE_REVIEWER_NAME='T15 Demo Reviewer' docker compose -p t15_delivery up -d --build` created `t15_delivery_postgres_data` and started healthy PostgreSQL and web services on port 3105; the existing `vtex` project was not stopped. `docker compose -p t15_delivery run --rm web bin/rails catalog:load_reference` inserted 975 products. `docker compose -p t15_delivery run --rm web bin/rails db:migrate` exited 0 on the prepared database; a loader rerun exited 0 with `0 products inserted, 975 already present`.
- **2026-09-30 — Real browser demo:** In the isolated app, selecting and uploading [the fixture](../demo/delivery-sample.json) produced three ordered results: linked `demo-galaxy` to reference product #2, created `demo-lamp` as product #976, and left `demo-ipad` pending with a 90.9% candidate for reference product #14. Clicking **Approve product #14** resolved case #1 and saved reviewer `T15 Demo Reviewer`. Uploading the unchanged file again produced `already_imported=3`, zero linked/created/pending/failed, and a row reason retaining the linked review decision. After the rerun, a read-only Rails runner showed 976 products, 3 seller associations, 2 batches, 1 review case, and 1 decision; no duplicate catalog or case state was created. The original batch's pending row remained immutable.
- **2026-09-30 — Screenshots and references:** Headless Docker Chromium captured and I visually inspected the [first results](screenshots/t15-demo-results.png), [resolved review decision](screenshots/t15-demo-resolved.png), and [unchanged rerun](screenshots/t15-demo-rerun.png) at 1280 px width. They show legible summary counts, product/case IDs, saved reviewer, and retained decision. `sha256sum docs/refs/ProductEntry.json docs/refs/catalog.db` matched T14's hashes `1b0c861fe568c19e8b1cebcf774ee3d1d95baf8c42e35129e4ae806ece04b8f6` and `733ff1d9cc20253da48a9f8b33d7241503e4a06e7c68f65f7fa00ef14466c404`; neither reference file was edited.
- **2026-09-30 — Final full gate on integrated main `6b348d1` plus T15 documentation/demo working tree:** `docker compose -p t15_delivery run --rm web bin/ci` exited 0 in 2m17.74s using the isolated project's test database. Ruby/ERB/JavaScript lint, Sorbet (`No errors`), concept sigils, gem/Rails RBI freshness, gem/importmap/Brakeman audits, test database preparation/consistency, and seed replant all passed. RSpec: 222 examples, zero failures; Ruby lines 1283/1298 (98.84%) and branches 280/325 (86.15%). Vitest: one test, zero failures, 100% applicable statements/lines/functions (no measured branches). No application, migration, or Sorbet RBI file changed; T14's focused acceptance and browser tests were included in the full RSpec run.
- **2026-09-30 — Documentation and integrity:** A Ruby check inside `docker compose -p t15_delivery exec -T web ruby -` resolved all 34 local Markdown paths and anchors in the README and this brief and parsed the separate demo JSON as exactly three rows; it exited 0. `git diff --check` exited 0, reference hashes still matched T14, and `git diff -- docs/refs/ProductEntry.json docs/refs/catalog.db` was empty. Post-CI `git status --short` showed only the two intended Markdown edits, the new demo fixture directory, and three T15 screenshot files. Setup/loader commands and browser actions were exercised as recorded above; there are no new behavior specs because behavior did not change.

## Handoff

The [README](../../README.md) is the delivery entry point. Its ordinary setup uses `docker compose up --build -d`, `docker compose run --rm web bin/rails db:migrate`, and `docker compose run --rm web bin/rails catalog:load_reference`; the isolated demo uses `docker compose -p t15_delivery` and the same migration/loader commands after setting the port and reviewer name. Upload the [three-row fixture](../demo/delivery-sample.json), approve the iPad candidate, and upload it unchanged again as described in the README. The three screenshots above are the visual evidence; T14's [acceptance matrix](README.md#acceptance-coverage) and [handoff](14-acceptance-journeys.md#handoff) cover the broader 269-row and AC1–AC12 journeys. Limits are in the README and Problems above. The parent will supply reviewed commit/PR references and record T15 `done` only after verifying its merge. No further implementation task is implied by this handoff.
