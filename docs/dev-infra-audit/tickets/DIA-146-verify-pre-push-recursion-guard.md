# DIA-146 - verify-pre-push recursion fork-bomb: root-cause fix (DIA-142 regression)

<!-- Fix ticket (fix-lane): root-cause fix for a recursion fork-bomb in
     scripts/verify-pre-push.sh introduced by commit 49d587a (DIA-142).
     Filed 2026-08-12, docs-lane. Fix committed 2026-08-12 (commits
     431b602/000f7e6/0760ef3/b3d86ad); two-axis review complete (rev-1:
     0 findings on both axes). Status VERIFIED. -->

---

id: DIA-146
title: "verify-pre-push recursion fork-bomb: root-cause fix (DIA-142 regression)"
area: git-hooks
severity: Critical
status: VERIFIED
blocked_by: []
discovered: 2026-08-12
source: fix-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0096fb3b3ffegmLnMLGu76QdMX"
lane_id: "docs-lane"
agent: "coder"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

A recursion fork-bomb ran inside poetry-dev: verify-pre-push.sh ->
make test-shell -> bats -> the same verify-pre-push test -> infinite.

Root cause: commit 49d587a (DIA-142) wired `make test-shell` into
scripts/verify-pre-push.sh. When the script is invoked inside the dev
container (hostname == poetry-dev, direct branch at line 68), it runs
`make test-shell`, which re-enters the full bats suite, which re-runs the
same verify-pre-push test, which invokes the script again, which runs
`make test-shell` again: unbounded recursion.

Evidence from the live incident:

- Nested process chains 6+ levels deep:
  bats-exec-suite -> bats-exec-file -> bats-exec-test ->
  verify-pre-push.sh -> make test-shell -> bats ...
- Dozens of /tmp/bats-run-\* dirs created every ~18s, all dying at the
  same test.
- Live processes still spawning after 1.5h (required a host-side storm
  kill; see Re-verify).

Root-cause detail: the test-side hostname shim (fake hostname ->
"host-machine", added in commit bb18099) protects the bats suite, but is
insufficient alone: it does not protect manual/husky invocations and is
a test-side patch. The script itself had no re-entrancy guard.

Related: DIA-142 (regression source), DIA-71 (env gates).

## Verification

- In a clean environment (no VERIFY_PRE_PUSH_RUNNING set), run
  `scripts/verify-pre-push.sh` inside poetry-dev (hostname ==
  poetry-dev). Pre-fix behavior: unbounded recursion
  (verify-pre-push.sh -> make test-shell -> bats -> same test -> ...),
  accumulating /tmp/bats-run-\* dirs every ~18s.
- Post-fix behavior: top-of-script guard fires - warning printed, exit 0,
  no gates run - when the flag is already set; nested invocations no
  longer recurse.
- `make test-shell` must pass (full bats suite) and the single-file
  verify-pre-push.bats suite must pass 9/9.

## Fix

Applied 2026-08-12, uncommitted (working tree):

1. scripts/verify-pre-push.sh: env-flag propagation guard
   VERIFY_PRE_PUSH_RUNNING - top-of-script guard (warn + exit 0 if the
   flag is set), then `export VERIFY_PRE_PUSH_RUNNING=1` before the six
   workspace gates. Any nested re-entry (via make test-shell -> bats or
   manual invocation) sees the flag, warns, and exits 0 without running
   the gates, breaking the recursion at the first hop.
2. scripts/tests/verify-pre-push.bats test #6 (direct-run test):
   `unset VERIFY_PRE_PUSH_RUNNING` so the test's own invocation does not
   inherit the guard flag from a guarded parent environment and stays a
   genuine direct-run test.

Design validated by the analysis report
knowledge/ana015-recursion-fork-bomb/ana015-recursion-fork-bomb-report.md.

## Re-verify

Re-verified 2026-08-12 (fix-time verification; two-axis review complete):

- Single-file verify-pre-push.bats: 9/9 pass, exit 0.
- Full `make test-shell`: 211/211 ok, exit 0.
- Guard fires correctly on nested invocation: warning printed, exit 0,
  no gates run.
- Zero /tmp/bats-run-\* dirs after runs; no stray processes after runs.
- Storm kill of the pre-fix incident: pkill chain executed from the
  host; verified dead (0 survivors, 0 bats-run dirs, load decaying
  0.74/1.88/2.47, 7 threads).

Review (two-axis, rev-1): 0 findings on Standards axis, 0 findings on
Spec-fidelity axis. All verification passed (above). Fixes committed
2026-08-12: 431b602 (ana015 root-cause analysis), 000f7e6 (ticket),
0760ef3 (guard fix), b3d86ad (memory/lesson persistence).

Status: VERIFIED.

<!-- UPDATE 2026-08-14 (RENUMBER, NO STATUS CHANGE): ticket renumbered DIA-122 -> DIA-146 (duplicate-ID collision resolution; local campaign ticket DIA-122-needs-input-ticker keeps its ID). Fix commit 8a385c0 ('fix(hooks): guard verify-pre-push against recursion fork-bomb (DIA-122)') exists in git log; merge 4b3dbf7 confirmed. Status stays VERIFIED (unchanged). -->
