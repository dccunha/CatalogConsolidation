# Implementation quality gates

These checks apply to every implementation task, including follow-up tasks. A task brief may add checks but cannot silently weaken these gates. Record the command, revision, result, and any limitation in the brief's validation evidence. A passing percentage or static checker is evidence, not a substitute for behavior review.

## Required checks

- Run focused specs while implementing. Before a PR is ready for review, run `docker compose run --rm web bin/ci` locally on its candidate revision and record the result. The suite runs Ruby, ERB, and JavaScript linters; Sorbet and RBI freshness checks; gem, importmap, and Brakeman security checks; RSpec and Vitest; database consistency; and seed checks. Fix failures before merge. Do not mark skipped or interrupted checks as passed.
- Ruby coverage from the full RSpec suite must meet 90% line and 80% branch coverage. JavaScript application behavior files covered by Vitest must each meet 80% lines, statements, and functions, and 70% branches. Framework boot files are excluded from the JavaScript denominator. Coverage reports live under `coverage/` and are ignored by Git.
- Add focused tests for changed behavior, including relevant invalid input, conflicts, transaction rollback, reruns, and browser journeys. The test reviewer checks assertions and missing scenarios; a green coverage number alone is insufficient. Do not add trivial tests solely to satisfy a threshold or exclude business logic from coverage.
- New Ruby files under `app/concepts/` must use `# typed: true` or stronger. Add useful Sorbet signatures to public context interfaces and nontrivial service/value-object methods. Run `bundle exec srb tc` through `bin/ci`; keep generated gem and Rails RBI files current when dependencies or dynamic interfaces change. Do not suppress type errors with broad `T.untyped`, `T.unsafe`, `# typed: false`, or unchecked RBI shims. If a narrow escape is unavoidable, explain it in code and the task handoff for review.
- Keep Ruby code under the accepted concept ownership rules and preserve database constraints for invariants. Reviewers inspect security, query behavior, errors, transaction boundaries, and cross-context calls even when automated checks pass.

## Review and handoff

The implementer records the changed behavior, relevant spec names, coverage summary, Sorbet/RBI updates, and all required check results. The correctness reviewer checks contracts, typing quality, and data integrity. The test reviewer checks coverage scope and failure assertions as well as running assigned checks. A failed gate or a substantive gap returns to implementation; both reviewers reassess the final revision. The orchestrator compares the reviewed revision with the PR head, verifies the recorded local `bin/ci` result, and checks GitHub mergeability before merging.

If a tool or environment cannot run, record the exact failure and keep the task unfinished until the gate can be verified or the user explicitly approves a change to this policy. A future task may raise these floors as the application grows; lowering or excluding new business code requires a documented decision.
