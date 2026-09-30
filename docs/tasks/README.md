# Implementation tasks

This is the authoritative status index for the catalog consolidation implementation. The [PRD](../prds/catalog-consolidation-importer.md) defines the product, [RFC 0001](../rfcs/0001-import-review-lifecycle.md) defines its lifecycle, and [ADR 0001](../adrs/0001-organize-by-concepts.md) defines code ownership. Task briefs turn those requirements into bounded changes; they do not replace them.

The Rails/PostgreSQL application, Catalog and Intake domain code, browser review workflow, and integrated acceptance journeys are implemented through T14. T00A established Better Specs conventions and T00Q established typing and coverage gates. T15 delivered the verified runbook and demo. T16 addresses the SQL control syntax found during final QA. The task status and linked evidence below distinguish merged work from work still under review.

## Task index

Implement in index order, initially T00–T15 plus the T00A and T00Q quality preflights and follow-up T00R, then T16, one task and one PR at a time. The “After merge” column is a sequencing gate, not a requirement to read every preceding task. Relevant technical context is linked in each brief. Status lives only in this table; briefs hold checkpoints and evidence. Insert any later follow-up tasks where their dependencies require, preserving existing task IDs.

| ID | Task | Status | After merge | PR | Current blocker |
| --- | --- | --- | --- | --- | --- |
| T00 | [Establish task records and workflow](00-task-workflow.md) | done | Foundation | [#6](https://github.com/dccunha/CatalogConsolidation/pull/6) | None |
| T00A | [Enforce Better Specs conventions](00a-better-specs-conventions.md) | done | T00 | [#9](https://github.com/dccunha/CatalogConsolidation/pull/9) | None |
| T00Q | [Enforce implementation quality gates](00q-quality-gates.md) | done | T00A | [#8](https://github.com/dccunha/CatalogConsolidation/pull/8) · merge `8b9f07a` | None |
| T00R | [Remove hosted CI requirement](00r-remove-hosted-ci.md) | done | T00Q | [#10](https://github.com/dccunha/CatalogConsolidation/pull/10) · merge `87089b9` | None |
| T01 | [Integrate concepts and Catalog persistence](01-concepts-and-catalog-persistence.md) | done | T00R | [#11](https://github.com/dccunha/CatalogConsolidation/pull/11) · merge `ff3b548` | None |
| T02 | [Load the reference catalog](02-reference-catalog-loading.md) | done | T01 | [#12](https://github.com/dccunha/CatalogConsolidation/pull/12) · merge `e9acc56` | None |
| T03 | [Implement Catalog public writes](03-catalog-public-writes.md) | done | T02 | [#13](https://github.com/dccunha/CatalogConsolidation/pull/13) · merge `8d1fe10` | None |
| T04 | [Validate and normalize seller rows](04-row-validation-and-normalization.md) | done | T03 | [#14](https://github.com/dccunha/CatalogConsolidation/pull/14) · merge `ad00870` | None |
| T05 | [Implement matching and evidence](05-matching-and-candidate-evidence.md) | done | T04 | [#15](https://github.com/dccunha/CatalogConsolidation/pull/15) · merge `443f5e2` | None |
| T06 | [Persist Intake history and state](06-intake-persistence.md) | done | T05 | [#16](https://github.com/dccunha/CatalogConsolidation/pull/16) · merge `07df420` | None |
| T07 | [Process imports with failure isolation](07-import-processing.md) | done | T06 | [#17](https://github.com/dccunha/CatalogConsolidation/pull/17) · merge `189bd88` | None |
| T08 | [Preserve decisions across reruns](08-reruns-and-source-identity.md) | done | T07 | [#18](https://github.com/dccunha/CatalogConsolidation/pull/18) · merge `dd55280` | None |
| T09 | [Add web upload and batch results](09-web-upload-and-results.md) | done | T08 | [#19](https://github.com/dccunha/CatalogConsolidation/pull/19) · merge `3f464aa` | None |
| T10 | [Add review queue and case details](10-review-queue-and-details.md) | done | T09 | [#20](https://github.com/dccunha/CatalogConsolidation/pull/20) · merge `3123ff6` | None |
| T11 | [Approve, reject, and correct](11-review-approval-rejection-correction.md) | done | T10 | [#21](https://github.com/dccunha/CatalogConsolidation/pull/21) · merge `2313ee1` | None |
| T12 | [Create explicitly and recheck evidence](12-review-creation-and-freshness.md) | done | T11 | [#22](https://github.com/dccunha/CatalogConsolidation/pull/22) · merge `3f09a1f` | None |
| T13 | [Resolve reassignment and listing conflicts](13-reassignment-and-listing-conflicts.md) | done | T12 | [#23](https://github.com/dccunha/CatalogConsolidation/pull/23) · merge `d3c9246` | None |
| T14 | [Verify acceptance journeys](14-acceptance-journeys.md) | done | T13 | [#24](https://github.com/dccunha/CatalogConsolidation/pull/24) · merge `685d26e` | None |
| T15 | [Prepare delivery and demo](15-delivery-and-demo.md) | done | T14 | [#25](https://github.com/dccunha/CatalogConsolidation/pull/25) · merge `ac839ef` | None |
| T16 | [Block SQL control syntax from Catalog writes](16-block-sql-control-syntax.md) | in review | T15 | [#27](https://github.com/dccunha/CatalogConsolidation/pull/27) | Final PR merge gate |

Milestones: T08 verifies importer/rerun services; T10 makes upload, results, and review evidence available in the browser; T13 completes the required user actions; T14 verifies integrated acceptance journeys; T15 completes delivery verification.

## Orchestrator run checkpoint

The user can invoke the [orchestrator instructions and starter prompt](orchestrator.md#starter-prompt) to run the remaining tasks with fresh implementers, two independent reviewers per task, automatic merges after passing gates, and a pause for final QA. Merely reading or editing those instructions does not start the run. Individual task requests can still use the manual workflow below.

- Run state: `running`.
- Current task/stage: T16 corrected runtime candidate passed full isolated Docker CI and both independent re-reviews; [PR #27](https://github.com/dccunha/CatalogConsolidation/pull/27) is open for final merge gate.
- Working directory, branch, candidate revision, and PR: `/home/daniel/.codex/worktrees/t16-catalog-text-guard/VTEX`, `codex/t16-catalog-text-guard` from verified main `a081718`; reviewed runtime candidate `e03b14d`; [PR #27](https://github.com/dccunha/CatalogConsolidation/pull/27).
- Active agent assignments and test-runner owner: implementer and both reviewers finished; no shared Docker runner active. Isolated `t16_guard` web and PostgreSQL services run on localhost:3116. Existing main-branch QA database and T15 demo remain untouched.
- Unresolved orchestration findings or decisions: T16-TEST-01/02/03 resolved and independently approved; no user decision is pending. User chose an input-only Catalog guard and retention of historical QA data.
- Last completed orchestration milestone: T15 merged as [PR #25](https://github.com/dccunha/CatalogConsolidation/pull/25) at `ac839ef`; final QA identified the new T16 behavior change.
- Next action: review the documentation-only PR record delta, verify PR head/remote checks/mergeability, then merge #27 if all gates pass and record the verified merge.

During a run, update this checkpoint at stage transitions and before interruption. Keep task statuses in the table above and detailed findings/evidence in the owning briefs. See [records and recovery](orchestrator.md#records-and-recovery) for resume rules.

## Working a task

1. Read the root `AGENTS.md`, this index, the selected brief, and its required-context links. Read dependency handoffs before following their implementation links. Expand into other files only as needed.
2. Verify the predecessor's PR merged and its handoff matches the integrated code. Record the actual PR/merge evidence; then mark the selected task `ready` and, when work begins, `in progress`. Use a `codex/` branch based on the integrated work and a fresh chat for a manual task, or a fresh implementer sub-agent in an explicitly invoked orchestration run.
3. Keep the task's current checkpoint accurate. Update it when pausing, encountering a blocker, or preparing a PR. If a task outgrows its bounded outcome, add a linked follow-up brief using [the template](task-template.md) and update sequencing before expanding the work.
4. Apply [the implementation quality gates](quality-gates.md). Run focused tests while implementing and `docker compose run --rm web bin/ci` before submitting a PR. Record commands, coverage/typing evidence, and actual outcomes, including failures or checks not run. Include screenshots for visible UI changes.
5. Prepare the handoff and mark `in review` when the change is ready for review. Manual tasks await human review. Orchestrated tasks require independent correctness and test reviews, with fixes and re-review before automatic merging. Add the PR link when it exists. This state can include local work awaiting PR creation; it never means merged.
6. After verifying the PR merged, record `done` and the merge reference in a small follow-up tracking commit. Unblock the next task. Review or merge failure leaves the task unfinished. During an orchestration run, continue automatically and update the run checkpoint; preserve the merge requirements in [the orchestrator workflow](orchestrator.md#validate-and-merge).

Normal transitions are `backlog` → `ready` → `in progress` → `in review` → `done`. Use `blocked` when unresolved input or a dependency prevents further task progress; link the problem entry and state the next required action. Expected future sequencing leaves a task in `backlog`, not `blocked`. Return review changes to `in progress`. Only one implementation task is active at a time.

For a manual single-task chat, use:

> Implement task TNN from its brief in docs/tasks/. Read AGENTS.md and the task index first, verify its merge gate, then read only the linked requirements and dependency handoffs needed for this task. Keep its checkpoint, problems, decisions, and validation evidence current. Finish with a reviewable change and handoff; do not begin the next task. Use interactive question dialogs for questions and wait for my explicit answer.

## Context, problems, and decisions

Keep each brief focused on its current outcome. Link test files, commits, PRs, and long diagnostic output instead of copying conversation transcripts or full logs. A new agent should find the next action and existing contracts without reading an earlier chat. Keep short dated history entries below the current checkpoint; do not overwrite the rationale for past decisions.

Use task-local problem IDs such as `T08-P01`: date, symptom, evidence, impact, attempted fixes, resolution or required input, and next action/owner. The index links only current blockers. Cross-task problems have one owning entry, with links from affected briefs.

Use decision IDs such as `T06-D01`: date, choice, rationale, and affected contracts/tasks. Agents may choose routine local details, including initial schema and service design owned by a task. Interview the user before changing agreed behavior, scope, architecture, or established contracts affecting other tasks. Use interactive dialogs and wait for an explicit answer; silence, expiration, and preselected options are not answers. Keep unanswered decisions unresolved.

For orchestrated tasks, append review rounds under validation evidence using [the template](task-template.md#review-rounds). Record both roles' revisions/verdicts, actionable finding IDs, fixes or deferral rationale, and actual checks. This preserves independent review evidence without carrying entire review conversations into later tasks.

Promote lasting architectural decisions to an ADR. Update the PRD/RFC when an explicitly approved decision changes product or lifecycle behavior. Link the durable document from the task decision entry rather than duplicating its contents. The implementation task owns schema and service-signature details and records the resulting interface, transaction boundary, and errors in its handoff.

## Agreed delivery choices

- Full PRD/RFC scope, organized for manageable tasks without an imposed submission deadline.
- Repository Markdown is the source of truth; tasks remain sequential with one reviewed PR per task; `done` means merged.
- When explicitly invoked, orchestration uses a fresh implementer and two independent reviewers per task, automatic merges after reviews/checks, and milestone reports without routine human pauses. The overall run pauses for final QA or unresolved decisions/blockers. These user-approved choices replace per-task human review pauses for that run; manual single-task chats remain available.
- Web upload and a clear, modestly styled Rails interface; no separate seller-import CLI deliverable. A command for reference-catalog loading remains necessary.
- Synchronous imports initially, reflecting the local demonstration and small input. Background jobs need evidence and a scope decision.
- One configured local reviewer name, without authentication. Persist the name used when each decision is made.
- Expose only implemented UI actions. Add browser-test runtime support when web journeys need it; run application tools inside Docker.

## Acceptance coverage

The owner is responsible for the criterion's core behavior. Supporting tasks add dependencies, UI, and lifecycle coverage. T14 verifies every criterion together. Replace pending evidence with concrete spec paths/examples as they are implemented; do not invent passing results or aggregate match counts.

| PRD criterion | Core owner | Supporting tasks | Implemented test evidence |
| --- | --- | --- | --- |
| AC1: every input row recorded | T07 | T06, T09, T14 | T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) loads the reference into a clean test catalog, verifies 269 ordered persisted rows and reconciled totals on two runs; [browser spec](../../spec/system/acceptance_journeys_spec.rb) verifies a mixed upload and displayed totals. |
| AC2: Galaxy S23 links to product 2 | T07 | T02, T03, T05, T14 | T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) checks source position 1 links product 2 after canonical reference load; [importer spec](../../spec/concepts/intake/services/import_processor_spec.rb) checks the association and unchanged reference product. |
| AC3: iPad punctuation difference requires review | T05 | T04, T07, T10, T14 | T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) checks supplied position 54 remains pending and reuses its case; [matcher spec](../../spec/concepts/intake/services/product_matcher_spec.rb) checks the reference near-match evidence; [case request spec](../../spec/concepts/intake/controllers/review_cases_controller_spec.rb) checks candidate display. |
| AC4: category conflict requires review | T05 | T07, T10, T14 | T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) checks supplied position 88 remains pending and its candidate evidence flags category; [matcher spec](../../spec/concepts/intake/services/product_matcher_spec.rb) verifies the Canon `Photo`/`Photography` conflict; [browser spec](../../spec/system/acceptance_journeys_spec.rb) shows category values on a review page. |
| AC5: missing brand requires review | T07 | T04, T05, T10, T11, T14 | T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) keeps null-brand input pending; [browser spec](../../spec/system/acceptance_journeys_spec.rb) rejects, corrects the missing brand, and creates only after a separate click; [importer spec](../../spec/concepts/intake/services/import_processor_spec.rb) covers missing brand with and without candidates. |
| AC6: equivalent duplicates and reruns | T08 | T04, T14 | T08 [importer spec](../../spec/concepts/intake/services/import_processor_spec.rb) checks exact keys, `Câmera`/`Camera`, whitespace, and pending reuse; T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) checks all 269 rows rerun without extra products, associations, seller items, or cases; [browser spec](../../spec/system/acceptance_journeys_spec.rb) uploads the same file twice. |
| AC7: materially changed identity | T08 | T06, T13, T14 | T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) checks unchanged association during changed-source review, explicit candidate reassignment, decision replay, historical-source return to pending, and superseded case refusal; [T13 spec](../../spec/concepts/intake/services/review_conflicts_spec.rb) checks both reassignment paths and rollback. |
| AC8: one seller, conflicting item IDs | T13 | T01, T03, T05, T07, T14 | T14 [browser spec](../../spec/system/acceptance_journeys_spec.rb) clicks both keep and replace choices, reruns both IDs, and asserts one surviving association; [T13 spec](../../spec/concepts/intake/services/review_conflicts_spec.rb) checks decision details and rollback. |
| AC9: atomic create and control-syntax rejection | T07, T16 | T03, T05, T14 | T16 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) checks row 181 Failed with its full source only in Intake and reconciled 269-row totals; [importer spec](../../spec/concepts/intake/services/import_processor_spec.rb) checks continuation, rerun, and no partial writes; [Catalog public-write spec](../../spec/concepts/catalog/public/writes_spec.rb) checks atomic rejection of new unsafe strings. The [T16 brief](16-block-sql-control-syntax.md#validation-evidence) records clean-file and CI evidence. |
| AC10: invalid/incomplete rows do not stop later rows | T07 | T04, T06, T09, T14 | T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) puts invalid and incomplete rows between valid outcomes and checks later creation; [browser spec](../../spec/system/acceptance_journeys_spec.rb) verifies four displayed outcomes and exact summary. |
| AC11: review decisions survive reruns | T13 | T08, T11, T12, T14 | T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) runs real correction, approval, reassignment, rejection, and stale-candidate commands, then checks replay and immutable prior results; [browser spec](../../spec/system/acceptance_journeys_spec.rb) clicks approval, rejection, correction, creation, keep, and replace, followed by reruns. [T12 spec](../../spec/concepts/intake/services/review_creation_spec.rb) checks new candidates after rejection and final-decision rollback. |
| AC12: material variants never auto-link | T05 | T04, T07, T14 | T14 [integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) imports `128GB` and `256GB` under one seller and checks distinct product IDs; [matcher spec](../../spec/concepts/intake/services/product_matcher_spec.rb) checks capacity/color candidates do not auto-link. |

RFC sequences: [T14 integrated spec](../../spec/concepts/intake/acceptance_journeys_spec.rb) checks pending-case reuse, original-source rerun after correction, supersession, explicit reassignment, and a newly appearing candidate after rejection; [T14 browser spec](../../spec/system/acceptance_journeys_spec.rb) checks resolved replay and declined/displaced ID outcomes after both listing choices. Existing [importer](../../spec/concepts/intake/services/import_processor_spec.rb), [review creation](../../spec/concepts/intake/services/review_creation_spec.rb), and [conflict](../../spec/concepts/intake/services/review_conflicts_spec.rb) specs cover rollback and historical identity edges. T15 links final evidence and documents limitations.
