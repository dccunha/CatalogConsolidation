# TNN: Task title

Status, sequencing gate, PR, and current blocker live in [the index](README.md). Add an index row and update affected gates when introducing a follow-up task. Replace all template guidance with concrete task content.

## Outcome and boundaries

Describe one bounded, observable outcome and its exclusions. Identify affected PRD acceptance IDs and any explicit user decisions.

## Required context

- Link relevant PRD/RFC/ADR sections, not every design document by default.
- Link the dependency handoffs and existing code entry points required for this task.
- Name expected entry points that do not exist yet without creating broken links.

## Deliverables and acceptance checks

- [ ] Describe each observable completion condition, including failure behavior.
- [ ] Identify interfaces affected and the contracts the handoff must record.
- [ ] Add focused behavior tests; update the index's acceptance evidence where applicable.
- [ ] Apply [the implementation quality gates](quality-gates.md): focused tests, Sorbet on new concept code, coverage floors, and full Docker CI. Record actual outcomes and include screenshots for visible UI changes.

## Current checkpoint

- Completed: nothing yet.
- Remaining: implementation and verification.
- Next action: verify the index's merge gate and inspect the required context.

## Problems

None recorded. For each problem, use `TNN-P01`, date, symptom, evidence, impact, attempted fixes, and resolution or required input with next action/owner. Preserve resolved entries briefly; link longer diagnostics.

## Decisions

None recorded. For each decision, use `TNN-D01`, date, choice, rationale, and affected contracts/tasks. Link ADR or PRD/RFC changes when applicable. Record unanswered questions as unresolved, without choosing on the user's behalf.

## Validation evidence

Not run. Record command or manual scenario, date, revision, outcome, coverage summary, Sorbet/RBI changes, and relevant spec/log/screenshot links. Separate passed, failed, and not-run checks.

### Review rounds

For orchestrated tasks, add one compact entry per round. Existing briefs can add this subsection under validation evidence when their run begins. No review has occurred merely because this format exists.

- Round and date; base/candidate revision.
- Correctness reviewer: agent/role, reviewed revision, verdict, and evidence.
- Test reviewer: agent/role, reviewed revision, verdict, and commands/results.
- Findings: stable IDs, severity, affected requirement, file/line or scenario, and requested correction.
- Resolution: fix revision or rationale for a nonblocking deferral; both reviewers' reassessment.
- Final gate: reviewed PR head, required checks, remaining limitations, and verified merge reference when available.

## Handoff

Not implemented. Before review, replace this with implemented code entry points, actual interfaces and errors, transaction/persistence assumptions, tests run, limitations, and the next task's concrete integration notes. Add PR/commit references; record merge evidence only after verification.
