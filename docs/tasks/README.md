# Implementation tasks

This is the authoritative status index for the catalog consolidation implementation. The [PRD](../prds/catalog-consolidation-importer.md) defines the product, [RFC 0001](../rfcs/0001-import-review-lifecycle.md) defines its lifecycle, and [ADR 0001](../adrs/0001-organize-by-concepts.md) defines code ownership. Task briefs turn those requirements into bounded changes; they do not replace them.

The Rails, PostgreSQL, and Docker foundation is present. T00Q establishes enforceable quality gates before domain implementation. Domain implementation has not started. A planned task or unchecked acceptance criterion is not evidence of working software.

## Task index

Implement in index order, initially T00–T15 plus the T00Q quality preflight, one task and one PR at a time. The “After merge” column is a sequencing gate, not a requirement to read every preceding task. Relevant technical context is linked in each brief. Status lives only in this table; briefs hold checkpoints and evidence. Insert any later follow-up tasks where their dependencies require, preserving existing task IDs.

| ID | Task | Status | After merge | PR | Current blocker |
| --- | --- | --- | --- | --- | --- |
| T00 | [Establish task records and workflow](00-task-workflow.md) | done | Foundation | [#6](https://github.com/dccunha/CatalogConsolidation/pull/6) | None |
| T00Q | [Enforce implementation quality gates](00q-quality-gates.md) | in review | T00 | Not opened | [T00Q-P01](00q-quality-gates.md#problems): publication approval |
| T01 | [Integrate concepts and Catalog persistence](01-concepts-and-catalog-persistence.md) | backlog | T00Q | Not opened | — |
| T02 | [Load the reference catalog](02-reference-catalog-loading.md) | backlog | T01 | Not opened | — |
| T03 | [Implement Catalog public writes](03-catalog-public-writes.md) | backlog | T02 | Not opened | — |
| T04 | [Validate and normalize seller rows](04-row-validation-and-normalization.md) | backlog | T03 | Not opened | — |
| T05 | [Implement matching and evidence](05-matching-and-candidate-evidence.md) | backlog | T04 | Not opened | — |
| T06 | [Persist Intake history and state](06-intake-persistence.md) | backlog | T05 | Not opened | — |
| T07 | [Process imports with failure isolation](07-import-processing.md) | backlog | T06 | Not opened | — |
| T08 | [Preserve decisions across reruns](08-reruns-and-source-identity.md) | backlog | T07 | Not opened | — |
| T09 | [Add web upload and batch results](09-web-upload-and-results.md) | backlog | T08 | Not opened | — |
| T10 | [Add review queue and case details](10-review-queue-and-details.md) | backlog | T09 | Not opened | — |
| T11 | [Approve, reject, and correct](11-review-approval-rejection-correction.md) | backlog | T10 | Not opened | — |
| T12 | [Create explicitly and recheck evidence](12-review-creation-and-freshness.md) | backlog | T11 | Not opened | — |
| T13 | [Resolve reassignment and listing conflicts](13-reassignment-and-listing-conflicts.md) | backlog | T12 | Not opened | — |
| T14 | [Verify acceptance journeys](14-acceptance-journeys.md) | backlog | T13 | Not opened | — |
| T15 | [Prepare delivery and demo](15-delivery-and-demo.md) | backlog | T14 | Not opened | — |

Milestones: T08 verifies importer/rerun services; T10 makes upload, results, and review evidence available in the browser; T13 completes the required user actions; T14 verifies integrated acceptance journeys; T15 completes delivery verification.

## Orchestrator run checkpoint

The user can invoke the [orchestrator instructions and starter prompt](orchestrator.md#starter-prompt) to run the remaining tasks with fresh implementers, two independent reviewers per task, automatic merges after passing gates, and a pause for final QA. Merely reading or editing those instructions does not start the run. Individual task requests can still use the manual workflow below.

- Run state: `not_started`.
- Current task/stage: none / idle; T00Q is being prepared outside the orchestrator and T01 follows its merge.
- Working directory, branch, candidate revision, and PR: assigned and verified at launch.
- Active agent assignments and test-runner owner: none.
- Unresolved orchestration findings or decisions: none.
- Last completed orchestration milestone: none.
- Next action: finish and merge T00Q, then invoke the starter prompt when ready to execute T01 onward.

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
| AC1: every input row recorded | T07 | T06, T09, T14 | Pending implementation |
| AC2: Galaxy S23 links to product 2 | T07 | T02, T03, T05, T14 | Pending implementation |
| AC3: iPad punctuation difference requires review | T05 | T04, T07, T10, T14 | Pending implementation |
| AC4: category conflict requires review | T05 | T07, T10, T14 | Pending implementation |
| AC5: missing brand requires review | T07 | T04, T05, T10, T11, T14 | Pending implementation |
| AC6: equivalent duplicates and reruns | T08 | T04, T14 | Pending implementation |
| AC7: materially changed identity | T08 | T06, T13, T14 | Pending implementation |
| AC8: one seller, conflicting item IDs | T13 | T01, T03, T05, T07, T14 | Pending implementation |
| AC9: atomic create and SQL-like text | T07 | T03, T05, T14 | Pending implementation |
| AC10: invalid/incomplete rows do not stop later rows | T07 | T04, T06, T09, T14 | Pending implementation |
| AC11: review decisions survive reruns | T13 | T08, T11, T12, T14 | Pending implementation |
| AC12: material variants never auto-link | T05 | T04, T07, T14 | Pending implementation |

T14 also checks the RFC sequences: pending-case reuse, corrected-input reruns, supersession, newly appearing candidates after rejection, and displaced/declined IDs. T15 links final evidence and documents limitations; it does not replace missing tests with a demo.
