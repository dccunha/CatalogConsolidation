# T00Q: Enforce implementation quality gates

Status, sequencing gate, PR, and current blocker live in [the index](README.md). This preflight follows the merged T00 workflow and precedes T01 domain work. Preparing it does not start the orchestrator.

## Outcome and boundaries

Make static typing and coverage expectations executable in Docker CI, and bind every implementation task and review to [the quality gates](quality-gates.md). Preserve the accepted product scope and reference inputs. This task does not implement Catalog or Intake behavior.

## Required context

- [Task workflow](README.md#working-a-task) and [orchestrator](orchestrator.md).
- [Existing CI](../../config/ci.rb), [Ruby coverage](../../spec/spec_helper.rb), and [JavaScript coverage](../../vitest.config.mjs).
- [ADR 0001](../adrs/0001-organize-by-concepts.md) for the future concept paths.

## Deliverables and acceptance checks

- [x] Add Sorbet and Rails/gem RBI generation, run `srb tc` in `bin/ci`, and require new concept Ruby files to opt into meaningful type checking.
- [x] Enforce a Ruby line/branch and JavaScript per-file coverage floor without counting framework boot files as application behavior.
- [x] Update AGENTS.md, the task template/index, orchestrator, developer runbook, and pull request CI so implementers and both reviewers use the gates and record actual evidence.
- [x] Run the full Docker CI suite, verify representative failing gates, and document practical limitations.

## Current checkpoint

- Completed: the existing CI baseline and updated full CI passed; Sorbet and Tapioca were installed, gem/Rails RBIs generated, coverage floors and CI steps added; targeted negative checks rejected a missing sigil, a type error, and uncovered JavaScript/Ruby.
- Remaining: verify the hosted CI permission fix, human PR review, and verified merge before T01 becomes ready.
- Next action: push the CI fix and check the new Actions run.

## Problems

T00Q-P01 (2026-09-30): Automatic approval review rejected the initial `git push -u origin codex/quality-gates`, stating the initial request did not establish the GitHub destination's trust or authorize publication. Resolved after the user explicitly requested a PR: pushed commits `ea04c62` and `b87f941` to `codex/quality-gates` and opened [PR #8](https://github.com/dccunha/CatalogConsolidation/pull/8). No further action required.

T00Q-P02 (2026-09-30): Hosted CI runs as a non-root Docker app user against a bind-mounted GitHub checkout. The first run could not write Rails logs; making `log`, `tmp`, and `storage` writable fixed those errors, but the second run then could not create `node_modules` or `coverage` under the root-owned checkout. Updated the workflow to grant write access to the ephemeral checkout root and runtime directories before Compose. Waiting for the next hosted run to verify the fix.

## Decisions

- T00Q-D01 (2026-09-30): Set initial enforceable floors to 90% Ruby line/80% branch and 80% JavaScript line/statement/function/70% branch per application behavior file. The preflight has only one Ruby spec and one Stimulus spec, so reviewers must still require scenario coverage on every task. Framework boot JavaScript is excluded from the behavior denominator.
- T00Q-D02 (2026-09-30): Require `typed: true` or stronger for new concept Ruby files and add Sorbet/Tapioca to Docker CI. Existing generated Rails files can remain at the Sorbet default until changed; task reviews inspect useful signatures and reject broad escape hatches.

## Validation evidence

- 2026-09-30, base `b39354f`: `docker compose run --rm web bin/ci` passed before the changes: 1 RSpec example, 1 Vitest test, 100% Ruby line coverage across 10 lines, 20% JavaScript line coverage across 5 lines, and all existing style/security/database/seed checks. These small baselines do not establish domain coverage.
- 2026-09-30: `docker compose build web` passed with the locked Sorbet/Tapioca gems; `docker compose run --rm web bundle exec tapioca init`, `docker compose run --rm web bin/tapioca dsl`, `docker compose run --rm web bundle exec srb tc`, `docker compose run --rm web bin/tapioca gems --verify`, and `docker compose run --rm web bin/tapioca dsl --verify` passed during setup.
- 2026-09-30: Temporary probes were removed after checking failures. `bin/check-concept-types` rejected a concept Ruby file without a sigil; `srb tc` rejected a `String` asserted as `Integer`; Vitest rejected an uncovered JavaScript application file; SimpleCov rejected an uncovered Ruby application file.
- 2026-09-30: Final `docker compose run --rm web bin/ci` passed in 25.33 seconds on commit `ea04c62`, including RuboCop, ERB Lint, ESLint, Sorbet, gem/Rails RBI freshness, three security checks, 1 RSpec example, 1 Vitest test, database consistency, and seeds. Ruby line coverage was 10/10 (100%); JavaScript behavior-file lines were 1/1 (100%). No domain code exists yet, so these figures do not demonstrate domain behavior coverage.

## Handoff

Ready for human review in [PR #8](https://github.com/dccunha/CatalogConsolidation/pull/8), currently at commit `b87f941` (quality implementation at `ea04c62`). `config/ci.rb` runs Sorbet, sigil, and RBI freshness gates; `spec/spec_helper.rb` and `vitest.config.mjs` enforce the coverage floors; `.github/workflows/ci.yml` runs the same suite on pull requests; `sorbet/` contains generated interfaces. `bin/ci` passed on the application configuration at `ea04c62`. T01 must begin only after this PR is reviewed and merged, then apply the shared gates to its concept models and tests. The current baseline has no domain implementation; reviewers must inspect future behavior tests and type signatures rather than extrapolating from its 100% coverage report.
