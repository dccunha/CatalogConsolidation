# ADR 0001: Organize Catalog Consolidation by Concepts

- **Status:** Accepted
- **Date:** 29 September 2026
- **Scope:** This Rails project

## Context

The [catalog consolidation PRD](../prds/catalog-consolidation-importer.md) describes a catalog, seller associations, an import process, and a human review workflow. These responsibilities need visible ownership as the project grows beyond its Rails foundation. We also want the code for each responsibility together, including its Rails models and web interface.

The assignment refers to a separate Guideline Document for code structure, naming, and documentation. That document was not available when this decision was made.

## Decision

Organize context-owned code under `app/concepts/<context>/<role>/`. Start with two contexts:

| Context | Owns |
| --- | --- |
| **Catalog** | Catalog products, seller-product associations, and loading the reference catalog into the application database. |
| **Intake** | Seller-file imports, import batches and row outcomes, matching decisions, review cases and decisions, and the review interface. |

Use `catalog` and `intake` directly beneath `app/concepts/`. Do not add a subdomain directory now. Add one when distinct business areas make a grouping useful, and record that change in an ADR.

Within each context, use role directories only where code exists, such as `models`, `services`, `controllers`, `views`, and `public`. Ruby constants match their paths, including the role namespace. For example:

| Path | Ruby constant |
| --- | --- |
| `app/concepts/catalog/models/product.rb` | `Catalog::Models::Product` |
| `app/concepts/catalog/models/seller_product.rb` | `Catalog::Models::SellerProduct` |
| `app/concepts/intake/controllers/imports_controller.rb` | `Intake::Controllers::ImportsController` |

Views live under their owning context's `views` directory; templates do not define Ruby constants. Context-owned controllers and models live in the concept tree. Application-wide Rails base classes, configuration, migrations, and genuinely generic code remain in conventional locations. Do not move existing foundation files solely to satisfy this ADR.

## Dependencies and public surface

Catalog owns writes to products and seller-product associations. Intake calls synchronous operations in `Catalog::Public` when an import or review decision needs such a write. The public namespace is the declared cross-context write surface; other Catalog classes are internal for writes. Intake may make documented, read-only queries against `Catalog::Models` for matching and display. It must not write Catalog records directly or use callbacks to bypass Catalog's operations.

Catalog does not depend on Intake. Intake owns writes to its import and review records. Both contexts use the same Rails application and database; this decision does not introduce an engine, service boundary, event bus, or separate persistence layer.

## Rails and test integration

Implementation must configure and verify Rails loading, controller routing, view lookup, and Active Record table mapping for the concept paths and role namespaces. Specs mirror the concept paths under `spec/concepts/<context>/<role>/`; configure RSpec types explicitly where its standard path inference does not apply. This ADR establishes the layout and dependency direction, while the PRD defines import behavior and acceptance criteria.

## Consequences

The structure makes ownership and cross-context writes visible. It also requires more Rails integration work than conventional `app/models`, `app/controllers`, and `app/views` placement. We accept that cost for this project and will keep the two contexts and their public surface small.
