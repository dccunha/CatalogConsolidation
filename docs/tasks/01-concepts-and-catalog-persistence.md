# T01: Integrate concepts and Catalog persistence

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Make the accepted concept layout work in Rails and persist Catalog products and seller associations in PostgreSQL. This provides the database constraints behind AC8 and AC9. Exclude reference loading, matching, Intake persistence, and product UI. Do not reorganize unrelated foundation files.

## Required context

- [ADR 0001](../adrs/0001-organize-by-concepts.md), especially namespaces, public ownership, and Rails integration.
- [Implementation quality gates](quality-gates.md), including Sorbet and coverage requirements.
- [PRD data definitions](../prds/catalog-consolidation-importer.md#4-data-and-business-definitions) and [persistence requirements](../prds/catalog-consolidation-importer.md#7-postgresql-persistence-requirements).
- [RFC persistence contract](../rfcs/0001-import-review-lifecycle.md#persistence-and-ownership-contract).
- Existing [application configuration](../../config/application.rb), [schema](../../db/schema.rb), and [RSpec setup](../../spec/rails_helper.rb).
- [T00A testing conventions](00a-better-specs-conventions.md#handoff), merged as PR #9.

## Deliverables and acceptance checks

- [x] Add Catalog models under `app/concepts/catalog/models/`, with role namespaces matching paths and explicit, consistent table mapping.
- [x] Configure and test concept loading/eager loading, controller routing, and owning-context view lookup. Use test fixtures where needed without exposing placeholder product screens.
- [x] Add migrations for products and seller associations. Preserve the ability to load reference product IDs and store seller item IDs as text.
- [x] Enforce both seller-association uniqueness rules and the product foreign key at the database level; add required indexes and practical nonempty-value checks.
- [x] Preserve supplied seller names and IDs exactly; do not add case folding or product-name uniqueness constraints that contradict the RFC.
- [x] Add explicit spec types under concept paths. Verify model/table integration, duplicate associations, nonexistent products, text IDs, and independent sellers.
- [x] Verify a fresh migration path and schema loading in Docker; run the relevant Rails loading check, focused specs, and required CI.

## Current checkpoint

- Completed: Catalog model and controller foundations, PostgreSQL migration and schema, model and request specs, generated model RBIs, fresh migration and schema-load verification, round-one review fixes, and Docker CI on the review-fix working tree.
- Remaining: PR and merge verification. The task index owns status and the merge gate.
- Next action: parent opens the reviewed PR, verifies GitHub mergeability, and merges after final head checks.

## Problems

- The first `bin/ci` run found that `database_consistency` requires model uniqueness validators corresponding to unique indexes. Both validators and model-level conflict examples were added; the database indexes remain the final integrity guard. The subsequent run passed.
- Round-one correctness review approved implementation commit `c27e62f1a6a1fdf3b3603b7ddb8191f4662f23ff` and requested exact revision attribution for CI evidence. Round-one test review requested T01-TEST-01, proving `MegaStore` and `megastore` may both use the same item ID and product, and T01-TEST-02, proving identical product names may both persist. Both focused specs were added without changing application behavior; reassessment remains pending.

## Decisions

- **T01-D01 — 2026-09-30:** Map `Catalog::Models::Product` explicitly to `products` (`id` bigint, `name` text required, `brand` and `category` nullable text). Explicit integer IDs allow the later reference loader to retain SQLite product IDs; that loader must advance the PostgreSQL sequence after explicit inserts.
- **T01-D02 — 2026-09-30:** Map `Catalog::Models::SellerProduct` explicitly to `seller_products` (`id` bigint, `seller_name` text, `seller_product_id` text, `product_id` bigint). Exact-value unique indexes cover `(seller_name, seller_product_id)` and `(seller_name, product_id)`; a separate `product_id` index supports association lookup. The `product_id` foreign key and non-null plus non-whitespace checks enforce persistence invariants. Model presence and uniqueness validators give earlier feedback without replacing the constraints. No normalization or product-name uniqueness is applied.
- **T01-D03 — 2026-09-30:** Register `app/concepts` as one eager-loaded Rails path. `Catalog::Controllers::BaseController` prepends Catalog's own view root and removes the structural `catalog/controllers/` prefix for local template lookup. A request-spec controller and view fixture verify routing and lookup without adding product UI routes. `Catalog::Public` remains reserved for later write operations; T01 adds no cross-context calls.

## Validation evidence

- **2026-09-30 — Passed on base `152d879` plus the T01 working tree:** `docker compose run --rm -e RAILS_ENV=test web bin/rails db:drop db:create db:migrate` with the old `db/schema.rb` temporarily moved aside ran `CreateCatalogProducts` from scratch. `docker compose run --rm -e RAILS_ENV=test web bin/rails db:drop db:create db:schema:load` then loaded the generated schema; the full specs passed against it. The generated schema retains all checks, indexes, and the foreign key.
- **2026-09-30 — Passed:** `docker compose run --rm web bin/rails zeitwerk:check` reported “All is good!”; [loading spec](../../spec/concepts/catalog/loading_spec.rb) checks the eager-loaded root and role constants, and the [controller request spec](../../spec/concepts/catalog/controllers/base_controller_spec.rb) checks routing and Catalog view lookup.
- **2026-09-30 — Passed on the original candidate:** `docker compose run --rm web bundle exec rspec` ran 16 examples, 0 failures; original `bin/ci` reported 33/33 lines covered and SimpleCov recorded 100% line and 100% branch coverage. [Product specs](../../spec/concepts/catalog/models/product_spec.rb) cover explicit IDs, nullable attributes, and database blank checks; [seller association specs](../../spec/concepts/catalog/models/seller_product_spec.rb) cover exact text values, both uniqueness constraints and model errors, foreign keys, and independent sellers.
- **2026-09-30 — Passed:** `docker compose run --rm web bundle exec srb tc` reported no errors for three `# typed: true` concept files; generated model RBIs live under `sorbet/rbi/dsl/catalog/models/`. The controller's view-prefix method has a Sorbet signature. There are no T01 public write operations or service/value-object methods to sign yet.
- **2026-09-30 — Passed on the original candidate later committed as `c27e62f1a6a1fdf3b3603b7ddb8191f4662f23ff`:** `docker compose run --rm web bin/ci` passed all style, type/RBI freshness, security, RSpec, Vitest, schema consistency, and seed gates in 21.20 seconds. The command ran on base `152d879` plus the T01 working tree before that tree was committed as `c27e62f`; it was not a post-commit run. Ruby coverage was 100% line/branch; JavaScript coverage was 100% statements, lines, and functions (no branches).
- **2026-09-30 — Passed on review-fix working tree:** `docker compose run --rm web bundle exec rspec spec/concepts/catalog` ran 17 examples, 0 failures, with 33/33 lines covered. The working tree is HEAD `c27e62f1a6a1fdf3b3603b7ddb8191f4662f23ff` plus the two model-spec changes for T01-TEST-01/02; their `git diff --binary` SHA-256 is `aa0a13df539575108fa28396df6d4c5e5aa8760cfc8258b8ca78e311453e5867`. [Seller association specs](../../spec/concepts/catalog/models/seller_product_spec.rb) now prove seller-name case distinctions, and [product specs](../../spec/concepts/catalog/models/product_spec.rb) prove duplicate names are allowed.
- **2026-09-30 — Passed on the same review-fix working tree:** `docker compose run --rm web bin/ci` passed every gate in 20.65 seconds: 18 RSpec examples, 0 failures, 33/33 Ruby lines and 100% branches; existing Vitest coverage 100% statements, lines, and functions with no branches; RuboCop, ERB/JS lint, Sorbet, concept sigils, both RBI freshness checks, security audits, database consistency, and seeds all passed. Revision attribution is HEAD `c27e62f1a6a1fdf3b3603b7ddb8191f4662f23ff` plus only the two uncommitted model-spec changes identified by SHA-256 above; the brief and task index edits do not affect application behavior or test inputs.

### Review rounds

- **Round 1, candidate `c27e62f` (2026-09-30):** correctness reviewer approved after inspecting the complete diff, migration/data constraints, Rails loading, and typing; read-only `git diff --check` passed. Test reviewer requested `T01-TEST-01` (case-distinct seller identities) and `T01-TEST-02` (duplicate product names) after inspecting assertions and running 15 focused examples and full `bin/ci` (16 examples), both passing. The implementer added the two requested specs; no application code changed.
- **Round 2, candidate `0dcd3a8c209000acbbc3dc739a22208fa7e7848f` (2026-09-30):** correctness reviewer approved the full diff and test-only delta with no findings; verified the CI evidence fingerprint and `git diff --check`. Test reviewer approved, confirming `T01-TEST-01` and `T01-TEST-02` resolved. The implementer ran 17 focused examples and full `bin/ci` with 18 examples on the equivalent pre-commit tree. The test reviewer inspected that evidence and did not rerun Docker; no application/schema code changed after round 1. Fresh migration/schema-load evidence remains from initial implementation.

## Handoff

T02 may use `Catalog::Models::Product` with table `products` and explicit bigint IDs to load the 975 reference records. Keep `brand` and `category` nullable and supplied strings unchanged. After setting explicit IDs, advance the PostgreSQL product sequence before future creates. T03–T06 may use `Catalog::Models::SellerProduct` with table `seller_products`, exact `seller_name`/text `seller_product_id`, the two unique indexes, `product_id` lookup index and foreign key, and non-whitespace checks. Database unique constraints must still be handled for concurrent writes. Catalog writes from Intake belong behind the reserved `Catalog::Public` namespace; this task defines no public write signature or Intake dependency.

New concept files autoload beneath the single `app/concepts` root with path-matching role namespaces. Catalog controllers should inherit `Catalog::Controllers::BaseController`; their templates resolve within `app/concepts/catalog/views/<controller_name>/`. Specs mirror concept paths under `spec/concepts/` with explicit types, use minimal FactoryBot factories for database examples, and place temporary routing/view fixtures in `spec/fixtures/`. T01 adds no product route or screen.
