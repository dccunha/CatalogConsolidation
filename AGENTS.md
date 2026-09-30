# Repository Guidelines

## Project Structure & Module Organization

This is a Rails 8 application with PostgreSQL, import maps, Turbo, and Stimulus. Shared Rails code lives in `app/`; JavaScript controllers are in `app/javascript/controllers/`, styles in `app/assets/`, and static files in `public/`. Database schema and seeds live in `db/`. Product requirements, architecture decisions, and reference inputs are in `docs/prds/`, `docs/adrs/`, and `docs/refs/`.

For new domain code, follow `docs/adrs/0001-organize-by-concepts.md`: place Catalog and Intake code under `app/concepts/<context>/<role>/`, with matching Ruby namespaces. Mirror those paths in `spec/concepts/`. Intake writes Catalog data through `Catalog::Public`; keep cross-context ownership explicit. The concept directories have not been implemented yet.

## Implementation Tasks and Handoffs

Use [the task index](docs/tasks/README.md) as the authoritative status record. Work on one numbered task at a time in sequence and one reviewed PR. Read its brief, linked requirements, and relevant dependency handoffs; do not load every task or earlier conversation by default. Verify the previous task's merge before starting the next. Mark `done` only after verifying a merge.

Apply [the implementation quality gates](docs/tasks/quality-gates.md) to every task. Require focused behavior tests, passing Docker CI, coverage floors, and Sorbet checking for new concept Ruby code before review and merge. Record actual evidence in the task brief; a planned check is not a passing check.

When the user explicitly invokes the [orchestrator workflow](docs/tasks/orchestrator.md), use fresh implementation sub-agents and two independent reviewers per task. The parent owns Git/PR operations and records, enforces one application writer and one shared test runner at a time, and automatically merges only after reviews and required checks pass. Report milestones and continue; pause for material decisions, blockers requiring user involvement, or final QA. Preparing these instructions does not start the loop. An assigned worker performs only its role and task. For individual task requests, retain the fresh-chat and human-review workflow unless the user authorizes otherwise.

Keep the selected brief's checkpoint, problems, decisions, validation evidence, and handoff current, especially before pausing or requesting review. Record actual checks and remaining limitations. Add a linked follow-up task when new work exceeds the current task's boundaries. Keep durable architecture decisions in ADRs and approved behavior changes in the PRD/RFC.

Choose and document routine local implementation details, including initial schema and service design owned by the task. Interview the user before changing agreed behavior, scope, architecture, or established contracts affecting other tasks. During orchestration, workers report questions to the parent, which asks the user. Use interactive question dialogs whenever asking a question and wait for the user's explicit answer. Never treat silence, a timeout, or a preselected option as an answer; leave unanswered decisions unresolved and pause until the user responds.

## Build, Test, and Development Commands

Run commands in Docker; host Ruby and Node installations are unnecessary.

- `docker compose up --build` starts PostgreSQL and Rails at `http://localhost:3000`.
- `docker compose run --rm web bin/rails db:migrate` applies migrations.
- `docker compose run --rm web bundle exec rspec` runs Ruby specs.
- `docker compose run --rm web npm run test:js` runs Vitest with coverage.
- `docker compose run --rm web bundle exec srb tc` runs Sorbet static checking.
- `docker compose run --rm web bin/ci` runs setup, linters, security audits, tests, database checks, and seed checks.

## Coding Style & Naming Conventions

Use two-space indentation in Ruby, ERB, and JavaScript, and let the configured tools settle style details. Run `bin/rubocop`, `bundle exec erb_lint --lint-all`, and `npm run lint:js` inside the web container. Use snake_case Ruby paths and methods, matching namespaces for concept code, and descriptive Stimulus controller filenames such as `hello_controller.js`.

## Testing Guidelines

Write RSpec examples in `spec/**/*_spec.rb` and Vitest files in `spec/javascript/**/*.test.js`. Add focused coverage for behavior you change; use explicit RSpec types for concept paths where Rails cannot infer them. SimpleCov and Vitest enforce the floors in the quality gates. New `app/concepts/` Ruby files must be checked at `typed: true` or stronger. Run `bin/ci` before submitting a pull request.

## Commit & Pull Request Guidelines

Recent commits use short, imperative, sentence-case subjects, such as `Add local code quality toolchain`. Keep each commit focused. In pull requests, describe the change, explain how it was tested, link a relevant issue or PRD, and include screenshots for visible UI changes.

## Configuration & Security

Copy `.env.example` to `.env` only for local overrides; never commit secrets. Development credentials are local only. Keep `docs/refs/` inputs unchanged unless the task explicitly calls for updating them.
