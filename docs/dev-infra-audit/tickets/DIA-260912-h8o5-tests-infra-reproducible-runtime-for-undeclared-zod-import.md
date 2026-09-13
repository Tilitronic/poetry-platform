# DIA-260912-h8o5 - tests-infra: reproducible runtime for undeclared zod import

---

id: DIA-260912-h8o5
title: "tests-infra: reproducible runtime for undeclared zod import"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-12
source: inventory
date: 2026-09-12
created: 2026-09-12
updated: 2026-09-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence:

- commit:2b0945a
- test:clean-worktree-frozen-install-red-replay

---

## Description

The reference OMO package's focused lifecycle tests import Zod at runtime, but
the package did not declare a reproducible test-owned Zod dependency. A clean
worktree therefore failed during module resolution before the committed RED-B
assertions could execute, blocking the separate GREEN lane for
DIA-260827-95fv.

## Verification

- [x] The package exact-pins development Zod 4.3.6 while retaining peer
      compatibility `^4.0.0`.
- [x] A Bun-generated lockfile resolves the exact pin with frozen install.
- [x] `test:red-b` targets only the two lifecycle seams that own the integrated
      RED commits; it does not run unrelated package tests.
- [x] The focused run reaches assertion bodies and contains the named
      `return-channel-pending` mismatch with no Zod resolution error.
- [x] The manifest and lockfile are committed, then the same receipt is
      reproduced from a disposable clean worktree.

## Fix

Added the exact `zod: 4.3.6` development pin, retained the `zod: ^4.0.0` peer
range, generated `bun.lock`, and added a narrow `test:red-b` package script.
No production or lifecycle assertion was changed. Because `.opencode` ignores
generic package artifacts, the manifest and lockfile must be staged explicitly
with `git add -f` for the isolated ticket commit.

## Re-verify

- `bun install --frozen-lockfile`: exit 0, 395 installs/398 packages, no
  changes; Zod resolves.
- `bun run test:red-b`: expected exit 1, 56 pass / 5 fail. Both
  `return-channel-pending` assertion mismatches execute; the three tombstone
  RED assertions also execute; no module-resolution error appears.
- Disposable worktree at commit `2b0945a`: frozen install exit 0; focused RED
  exit 1 with 56 pass / 5 expected fail; named pending/tombstone evidence
  present; zero Zod resolution errors; worktree removed successfully.
