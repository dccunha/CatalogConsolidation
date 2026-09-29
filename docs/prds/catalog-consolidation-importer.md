# Catalog consolidation importer — Product Requirements Document

**Status:** Draft for interview take-home  
**Date:** 29 September 2026  
**Inputs:** [catalog.db](../refs/catalog.db), [ProductEntry.json](../refs/ProductEntry.json), and [assignment PDF](<../refs/VTEX _ Coding Interview AI - Take home assessment 2.pdf>)

## 1. Purpose and problem

The company is moving from a single-retailer catalog to a marketplace. Multiple sellers can offer the same sellable item using different descriptions. The importer must associate seller items with catalog products without silently linking unlike items or creating avoidable duplicates.

The supplied assignment requires reading a seller-product file and saving the result in the supplied SQLite database. For each item, the system must link it to an existing `Product` or create a `Product`, and record the seller association. This PRD adds a small, persistent review workflow for decisions that cannot be made safely without a person.

## 2. Goals and success measures

1. Import the supplied JSON file into SQLite and preserve a traceable outcome for every input row.
2. Automatically link only clear, explainable matches. Send plausible but uncertain matches to review.
3. Create a new catalog product only when the input is complete and no credible existing candidate is found.
4. Make repeated imports safe: the same seller item must not create a second association or reopen a resolved review decision.
5. Keep valid rows moving when another row is invalid or fails.

**Success is measured by** correct links and new products in the acceptance scenarios below, zero duplicate seller associations after reruns, a visible reason for every review or failure, and no unreviewed modification to existing catalog attributes.

## 3. Scope

### Required in this take-home PRD

- Read a JSON array using the structure of the supplied `ProductEntry.json`.
- Validate, normalize, compare, create or link, and record an outcome per row.
- Persist review cases and decisions, and provide a simple local web screen for a reviewer.
- Provide an import summary and row-level results.
- Make the SQLite schema changes needed for text seller IDs, uniqueness, and the review queue.

### Out of scope

- CSV and configurable seller-file mapping.
- A product-family/variant hierarchy. Each distinct sellable variant is a separate `Product` row; family grouping is a later extension.
- Prices, stock, images, seller onboarding, and publication to a storefront.
- Large-scale concurrency, external matching services, and production authentication. The review screen is intended for a local take-home demonstration.

## 4. Data and business definitions

| Concept | Requirement |
| --- | --- |
| Catalog product | One specific sellable item. A different size, color, storage capacity, or other material variant is a different `Product`. |
| Seller item identity | The pair `(SellerName, Id)` from the input. `Id` is an opaque string; it must not be parsed as an integer or assumed to be a valid UUID. |
| Seller association | A seller may have at most one item ID linked to a given catalog product. Different sellers may link to the same product. |
| Input fields | Every row has `Id`, `SellerName`, `Name`, `Brand`, and `Category`. `Id`, `SellerName`, and `Name` must be nonempty strings. Missing or blank `Brand` or `Category` requires review. |
| Existing catalog attributes | An import must not automatically overwrite an existing product's `Name`, `Brand`, or `Category`. |

The supplied database has 975 `Product` rows and an empty `SellerProduct` table. The supplied JSON has 269 rows from 20 sellers. Its IDs are strings, three rows have a null `Brand`, and one `(SellerName, Id)` pair occurs twice with an accent difference in the name. These are input observations, not target result counts.

## 5. Import behavior

### 5.1 Row validation and idempotency

1. Reject malformed JSON at the file level with a clear error. For a valid JSON array, process rows independently.
2. Mark a row with a missing or invalid `Id`, `SellerName`, or `Name` as failed. Continue with other rows.
3. If `(SellerName, Id)` has already been imported, compare its normalized identity fields (`Name`, `Brand`, `Category`). If they are unchanged, mark the row **skipped / already imported**. If they have materially changed, hold the row for review; do not silently relink it.
4. Treat duplicate occurrences of the same seller item within one file by the same rule. Accent or whitespace differences alone do not create another association.

### 5.2 Matching policy

**Safe normalization** for comparison: Unicode case folding, removal of diacritics, trimming, and collapsing internal whitespace. Preserve punctuation, numbers, units, model tokens, and variant words. For example, `Câmera` and `Camera` compare equally; `12.9''` and `12.9"` do not become identical automatically.

For a complete row, the decision order is:

1. **Automatic link:** exactly one existing `Product` has the same normalized `Name`, `Brand`, and `Category`, and linking it would not violate the one-item-per-seller-and-product rule.
2. **Review:** more than one exact candidate exists; a plausible near-name candidate exists; a candidate has conflicting brand or category; or the seller already has a different item ID linked to the candidate product. No automatic link is permitted when brand or category conflicts or is missing.
3. **Automatic create:** the row has all identity fields and no credible existing candidate. Create one `Product` and one `SellerProduct` association in the same transaction.

For a row missing `Brand` or `Category`, hold it for review even if no candidate is found. Do not create an incomplete product automatically.

**Proposed, deterministic candidate rule for review:** include a product when its normalized name is identical to the input name, regardless of brand/category, or when its normalized brand matches and normalized-name similarity is at least 0.85 using a documented character-similarity calculation. Candidate ranking affects what the reviewer sees; it never grants an automatic link. The implementation must document the exact calculation and show the comparison evidence in the review screen. This threshold is an implementation starting point to validate against the supplied examples and explicit variant tests.

If two names differ in a material variant token, such as `128GB` versus `256GB`, they must not be automatically linked. A close name can still be presented for review.

### 5.3 Failure isolation and catalog writes

- Use a transaction for each row's catalog and association writes. A failed row must not leave a partial product or association.
- Continue processing the rest of a valid file after a row-level failure.
- Existing `Product` values remain unchanged on link. The seller's original fields are retained in the import/review record for audit and later comparison.
- Use parameterized SQL for every supplied string, including values containing quotes or SQL-like text.

## 6. Review workflow

The importer stores pending rows with the original input, normalized comparison values, reason for review, ranked candidate products, and any conflicting seller association. Pending rows do not receive a `SellerProduct` link until resolved.

The local web screen shows the seller item, the proposed catalog product and its differences, the decision reason, and the import batch. A reviewer can:

1. **Approve the suggested product:** create or update the seller association after rechecking uniqueness and foreign-key constraints. Catalog attributes stay unchanged.
2. **Reject the suggested product:** show the next plausible candidate. If all candidates are rejected and the row is complete, create a new product and associate the seller item.
3. **Correct missing or erroneous input metadata:** save the corrected `Brand`, `Category`, or other identity field, then rerun matching. The original input remains visible.
4. **Resolve a same-seller listing conflict:** choose which of the two seller item IDs remains linked to the product. Record the displaced ID so reimporting it does not silently restore the old association.

A changed identity for an existing `(SellerName, Id)` also enters review. The reviewer may approve a suggested product or reject candidates until a new product is created. Any reassignment of the existing seller association is atomic and recorded.

Store the reviewer, decision, time, and resulting `ProductId` or rejection reason. Reruns must honor resolved decisions. If a reviewer has not resolved a row, it remains pending; it is not silently created or linked.

## 7. SQLite requirements

- Store `SellerProductId` as `TEXT` to preserve the input `Id` exactly. The supplied `SellerProduct` table is empty, so this migration does not have to preserve existing associations.
- Enforce `UNIQUE (SellerName, SellerProductId)` and `UNIQUE (SellerName, ProductId)`.
- Keep `SellerProduct.ProductId` as a foreign key to `Product.Id`; enable `PRAGMA foreign_keys = ON` on every connection.
- Index `SellerProduct.ProductId` and the columns used to find seller identities and review rows.
- Reject empty required strings through validation and, where practical, database constraints.
- Persist import batches, row outcomes, review state, source values, and decisions. The physical table layout is an implementation choice, provided these requirements and constraints are met.

## 8. Import output

Each run returns a batch identifier and totals for linked, created, already imported, pending review, and failed rows. A row-level report includes source row number, seller name and ID, outcome, resulting `ProductId` when applicable, review case ID when applicable, and a human-readable reason. Counts must reconcile to the number of input rows. The review screen can filter pending and resolved cases by batch and seller.

## 9. Acceptance criteria

| ID | Scenario | Expected result |
| --- | --- | --- |
| AC1 | Import the supplied JSON array. | Every one of its 269 rows has a recorded outcome; one bad row does not erase successful rows. |
| AC2 | Import `MegaStore` / `Smartphone Galaxy S23` with `Samsung` and `Electronics`. | The seller item links to existing `Product.Id = 2`; no new catalog product is created for it. |
| AC3 | Import `KitchenPlus` / `Tablet iPad Pro 12.9''` when the catalog has `Tablet iPad Pro 12.9"`. | The near match is shown for review; it is not automatically linked or created as a duplicate. |
| AC4 | Import `GardenStore` / `Camera Canon EOS R6` with category `Photo` when the catalog candidate uses `Photography`. | The category conflict blocks automatic linking and is visible to the reviewer. |
| AC5 | Import a row with null `Brand`, such as `Cable Organizer Kit`. | The row remains pending review, even if the name and category match or no candidate exists. |
| AC6 | Import the same `(SellerName, Id)` twice with `Câmera` versus `Camera`, then rerun the file. | The equivalent normalized identity produces one seller association and no duplicate review decision. |
| AC7 | Reuse an existing `(SellerName, Id)` with materially changed identity fields. | The old association is not silently changed; the row enters review. |
| AC8 | A second ID from one seller would link to a product that seller already offers. | The row enters review; the reviewer chooses which ID remains, and the database never contains both associations. |
| AC9 | A complete row has no credible existing candidate. | Exactly one product and seller association are created atomically. SQL-like text in a field is stored as data and cannot execute. |
| AC10 | An incomplete or invalid row occurs between valid rows. | Invalid required fields yield a failed row; missing brand/category yields review; later valid rows still import. |
| AC11 | The reviewer approves, rejects, corrects, or resolves a conflict, then reruns the same input. | The decision is recorded, reflected in catalog associations, and preserved across reruns. |
| AC12 | Two listings differ only by a material variant attribute such as color or capacity. | They are not automatically linked to the same `Product`. |

## 10. Delivery expectations and known trade-offs

The take-home delivery should include the importer, schema migration, local review screen, concise setup/run instructions, and tests covering the acceptance scenarios. A demo should show the import summary, at least one automatic link, one new product, and one resolved review case.

This policy deliberately favors review over a false automatic link. Candidate search can still miss an unusual paraphrase and create a duplicate; that limitation should be stated in the submission, along with examples that were reviewed and the rationale for the candidate threshold. The required web screen and persistent review queue are extensions chosen for this PRD beyond the assignment's minimal create-or-link behavior.

## 11. Assignment context

The assignment PDF allows database changes and AI assistance, and emphasizes reasoning and problem understanding over production scale. It states a 48-hour submission window and asks for a public GitHub or GitLab repository link in reply to the assessment email. Those are submission constraints for the candidate, not actions requested by this PRD.

The PDF also refers to a separate Guideline Document for code structure, naming, and documentation. That document has not been supplied here, so this PRD does not assume its contents.
