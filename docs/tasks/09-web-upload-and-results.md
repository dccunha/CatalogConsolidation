# T09: Add web upload and batch results

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Let a local user upload the seller JSON and inspect batch summaries and row outcomes in the browser. Use synchronous processing and a clear, modestly styled Rails interface. Support AC1/AC10 visibility; exclude background jobs, seller-import CLI, authentication, and review actions.

## Required context

- [T08 importer handoff](08-reruns-and-source-identity.md#handoff), [T07 runner contract](07-import-processing.md#handoff), and [T01 Rails integration](01-concepts-and-catalog-persistence.md#handoff).
- [PRD output](../prds/catalog-consolidation-importer.md#8-import-output).
- [Agreed delivery choices](README.md#agreed-delivery-choices) and [ADR layout](../adrs/0001-organize-by-concepts.md#decision).
- Existing [routes](../../config/routes.rb) and [application layout](../../app/views/layouts/application.html.erb).

## Deliverables and acceptance checks

- [ ] Add Intake-owned upload and batch-result pages with a discoverable application entry point.
- [ ] Submit the uploaded content to the existing importer synchronously. Show clear errors for missing, malformed, or non-array input and a results page for valid arrays containing individual failures.
- [ ] Show batch identity and reconciled totals, plus row numbers, seller keys, outcomes, product/case IDs, and reasons. Render source text safely, including HTML-like and quoted values.
- [ ] Provide navigation to recorded batches/results. Only link to implemented routes; show review-case IDs until T10 supplies case pages.
- [ ] Retain persisted row audit data after request completion. Keep upload handling limited to this local demonstration rather than adding file-management infrastructure.
- [ ] Add request/form journey tests for successful upload, invalid file, mixed row outcomes, and reupload. Add browser-runtime support inside Docker if the chosen interaction tests require it.
- [ ] Verify readable labels, validation messages, empty states, and keyboard form use. Include screenshots and update the local run instructions.

## Current checkpoint

- Completed: task brief only.
- Remaining: upload/results UI, tests, and screenshots.
- Next action: inspect the integrated importer contract and concept view lookup.

## Problems

None recorded. The foundation has Capybara/Selenium dependencies but no configured browser runtime; inspect before choosing the necessary journey-test setup.

## Decisions

The user chose web upload and a simple Rails UI; synchronous processing is the agreed starting default. Record routes, form behavior, and any test-runtime setup when implemented.

## Validation evidence

Not run. Record request/journey specs, manual browser scenarios, screenshots, and CI results.

## Handoff

Not implemented. Publish routes, result queries, upload/error behavior, view conventions, and the browser-test command for T10–T14. Note where case IDs become links in T10.
