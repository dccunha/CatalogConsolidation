# T15: Prepare delivery and demo

Status, sequencing gate, PR, and current blocker live in [the index](README.md).

## Outcome and boundaries

Make the completed local application easy to run, evaluate, and explain using verified setup instructions and a reproducible demonstration. Close delivery documentation after T14 validates behavior. Exclude publishing/deploying the application, emailing the assessment, changing reference inputs, or claiming completion with unresolved acceptance failures.

## Required context

- [T14 acceptance handoff](14-acceptance-journeys.md#handoff) and [index evidence](README.md#acceptance-coverage).
- [PRD delivery expectations](../prds/catalog-consolidation-importer.md#10-delivery-expectations-and-known-trade-offs) and [assignment context](../prds/catalog-consolidation-importer.md#11-assignment-context).
- [RFC threshold rationale](../rfcs/0001-import-review-lifecycle.md#matching-and-candidate-evidence).
- Existing [README](../../README.md); follow T02/T09/T10 handoff links only for commands/configuration not already documented there.

## Deliverables and acceptance checks

- [ ] Update the README from foundation-only status to the verified application: Docker setup, migration/reference loading, browser upload, reviewer configuration, review workflow, and test commands.
- [ ] Rehearse instructions in an isolated clean local/test environment without deleting the user's existing database or altering the reference files.
- [ ] Document a short repeatable demo showing import summary, a known automatic link, a new product, and an explicitly resolved review case, followed by an unchanged rerun preserving that decision.
- [ ] Include useful screenshots of the finished UI and explain how to reach each demonstrated state. Use separate demo fixtures when needed; keep supplied references unchanged.
- [ ] Explain the conservative matching policy, the 0.80 review threshold, observed misses/limitations, material-variant handling, and PostgreSQL's deliberate replacement of the assignment's SQLite output target.
- [ ] Link PRD/RFC/ADR and acceptance evidence; report any outstanding problems honestly. Update milestone/status records based on verified merges only.
- [ ] Run final required checks, verify documentation commands and links, and prepare the final review handoff. T15 becomes `done` only after its own PR merge is verified and recorded.

## Current checkpoint

- Completed: task brief only.
- Remaining: runbook/demo, screenshots, final validation, and delivery review.
- Next action: inspect T14's verified evidence and identify the minimal reproducible demo sequence.

## Problems

None recorded. The separate assignment Guideline Document remains unavailable unless supplied later; do not claim compliance with its unknown contents.

## Decisions

None recorded. Record demo fixture/scenario choices and observed limitations. The agreed target is full PRD scope, with no separately imposed submission deadline or authorization to submit externally.

## Validation evidence

Not run. Record the clean-environment rehearsal, demo sequence, screenshots, documentation-link checks, and final CI results.

## Handoff

Not implemented. Publish concise run/demo commands, final evidence links, limitations, and PR/commit references. Record the final merge in the index afterward; no further implementation task should be implied unless explicitly listed as a follow-up.
