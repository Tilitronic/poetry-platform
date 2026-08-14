# DIA-168 - test infra Phase 1: de-duplication (bats helpers, it.each, bash -n auto-discovery, per-package dependsOn)

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-125 collided with origin/omo-slim-changes ticket DIA-149-test-infra-phase1-dedup.md (different ticket). Renumbered to DIA-168. This ticket duplicates remote DIA-149-test-infra-phase1-dedup.md (same work, renumbered on the remote lineage via bab080c); SUPERSEDED by the remote ticket. -->

<!-- Ticket 2 of 4 from the approved test-refactoring plan (reviewed with
     mandatory corrections incorporated). Phase 1 - De-duplication. Blocks
     nothing. -->

---

id: DIA-168
title: "test infra Phase 1: de-duplication (bats helpers, it.each, bash -n auto-discovery, per-package dependsOn)"
area: tests-infra
severity: Medium
status: OPEN
blocked_by: []
discovered:
source: baseline
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Phase 1 of the approved test-refactoring plan: remove duplicated test helper
code and hand-maintained lists; replace with shared, auto-discovered
mechanisms. Net-negative line count at the same pass rate.

### 1. Extract duplicated bats setup helpers into test-helper.bash

The hermetic host-context setup block (fake hostname on PATH +
POETRY_COMMANDS_DIR isolation) and the `mock_docker_down` fake-docker helper
are duplicated across bats suites:

- `scripts/__tests__/verify-pre-commit.bats` setup() lines ~17-36
- `scripts/__tests__/verify-pre-push.bats` setup() lines ~16-36
- `scripts/__tests__/check-host-jq.bats` (per plan; implementation note:
  `mock_docker_down` currently also exists in `check-host-lsp.bats` lines
  ~82-96 and `eval-lite.bats` lines ~39-54 — consolidate ALL copies)

Extract `setup_hermetic_host_context` and `mock_docker_down` into
`scripts/__tests__/test-helper.bash` (which suites already `load test-helper`)
and update each suite to call the shared helpers. Verify all suites still
pass 1:1 (same test count, same pass rate) with the duplication removed.

### 2. Parameterize punctuation tests with it.each (MANDATORY CORRECTION applied)

In `packages/editor-engine/src/view/opusFormattingFilter.test.ts` (double
punctuation describe block, lines ~523-675):

- Convert to `it.each` ONLY the 12 genuinely-parameterizable punctuation
  tests: 6 `allows single <punct>` (comma, colon, semicolon, hyphen, English
  apostrophe, Ukrainian apostrophe) + 6 `blocks double <punct>` (same six).
- **MANDATORY CORRECTION (from review):** the 2 `blocks triple` tests (triple
  comma, triple hyphen) and the 7 `collapses ... on paste` tests are
  structurally different — do NOT force them into `it.each`. Leave them as
  standalone tests.

### 3. Auto-discover bash -n syntax-check list (with exclusion escape hatch)

`scripts/__tests__/bats-wrapper.sh` lines ~20-46 currently hard-maintains a
25-entry list of shell scripts fed to `bash -n`. Replace the hand-maintained
list with `find ... | xargs bash -n` auto-discovery over the scripts
directories, with a documented exclusion-list escape hatch (for files that
must NOT be syntax-checked, e.g. deliberately non-bash or generated files).
New scripts get syntax-checked for free; no list maintenance.

### 4. Remove test-task build dependency PER-PACKAGE (MANDATORY CORRECTION applied)

`turbo.json` test task (line ~22) has `"dependsOn": ["build"]` for ALL
packages. **MANDATORY CORRECTION (from review):** removal must be
PER-PACKAGE — only packages whose tests do NOT need build output get the
override; packages whose tests consume build artifacts (dist output) must
keep `dependsOn: ["build"]`. Not a blanket removal.

Approach: per-package `turbo.json` overrides (e.g. a package-level
`turbo.json` with `"test": { "dependsOn": [] }`) or an explicit package list
in the root config — whichever mechanism the codebase already supports —
applied only to packages verified to not need build output for their tests.

## Verification

Acceptance criteria (all must hold):

- [ ] `setup_hermetic_host_context` and `mock_docker_down` defined once in
      test-helper.bash; no duplicated bodies remain in the bats suites.
- [ ] Full bats suite (`make test-shell`) passes with identical test count
      and pass rate before/after.
- [ ] Exactly 12 punctuation tests converted to `it.each`; the 2 blocks-triple
      and 7 collapse-on-paste tests remain standalone (their titles and
      bodies unchanged in substance).
- [ ] `bats-wrapper.sh` has no hand-maintained script list; `bash -n` runs
      over auto-discovered scripts; exclusion list documented and honored;
      adding a new plain script requires no wrapper edit.
- [ ] `dependsOn: ["build"]` removed from the test task ONLY for packages
      that do not need build output; packages whose tests consume build
      artifacts still depend on build; turbo test still green.
- [ ] Net negative line count across the touched files.

Per AGENTS.md 2.3.1, handoff must include verification evidence: exit codes

- summary lines for `make test-shell`, `pnpm test` (editor-engine), turbo
  test, plus a before/after line count for the touched files.

## Fix

Applied 2026-08-12, landed in commit 570055e (branch omo-slim-changes):

1. `scripts/__tests__/test-helper.bash`: extracted the shared
   `mock_docker_down` fake-docker helper and `setup_hermetic_host_context`
   (fake hostname on PATH + POETRY_COMMANDS_DIR isolation) — the duplicated
   setup blocks and local `mock_docker_down` copies removed from the suites.
2. `scripts/__tests__/verify-pre-commit.bats` (-10) and
   `scripts/__tests__/verify-pre-push.bats` (-11) now call
   `setup_hermetic_host_context` from test-helper; local
   `mock_docker_down` deleted from `check-host-lsp.bats` (-15) and
   `eval-lite.bats` (-18).
3. `packages/editor-engine/src/view/opusFormattingFilter.test.ts` (-46):
   exactly 12 punctuation tests converted to two `it.each` blocks (6
   `allows single <punct>` + 6 `blocks double <punct>`); the 2
   `blocks triple` and 7 `collapses ... on paste` tests left standalone per
   the mandatory correction.
4. `scripts/__tests__/bats-wrapper.sh` (-2): the 25-entry hand-maintained
   script list replaced with `find -print0` auto-discovery over `scripts/`,
   `.opencode/scripts/`, and the root `dev-entrypoint.sh`, with a
   `BASH_N_EXCLUDE` escape hatch. 9 previously-unlisted scripts now get
   `bash -n` checked.
5. `turbo.json` (+18): base `test.dependsOn: ["build"]` KEPT; per-package
   `dependsOn: []` overrides applied only to the 4 empirically-verified
   packages whose tests do not consume build output.

Verification evidence (exit codes + summary lines):

- `make test-shell` (in dev container): exit 0. 212 ok / 0 not ok;
  git-stash A/B identical 212/0 before vs after.
- `pnpm test` (turbo): exit 0. "Tasks: 4 successful, 4 total"; no build
  phase ran.
- editor-engine vitest: 91 passed (91) — count unchanged by the `it.each`
  conversion; `--reporter=verbose` titles identical before/after.
- editor-engine lint (`eslint .`) exit 0; `tsc --noEmit` exit 0.
- `bash -n` clean on bats-wrapper, test-helper, and all 9 newly-discovered
  scripts.
- `make test-config`: 24 passed / 0 failed (bats portion); 11 recipe steps
  exit 0 individually (compose step run on host — see deviation note).

Deviations from ticket (flagged, not silent):

- `make test-config` full recipe not run as one target: `make` is
  unavailable on the host and the recipe mixes host-only steps (docker
  compose) with container steps; the 11 steps were run individually with
  the compose step on the host (exit 0), consistent with the DIA-167 note
  on the make/docker CLI split. Container run confirmed the docker compose
  step is the only host-dependent one.

## Re-verify

> To be filled at re-verify time.
