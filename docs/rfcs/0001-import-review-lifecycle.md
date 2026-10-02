# RFC 0001: Import and review lifecycle

- **Status:** Accepted
- **Date:** 29 September 2026
- **Relates to:** [Catalog consolidation PRD](../prds/catalog-consolidation-importer.md) and [ADR 0001: Organize by concepts](../adrs/0001-organize-by-concepts.md)

## Purpose

The PRD defines the safe matching policy and review capabilities, while ADR 0001 assigns Catalog and Intake ownership. This RFC settles the identity, rerun, candidate, and review-state decisions needed to break that behavior into implementation tasks. It does not prescribe table columns, Rails service signatures, or the review screen's layout.

## Seller identity and row outcomes

The seller item key is the exact supplied `(SellerName, Id)` pair. Validate both as nonempty strings after trimming for the emptiness check, but preserve their supplied values for the key and audit record. Do not case-fold the seller name or parse, normalize, or coerce `Id`; `MegaStore` and `megastore` are distinct keys. Only `Name`, `Brand`, and `Category` are normalized for comparison. Missing and blank `Brand` or `Category` both count as absent. Validate any supplied field even when it is excluded from product matching.

Every element of a valid JSON array gets a batch row result, including repeated occurrences and invalid rows. A result records its source position, original values, outcome, reason, and applicable product or review-case reference. Batch totals count row results, so they always reconcile to the array length. The import-time result remains an audit of that run; the linked review case can later show its current decision.

For each valid seller key, Intake tracks the active source identity: the normalized `(Name, Brand, Category)` tuple from the latest accepted or pending version. This is a comparison identity, not a replacement for the original input. Within a file and across reruns:

| Incoming row | Result |
| --- | --- |
| Same key and identity as an active pending case | Record another pending row result pointing to that case; do not open a second case. |
| Same key and identity as a linked, created, or resolved version | Record **already imported** with the existing product or decision and make no Catalog write. A displaced or declined ID remains unlinked, with that reason visible. |
| Same key with materially changed identity | Open a new pending case and leave any current association untouched. Supersede an older pending case so only the latest version is actionable; retain its history. |
| No valid key because a required field is invalid | Record a failed row and continue with later rows. |

The active source identity remains the **original source tuple** when a reviewer corrects metadata. An unchanged rerun therefore reuses the review decision instead of mistaking the uncorrected file for a new change. Matching choices are not part of that identity: changing them alone does not reprocess an unchanged seller row. A later source tuple that differs from the active one requires review under its new batch's choices, even if it resembles an older historical version; an old decision must not silently restore an association. Accent and whitespace differences covered by normalization do not constitute a material change. These rules cover [AC1, AC6, AC7, AC10, AC11, and AC14](../prds/catalog-consolidation-importer.md#9-acceptance-criteria).

## Matching and candidate evidence

Normalize comparison text with Unicode case folding, removal of diacritics, trimming, and collapse of internal whitespace. Preserve punctuation, numbers, units, model tokens, and variant words. Each seller-file upload independently selects whether `Brand` and `Category` participate in product matching; both default to selected, preserving the original policy. Persist the choices with the batch and use them throughout any later case review. Previously stored batches use both-selected behavior. `Name` always participates. An ignored field cannot make a match exact, break an exact match, affect candidate ranking, or require review merely because it is absent. Its source and catalog values remain visible as evidence, and supplied source values are retained when creating a product.

Exact automatic linking requires **one** product whose normalized `Name` and all selected fields equal the row's values, no other credible candidate, and a valid seller/product uniqueness check. An ignored-field difference does not block that link. Multiple exact or other credible candidates, a missing or conflicting selected field, or a seller listing conflict go to review. A row with no credible candidate may be created automatically only when all selected fields are present and it has never entered review. Missing ignored fields do not block that outcome.

For review candidates, include a product when its normalized name is identical regardless of brand or category. Otherwise, require name similarity of at least **0.80** and, only when Brand is selected, an equal nonblank normalized brand. When Brand is ignored, near-name candidates remain visible regardless of Brand or Category, even if Category is selected. Similarity is `1 - LevenshteinDistance(a, b) / max(length(a), length(b))`, measured over Unicode characters of the normalized names. Rank candidates by descending similarity, then matching selected brand, then matching selected category, then ascending `Product.Id`; ignored fields cannot break ties. Candidate rank never authorizes a link. Retain and show the score, original and normalized fields, differing values, and which fields were ignored so a reviewer can explain the choice.

The PRD's 0.85 threshold was a starting point. Against the supplied reference products, normalized `Roteador WiFi 6 TP-Link` and `Router WiFi 6 TP-Link` score about **0.826** by this formula: 0.85 would miss that plausible duplicate, while 0.80 includes it. The same sample has no extra multiple-candidate rows at 0.80 compared with 0.85 under the original both-selected policy; other matching choices may produce more candidates. This is a conservative candidate **review** threshold, not an automatic-link threshold. A capacity or color difference can appear as a candidate but cannot pass the exact-name automatic-link rule. Document observed misses as a limitation rather than silently lowering the automatic-link bar. These rules cover [AC2–AC5, AC9, AC12, and AC14](../prds/catalog-consolidation-importer.md#9-acceptance-criteria).

## Review lifecycle

A case begins **pending** with the original input, normalized evidence, reason, ranked candidates, and any conflicting seller association. Its batch retains the matching choices for every candidate refresh, correction, and final decision. Rejections record the reviewer, time, and reason individually and expose the next candidate. Corrections save reviewer-supplied fields separately from the original input and rerun matching under those retained choices; the case remains in review. Once a row enters review, neither a correction nor a rematch can automatically link or create a product, even when the corrected row has one exact match or no candidate.

Before a new row can enter matching or review, Intake rejects `;`, `--`, `/*`, `*/`, or Unicode control characters in `Id`, `SellerName`, `Name`, `Brand`, or `Category`. It records a **Failed** result and the full original JSON in Intake, with no seller item or case and no Catalog write. Such a row needs a corrected new import. Ordinary apostrophes and product punctuation remain allowed. `Catalog::Public::Writes` applies the rule again to new caller-supplied strings. Existing target-product fields are not inspected when linking or reassigning. This is a defined control-syntax filter; all Catalog text remains untrusted to downstream systems.

An older pending case containing newly prohibited text remains readable. Its unsafe comparison cannot drive a Catalog decision. A reviewer can correct Name, Brand, or Category when those are the only unsafe fields; an unsafe Id or SellerName requires a corrected new import. Rejected unsafe correction attempts leave the case unchanged.

The reviewer finishes a case by explicitly approving a candidate, choosing the surviving ID in a same-seller listing conflict, or confirming creation of a new product for a row complete under its retained matching choices after all credible candidates are rejected. A row missing a selected field cannot be created. Every final decision records the reviewer, decision, time, reason where applicable, resulting product, and any displaced seller ID. Keeping the existing ID resolves the incoming ID as declined; reruns of that unchanged incoming row report the retained decision rather than relinking it. Replacing an ID records the displaced ID, whose unchanged reruns likewise cannot restore it.

Before a final link, reassignment, or creation, recheck current Catalog data, candidates, and uniqueness. Previously rejected candidates stay rejected. If a new credible candidate has appeared since the last review, return the case to pending and show that candidate before allowing creation. If other evidence has gone stale or a constraint would be violated, leave the case pending with updated evidence and a visible reason. Catalog product/association writes and the corresponding review decision must commit atomically. Existing product attributes are never changed by an approval. These transitions cover [AC7, AC8, and AC11](../prds/catalog-consolidation-importer.md#9-acceptance-criteria).

Rejection and creation are separate reviewer actions. The case becomes ready for explicit creation after the last rejection; rejection alone never writes a product.

## Persistence and ownership contract

Intake persists a batch with its matching choices and one row result per input element, at most one active review case per seller key, original and corrected values, candidate evidence, and an append-only decision history. Historical and superseded cases remain auditable. Catalog owns products and seller associations; Intake requests all Catalog writes through `Catalog::Public`, as required by ADR 0001. PostgreSQL remains the application database, and `catalog.db` remains an unchanged reference input.

Catalog must enforce unique `(SellerName, SellerProductId)` and `(SellerName, ProductId)` associations and the `ProductId` foreign key. A row's catalog write is atomic; failure leaves no partial product or association and does not stop later rows in a valid file. The physical schema and public-operation signatures belong to the implementation tasks.

## Examples to verify during implementation

| Sequence | Expected behavior | PRD criteria |
| --- | --- | --- |
| Import an exact row twice, including `Câmera`/`Camera` or whitespace-only name differences | First row may link; later equivalent rows are already imported. One association and no duplicate case. | AC2, AC6 |
| Import an uncertain row, then rerun it before and after resolution | Rerun shares the pending case; after resolution it reports the retained decision without another Catalog write. | AC3–AC5, AC11 |
| Correct metadata, then find one exact match or no candidate | Keep the case pending until explicit approval or creation, respectively. Original input remains visible. | AC5, AC11 |
| Reject all shown candidates, then another import creates a credible product before final creation | Keep earlier rejections; show the new candidate and require another reviewer decision before creating. | AC11 |
| Reuse a seller key with a changed identity | Open review; preserve the current association until an atomic decision. | AC7 |
| Offer one product under two IDs from the same seller | Review chooses the surviving ID; the displaced or declined ID cannot silently return on rerun. | AC8, AC11 |
| Present otherwise similar `128GB` and `256GB` items | Never automatically link them to one product; show a credible near match for review when the rule finds one. | AC12 |
| Ignore Brand, Category, or both for a batch | Match on Name and selected fields only; preserve ignored source values, show the retained choices, and review other credible candidates before creation. | AC14 |
| Rerun an unchanged seller row with different matching choices, then revisit an earlier pending case | Retain the prior row outcome and use the case's original batch choices for refreshed evidence and final decisions. | AC6, AC11, AC14 |
