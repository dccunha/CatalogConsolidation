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

- [ ] Inspect the reference schema and verify the documented 975 products and empty seller-association table before implementing the transfer.
- [ ] Add a Catalog-owned loader and document its Docker invocation. Include any required SQLite-reading dependency in the container setup; SQLite is not an application database.
- [ ] Preserve product IDs and values, including product 2. Keep new-product ID allocation clear of loaded IDs.
- [ ] An identical rerun does not duplicate or overwrite records. A conflicting existing reference ID fails clearly instead of overwriting catalog values or resetting unrelated data.
- [ ] Handle missing/unreadable input and transfer failure without leaving a partially loaded reference set.
- [ ] Test fresh loading, repeat loading, conflict handling, and creation of a subsequent product. Verify reference-file contents remain unchanged.
- [ ] Keep the loader explicit; ordinary app startup and CI seed checks must not unexpectedly reset or reload live data.

## Current checkpoint

- Completed: task brief only.
- Remaining: loader, command documentation, and verification.
- Next action: read the T01 handoff and inspect the SQLite reference in read-only mode.

## Problems

None recorded.

## Decisions

None recorded. Record the reader dependency, command, transaction strategy, and repeated-load behavior once implemented.

## Validation evidence

Not run. Record verified reference counts, loader specs, unchanged-input evidence, and CI results.

## Handoff

Not implemented. Publish the exact load command, prerequisites, repeat/conflict behavior, verified ID preservation, and fixture strategy for T05 and T14. Link the updated setup instructions.
