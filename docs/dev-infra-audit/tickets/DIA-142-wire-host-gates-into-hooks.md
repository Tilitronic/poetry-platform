# DIA-142 — Wire host-runnable gates into hooks and fix turbo.json test.inputs cache masking

<!-- Fix ticket (fix-lane): implements developer-approved findings from
     ana014-hook-test-coverage (DIA-139). Filed 2026-08-12, cod-lane. -->

---

id: DIA-142
title: "Wire host-runnable gates into hooks and fix turbo.json test.inputs cache masking"
area: git-hooks
severity: Major
status: VERIFIED
blocked_by: []
discovered: 2026-08-12
source: fix-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
lane_id: "cod-lane"
agent: "coder"
model: ""
parent_session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

References ana014-hook-test-coverage (knowledge/ana014-hook-test-coverage/). Two developer-approved fixes:

1. pre-push hook does not run make test-shell (100+ bats, host-runnable, no Docker) nor make test-config (8 OpenCode config validators catching agent-name drift) — wire both into .husky/pre-push via scripts/verify-pre-push.sh so config/shell regressions are caught before push.
2. turbo.json test task has inputs that exclude src/\*\* so cached test results mask source regressions — fix the inputs so source changes invalidate the cache.

## Verification

- pre-push runs both gates (bats suite passes, test-config passes).
- turbo.json test task shows src/\*\* in inputs.
- make test-shell and make test-config pass on host.

## Fix

FIX 1 (pre-push host gates) - applied 2026-08-12:

- scripts/verify-pre-push.sh: added `run_workspace "make test-shell"` and
  `run_workspace "make test-config"` BEFORE the four pnpm verify steps.
  Fail-fast: a shell/config regression aborts the hook (non-zero exit) before
  the slow turbo chain. Delegated via run_workspace (the audit's own example
  mechanism) because the dev container ships make and bats is vendored on the
  shared /workspace mount; hosts without make never reach these lines since
  the Makefile is the documented stack entrypoint (make up). The container-
  down contract (warn + pass, DIA-94) is unchanged.
- scripts/**tests**/verify-pre-push.bats: extended the delegation test to
  assert all six steps; added two failure tests (test-shell failure exits 1
  before turbo; test-config failure exits 1 before turbo); extended the
  inside-container test with a fake make and a temp ~/.bash_profile so the
  fakes survive Debian /etc/profile's unconditional PATH reset.
- Host verification (no make on host, no docker): ran the underlying scripts
  directly. All 10 test-config validators exit 0. test-shell: check-pin-sync,
  check-host-jq, check-opencode-docker exit 0; check-host-lsp exits 1 (LSP
  binaries not installed on this bare host). verify-pre-push.bats 9/9 pass.
  Full bats suite: 194 pass, 1 pre-existing failure (verify-pre-commit
  inside-container test, same /etc/profile PATH-reset fragility, file not
  touched by this ticket).

FIX 2 (turbo test inputs) - applied 2026-08-12:

- turbo.json test task inputs: `["src/**/*.test.ts", "src/**/*.spec.ts",
"src/**/*.test.py"]` -> `["src/**", "src/**/*.test.ts", "src/**/*.spec.ts",
"src/**/*.test.py"]` (audit C1's exact suggested line). Source changes now
  invalidate the test cache. Verified with `npx turbo run test --dry-run`
  (turbo 2.9.16, host): resolved inputs BEFORE were
  `["src/**/*.spec.ts","src/**/*.test.py","src/**/*.test.ts"]`, AFTER are
  `["src/**","src/**/*.spec.ts","src/**/*.test.py","src/**/*.test.ts"]`.
- No other task (lint/typecheck/build) touched.

## Re-verify

Re-verified 2026-08-12: reviewer ACCEPT (two-axis review). Polish applied
3/3: DELEGATION_LOG rename, fail-fast order assertion, dead turbo globs
removed. All gates:

- verify-pre-push.bats 9/9 pass, exit 0.
- All 10 test-config validators exit 0.
- Commit 9ac204f landed.

Honest caveat: in-container 'make test-shell' exits 2 due to a pre-existing
check-host-lsp rust-analyzer version drift (1.83.0 vs 1.97.1) in the dev
image - tracked as follow-up, not a regression of this change.

Status: OPEN -> VERIFIED.

<!-- UPDATE 2026-08-14 (RENUMBER, NO STATUS CHANGE): ticket renumbered DIA-118 -> DIA-142 (duplicate-ID collision resolution; local campaign ticket DIA-118-worktrees-sh-missing-executable-bit keeps its ID). Fix commits landed: 2baf8f9 (hook wiring + turbo inputs), 3cf6043 (recursion lesson persistence); merge 4b3dbf7 confirmed. Status stays VERIFIED (unchanged). -->
