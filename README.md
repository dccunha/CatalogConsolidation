# Catalog Consolidation

A local Rails 8 application for importing marketplace seller items into a PostgreSQL catalog. It loads the supplied SQLite catalog as reference data, imports JSON seller rows, shows a result for every row, and records explicit reviewer decisions for uncertain matches. The supplied files under `docs/refs/` stay unchanged.

## Requirements and setup

Install Docker Engine and Docker Compose v2. Ruby, Node, PostgreSQL, Chromium, and application tools run in Docker.

```sh
docker compose up --build -d
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bin/rails catalog:load_reference
```

Open <http://localhost:3000/>; <http://localhost:3000/up> is the health endpoint. Compose waits for PostgreSQL and the web service runs `db:prepare` on startup; the explicit migration command above also works on a prepared database. The loader reads `docs/refs/catalog.db` read-only and copies its 975 products into PostgreSQL with their original IDs. Run it before importing seller items. An unchanged rerun inserts nothing. Startup and `db:seed` do not run the loader. The PostgreSQL volume persists through `docker compose down`.

For local overrides, copy `.env.example` to `.env` before startup. `WEB_PORT` changes the host port, `DB_PASSWORD` changes the local database password, and `INTAKE_REVIEWER_NAME` sets the name saved on **new** review actions (default: `Local reviewer`). After changing the reviewer name, run `docker compose up -d --force-recreate web` so the new environment reaches a new web container; `docker compose restart web` keeps the old container environment. Past decisions retain their saved reviewer names. The review UI has no login; it is intended for a local demonstration. The default database credentials are local development credentials.

## Import and review in the browser

At **Upload**, choose a JSON file with a top-level array of objects containing `Id`, `SellerName`, `Name`, `Brand`, and `Category`, then select **Upload and process**. The supplied [`ProductEntry.json`](docs/refs/ProductEntry.json) is a full 269-row example. `Id`, `SellerName`, and `Name` must be nonblank strings. A missing `Brand` or `Category` opens a review case. Any of the five fields containing `;`, `--`, `/*`, `*/`, or a control character makes that row **Failed** before matching. The full source remains in Intake; no seller item, review case, product, or Catalog association is made for the row. Ordinary apostrophes and product punctuation are allowed. Submit a corrected row in a new import. Processing is synchronous; the results page shows the batch ID, reconciled totals, source row numbers, reasons, product IDs, and review-case links. Invalid individual rows are marked **Failed** while later rows continue. Malformed JSON and non-array files show an upload error and create no batch. **Batches** reopens historical results.

At **Review queue**, filter by status, batch, or seller. Open a case to compare the original row with ranked catalog candidates, normalized fields, match scores, differences, and history. For an actionable pending case, a reviewer can:

- **Approve** a credible candidate after checking the evidence; the existing catalog product's attributes stay unchanged.
- **Reject** a candidate with a reason. After all candidates are rejected, a complete row can be created only with a separate **Create new product and link seller item** action.
- **Correct** `Name`, `Brand`, or `Category` and rematch. The original row remains visible, and a final approval or creation is still required.
- Resolve a same-seller listing conflict by **keeping** the current item ID or **replacing** it with the incoming ID. A changed listing may instead be explicitly **reassigned** to a candidate or a new product.

The case page displays the reviewer and time of each action. Resolved and superseded cases remain in the queue's corresponding filters. Each batch row keeps its import-time outcome even after a review decision; an unchanged later upload reports **Already imported** and retains that decision. See the [acceptance evidence matrix](docs/tasks/README.md#acceptance-coverage) for the tested edge cases.

## Short demo

Use the separate [`delivery-sample.json`](docs/demo/delivery-sample.json) so the first run shows all three outcomes without changing either supplied reference file. For a clean, isolated rehearsal, choose an unused host port and Compose project name. This example uses a separate `t15_delivery` PostgreSQL volume; it does not touch the default project's database.

```sh
WEB_PORT=3105 INTAKE_REVIEWER_NAME='T15 Demo Reviewer' docker compose -p t15_delivery up -d --build
docker compose -p t15_delivery run --rm web bin/rails db:migrate
docker compose -p t15_delivery run --rm web bin/rails catalog:load_reference
```

1. Open <http://localhost:3105/> and upload `docs/demo/delivery-sample.json`. On a clean reference catalog, the three rows show **Linked 1** (`demo-galaxy` → product #2), **Created 1** (`demo-lamp` → product #976), and **Pending review 1** (`demo-ipad` → a candidate for product #14). [First batch screenshot](docs/tasks/screenshots/t15-demo-results.png).
2. Follow the `demo-ipad` case link. The source has `12.9''` while the catalog has `12.9"`; the displayed name score is 90.9%. Inspect the candidate, then select **Approve product #14**. The case becomes **Resolved** and records `T15 Demo Reviewer` as the decision maker. [Resolved case screenshot](docs/tasks/screenshots/t15-demo-resolved.png).
3. Return to **Upload** and submit the **same unchanged file**. The second batch shows **Already imported 3**, with no new link, product, or pending case. Its iPad row links back to the resolved case, while the first batch still records the original pending outcome. [Rerun screenshot](docs/tasks/screenshots/t15-demo-rerun.png).

Batch and case numbers are generated per database. Product #976 is the next ID only in a clean database loaded from the 975-product reference. The separate demo project can be stopped with `docker compose -p t15_delivery down`; that command retains its data volume for later inspection. For the larger supplied input, upload `docs/refs/ProductEntry.json` into a separately prepared clean catalog. The [T16 clean reference run](docs/tasks/16-block-sql-control-syntax.md#validation-evidence) produced **Linked 247**, **Already imported 1**, **Pending review 20**, and **Failed 1** for row 181; an unchanged rerun produced **Already imported 248**, **Pending review 20**, and **Failed 1**. These are observations for this input and catalog state, not matching policy. The [T14 run](docs/tasks/14-acceptance-journeys.md#validation-evidence) predates the text rule.

## Matching policy and limits

Automatic linking requires exactly one product with equal normalized `Name`, `Brand`, and `Category`, no other credible candidate, and no seller/product uniqueness conflict. Normalization folds case and accents and collapses whitespace; it preserves punctuation, numbers, model terms, and variant words. Missing or conflicting metadata and plausible near matches go to review. A complete row with no credible candidate can be created automatically if it has never entered review. Once review begins, any final link or creation requires an explicit reviewer action.

For candidate **review**, identical normalized names are included even if brand or category differs. Otherwise the normalized brand must match and normalized-name Levenshtein similarity must be at least **0.80**. The score ranks evidence; it never permits an automatic link. The [accepted RFC](docs/rfcs/0001-import-review-lifecycle.md#matching-and-candidate-evidence) explains why 0.80 was chosen: the supplied `Roteador WiFi 6 TP-Link` / `Router WiFi 6 TP-Link` pair scores about 0.826 and would be missed by 0.85, without adding extra multiple-candidate rows in that sample. The iPad punctuation difference in the demo is another observed review case. The [T14 reference run](docs/tasks/14-acceptance-journeys.md#validation-evidence) historically observed 20 pending rows before the T16 text rule. A fresh import now marks supplied row 181 **Failed** in the [batch result screenshot](docs/tasks/screenshots/t16-row-181-failed.png); use the [T16 evidence](docs/tasks/16-block-sql-control-syntax.md#validation-evidence) for current totals. Pending rows are review decisions, not proven duplicates or misses. No exhaustive semantic duplicate audit has been performed. An unusual paraphrase below the threshold can still be missed and automatically created as a duplicate.

Material differences such as `128GB` versus `256GB` or color are distinct sellable products and never pass the exact-name automatic-link rule. A close variant may be offered for review, or a complete item with no credible candidate may be created as a separate product. Matching currently scans the catalog per row; the supplied 975-product reference is small, but larger catalogs would need a faster candidate lookup. The import is synchronous, the local review screen has no authentication, and large concurrent imports have not been validated.

The [assignment context](docs/prds/catalog-consolidation-importer.md#11-assignment-context) requested writing to the supplied SQLite database. This application's deliberate target is PostgreSQL for products, seller associations, batches, and decisions; `catalog.db` is an unchanged, read-only source for the explicit loader. See the [PRD](docs/prds/catalog-consolidation-importer.md), [review lifecycle RFC](docs/rfcs/0001-import-review-lifecycle.md), and [concept ownership ADR](docs/adrs/0001-organize-by-concepts.md) for the agreed scope and reasoning. The separate Guideline Document mentioned by the assignment was not supplied, so its contents could not be verified.

## Checks and development commands

Run the complete gate before review:

```sh
docker compose run --rm web bin/ci
```

It runs Ruby, ERB, and JavaScript lint; Sorbet and RBI freshness checks; dependency and Rails security audits; RSpec and Vitest with coverage floors; database consistency; and seed checks. The required floors are 90% Ruby lines, 80% Ruby branches, and per JavaScript behavior file 80% lines/statements/functions and 70% branches. The [quality gates](docs/tasks/quality-gates.md) require behavior review as well as these checks. T14's [integrated and browser evidence](docs/tasks/14-acceptance-journeys.md#validation-evidence) covers AC1–AC12; its optional screenshot capture is separate from ordinary CI.

```sh
docker compose run --rm web bundle exec rspec
docker compose run --rm web npm run test:js
docker compose run --rm web bundle exec srb tc
docker compose run --rm web bin/rails console
docker compose run --rm web bin/rails dbconsole
docker compose exec db psql -U catalog -d catalog_consolidation_development
```

Development and test use separate PostgreSQL databases. Production reads `DATABASE_URL`; this Compose setup runs development. Generated coverage reports are under `coverage/ruby/` and `coverage/js/`. The [task index](docs/tasks/README.md) is the authoritative implementation and merge record. Stop the default app with `docker compose down`; its PostgreSQL volume is retained.
