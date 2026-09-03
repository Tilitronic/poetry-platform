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
status: CLOSED
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
attempts: 1
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-121-bats-version-drift-wrapper-vendor.md", "scripts/__tests__/bats-wrapper.sh", "scripts/__tests__/check-bats-vendor-drift.sh", "scripts/__tests__/check-bats-vendor-drift.bats"]
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

Fixed 2026-08-12 via commit `548a93a` (fix(dev-infra): DIA-121 re-pin bats
wrapper to v1.14.0 + add vendor drift check).

Developer decision: accept v1.14.0 as the new baseline (the suite passes with
it) and add drift re-validation. Combination of candidate fix 1 + 2.

1. `scripts/__tests__/bats-wrapper.sh`:
   - Added `BATS_VENDOR_VERSION="1.14.0"` as the single source of truth for
     the pinned version (package.json format, no leading "v").
   - Re-pinned the vendor clone: `git clone --depth 1 --branch
"v${BATS_VENDOR_VERSION}" ...` (was hardcoded `--branch v1.11.0`).
   - Added a drift re-validation block at wrapper start: when the vendor dir
     exists, `bash scripts/__tests__/check-bats-vendor-drift.sh
"$BATS_VENDOR_VERSION" "$VENDOR_DIR" || true` runs. On mismatch the
     check prints a stderr warning and exits 1; the wrapper deliberately
     does NOT propagate the exit (warn-and-continue, documented in a
     comment: a drift is a hygiene issue, not a blocker - re-cloning would
     be destructive/network-dependent and hard-failing would lock
     developers out of `make test-shell`).
   - Added the new script to the `bash -n` syntax-check loop.
2. `scripts/__tests__/check-bats-vendor-drift.sh` (new): compares the
   vendored `package.json` `version` field against the pin constant. Uses
   package.json (not `git describe`) because the shallow `--depth 1
--branch` clone has no tags, so `git describe` fails. Exit 0 on match or
   absent vendor dir; exit 1 + stderr warning on mismatch or unverifiable
   checkout; exit 2 on usage error.
3. `scripts/__tests__/check-bats-vendor-drift.bats` (new): 7 hermetic unit
   tests (match passes / positive control: v1.11.0 pin vs v1.14.0 vendor
   detected / vendor upgrade past pin detected / absent dir silent / missing
   package.json warned / usage error / wrapper wiring guard).

The git-ignored vendor dir was NOT re-cloned or modified (already v1.14.0);
no changes outside `scripts/__tests__/` and this ticket file.

## Re-verify

Re-verified 2026-08-12 (commit `548a93a`):

- `make test-shell` exits 0: 216 tests, 0 failures (exit code 0).
- Individual suites not regressed: worktrees.bats 16/16,
  verify-pre-push.bats 7/7, verify-pre-commit.bats 7/7.
- New drift-check suite passes: 7/7 (tests 24-30 in the full run).
- Drift reproduction (consistent state after fix):
  - wrapper pin `BATS_VENDOR_VERSION="1.14.0"` (bats-wrapper.sh line 28)
    vs vendored `"version": "1.14.0"` (vendor/bats-core/package.json) ->
    consistent.
  - `bash scripts/__tests__/check-bats-vendor-drift.sh 1.14.0
scripts/__tests__/vendor/bats-core` exits 0, silent.
  - Positive control: `... 1.11.0 ...` exits 1 and warns "vendored bats
    version mismatch: ... is at v1.14.0 but bats-wrapper.sh pins v1.11.0".
  - Wrapper start on the consistent state produces no drift warnings on
    stderr and exits 0.
- Vendor dir left untouched (still the git-ignored v1.14.0 checkout).

Re-verified 2026-08-12, review-findings round (S3 - execution evidence appended;
FAL-1/FAL-2/FAL-3 added 3 tests, suite 7 -> 10):

`make test-shell` exit 0 (full run, host-side; vendored bats
`scripts/__tests__/vendor/bats-core/bin/bats`), plan `1..219`, 219 ok / 0 not ok:

```
$ make test-shell
bash scripts/check-pin-sync.sh
summary: 4 ok, 0 fail
bash scripts/check-host-jq.sh
summary: 1 ok, 0 fail
bash scripts/check-host-lsp.sh
summary: 3 ok, 0 fail, 0 skip
bash scripts/check-opencode-docker.sh
ok: required subproject files present
ok: shell artifacts pass bash -n
ok: bootstrap.py parses (AST)
ok: config/opencode.json is valid JSON
ok: subproject Makefile declares build/run/shell/clean
ok: tools/opencode-docker static integrity passed
bash scripts/__tests__/bats-wrapper.sh
ok: shell syntax (bash -n) passed for all scripts under test
ok: node --check passed for scripts/context7-docs.mjs
ok: using vendored bats: .../vendor/bats-core/bin/bats
1..219
ok 24 drift check passes when vendored version matches the pin
ok 25 drift check detects the original v1.11.0 pin against a v1.14.0 vendor tree (DIA-121 positive control)
ok 26 drift check detects a vendor upgrade past the current pin
ok 27 drift check reads the TOP-LEVEL version even when a nested object has a version field first (FAL-1)
ok 28 drift check is silent when the vendor dir does not exist
ok 29 drift check warns when the vendor dir lacks package.json
ok 30 drift check rejects missing arguments with a usage error
ok 31 wrapper wiring: bats-wrapper.sh invokes the drift check with the pin constant
ok 32 wrapper wiring end-to-end: drifted vendor emits the drift warning (FAL-2 positive control)
ok 33 wrapper wiring end-to-end: consistent vendor emits no drift warning (FAL-2 negative control)
...
ok 186 verify-pre-commit: delegates lint-staged to the dev container when on the host
ok 187 verify-pre-commit: passes --allow-empty so empty commits are not blocked
ok 188 verify-pre-commit: blocks the commit when the dev container is down
ok 189 verify-pre-commit: runs lint-staged directly when already inside the dev container
ok 190 verify-pre-commit: delegates a workspace path with spaces as one cd argument
ok 191 verify-pre-commit: blocks the hook when a .opencode/commands file contains literal /home/qualt
ok 192 verify-pre-commit: passes when no .opencode/commands file contains literal /home/qualt
ok 193 verify-pre-push: skips with a warning when the dev container is not running
ok 194 verify-pre-push: delegates every verification step to the dev container
ok 195 verify-pre-push: aborts (exit 1) when a delegated step fails
ok 196 verify-pre-push: runs steps directly when already inside the dev container
ok 197 verify-pre-push: delegates a workspace path with spaces as one cd argument
ok 198 verify-pre-push: blocks the push when a .opencode/commands file contains literal /home/qualt
ok 199 verify-pre-push: passes when no .opencode/commands file contains literal /home/qualt
ok 204 worktrees: T1 create -> exit 0 + worktree dir + branch + isolated .opencode/session
...
ok 219 worktrees: T16 list forwards args to git worktree list (--porcelain works)
$ echo $?
0
```

Suite tallies in the 219-run: drift-check suite 10/10 (tests 24-33, +3 from the
review round), verify-pre-commit.bats 7/7 (186-192), verify-pre-push.bats 7/7
(193-199), worktrees.bats 16/16 (204-219).

YAML frontmatter validator: `python3 -c "import yaml; yaml.safe_load(...)"` on
the `---`-delimited block - parses OK; `files_touched` 4 entries (all
`scripts/__tests__/` paths), `artifacts: []` / `evidence: []` are top-level
keys.

**Re-verify (re-review cycle 1/2, 2026-08-12): CLOSED.** All 5 developer-accepted
findings verified-closed with evidence:

- S1 (frontmatter `files_touched` prettier stability) - verified-closed via commit
  `66139dd` (`fix(dev-infra): DIA-121 S1 frontmatter - prettier-stable inline
files_touched (S2 untouched)`); YAML frontmatter re-validated, byte-identical
  after prettier.
- S3 (execution evidence appended) - verified-closed via commit `3d7ebd8`
  (full `make test-shell` run transcript recorded in this ticket).
- FAL-1 / FAL-2 / FAL-3 (3 drift-check tests added, suite 7 -> 10) -
  verified-closed via commit `3d7ebd8`; suite now 10/10 (tests 24-33).
- Re-review evidence: `make test-shell` exit 0 - plan `1..219`, 219 ok / 0 not
  ok (host-side, vendored bats `scripts/__tests__/vendor/bats-core/bin/bats`).
- Status transitioned FIXED -> CLOSED (re-review cycle 1/2 passed; no residual
  findings).
