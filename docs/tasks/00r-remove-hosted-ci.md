# T00R: Remove hosted CI requirement

Status, sequencing gate, PR, and current blocker live in [the index](README.md). This follow-up changes the CI policy introduced by merged T00Q before T01 begins.

## Outcome and boundaries

Require the full Docker `bin/ci` suite locally before review and merge without running it through GitHub Actions. Preserve T00Q's historical hosted run results as evidence of what ran then. This task does not change application behavior, coverage floors, typing rules, or product requirements.

## Required context

- [T00Q handoff](00q-quality-gates.md#handoff), merged in [PR #8](https://github.com/dccunha/CatalogConsolidation/pull/8) at `8b9f07a`.
- [Implementation quality gates](quality-gates.md) and [orchestrator merge rules](orchestrator.md#validate-and-merge).
- [Task workflow](README.md#working-a-task) and the root `AGENTS.md`.

## Deliverables and acceptance checks

- [x] Remove the GitHub Actions `bin/ci` workflow, including its pull request and `main` push triggers.
- [x] Update current quality gate and orchestration instructions to require recorded local `bin/ci` evidence and GitHub mergeability checks.
- [x] Sequence this follow-up before T01 and link the policy change from T00Q without deleting historical validation evidence.
- [x] Run `docker compose run --rm web bin/ci` on the candidate working tree and record the result.
- [ ] Confirm no current instructions require hosted CI and that the PR can merge without a stale required status check.

## Current checkpoint

- Completed: PR #8 merge verified; workflow removed, policy documentation updated, and full local suite passed.
- Remaining: PR mergeability check and human review.
- Next action: open the PR, inspect its merge state and any required checks, then update the handoff.

## Problems

T00R-P01 (2026-09-30): GitHub's required-status-check endpoint returned HTTP 403, stating this private repository needs GitHub Pro or public visibility for that feature. Repository settings could not be inspected through that endpoint. Check the new PR's reported mergeability; do not bypass any protection.

## Decisions

- T00R-D01 (2026-09-30): The user chose to remove the entire GitHub Actions workflow, including the `main` push run, while retaining recorded local Docker `bin/ci` as a review and merge gate. This supersedes T00Q's hosted CI requirement; its historical run evidence remains factual.

## Validation evidence

- 2026-09-30: `gh pr view 8 --json state,mergedAt,mergeCommit,url` confirmed PR #8 merged at `8b9f07a` on 2026-09-30T03:38:19Z.
- 2026-09-30, candidate working tree based on `c8e860f`: `docker compose run --rm web bin/ci` passed in 33.57 seconds. RuboCop, ERB Lint, ESLint, Sorbet, concept sigils, gem/Rails RBI freshness, three security checks, database preparation/consistency, and seeds passed; RSpec had 1 example and 0 failures with 10/10 Ruby lines covered; Vitest had 1 test and 100% JavaScript lines/statements/functions (1/1), with no branches. No application code changed in this task.
- 2026-09-30: `rg` found no current instruction requiring hosted CI. Remaining GitHub Actions/hosted mentions are historical T00Q evidence or descriptions of T00R's removal; `.github/workflows/ci.yml` is deleted. `git diff --check` passed.
- New PR mergeability check: pending.

## Handoff

The GitHub Actions workflow is deleted. Future task PRs require a recorded local `docker compose run --rm web bin/ci` result; reviewers still inspect the coverage and typing evidence, and the orchestrator checks GitHub mergeability without bypassing protection. The full local suite passed on the candidate working tree based on `c8e860f`. PR mergeability remains to be checked. T01 follows this task only after its reviewed PR merges.
