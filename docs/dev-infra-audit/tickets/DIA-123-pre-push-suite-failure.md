# DIA-123 - pre-push blocked: make test-shell fails inside hook (unshare 127 + guard-flag interaction suspicion)

<!-- Docs-lane ticket filed 2026-08-12 after a push attempt was blocked by the
     husky pre-push hook following the DIA-122 commit. Two distinct suspects
     recorded; root-cause not yet determined. -->

---

id: DIA-123
title: "pre-push blocked: make test-shell fails inside hook (unshare 127 + guard-flag interaction suspicion)"
area: git-hooks
severity: Critical
status: VERIFIED
blocked_by: []
discovered: 2026-08-12
source: test-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: "docs-lane"
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

git push blocked by the husky pre-push hook: verify-pre-push.sh ->
make test-shell failed with exit 1. Output tail: ok 209..211
(worktrees), then BW01 warning "run's command 'unshare -r -m bash
/tmp/bats-run-MTVv9v/test/81/ns.sh bash
/workspace/dev-entrypoint.sh' exited with code 127 (Command not
found)" in dev-entrypoint.bats test 81 (via test-helper.bash
run_entrypoint_ns line 391, dev-entrypoint.bats line 108), then make
Error 1, husky code 2.

Two suspicions, possibly independent:

- Suspicion A (guard-flag inheritance): DIA-122's fix exports
  VERIFY_PRE_PUSH_RUNNING=1 before the workspace gates; when the hook
  triggers the suite, all bats tests inherit the flag.
  verify-pre-push.bats tests (183-191) invoke verify-pre-push.sh
  directly and would hit the new top-of-script guard (warning + exit
  0), breaking assertions. DIA-122's verification ran the suite
  standalone (no flag) - 211/211 - which would NOT catch this.
- Suspicion B (unshare 127): separate suspect - dev-entrypoint.bats
  test 81 unshare command not found; may be a pre-existing env gap or
  container-image issue, unrelated to the guard flag.

Related: DIA-122 (recursion guard fix - suspicion that inherited
VERIFY_PRE_PUSH_RUNNING=1 breaks verify-pre-push.bats tests 183-191),
DIA-071 (pre-existing env-gate push blocker).

## Verification

- Reproduce the suite run WITH VERIFY_PRE_PUSH_RUNNING=1 set vs
  standalone (unset); compare pass/fail counts.
- Identify the exact failing test numbers under the hook-exact
  environment.
- Confirm whether dev-entrypoint.bats test 81 fails independently of
  the flag (unshare 127 root cause).

## Fix

> To be filled at fix time.

## Re-verify

- Fix commit: d6c6a64 (unset VERIFY_PRE_PUSH_RUNNING in verify-pre-push.bats
  setup() + new guard test asserting the guard fires).
- Hook-exact verification: VERIFY_PRE_PUSH_RUNNING=1 make test-shell ->
  212/212, exit 0.
- Standalone verification: make test-shell -> 212/212, exit 0.
- Pre-commit hook: PASS.
- Re-review: all findings verified-closed (commit d6c6a64).
- Secondary finding: the unshare 127 warning in the original push failure was a
  transient race (storm-kill `rm -rf /tmp/bats-run-*` deleted an active suite's
  ns.sh between creation and exec), NOT a code/image gap.
