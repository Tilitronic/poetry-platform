# DIA-121 - bats-wrapper.sh claims v1.11.0 but vendored bats is v1.14.0 - version drift

<!-- Filed from session observation (DIA-119 investigation lane, 2026-08-12).
     While investigating the DIA-119 pnpm sandbox failure (make test-shell
     exit 2, verify-pre-push test 187), the off-by-one between the failing
     test number observed (186) and the ticket number (187) pointed at a
     possible bats-version discrepancy. Inspecting scripts/__tests__/
     bats-wrapper.sh line 65 shows the clone is pinned to tag v1.11.0, but
     the git-ignored vendor dir scripts/__tests__/vendor/bats-core was
     observed at version 1.14.0 (package.json version field) with a HEAD
     commit not on the v1.11.0 tag. The vendor dir is never re-validated
     against the pin. Planning ticket only - no implementation performed. -->

---

id: DIA-121
title: "bats-wrapper.sh claims v1.11.0 but vendored bats is v1.14.0 - version drift"
area: dev-infra
severity: Low
status: OPEN
blocked_by: [] # no blockers
discovered: 2026-08-12
source: session-observation (DIA-119 investigation lane, 2026-08-12)
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
files_touched: ["docs/dev-infra-audit/tickets/DIA-121-bats-version-drift-wrapper-vendor.md"]
artifacts: []
evidence: []

---

## Description

`scripts/__tests__/bats-wrapper.sh` line 65 pins the vendor clone to a tag
(claims v1.11.0), but the git-ignored vendor dir
(`scripts/__tests__/vendor/bats-core`) was cloned with a different tag
(observed v1.14.0 - the `package.json` `version` field reads `1.14.0` and
the shallow HEAD commit is not on the v1.11.0 tag) and is never
re-validated. The wrapper's pin comment claims v1.11.0 and the clone
command uses `--branch v1.11.0`, so a fresh clone SHOULD land on v1.11.0;
the observed vendor state proves a machine can end up on a different
version (e.g., a re-clone, a manual clone, or a checkout drift) with no
detection.

Bats-version drift across machines can shift test numbering (bats changes
test-order/numbering and runner behavior between minor releases). This
likely explains DIA-119's off-by-one: the failing test was observed as
test 186 while the ticket recorded test 187. It is also a hygiene gap: the
pinned tag is only enforced at first-clone time, and only when a system
bats is absent - once the vendor dir exists, the pin is never checked
again.

Impact: Low (the suite still runs; numbering/reporting may shift and
version-sensitive behavior may differ between machines). No active
failure was observed beyond the DIA-119 off-by-one signal.

Candidate fix (choose one, verify with `make test-shell`):

1. Re-validate the vendor dir against the pinned tag inside the wrapper (or
   a `make test-shell` pre-check target): e.g. read the tag from
   `vendor/bats-core/package.json` (or `git -C "$VENDOR_DIR" describe
--tags` / `rev-parse`) and warn or re-clone when it does not match
   v1.11.0.
2. Re-pin the wrapper to the actual vendored version (v1.14.0) if the
   drift is accepted as the new baseline, keeping the pin and the vendored
   state consistent.

**Reference files:** `scripts/__tests__/bats-wrapper.sh` (line 65 pin;
lines 59-68 vendor logic); `scripts/__tests__/vendor/bats-core/package.json`
(git-ignored, observed version 1.14.0); `.gitignore` line 63
(`scripts/__tests__/vendor/`); `Makefile` `test-shell` target.

## Verification

- Reproduce the drift: compare the wrapper pin vs the vendored state -
  `sed -n '62,65p' scripts/__tests__/bats-wrapper.sh` (claims v1.11.0) vs
  `grep '"version"' scripts/__tests__/vendor/bats-core/package.json`
  (observed v1.14.0), and/or `git -C scripts/__tests__/vendor/bats-core
describe --tags` (no tag resolves on the shallow clone - HEAD commit
  ae4b94d is not on v1.11.0).
- Design a validation: define the drift check (e.g., read the version from
  `vendor/bats-core/package.json` and compare against the pin constant in
  the wrapper, or check `git -C "$VENDOR_DIR" rev-parse` against the
  pinned ref) and where it runs (wrapper start or a `make test-shell`
  pre-check target).
- After fix:
  1. The drift check reports a mismatch when the vendor version differs
     from the pin (positive control: temporarily point the pin at a
     different tag and confirm detection).
  2. `make test-shell` passes (exit 0) on a consistent vendor state.
  3. No regression in the individual suites (worktrees.bats 16/16,
     verify-pre-push.bats 7/7, verify-pre-commit.bats 7/7).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
