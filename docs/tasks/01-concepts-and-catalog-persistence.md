# T01: Integrate concepts and Catalog persistence

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Make the accepted concept layout work in Rails and persist Catalog products and seller associations in PostgreSQL. This provides the database constraints behind AC8 and AC9. Exclude reference loading, matching, Intake persistence, and product UI. Do not reorganize unrelated foundation files.

## Required context

- [ADR 0001](../adrs/0001-organize-by-concepts.md), especially namespaces, public ownership, and Rails integration.
- [PRD data definitions](../prds/catalog-consolidation-importer.md#4-data-and-business-definitions) and [persistence requirements](../prds/catalog-consolidation-importer.md#7-postgresql-persistence-requirements).
- [RFC persistence contract](../rfcs/0001-import-review-lifecycle.md#persistence-and-ownership-contract).
- Existing [application configuration](../../config/application.rb), [schema](../../db/schema.rb), and [RSpec setup](../../spec/rails_helper.rb).
- [T00A testing conventions](00a-better-specs-conventions.md#handoff), after its merge.

## Deliverables and acceptance checks

- [ ] Add Catalog models under `app/concepts/catalog/models/`, with role namespaces matching paths and explicit, consistent table mapping.
- [ ] Configure and test concept loading/eager loading, controller routing, and owning-context view lookup. Use test fixtures where needed without exposing placeholder product screens.
- [ ] Add migrations for products and seller associations. Preserve the ability to load reference product IDs and store seller item IDs as text.
- [ ] Enforce both seller-association uniqueness rules and the product foreign key at the database level; add required indexes and practical nonempty-value checks.
- [ ] Preserve supplied seller names and IDs exactly; do not add case folding or product-name uniqueness constraints that contradict the RFC.
- [ ] Add explicit spec types under concept paths. Verify model/table integration, duplicate associations, nonexistent products, text IDs, and independent sellers.
- [ ] Verify a fresh migration path and schema loading in Docker; run the relevant Rails loading check, focused specs, and required CI.

## Current checkpoint

- Completed: task brief only.
- Remaining: implementation and verification.
- Next action: verify T00A's merge, then inspect Rails loading and persistence conventions.

## Problems

None recorded.

## Decisions

None recorded. ADR 0001 already fixes ownership and namespaces. Record actual table/column mappings and any Rails integration decisions here.

## Validation evidence

Not run. Record migration, loading, constraint-spec, and CI results with links to the implemented specs.

## Handoff

Not implemented. Publish model/table mappings, indexes/constraints, concept configuration, and spec conventions for T02–T06. Identify the public namespace reserved for Catalog writes without adding Intake dependencies.
