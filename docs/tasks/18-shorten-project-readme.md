# T18: Shorten the project README

Status, sequencing gate, PR, and current blocker live in [the index](README.md). This documentation task follows merged T17.

## Outcome and boundaries

Make the root README a roughly 250–350-word quick start while preserving its original content verbatim in a second root-level Markdown file. Keep the existing application behavior, supplied reference inputs, and final QA state unchanged. The user chose a quick-start emphasis and an exact copy of the original guide.

## Required context

- [T17 merge record and final QA handoff](17-export-current-catalog-as-sqlite.md#final-qa-handoff).
- The original root README, its links to `docs/`, and task links back to root README headings.
- [Implementation quality gates](quality-gates.md) and [task workflow](README.md#working-a-task).

## Deliverables and acceptance checks

- [x] Preserve the original README byte-for-byte as `README-full.md` at the repository root, so its relative links keep their targets.
- [x] Replace `README.md` with a 250–350-word quick start covering purpose, Docker setup, reference loading, import/review, export, and development checks. Link prominently to the full guide and to the task index.
- [x] Keep the `Requirements and setup` anchor used by T17 and provide the `Load the reference catalog` anchor referenced by T02.
- [x] Verify the archived copy, Markdown links and headings, and the required Docker CI gate; record actual results below.
- [ ] Submit one reviewed PR under the manual task workflow. Mark this task done only after verifying its merge.

## Current checkpoint

- Completed: confirmed T17 merge commit `b0034e8` is an ancestor of this checkout; committed the guide and quick start as `7729245` on `codex/t18-short-readme`; checked links, headings, and local Markdown rendering; and passed the full Docker CI gate in an isolated Compose project.
- Remaining: obtain explicit authorization for the GitHub destination after the automatic approval review rejected the branch push; then open a PR for human review and verify its merge before marking T18 done.
- Next action: wait for the user's explicit answer about pushing this branch to `dccunha/CatalogConsolidation`.

## Problems

- **T18-P01 — 2026-09-30:** Two runs of `docker compose run --rm web bin/ci` in the default Compose project stopped during RSpec after 66 progress dots with exit 143 and no test failure report. A later direct RSpec attempt found `sqlite3-2.9.6` missing from the shared `catalog-consolidation:development` image and could not install it as the container user. An isolated Compose project with image `catalog-consolidation:t18-readme` built from this checkout passed the full gate. The cause of the default project's termination was not established; the isolated passing run is the validation evidence for this candidate.
- **T18-P02 — 2026-09-30:** Automatic approval review twice rejected `git push -u origin codex/t18-short-readme`, even after confirming the configured remote matched prior PR records and the signed-in GitHub account. The reviewer said the GitHub destination's trust and ownership were not established by trusted user content and that the user had not explicitly authorized that destination. No push or PR occurred. The user must explicitly authorize this repository as the publishing destination before retrying.

## Decisions

- **T18-D01 — 2026-09-30:** Keep `README.md` as the main quick-start entry point and preserve its original bytes in root-level `README-full.md`. The user explicitly chose an exact copy. Root placement keeps the full guide's relative paths valid.
- **T18-D02 — 2026-09-30:** Focus the short README on setup and the basic workflow. The user chose quick start as the primary audience path.

## Validation evidence

- **2026-09-30, documentation candidate commit `7729245` based on `6ca77c7`:** `README-full.md` and `git show 6ca77c7:README.md` both have SHA-256 `027cee7de9c2a05584908ec1142d99915d656bccc5eaf2176b121cf4340a121c`; the copy is byte-identical. The new README is 296 words.
- A local check resolved all 31 Markdown links and anchors in `README.md`, `README-full.md`, and this brief. It covered the T17 `#requirements-and-setup` and T02 `#load-the-reference-catalog` targets. Ruby's local RDoc Markdown renderer produced headings, code blocks, and links as expected; its HTML output was inspected. `git diff --check` passed.
- `docker compose -f docker-compose.yml -f /tmp/t18-readme-compose.yml -p t18_readme run --build --rm web bin/ci` passed with exit 0. The temporary override gave the web image the unique tag `catalog-consolidation:t18-readme`; all application checks remained those in `bin/ci`. RSpec: 248 examples, 0 failures; Ruby line coverage 98.94%, branch coverage 87.32%. Vitest: 1 file and 1 test passed, with 100% statements, branches, functions, and lines. Ruby/ERB/JavaScript lint, Sorbet and RBI freshness, audits, database checks, and seeds passed. The test run preceded only this evidence/checkpoint update; application and README content did not change afterward.
- No application behavior or concept Ruby file changed, so no new behavior spec or Sorbet annotation was added. Human PR review and merge remain outstanding.

## Handoff

The root README provides setup and workflow entry points; `README-full.md` retains the original detail and existing relative links. No application interface, database, PRD/RFC, or reference input changed. The isolated full Docker CI run passed. Human PR review and verified merge remain required before the index can mark T18 done.
