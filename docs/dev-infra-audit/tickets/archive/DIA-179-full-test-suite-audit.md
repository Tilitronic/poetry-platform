# DIA-179 — Full test-suite audit: execution order, fast-to-fail, duplicates, stale tests, verification honesty, DRY helpers

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-139 collided with origin/omo-slim-changes ticket DIA-139-hook-test-coverage-audit.md (different ticket). Renumbered to DIA-179. -->

---

id: DIA-179
title: "Full test-suite audit: execution order, fast-to-fail, duplicates, stale tests, verification honesty, DRY helpers"
area: tests-infra
severity: Medium
status: DONE
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: baseline
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fff77a14effezT82MKtHSrdJre" # OpenCode session ID that owned this ticket
lane_id: "ana-1" # e.g. cod-1, ai--3
agent: "analyzer" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "ses_fff77a14effezT82MKtHSrdJre" # orchestrator's session ID
attempts: 1 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["knowledge/ana021-test-suite-audit/ana021-test-suite-audit-report.md", ".opencode/memory-shelf.yaml"] # list of file paths modified
artifacts: ["knowledge/ana021-test-suite-audit/ana021-test-suite-audit-report.md"] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Requested by the developer as a scheduled follow-up (explicitly "next year" —
planned for 2027): a full, cross-cutting audit of EVERY test the project
currently has for the dev setup, not just one area. Prior test work was
piecemeal (DIA-158 hook coverage, DIA-167..170 test-infra phases); this is the
holistic pass over the whole test surface.

Audit questions, verbatim from the request:

1. **Execution order** — is the order in which tests run optimal? (e.g. turbo
   pipeline / Makefile gate order: host gates vs container gates, pre-commit
   vs pre-push, per-package dependsOn)
2. **Fast-to-fail** — do we have a fast-to-fail approach? i.e. the cheapest,
   fastest tests run first so a broken tree fails in seconds, not after a long
   suite.
3. **Duplicated tests** — same behavior asserted in multiple places/files.
4. **Outdated tests** — tests that no longer match current behavior, pin stale
   versions, or test removed features.
5. **Unnecessary tests** — tests that add no signal (redundant, tautological,
   or covering nothing real).
6. **Verification honesty** — do tests REALLY verify the behavior they claim,
   or do they fake/imitate verification? (e.g. empty assertions, always-pass
   mocks, checking implementation instead of behavior, tests that never run in
   any gate.)
7. **Fixes needed** — concrete list of corrections.
8. **Optimizations / DRY helpers** — shared helpers, fixtures, or utilities to
   stop repeating ourselves across test files (bats helpers, it.each,
   conftest, test factories), and any ordering/parallelization wins.

## Verification

- Inventory every test artifact in the repo: `make test-*` targets, `scripts/*`,
  turbo tasks (`turbo.json`), bats suites (`tests/` or `scripts/**/*.bats`),
  pytest suites, vitest/jest in author-studio, pre-commit/pre-push hooks
  (`.husky/`), CI config if present.
- Map the actual execution order: `make test-config` → `make test-shell` →
  `make test-python` → `make test-infra` (and hook wiring per DIA-161), plus
  turbo pipeline `dependsOn`.
- For each test: does it assert real behavior? grep for empty assertions,
  tautological checks, mocked-only paths, skipped tests, `TODO` tests.
- Cross-check for duplicates: same fixture/assertion across `.bats` files,
  `test_*.py`, `*.test.ts`.
- Produce knowledge/ana021-test-suite-audit/ana021-test-suite-audit-report.md
  with categorized findings: ORDER / FAST-TO-FAIL / DUPLICATE / STALE /
  UNNECESSARY / FAKE-VERIFICATION / FIX / DRY-HELPER + rationale and concrete
  fix suggestion for each.

## Fix

Audit completed 2026-08-14 (analyzer lane ana-1). Report:
knowledge/ana021-test-suite-audit/ana021-test-suite-audit-report.md (451 lines,
registered in memory-shelf.yaml under shelf.analyses).

Inventory: 409 tests total - 240 bats (scripts/**tests**, make test-shell,
24.6s), 43 node:test batch-d-infra (make test-config, 0.3s), 218 vitest
(author-studio + data-contracts/editor-engine/phonetics-core via turbo test),
2 pytest (api-server + analytics-pipeline).

Key findings (full list in report):

- F-1 [High] pre-push runs slowest gate (make test-shell, 24.6s) FIRST - reorder so format/typecheck run first (TTF 32s -> 1.2s)
- F-2 [Medium] turbo.json base test task inherits dependsOn:["build"] - new packages get slow tests by default; flip the default
- F-3 [Low] test-infra rebuilds the Docker stack twice per run
- F-4 [Medium] bats monolith (240 tests in one pass) has no quick tier for shell iteration; add --quick mode
- F-6 [Low] /home/qualt regression guard byte-identical in both hook scripts and tested in both bats files - extract helper, dedup
- F-7 [Low] conftest.py (PEP 420 bootstrap) duplicated across api-server + analytics-pipeline
- F-9/F-10 [Clean] no tautological tests, no empty asserts, no always-pass mocks (DIA-167/168 cleanup verified)
- F-11/F-12 [Clean] example-store.test.ts and Python import smokes are honest scaffolds
- O-1 [Recommendation] no CI pipeline exists - pre-push is the only automated gate; consider GitHub Actions
- O-2 [Backlog] 4 packages have no tests at all (publishing-platform, stress-lang-core, visualizer-2d/3d)

Evidence gaps: make test-infra not run end-to-end (needs image rebuilds);
pytest runs executed manually in-container; no CI to audit.

Developer disposition pending: which findings become fix tickets.

> To be filled at fix time.

### Merge phase (2026-08-14, coder lane)

Merge gate evidence (DIA-174 item 6, `docker compose ps` before merges):

- poetry-dev: Up 3 hours, image poetry-platform-dev:latest, ports 3000/8000/9000
- poetry-postgres: Up 3 hours

Target branch: `omo-slim-changes`; contains spec commit 7e06002
(`git merge-base --is-ancestor 7e06002 HEAD` confirmed).

Merge order (strictly serial per DIA-172/174; B before C because both extend
`scripts/__tests__/batch-d-infra.test.mjs`). Squash-merges, no push:

1. slice B (F-2) -> `8e5e565` (squash of 1e9980e + 6cf2db9 + 8c55af8)
2. slice C (F-3) -> `5820d4e` (squash of fe22202 + 795750b + ecc614f + 4e17398)
3. slice A (F-1, F-6) -> `b4f8ed9` (squash of 7f44f65 + d86f3b6 + 5926ed3)
4. slice D (F-4) -> `8a1e152` (squash of 585285c + 2d29257 + f998514 + e2a8c9c)
5. slice F (F-7) -> `354a681` (squash of 9796123 + 5e73a94 + c50ad9a)

Conflict resolution (batch-d-infra.test.mjs, merge 2 of slice C): expected
conflict - both sides appended after the S3 block. Resolved manually keeping
BOTH describe blocks (S4 from slice C, S5 from slice B); file header section
list updated to include both (5. slice C, 6. slice B). No other conflicts.

Extra merge-phase fix: slice D committed `scripts/__tests__/bats-wrapper.sh`
as mode 100644, but the lint-staged `*.sh` entry execs it directly
(`bats-wrapper.sh --quick <files>`), which EACCESed on a non-executable file.
Root-cause fix folded into the slice D merge commit: mode changed
100644 => 100755.

Per-merge gates (all exit 0):

- after B: `TEST_ROOT=/workspace node scripts/__tests__/batch-d-infra.test.mjs`
  -> 45 pass, 0 fail (baseline 43 + 2)
- after C: same suite -> 49 pass, 0 fail; S4/S5 blocks both present
  (dispatch estimate was 47; actual 49 because the S4 block carries 4 tests)
- after A: bats wrapper (test-shell) -> 256 pass, 0 fail; the 3 slice A files
  (guards-home-qualt 4 + verify-pre-commit 6 + verify-pre-push 10) = 20 ok
- after D: bats wrapper -> 259 pass, 0 fail, incl. bats-wrapper.bats 3/3
  (dispatch estimate was 243; actual 259, count reflects concurrent-lane
  worktree-cleanup tests present in the main tree)
- after F: pytest in dev container -> api-server 2 passed, analytics-pipeline
  2 passed (both include the new test_pythonpath_bootstrap.py; old conftest.py
  files deleted)

Aggregate gates (post all merges, target branch):

- make test-config recipe (host, run step-by-step; `make` exists only in the
  dev container and the container has no /workspace/node_modules, so the
  host-equivalent recipe was run): validate-agent-names.sh 0 (24 passed, 0
  failed), validate-output-contracts.sh 0, validate-reviewer-sections.sh 0,
  validate-handoff.sh 0, test-ticket-gate.sh 0, audit-agent-tool-coverage
  (.opencode/opencode.jsonc) 0, audit-agent-tool-coverage
  (tools/opencode-docker) 0, batch-d-infra suite 49 pass 0 fail -> recipe
  equivalent exit 0
- make test-shell (bats-wrapper.sh): 259 pass, 0 fail, exit 0
- bash scripts/validate-agent-names.sh: exit 0 (24 passed, 0 failed, 0 warnings)
- node --check scripts/**tests**/batch-d-infra.test.mjs: exit 0

Accepted deviations (reviewer-approved, per review re-verify cycle 1):

- Slice A: guard helper (scripts/guards/home-qualt.sh) output normalized to
  ASCII hyphens (DIA-079) per review findings S-2/P-2 - no em-dashes in guard
  error output.
- Slice D: --quick measured 5.11s on this machine vs the aspirational sub-3s;
  the acceptance band is 4.97-5.2s (<5s target), measured at the top edge.

Evidence gaps:

- make test-infra end-to-end not run (heavy path, needs image rebuilds;
  inherited from the audit phase)
- make test-config not run inside the container (container lacks
  /workspace/node_modules; host-equivalent recipe run instead, all steps 0)

Process notes:

- unrelated in-flight edits to DIA-177 worktree-cleanup files (worktrees.sh,
  worktrees.bats, openspec/worktree-branch-cleanup/\*) were present in the main
  tree during the merges (concurrent lane); left untouched and uncommitted by
  this lane, later committed by that lane as f9ab26c.
- pre-existing memory-file edits (.opencode/memory-shelf.yaml,
  .opencode/memory/lessons.md) stashed before merges and restored after; not
  committed.
- feature branches kept (rollback window per worktree-conventions); no push to
  target branch (DIA-096).

## Re-verify

> To be filled at re-verify time.
