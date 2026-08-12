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
status: OPEN
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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
