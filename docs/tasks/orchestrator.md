# Implementation orchestrator

## Activation and scope

Use this workflow when the user explicitly invokes the starter prompt below or asks to run the orchestrator. Creating, editing, or reviewing these instructions does not launch implementation. An agent assigned an implementer or reviewer role performs only that assignment; it does not start another orchestration loop.

You are the parent orchestrator for the remaining tasks in [the task index](README.md). Complete the agreed PRD/RFC scope through sequential task PRs, then prepare the application for the user's final QA. Read the index at startup; do not assume a fixed next task or repeat completed work. The PRD, RFC, ADR, [implementation quality gates](quality-gates.md), and task briefs remain the requirements.

Invoking this workflow authorizes task branches, commits, pushes, PR creation, and automatic task merges after the gates below pass. It replaces per-task human review pauses with two independent agent reviews. It does not authorize changing product requirements, bypassing repository protections, deploying the app, submitting the assessment, or deleting the user's existing data.

Use sub-agent tools within the current orchestration chat. Use fresh agents for each task instead of creating user-owned sidebar chats. Preserve a compact parent context and durable repository records so an interrupted run can resume. This is an active-session workflow; saved checkpoints do not schedule background execution.

## Roles and ownership

| Role | Responsibility | Write authority |
| --- | --- | --- |
| Orchestrator | Select work, delegate, reconcile findings, maintain records, run final checks, manage branches/PRs/merges, and communicate with the user. | Workflow records and Git operations; delegate application changes. |
| Implementer | Implement the selected brief, add meaningful tests, fix findings, and prepare its handoff. | Application/test files and the selected brief within the assigned scope. |
| Correctness reviewer | Independently inspect requirements, code, architecture, data integrity, error paths, and regressions. | Read-only source review; report findings to the orchestrator. |
| Test reviewer | Independently assess acceptance coverage, assertions, fixtures, failure cases, and integration behavior; execute assigned checks. | Read-only source review; test execution may write ordinary test artifacts. |

Only the orchestrator manages task branches, commits, pushes, PRs, and merges. Workers must not change shared Git state or start unrelated work. The orchestrator owns index status and the run checkpoint; implementer edits to its brief finish before the orchestrator records reviews there.

Keep one application writer active at a time. Pause implementation while reviewers inspect a stable revision. Reviewers can read concurrently, but the orchestrator assigns only one test runner at a time when commands share a database, server, port, or generated artifacts. An idle implementer must not run checks while a reviewer owns the test environment.

Use the runtime's available agent capacity. With four slots, the parent, implementer, and two reviewers fit the task. Retire completed agents with supported lifecycle tools when necessary. Reviewers may continue within one task's fix loop; the next task gets fresh role contexts. Keep the configured model defaults unless the user specifies otherwise. If independent sub-agents are unavailable, record the limitation and pause instead of presenting self-review as independent approval.

## Prepare a task and its context

1. Inspect repository status, the task index/run checkpoint, and any recorded branch, PR, and active-agent state. Preserve existing work. Verify GitHub merge state rather than relying on an earlier conversation's claim.
2. Select the first unfinished task in index order whose merge gate is satisfied. Resume an existing branch/PR when appropriate; otherwise create a `codex/` branch from the latest integrated main branch. Reuse a suitable existing checkout. Never switch a checkout while another agent or process uses it.
3. Set the task to `in progress` and update the run checkpoint. Read its brief and relevant dependency handoffs. Follow additional code and requirement links only as needed.
4. Dispatch a fresh implementer with the absolute working directory, task ID/brief, relevant requirement links, dependency contracts, allowed scope, and [required quality gates](quality-gates.md). Include any explicit user decisions. Do not send the entire parent conversation.

An implementer assignment should say:

> Implement only task TNN in the supplied working directory. Read AGENTS.md, the task brief, the implementation quality gates, and the linked requirements/dependency handoffs. Implement its acceptance criteria and meaningful tests, use Sorbet sigils/signatures for new concept Ruby code, run focused Docker checks, and update its checkpoint, decisions, validation evidence, and handoff. Preserve reference inputs. Do not switch branches, commit, push, open/merge PRs, or begin another task. Report material unresolved decisions to the parent. Return changed entry points, actual interfaces, commands/results, coverage and typing evidence, remaining concerns, and the next concrete action. Stop writing when your handoff is ready.

New schema and service design explicitly owned by the task are routine implementation choices. Changing an agreed architecture, product rule, or established contract affecting other tasks requires a user decision. Agents must not reopen settled choices merely because another design is possible.

## Implement, review, and fix

1. Receive the implementer's handoff and confirm its changes are within scope. Record the candidate commit and base revision; mark the task `in review` when it is ready for review.
2. Dispatch two fresh reviewers against the same candidate revision and requirement set. Let each form a verdict before seeing the other's findings. Supply the task's requirements and diff, not a persuasive account of why the implementation is correct.
3. The correctness reviewer checks the full task diff, relevant existing code, Sorbet typing quality, and data/security contracts. The test reviewer inspects test quality, coverage scope and thresholds, and runs focused checks as the sole assigned test runner. Passing tests do not substitute for inspecting what they assert.
4. Record findings with stable IDs, severity, file/line or scenario evidence, affected requirement, and requested correction. Review verdicts are `approved`, `changes requested`, or `blocked`. Approval must state the reviewed revision, evidence, and practical limits; silence is not approval.
5. Send actionable findings to the implementer. Mark the task `in progress` during fixes. Reviewers must finish or pause before source changes resume. After fixes, both reviewers assess the new revision and confirm resolved findings and any newly affected behavior.
6. Repeat until both approve and no substantive finding remains. Resolve technical disagreement with evidence and reviewer reassessment. Do not waive a valid correctness, requirement, or test-coverage defect to finish the loop. Nonblocking suggestions can be deferred with a recorded rationale; repository rules still apply.

Reviewer assignments should state the role, task brief/requirements, absolute working directory, base and candidate revisions, allowed commands, and whether the test runner is assigned. Require a concise report containing:

- Verdict, reviewed revision, and review scope.
- Findings with IDs, severity, evidence, affected acceptance criterion, and expected correction.
- Commands actually run and outcomes, distinguishing inspected evidence from executed checks.
- Remaining uncertainty, untested behavior, and blocking questions.

The test reviewer looks for assertions that could pass with broken behavior, excessive mocking of the behavior under test, missing rollback/rerun/conflict coverage, and fixtures that hide integration failures. Fixes and new regression tests belong to the implementer. Do not weaken tests or silently reduce requirements to obtain a pass.

## Validate and merge

1. Run the task's [required quality gates](quality-gates.md), focused checks, and `docker compose run --rm web bin/ci` before submitting its PR. Reuse valid evidence for unchanged code; repeat or broaden checks when fixes, failures, integration changes, or unresolved concerns justify it. Record the revision, command, result, coverage summary, Sorbet/RBI changes, and evidence location. Capture screenshots for visible UI changes. A fixable failed check returns the task to `in progress`: send its evidence to the implementer, then repeat the affected checks and both reviews. Handle environment blockers under the escalation rules.
2. Open or update one task PR with the final behavior, requirement links, validation, and both review verdicts. Attach it to the orchestration chat when the app supports PR attachments. Keep unfinished work clearly identified.
3. Ensure every final change has been reviewed. Application, schema, test, dependency, or configuration changes after approval invalidate the previous verdicts and affected test evidence. Documentation-only bookkeeping can receive a delta review while retaining earlier runtime evidence with its original revision identified.
4. Before merging, compare the current PR head to the final reviewed revision and check remote reviews, required checks, and mergeability. If the head or base changes materially, resolve integration, rerun affected checks, and re-review. Do not merge an unseen revision.
5. Merge automatically only when both reviewers approve, required acceptance checks/CI pass, no substantive finding remains, and GitHub permits the merge. Do not bypass protection or dismiss a required external review. Agent verdicts are not GitHub approvals from another account.
6. Verify GitHub reports the PR merged and record the merge commit. A failed or uncertain merge leaves the task unfinished; query the existing PR before retrying. Never create a duplicate PR to recover an ambiguous response.
7. Mark the task `done`, finalize its review/handoff evidence, and make the next task `ready`. Preserve the repository's small post-merge tracking-commit convention, limited to truthful metadata. If branch rules require a PR for that update, use a reviewed tracking PR. Tracking-only updates do not create numbered implementation tasks or recursive completion records. If the merge succeeded but bookkeeping was interrupted, recover the records from the verified merge instead of repeating the task or merge.
8. Continue with the next eligible task without requesting permission again.

## Records and recovery

The index remains the only task-status table. Its [run checkpoint](README.md#orchestrator-run-checkpoint) records overall run state, current task/stage, working directory, branch/revision/PR, active assignments, test-runner ownership, unresolved finding links, and next action. Update it at meaningful stage changes and before pausing. Use `not_started`, `running`, `blocked`, `awaiting_final_qa`, or `complete` for the overall run; this does not replace task statuses.

Use the selected brief's existing checkpoint, problems, decisions, validation, and handoff sections. Under validation, append a compact review-round record with each role's candidate revision, verdict, finding IDs/resolutions, and actual checks. The [task template](task-template.md) includes the format. Link longer reports/logs instead of copying them into the parent context. Persist pending questions and failed attempts before an interruption; keep original decisions and resolved problem history auditable.

On resume, verify the working tree, remote PR state, running agents/processes, candidate revision, and saved evidence. Continue from the last verified stage. Reuse valid results; rerun checks whose environment/revision or completion is uncertain. Do not recreate merged work or treat an interrupted command as successful.

When a task exceeds its boundary, add a bounded follow-up brief and dependency links for work necessary to satisfy the agreed requirements. Additional product scope requires the user's decision. Never mark an unmet acceptance criterion complete merely by moving it to a follow-up.

## Escalation and communication

Keep concise progress updates during active work. Report verified task/milestone outcomes and the next step without dumping tool logs. Milestone reports normally do not require a response.

Pause the dependent work when:

- A material decision changes agreed behavior, scope, architecture, or an established contract affecting other tasks.
- A required credential, permission, external approval, or unavailable environment prevents progress and needs the user's involvement.
- The same blocking problem persists through three fix/review cycles without meaningful progress. Record attempted fixes and evidence across restarts; do not reset the counter by replacing agents.
- The application is ready for the user's final QA.

Ordinary defects and productive fix cycles remain the agents' responsibility. For a decision, present the concrete issue, evidence, meaningful options, recommendation, and impact through an interactive question dialog. Wait for the user's explicit answer. A timeout, silence, or a preselected option is not an answer. If the requested dialog is unavailable in the current mode, save the checkpoint and ask for a mode that supports it; do not infer the decision. Tool approval requirements still apply.

Only the orchestrator asks the user; workers report questions to the parent. Record the answer in the owning task, then update ADR/PRD/RFC and affected briefs when needed before resuming. A real required decision is not subject to a timeout default.

## Milestones and final QA

The test reviewer performs broader milestone checks alongside the task review. Report results and continue after these pass:

| Milestone | Automated assessment |
| --- | --- |
| T08 | Supplied-file outcomes and reruns, pending/resolved identity behavior, and failure isolation. Distinguish fixture-based decision replay from reviewer commands that do not exist yet. |
| T10 | Browser upload/results, queue filters, comparison evidence, and history. Do not claim future action forms are working. |
| T13 | Complete real approval, correction, rejection, creation, reassignment, and conflict journeys followed by reruns. |
| T14 | All AC1–AC12 and RFC sequences against the integrated app, including browser journeys and reference-input preservation. |

After T15, check the delivered runbook and demonstration against the verified integrated application. Hand the user the app URL, startup/reproduction commands, exact revision, a short manual QA checklist, representative screenshots, acceptance evidence, and known limitations. Ensure no required task, review, test, or merge remains unresolved before claiming readiness.

Set the run to `awaiting_final_qa` and pause. Merged tasks may be `done`; user QA is still pending. If the user reports defects, record bounded follow-ups and use the same loop to fix them. Record the run as `complete` only after the user accepts final QA. New product requests remain scope decisions.

## Starter prompt

Copy this into a chat for this repository when you want to start or resume execution:

> Act as the orchestrator for the remaining implementation tasks in `docs/tasks/README.md`, following `docs/tasks/orchestrator.md`.
>
> Use fresh implementation sub-agents and two independent review sub-agents per task. Run the implementation, review, fix, validation, and merge loop until all tasks are complete and the application is ready for my final QA.
>
> You are authorized to create branches, commit, push, open PRs, and automatically merge tasks after the required reviews and checks pass. Keep task progress, problems, decisions, review findings, and handoffs current in the repository.
>
> Report milestones and continue automatically. Pause only for a material decision, a blocker that requires my involvement, or final QA. Ask questions through interactive dialogs and wait for my explicit answer. Resume from verified repository state if interrupted.
