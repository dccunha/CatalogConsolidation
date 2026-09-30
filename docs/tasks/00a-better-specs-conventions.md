# T00A: Enforce Better Specs conventions

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Set up targeted, automated RSpec conventions before T01 adds domain specs. This task changes test tooling and guidance only; it adds no domain models, factories for nonexistent models, or product behavior. Preserve the accepted [concept spec layout](../adrs/0001-organize-by-concepts.md#rails-and-test-integration).

## Required context

- [Better Specs](https://www.betterspecs.org/) and [RuboCop RSpec cops](https://docs.rubocop.org/rubocop-rspec/latest/cops_rspec.html).
- [Repository testing guidelines](../../AGENTS.md#testing-guidelines), [RuboCop config](../../.rubocop.yml), [RSpec setup](../../spec/spec_helper.rb), and [CI checks](../../config/ci.rb).
- [T00 handoff](00-task-workflow.md#handoff) and its merged PR #6.

## Deliverables and acceptance checks

- [x] Enforce objective Better Specs conventions with selected RuboCop RSpec cops and RSpec `expect` syntax.
- [x] Limit one expectation to isolated `*_unit_spec.rb` files; allow coherent multiple assertions in integration examples.
- [x] Add FactoryBot Rails for future database-backed specs without creating placeholder domain factories.
- [x] Document conventions and limits of automation in `AGENTS.md`; update T01's merge gate and handoff link.
- [x] Show focused positive and negative lint behavior, then run required Docker CI and record actual results.

## Current checkpoint

- Completed: T00 merge commit `07ab9b358b68f76ab67989e07e3693ea472a2cc2` verified in integrated Git history; implementation on `codex/t00a-better-specs` from `b39354f8851ec22d190b93bb355e9907914b82a3`; targeted rules, RSpec syntax, FactoryBot dependency, and guidance added; focused checks and full CI passed.
- Remaining: human PR review and verified merge. T01 stays in backlog until then.
- Next action: open the T00A PR and await human review.

## Problems

None recorded.

## Decisions

- **T00A-D01 — 2026-09-30:** The user chose a new task before T01, preserving the one-task-at-a-time sequence and changing T01's merge gate to T00A.
- **T00A-D02 — 2026-09-30:** Enable targeted objective checks, not the whole RSpec department. Keep the 40-character description suggestion as review guidance.
- **T00A-D03 — 2026-09-30:** Apply the one-expectation check only to isolated unit specs identified by `*_unit_spec.rb` within mirrored concept paths. Allow related assertions in slower integration examples.
- **T00A-D04 — 2026-09-30:** Add FactoryBot Rails now for database-backed specs; use plain objects for isolated specs. T01 will add model factories when its models exist.

## Validation evidence

- **2026-09-30 — Passed:** `docker compose run --rm --no-deps -e BUNDLE_DEPLOYMENT=false web bundle lock` added only `factory_bot` and `factory_bot_rails` to the lockfile; `docker compose build web` succeeded.
- **2026-09-30 — Passed:** `docker compose run --rm --no-deps web bin/rubocop` inspected 26 Ruby files with no offenses.
- **2026-09-30 — Passed (expected offense):** A disposable two-expectation example supplied to `rubocop --stdin` as `spec/concepts/catalog/services/example_unit_spec.rb` failed with `RSpec/MultipleExpectations [2/1]`.
- **2026-09-30 — Passed:** The same two-expectation example supplied as `spec/requests/example_spec.rb` had no `RSpec/MultipleExpectations` offense. A separate disposable example produced the expected `ContextWording`, `ExampleWording`, and `InstanceVariable` offenses.
- **2026-09-30 — Passed:** A Docker Rails runner confirmed `FactoryBot` loads in test; a Ruby check confirmed RSpec expectation and mock syntax are both `[:expect]`.
- **2026-09-30 — Passed:** `docker compose run --rm web bin/ci` completed setup, Ruby/ERB/JavaScript linting, security audits, database checks, one RSpec example, one Vitest test, and seed checks. No domain acceptance criteria are implemented yet.

## Handoff

`bin/ci` already runs RuboCop, so its selected RSpec cops now apply to every PR. RSpec accepts only `expect` syntax. `RSpec/MultipleExpectations` applies to `spec/**/*_unit_spec.rb`, preserving the concept path layout while allowing related assertions in integration specs. `factory_bot_rails` is loaded in development and test, with no domain factories yet. Reviewers must still assess edge-case coverage, mock use, minimal setup, and description clarity; no 40-character cap is automated.

T01 must verify this PR's merge before starting, then add its first model factories and use the conventions in `AGENTS.md`. No schema or product interface changed.
