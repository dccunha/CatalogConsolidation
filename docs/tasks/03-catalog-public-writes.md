# T03: Implement Catalog public writes

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Provide the synchronous `Catalog::Public` operations Intake will use to link, create, and reassign seller associations. Catalog owns these writes and has no Intake dependency. This establishes atomicity for AC8/AC9 and later review decisions; it does not implement matching or review authorization.

## Required context

- [T01 handoff](01-concepts-and-catalog-persistence.md#handoff) and [T02 handoff](02-reference-catalog-loading.md#handoff).
- [ADR public surface](../adrs/0001-organize-by-concepts.md#dependencies-and-public-surface).
- [PRD write isolation](../prds/catalog-consolidation-importer.md#53-failure-isolation-and-catalog-writes) and [review actions](../prds/catalog-consolidation-importer.md#6-review-workflow).
- [RFC review lifecycle](../rfcs/0001-import-review-lifecycle.md#review-lifecycle).

## Deliverables and acceptance checks

- [x] Implement bounded operations for linking an existing product, creating a product with its association, and changing associations for explicit review decisions.
- [x] Keep existing product attributes unchanged on link or reassignment. Route all supplied strings through Active Record/bound SQL parameters.
- [x] Respect both uniqueness constraints; report useful conflict information without silently selecting a surviving seller ID.
- [x] Support an enclosing Intake transaction so Catalog writes and an Intake decision can commit or roll back together. Do not introduce independent commits or callbacks across the ownership boundary.
- [x] Test successful writes, constraint failures, create/association rollback, reassignment rollback, quoted/SQL-like values, and unchanged product fields.
- [x] Record exact operation signatures, return values, expected exceptions/conflicts, and transaction behavior for downstream tasks.

## Current checkpoint

- Completed: `Catalog::Public::Writes` implements the three bounded operations, 17 focused database examples cover the write contract, and Docker CI passes on base `12e43ad` plus this working tree.
- Remaining: parent-owned review, PR, and merge workflow. The task index owns status and AC evidence.
- Next action: parent reviews the candidate and arranges independent correctness and test reviews.

## Problems

- A focused `rspec spec/concepts/catalog/public/writes_spec.rb` run passed its examples but exited 2 because global SimpleCov includes unrelated code; full CI passed both coverage floors.
- The first full CI run exposed a RuboCop ABC-size offense and 65.51% branch coverage. The write-error path was simplified, and the final full CI run passed.

## Decisions

- **T03-D01 — 2026-09-30:** Expose the synchronous class methods on `Catalog::Public::Writes`:
  - `.link(product_id: Integer, seller_name: String, seller_product_id: String) -> Catalog::Models::SellerProduct` inserts an association for an existing product.
  - `.create_with_association(name: String, brand: String | nil, category: String | nil, seller_name: String, seller_product_id: String) -> Catalog::Models::SellerProduct` creates the product and its association together; the returned association's `product` and `product_id` identify the product.
  - `.reassign(association_id: Integer, product_id: Integer, seller_product_id: String) -> Catalog::Models::SellerProduct` updates that association in place. Pass its current `product_id` to replace only a seller item ID, or its current `seller_product_id` to change only the product. The seller name is immutable through this operation. Intake chooses the winning ID explicitly; this API never displaces another association automatically.
- **T03-D02 — 2026-09-30:** Each operation runs in `SellerProduct.transaction(requires_new: true)`. Standalone calls commit on success. Inside an Intake transaction, the nested savepoint releases into the outer transaction and is rolled back if the outer transaction rolls back; a failed operation rolls back only its savepoint, so Intake may record a row failure and continue. No callbacks or independent connection/commit are used.
- **T03-D03 — 2026-09-30:** Exact seller identity and association conflicts raise `Catalog::Public::Writes::ConflictError` with `kind` `:seller_item_taken` or `:seller_product_taken` and `existing_association_id`. A database uniqueness race raises the same class with `kind: :database_unique_conflict` and the database detail in its message. Missing product or association IDs raise `ActiveRecord::RecordNotFound`; invalid attributes or a uniqueness validation racing after the precheck raise `ActiveRecord::RecordInvalid` with model errors. A concurrent foreign-key race may raise `ActiveRecord::InvalidForeignKey`. These exceptions leave the operation's savepoint rolled back. Only Active Record binds supplied strings; no string is interpolated into SQL. Intake owns conflict review, candidate rechecks, decision/audit state, and row isolation.

## Validation evidence

- **2026-09-30 — Focused specs:** `docker compose run --rm web bundle exec rspec spec/concepts/catalog/public/writes_spec.rb` passed 16 examples, 0 failures on the first candidate; its process exited 2 because the focused file alone covered 43.95% lines and 27.58% branches of the repository-wide SimpleCov denominator. One later race-error example was added and verified by full CI.
- **2026-09-30 — Full gate on base `12e43ad` plus T03 working tree:** `docker compose run --rm web bin/ci` passed in 20.43 seconds: Ruby/ERB/JS lint, Sorbet (`No errors`), concept sigils (5 files), both RBI freshness checks, security audits, 44 RSpec examples, 1 Vitest test, database consistency, and seeds. Ruby coverage was 161/163 lines (98.77%) and 17/18 branches (94.44%); JavaScript coverage was 100% statements/lines/functions, with no branches. The new concept file is `# typed: true` with public and helper method signatures; no RBI update was required. [Write specs](../../spec/concepts/catalog/public/writes_spec.rb) cover link/create/reassign, both uniqueness conflicts with existing association IDs, missing products, invalid inputs, create rollback after association failure, outer rollback, continuing after a failed nested savepoint, unchanged product values, and exact quoted/SQL-like strings.

## Handoff

T07 and T11–T13 call the three class methods and handle the return value/exceptions described in T03-D01 through T03-D03. Wrap a Catalog call and the corresponding Intake row or review decision in an Intake-owned Active Record transaction; a raised exception rolls back Catalog's savepoint, and rolling back the outer transaction rolls back both contexts. If an operation fails and Intake needs to continue processing, rescue the exception outside the Catalog call, then record the failed row in the outer transaction. For a seller conflict, use `existing_association_id` to show the conflicting listing and require an explicit decision before `.reassign`; do not treat a conflict as permission to overwrite it. Intake may query `Catalog::Models::Product` and `Catalog::Models::SellerProduct` read-only for matching, candidate evidence, and display, but all Catalog writes use `Catalog::Public::Writes`. The database enforces uniqueness, nonblank fields, and foreign keys; Intake still owns matching, input completeness policy, reviewer authorization, and decision history.
