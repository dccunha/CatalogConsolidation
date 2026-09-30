# T02: Load the reference catalog

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Provide a reproducible Docker command that loads the unchanged SQLite reference products into PostgreSQL. This enables AC2's known product ID and realistic matching tests. Exclude seller-file imports, automatic catalog resets, and modifications to reference inputs.

## Required context

- [T01 handoff](01-concepts-and-catalog-persistence.md#handoff).
- [PRD persistence requirements](../prds/catalog-consolidation-importer.md#7-postgresql-persistence-requirements) and [data observations](../prds/catalog-consolidation-importer.md#4-data-and-business-definitions).
- [ADR ownership](../adrs/0001-organize-by-concepts.md#decision).
- [Reference database](../refs/catalog.db), opened read-only; existing [seeds](../../db/seeds.rb) and [Dockerfile](../../Dockerfile).

## Deliverables and acceptance checks

- [x] Inspect the reference schema and verify the documented 975 products and empty seller-association table before implementing the transfer.
- [x] Add a Catalog-owned loader and document its Docker invocation. Include any required SQLite-reading dependency in the container setup; SQLite is not an application database.
- [x] Preserve product IDs and values, including product 2. Keep new-product ID allocation clear of loaded IDs.
- [x] An identical rerun does not duplicate or overwrite records. A conflicting existing reference ID fails clearly instead of overwriting catalog values or resetting unrelated data.
- [x] Handle missing/unreadable input and transfer failure without leaving a partially loaded reference set.
- [x] Test fresh loading, repeat loading, conflict handling, and creation of a subsequent product. Verify reference-file contents remain unchanged.
- [x] Keep the loader explicit; ordinary app startup and CI seed checks must not unexpectedly reset or reload live data.

## Current checkpoint

- Completed: read-only source inspection, Catalog loader and Rake command, Docker dependency, behavior specs, setup documentation, and passing full Docker CI on the T02 working tree based on `590fc8ac988eb3ceaa4a6721165829a389c7bda1`.
- Remaining: independent reviews, parent-owned commit/PR/merge, and post-merge status update.
- Next action: have the correctness and test reviewers inspect this implementation and its evidence.

## Problems

- A loader-only focused RSpec run passed all 7 examples but exited 2 because the repository's global SimpleCov denominator includes unrelated files not exercised by that subset (73.19% line coverage). The full RSpec suite and full CI passed their coverage gates.

## Decisions

- **T02-D01 — 2026-09-30:** Install the `sqlite3` executable in the Docker image and call it with `-readonly` from `Catalog::Services::ReferenceCatalogLoader`. This avoids adding SQLite as a Rails adapter or Ruby gem; PostgreSQL remains the application database. The loader reads the supplied `docs/refs/catalog.db` by default and validates 975 products and zero seller associations before writing.
- **T02-D02 — 2026-09-30:** Expose only the explicit `catalog:load_reference` Rake command, documented in the [README](../../README.md#load-the-reference-catalog). App startup and seeds do not invoke it. The service also accepts a path for isolated specs.
- **T02-D03 — 2026-09-30:** Lock `products` within one PostgreSQL transaction, compare every existing reference ID's name/brand/category exactly, then insert missing rows in batches of 100. Identical rows are skipped; a mismatch raises `ConflictError` before any insert. Database failure rolls back all prior batches. After successful inserts, set the product sequence to at least the larger of the table's maximum ID and its current sequence value so later automatic IDs clear loaded and unrelated high IDs.

## Validation evidence

- **2026-09-30 — Source inspected read-only:** `sqlite3 -readonly docs/refs/catalog.db '.schema'` showed `Product(Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT NOT NULL, Brand TEXT, Category TEXT)` and `SellerProduct` with its seller/product fields. Queries verified 975 products, IDs 1–975, zero seller associations, and product 2 as `Smartphone Galaxy S23` / `Samsung` / `Electronics`. There are 119 null brands and 34 null categories. T01 merge `ff3b548dd18214d4f9eabbb2205ec60cc21d93c1` is an ancestor of base `590fc8a`.
- **2026-09-30 — Input unchanged:** SHA-256 of `docs/refs/catalog.db` was `733ff1d9cc20253da48a9f8b33d7241503e4a06e7c68f65f7fa00ef14466c404` before and after implementation and command runs. No file under `docs/refs/` changed.
- **2026-09-30 — Docker image and command passed:** `docker compose build web` completed with `sqlite3`. In the disposable test database, `docker compose run --rm -e RAILS_ENV=test web bin/rails catalog:load_reference` reported 975 inserted; an identical second invocation reported 0 inserted and 975 already present. The test database was then reset with `db:drop db:create db:schema:load` before CI.
- **2026-09-30 — Behavior specs passed:** [reference loader specs](../../spec/concepts/catalog/services/reference_catalog_loader_spec.rb) check all 975 source rows against PostgreSQL values, product 2, new-ID allocation, idempotent rerun, preservation of an unrelated high-ID product, clear conflict without writes, missing/unreadable/damaged/incomplete source, nonempty seller associations, and rollback when the final insert batch violates the product-name check. Full `docker compose run --rm web bundle exec rspec` passed 27 examples, 0 failures.
- **2026-09-30 — Full gate passed on HEAD `590fc8a` plus T02 working tree:** `docker compose run --rm web bin/ci` passed in 20.65 seconds after the final spec changes: RuboCop (39 files), ERB/JS lint, Sorbet (`No errors`), concept sigils (4 files), gem and Rails RBI freshness (no changes needed), security audits, 27 RSpec examples, 1 Vitest test, database consistency, and seeds. Ruby coverage was 104/106 lines (98.11%) and 11/12 branches (91.66%); JavaScript coverage was 100% statements/lines/functions with no branches. `git diff --check` passed. New loader Ruby is `# typed: true` with method signatures; no new RBI was required.

## Handoff

Build the web image and prepare PostgreSQL, then run `docker compose run --rm web bin/rails catalog:load_reference` as described in [setup](../../README.md#load-the-reference-catalog). The entry point is `Catalog::Services::ReferenceCatalogLoader.call(path: Rails.root.join("docs/refs/catalog.db"))`, returning the number of inserted products. It raises `InputError` for a missing/unreadable/damaged/incomplete SQLite source or nonempty source associations, and `ConflictError` if any existing reference ID has different attributes. A database insert error propagates; the transaction leaves no partial reference set. Identical records are skipped without updates, and unrelated catalog rows remain intact. Product 2 and all other source IDs and values were compared exactly in specs; subsequent generated IDs exceed the loaded maximum (and an unrelated higher sequence value).

For T05 and T14, load the canonical reference once into a fresh test database for realistic candidate/acceptance runs; the source file stays read-only. Specs that need altered reference input should copy `catalog.db` to a temporary location and pass `path:` rather than editing `docs/refs/`. The regular `db:seed` path remains empty, so tests must arrange their own catalog data or invoke this loader explicitly.
