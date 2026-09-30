# Catalog Consolidation

A local Rails 8 application that loads a reference SQLite catalog into PostgreSQL, imports seller items from JSON, and helps a reviewer resolve uncertain matches. The supplied files in `docs/refs/` remain unchanged. For import rules, matching details, a walkthrough, and development commands, see the [full guide](README-full.md).

## Requirements and setup

Install Docker Engine and Docker Compose v2. Start the app and prepare its database:

```sh
docker compose up --build -d
docker compose run --rm web bin/rails db:migrate
```

### Load the reference catalog

Before importing seller items, copy the supplied catalog into PostgreSQL:

```sh
docker compose run --rm web bin/rails catalog:load_reference
```

The loader reads `docs/refs/catalog.db` without changing it and can be rerun safely. Open <http://localhost:3000/> after startup. Copy `.env.example` to `.env` only if you need local overrides.

## Import and review

On **Upload**, choose a JSON file and select **Upload and process**. Try the three-row [delivery sample](docs/demo/delivery-sample.json) for a quick tour, or the supplied [269-row input](docs/refs/ProductEntry.json). The results page shows each row's outcome and links to any review case; **Batches** reopens earlier results.

Use **Review queue** to inspect uncertain matches and choose a candidate, reject one, correct seller data, or explicitly create a product. The original input and decision history remain available. The [full guide](README-full.md#import-and-review-in-the-browser) explains the review choices and input validation rules.

## Export the catalog

Open **Export catalog** in the app. Resolve active pending review cases before downloading `catalog-updated.db`, a fresh SQLite snapshot of the current products and seller associations. The supplied reference database is never overwritten. See the [export details](README-full.md#download-the-current-catalog) for the pending-case rule and file contents.

## Development

Run the complete Docker quality gate before review:

```sh
docker compose run --rm web bin/ci
```

The [task index](docs/tasks/README.md) tracks implementation and acceptance evidence. See the [PRD](docs/prds/catalog-consolidation-importer.md) for product requirements.
