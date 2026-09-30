# CatalogConsolidation

A full-stack Rails development environment for the catalog consolidation project. Rails uses PostgreSQL for its application data. Catalog tables, an explicit reference loader, and the seller JSON upload and batch-result pages are available. Review actions are still in progress. The files in `docs/refs/`, including `catalog.db`, remain unchanged reference inputs.

## Implementation progress

See the [task index](docs/tasks/README.md) for the implementation sequence, current status, acceptance coverage, and workflow for fresh agent chats. Each task has a brief with its required context, acceptance checks, problems, decisions, and handoff. The index distinguishes planned work from verified, merged implementation.

For agent-managed implementation, use the [orchestrator starter prompt](docs/tasks/orchestrator.md#starter-prompt). It delegates implementation and independent reviews, manages fixes and merges, and prepares the application for final human QA when explicitly invoked.

## Requirements

- Docker Engine
- Docker Compose v2

Ruby, Bundler, Rails, PostgreSQL, Node, and the development dependencies run inside Docker. No host installation of those tools is needed.

## Start the app

```sh
docker compose up --build
```

Open <http://localhost:3000>. The Rails health endpoint is <http://localhost:3000/up>. Compose waits for PostgreSQL to become healthy; the web service then prepares the `catalog_consolidation_development` database. PostgreSQL data lives in the `postgres_data` Docker volume and survives `docker compose down`.

## Upload seller products

After loading the reference catalog below, open <http://localhost:3000/>. Choose a JSON file whose top level is an array of seller product objects, then select **Upload and process**. Processing is synchronous. The result page shows the batch ID, counts by outcome, and every source row with its reason and product or review-case ID. Invalid individual rows stay in the batch; malformed JSON and non-array files return to the form with an error and create no batch. Use **Batches** to reopen earlier results or upload the same file again. Review-case IDs are shown as text until review pages are implemented.

## Load the reference catalog

After building the web image and preparing the database, run:

```sh
docker compose run --rm web bin/rails catalog:load_reference
```

The command reads `docs/refs/catalog.db` with SQLite in read-only mode and inserts its 975 products into PostgreSQL with the same IDs, names, brands, and categories. It expects the supplied file to have no seller associations. An identical rerun reports zero inserts. If a reference ID already has different values, the command fails without changing existing products or loading part of the file. PostgreSQL allocates later product IDs above the loaded IDs. The command is explicit: app startup and `db:seed` do not run it.

The default credentials are for local development only. To override the password or web port, copy `.env.example` to `.env` and edit `DB_PASSWORD` or `WEB_PORT` before startup. The PostgreSQL port is not published to the host; use the container commands below to inspect it.

## Work inside the containers

```sh
docker compose run --rm web bin/rails console
docker compose run --rm web bin/rails dbconsole
docker compose run --rm web bin/rails db:migrate
docker compose exec db psql -U catalog -d catalog_consolidation_development
docker compose run --rm -e RAILS_ENV=test web bin/rails db:prepare
docker compose run --rm web bin/rake -T
docker compose run --rm web bundle exec rspec
docker compose run --rm web npm run test:js
```

Development and test use separate PostgreSQL databases. Production is configured through `DATABASE_URL`; this Compose setup runs development only. To open a shell in the running server container, use `docker compose exec web sh`. Run other Rails, Bundler, PostgreSQL, and Node commands from that shell. After changing `Gemfile` or `Gemfile.lock`, rebuild with `docker compose build web` and restart the service. `bin/setup` runs `npm ci` from `package-lock.json` for JavaScript tools.

## Code quality

Run the full local check suite with:

```sh
docker compose run --rm web bin/ci
```

It runs RuboCop, ERB Lint, ESLint, Sorbet and RBI freshness checks, the security audits, RSpec, Vitest, DatabaseConsistency, and the seed check. Bullet reports query issues in development and raises in RSpec examples. Ruby coverage must reach 90% lines and 80% branches; each JavaScript application behavior file must reach 80% lines/statements/functions and 70% branches. Open `coverage/ruby/index.html` and `coverage/js/index.html` after a test run; these generated files are ignored by Git. The [implementation quality gates](docs/tasks/quality-gates.md) also require meaningful scenario tests and typing review on every task.

New Ruby code under `app/concepts/` uses `# typed: true` or stronger and useful Sorbet signatures. Run `docker compose run --rm web bundle exec srb tc` for a focused type check. When gems or Rails DSL interfaces change, regenerate RBI files with `docker compose run --rm web bin/tapioca gems` and `docker compose run --rm web bin/tapioca dsl`, inspect the changes, and commit them with the implementation.

Mutation testing is a separate, targeted check. Once business logic and matching specs exist, run `docker compose run --rm web bin/mutate 'CatalogMatcher#match'`, replacing the subject with the class or method to analyze. The command uses Mutant's open-source mode and one worker. It is intentionally separate from `bin/ci` until there is code to mutate.

Stop the app with `docker compose down`. To intentionally delete the PostgreSQL data volume, run `docker compose down -v`.
