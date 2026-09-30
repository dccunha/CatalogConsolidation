# T08: Preserve identity and decisions across reruns

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Complete importer behavior for repeated, changed, pending, and resolved seller identities within a file and across runs. Own AC6/AC7 and the importer side of AC11. Exclude reviewer commands and UI; later tasks create the decisions whose replay behavior is established here.

## Required context

- [T07 importer](07-import-processing.md#handoff), [T06 persistence](06-intake-persistence.md#handoff), and [T04 normalization](04-row-validation-and-normalization.md#handoff).
- [RFC seller identity table](../rfcs/0001-import-review-lifecycle.md#seller-identity-and-row-outcomes) and [verification sequences](../rfcs/0001-import-review-lifecycle.md#examples-to-verify-during-implementation).
- [PRD AC6/AC7/AC11](../prds/catalog-consolidation-importer.md#9-acceptance-criteria).

## Deliverables and acceptance checks

- [ ] Same key/identity with an active pending case yields another pending row result pointing to the same case, with no new case or Catalog write.
- [ ] Same key/identity already linked, created, or resolved yields already imported with the retained product/decision and reason. Declined/displaced IDs remain unlinked.
- [ ] A material source change opens a new pending case, preserves any current association, and supersedes the old pending version. Only the latest version remains actionable.
- [ ] Compare against the active original source tuple after reviewer correction. A historical identity returning later is a new change, not permission to restore an old association.
- [ ] Test accent/whitespace equivalents, repeated keys in one array, pending reruns, resolved reruns, correction reruns, multiple successive changes, and historical reversion.
- [ ] Use explicit persisted fixtures for review decisions until T11–T13 provide commands; record this boundary. Those tasks and T14 must repeat journeys using real decision operations.
- [ ] Run the supplied array through the service and verify 269 outcomes per run and no duplicate associations/cases for equivalent repeats, without prescribing category totals.

## Current checkpoint

- Completed: task brief only.
- Remaining: active-identity rules, sequence tests, and supplied-file verification.
- Next action: inspect T07's row flow and T06's active-version representation.

## Problems

None recorded.

## Decisions

None recorded. Source identity, supersession, and retained decisions are RFC requirements. Record implementation-specific lookup and transaction choices.

## Validation evidence

Not run. Record sequence specs, supplied-array/rerun results, and CI. Distinguish fixture-based decision replay from actual reviewer-command coverage.

## Handoff

Not implemented. Publish the identity/rerun contract and passing sequence tests for T09–T13. Document how review commands must resolve, supersede, or displace versions without changing original source identity.
