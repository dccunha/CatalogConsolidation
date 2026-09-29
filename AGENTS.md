# Repository Guidelines

## Project Structure & Module Organization

This is a Rails 8 application with PostgreSQL, import maps, Turbo, and Stimulus. Shared Rails code lives in `app/`; JavaScript controllers are in `app/javascript/controllers/`, styles in `app/assets/`, and static files in `public/`. Database schema and seeds live in `db/`. Product requirements, architecture decisions, and reference inputs are in `docs/prds/`, `docs/adrs/`, and `docs/refs/`.

For new domain code, follow `docs/adrs/0001-organize-by-concepts.md`: place Catalog and Intake code under `app/concepts/<context>/<role>/`, with matching Ruby namespaces. Mirror those paths in `spec/concepts/`. Intake writes Catalog data through `Catalog::Public`; keep cross-context ownership explicit. The concept directories have not been implemented yet.

## Build, Test, and Development Commands

Run commands in Docker; host Ruby and Node installations are unnecessary.

- `docker compose up --build` starts PostgreSQL and Rails at `http://localhost:3000`.
- `docker compose run --rm web bin/rails db:migrate` applies migrations.
- `docker compose run --rm web bundle exec rspec` runs Ruby specs.
- `docker compose run --rm web npm run test:js` runs Vitest with coverage.
- `docker compose run --rm web bin/ci` runs setup, linters, security audits, tests, database checks, and seed checks.

## Coding Style & Naming Conventions

Use two-space indentation in Ruby, ERB, and JavaScript, and let the configured tools settle style details. Run `bin/rubocop`, `bundle exec erb_lint --lint-all`, and `npm run lint:js` inside the web container. Use snake_case Ruby paths and methods, matching namespaces for concept code, and descriptive Stimulus controller filenames such as `hello_controller.js`.

## Testing Guidelines

Write RSpec examples in `spec/**/*_spec.rb` and Vitest files in `spec/javascript/**/*.test.js`. Add focused coverage for behavior you change; use explicit RSpec types for concept paths where Rails cannot infer them. SimpleCov and Vitest report coverage, but neither enforces a percentage threshold. Run `bin/ci` before submitting a pull request.

## Commit & Pull Request Guidelines

Recent commits use short, imperative, sentence-case subjects, such as `Add local code quality toolchain`. Keep each commit focused. In pull requests, describe the change, explain how it was tested, link a relevant issue or PRD, and include screenshots for visible UI changes.

## Configuration & Security

Copy `.env.example` to `.env` only for local overrides; never commit secrets. Development credentials are local only. Keep `docs/refs/` inputs unchanged unless the task explicitly calls for updating them.
