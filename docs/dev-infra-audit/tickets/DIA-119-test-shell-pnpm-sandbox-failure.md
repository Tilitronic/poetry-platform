# DIA-119 - make test-shell exit 2 - verify-pre-push bats pnpm sandbox failure (test 187 ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND)

<!-- Filed from session observation (2026-08-12). `make test-shell` exits 2
     because the verify-pre-push bats suite fails test 187 with
     ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND (pnpm sandbox failure). Confirmed
     identical on pristine HEAD - NOT caused by DIA-100/DIA-117/DIA-118.
     Pre-existing infra issue. Planning ticket only - no implementation
     performed. -->

---

id: DIA-119
title: "make test-shell exit 2 - verify-pre-push bats pnpm sandbox failure (test 187 ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND)"
area: dev-infra
severity: Low
status: FIXED
blocked_by: [] # no blockers
discovered: 2026-08-12
source: session-observation (pre-existing, confirmed on pristine HEAD, 2026-08-12)
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00a01b8b1ffe5t0J9OnsRbo9Zm"
lane_id: ""
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-119-test-shell-pnpm-sandbox-failure.md"]
artifacts: []
evidence: []

---

## Description

`make test-shell` exits 2 because the verify-pre-push bats suite fails test
187 with `ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND` (pnpm sandbox failure). The
error indicates pnpm could not find an importer manifest (package.json /
pnpm-workspace.yaml) in the sandbox directory the test creates.

Confirmed identical on pristine HEAD - NOT caused by DIA-100/DIA-117/DIA-118
(the worktree lifecycle and config changes did not touch the verify-pre-push
test or the pnpm sandbox setup). This is a pre-existing infra issue that
pre-dates the current campaign's work.

Impact: `make test-shell` (the host-side shell test gate, `make test-shell`
bats, docker mocked) cannot pass as a whole, which weakens the shell-gate
signal even though the worktrees.bats suite itself passes 16/16 (T1-T16)
independently.

Candidate fix path: investigate the pnpm sandbox setup in the verify-pre-push
bats test (missing package.json / importer manifest in the sandbox dir? wrong
working directory? env not carried into the sandbox?), fix the sandbox setup,
or document as known-failing with an exclusion so `make test-shell` can pass
while the suite is in that state.

**Reference files:** `scripts/verify-pre-push.sh` (or the bats file covering
the verify-pre-push flow - grep `ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND` and
`pnpm` under `tests/` / `scripts/`); `Makefile` `test-shell` target.

## Verification

- Reproduce: run `make test-shell` from the repo root; confirm exit 2 and the
  test 187 failure with `ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND`.
- Confirm pre-existing: run the same on pristine HEAD (e.g. `git stash` +
  `git checkout HEAD -- .` or a clean clone at HEAD) and confirm identical
  failure.
- Confirm worktrees.bats isolation: run only the worktrees suite and confirm
  T1-T16 pass 16/16.
- After fix:
  1. `make test-shell` full suite exits 0 (or the failing test is documented
     as known-failing with an exclusion, and the rest of the suite passes).
  2. No regression in the worktrees.bats 16/16 result.

## Fix

> Implemented 2026-08-12 in commit `02141f6` (fix(dev-infra): DIA-119 seed
> pnpm/npx sandbox manifests in bats tests). Developer disposition: FIX BOTH
> TESTS.

Root cause (validated by the investigation lane, reproduced byte-for-byte in
the leak scenario): the verify-pre-push bats test 4 ("runs steps directly when
already inside the dev container") is the only test invoking pnpm directly. Its
only defense against the REAL pnpm shadowing its fake is a temp-HOME export
(`export HOME="$BATS_TEST_TMPDIR/home"`). When the login shell (`bash -lc` in
run_workspace) resolves the real HOME, the host `~/.profile` prepends
`$VOLTA_HOME/bin`, the real pnpm runs in the EMPTY temp sandbox
(`$POETRY_WORKSPACE` has no package.json) and emits
ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND. Failure is INTERMITTENT
(environment-dependent HOME breach). NOT a store/cache race, NOT test-ordering.

Fix: seed the sandbox so the outcome no longer depends on which pnpm/npx
resolves.

Files changed:

- `scripts/__tests__/verify-pre-push.bats` (test 4): seed
  `$POETRY_WORKSPACE/package.json` with a `verify-pre-push-sandbox` importer
  manifest plus the four verify scripts (`verify:format`, `verify:js`,
  `verify:js-tests`, `verify:python`), each logging to `$PNPM_LOG` exactly like
  the fake pnpm.
- `scripts/__tests__/verify-pre-commit.bats` (test 4, symmetric fix): seed
  `$POETRY_WORKSPACE/package.json` (`verify-pre-commit-sandbox`) plus a local
  `node_modules/.bin/lint-staged` stub logging to `$NPX_LOG` exactly like the
  fake npx. Real npx resolves binaries from `node_modules/.bin` first, so the
  leak path runs the stub instead of fetching/ENOENT'ing real lint-staged.

Test results (after fix):

- `make test-shell`: exit 0, 209/209 passed.
- Isolated `verify-pre-push.bats`: 7/7 passed.
- Isolated `verify-pre-commit.bats`: 7/7 passed.
- `worktrees.bats`: 16/16 (T1-T16) passed.

Leak-scenario proof (positive regression, real tool wins):

- Command: sed-copy of each FIXED test file with the temp-HOME guard line
  removed, then run with HOME forced to the real home:
  `HOME=/home/qualt scripts/__tests__/vendor/bats-core/bin/bats --filter
"runs steps directly" <copy>` (pre-push) and `--filter "runs lint-staged
directly" <copy>` (pre-commit). This forces the login shell to source the
  real `~/.profile`, which prepends `$VOLTA_HOME/bin` so the REAL pnpm/npx
  resolves instead of the fake.
- Before fix: pre-push test 4 FAILED with `ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND
No package.json ... was found in "/tmp/bats-run-*/test/1/ws"`; pre-commit
  test 4 FAILED with real lint-staged "Current directory is not a git
  directory!" (exit 1).
- After fix: BOTH PASS — the real pnpm finds the seeded package.json and the
  real npx resolves the seeded local lint-staged stub from node_modules/.bin.

Docker gate (DIA-094): poetry-dev container up (healthy) before commit; husky
pre-commit hook passed (delegated autofix, exit 0).

## Re-verify

> Two-axis review findings F2/S1/S2 (all developer-accepted) resolved
> 2026-08-12 in commit `cdeb708` (fix(dev-infra): DIA-119 review findings F2
> S1 S2). F2: the seeded node_modules/.bin/lint-staged stub now logs via "$\*"
> (command name rebuilt from $0, since real npx strips it) so hook-arg drift is
> detected; leak-scenario spot check (HOME=/home/qualt, temp-HOME guard line
> removed) still passes for both the pre-commit and pre-push suites. S1: the
> dead scripts.lint-staged entry was removed from the seeded package.json
> (minimal importer skeleton kept). S2: the 3-stage escape chain in the seeded
> verify-pre-push package.json is now documented. Status stays FIXED.
> Re-verify evidence: make test-shell exit 0, 209/209; isolated
> verify-pre-commit 7/7, verify-pre-push 7/7, worktrees 16/16.
