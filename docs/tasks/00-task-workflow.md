# T00: Establish task records and workflow

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Make the agreed implementation sequence usable by fresh agent chats, with durable progress, problem, decision, and handoff records. This task creates planning artifacts and repository instructions; application implementation belongs to T01–T15. The existing Rails/Docker/tooling foundation remains the baseline.

## Required context

- [PRD](../prds/catalog-consolidation-importer.md), [RFC 0001](../rfcs/0001-import-review-lifecycle.md), and [ADR 0001](../adrs/0001-organize-by-concepts.md).
- [Repository instructions](../../AGENTS.md) and [setup instructions](../../README.md).
- User choices are recorded below and in the index's agreed delivery choices.

## Deliverables and acceptance checks

- [x] Index lists T00–T15, sequencing gates, truthful statuses, PR fields, and current blockers.
- [x] Every task has bounded outcomes, required context, acceptance checks, checkpoint, problems, decisions, validation evidence, and handoff sections.
- [x] AC1–AC12 have explicit ownership, supporting tasks, and initially pending test evidence.
- [x] Workflow specifies fresh chats, one active implementation task, context selection, question dialogs, review/merge gates, and durable decisions.
- [x] Root README and AGENTS link to the workflow; a reusable template supports bounded follow-up work.
- [x] Local links, task references, required sections, and whitespace checks pass. No application or reference-input changes are included.

## Current checkpoint

- Completed: index, 16 task briefs, reusable template, root navigation/instructions, documentation/CI validation, PR #6 review, and merge.
- Remaining: no T00 work; no application implementation has begun.
- Next action: begin T01 in a fresh chat from the integrated main branch.

## Problems

None recorded. The assignment's separate Guideline Document is unavailable, as already noted in the PRD/ADR; the agreed repository conventions govern this task.

## Decisions

- **T00-D01 — 2026-09-29:** The user selected repository Markdown, sequential fresh chats, and full PRD scope without a newly imposed deadline. Use one index and bounded briefs so future agents can recover state without prior chats.
- **T00-D02 — 2026-09-29:** The user selected 12–16 focused tasks and routine autonomy. The resulting sequence has one planning task and 15 implementation tasks. Ask before behavior, scope, or downstream-contract changes; routine local details are recorded by the implementing agent.
- **T00-D03 — 2026-09-29:** The user selected web upload, a simple Rails UI, and a configured local reviewer. Synchronous imports are the accepted starting default. These choices guide T09–T13 without adding authentication or a seller-import CLI.
- **T00-D04 — 2026-09-29:** The user selected PR merge as the completion gate. Local changes or review readiness never count as `done`; record merge evidence afterward.

## Validation evidence

- **2026-09-29 — Passed:** Python structural/link checks covering the 20 changed/new Markdown files, 16 task briefs, required sections, local targets/anchors, ordered task IDs, and all 12 acceptance mappings. Future application evidence remains explicitly pending.
- **2026-09-29 — Passed:** `git diff --check`, plus a whitespace/conflict-marker check including the new task files. Only root instructions/README and task documentation changed; reference inputs and application files remain untouched.
- **2026-09-29 — Passed:** `docker compose run --rm web bin/ci` completed successfully: setup, Ruby/ERB/JavaScript linting, security audits, database preparation/consistency, seed checks, one RSpec example, and one Vitest test. These are foundation checks, not evidence that future product acceptance criteria are implemented.
- **2026-09-30 UTC — Merged:** [PR #6](https://github.com/dccunha/CatalogConsolidation/pull/6), merge commit `07ab9b358b68f76ab67989e07e3693ea472a2cc2`.

## Handoff

The task index is the sole status record. Individual briefs carry the current checkpoint, problems, decisions, validation, and handoff; the template supports future bounded follow-ups. Root AGENTS and README link to this workflow. No application interfaces have been introduced.

T00 is complete after the verified merge of PR #6. T01 is ready and is the next application task: establish concept integration and Catalog persistence before later tasks consume those contracts. No implementation task has started. AC1–AC12 test evidence remains pending. Start T01 in a fresh chat using the starter prompt in the index.
