# DIA-260927-w3og - re-review fix: strengthen the SIGPIPE regression test and de-ASCII its comments (RO-1/RO-2)

---

id: DIA-260927-w3og
title: "re-review fix: strengthen the SIGPIPE regression test and de-ASCII its comments (RO-1/RO-2)"
area: scripts
severity: Medium
status: VERIFIED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-27
source: inventory
date: 2026-09-27
created: 2026-09-27
updated: 2026-09-27

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
evidence: []

---

## Description

Origin: two-axis review findings on the validate-skills SIGPIPE work. The developer dispositioned both as ACCEPTED (not fixed); they had no ledger entry, only handoff prose - this ticket is that entry.

- RO-1 [Major]: the SIGPIPE regression test in scripts/**tests**/validate-skills.bats cannot fail if the production fix is reverted, for three independent reasons. Requirement: rewrite the test so it guards the real production path and genuinely fails when that path regresses.
- RO-2 [Minor]: raw UTF-8 Cyrillic in comments contradicts the test's own ASCII claim. Requirement: de-ASCII the comments in the same pass, with no behaviour change.

Sequencing: after both items land, dispatch review cycle 2/2 at the fixed point commit fd7e64e2, with exactly ONE FIXED_POINT marker in the re-review dispatch.

## Verification

- [x] reverse-verification proof: with the production fix reverted, the rewritten test FAILS (evidence: exact command plus its failing output)
- [x] the rewritten test PASSES with the fix present (evidence: bats run output plus exit code 0)
- [x] zero non-ASCII bytes remain in the touched test file (evidence: grep -P '[^\x00-\x7F]' on the file returns empty)
- [x] the three independent reasons the old test could not fail are enumerated in the Fix section
- [x] review cycle 2/2 recorded at fixed point fd7e64e2 with exactly one FIXED_POINT marker

## Fix

Scope: `scripts/__tests__/validate-skills.bats` only. Commit state (corrected
per re-review OBS-1): the RO-1/RO-2 changes ARE COMMITTED - they are part of
the reviewed artifact commit 7b3025f9 (review range: fixed point fd7e64e2 ..
7b3025f9). What lived only in the working tree was the reverse-verification
revert of the PRODUCTION script: `.opencode/scripts/validate-skills.sh` was
temporarily reverted during verification and then restored, ending at 0 diff
lines - that revert was never committed, and it was restored by direct edit
because `git checkout -- <path>` is permission-denied in this environment.
Line numbers below for the "old test" refer to the pre-edit file (blob
24d5265c, 1040 lines).

### RO-1: three independent reasons the old test could not fail

1. PART 1 never executed the production script. The pipe-to-head SIGPIPE
   demonstration ran the pipeline inside the TEST shell
   (`"$stubbin/bash" --version 2>/dev/null | head -n 1`, old bats:949) and was
   asserted by `[ "$pre_fix_rc" -eq 141 ]` (old bats:953). That assertion is
   about the stub plus the test's own pipeline; it holds with the production
   fix present AND with it reverted.
2. PART 2 never executed the production script either. The fixed in-shell
   extraction (`bash_line="${bash_line%%$'\n'*}"`) was re-implemented inside
   the TEST (old bats:960-961) and asserted on test-local state
   (`[[ "$post_fix_output" == *"5.1.0"* ]]`, old bats:965). Also independent
   of production state.
3. PART 3 DID run the real script (old bats:971-978) but its fixture came
   from `valid_skill` (old bats:63-73), which declares no `requires_bash:`
   field. The script consults the `bash --version` probe ONLY when a skill
   declares that floor (.opencode/scripts/validate-skills.sh:633-660); the
   empty-probe FAIL is `bash version unknown` at :648-649. With no
   declaration a reverted probe (:472-479) left `compat_bash_actual` empty and
   the script still exited 0, so `assert_status 0` (old bats:974) held.

Additional defect found while fixing (would have masked ANY PART 3 failure):
the old test ran `set +euo pipefail 2>/dev/null || true` after PART 1 and
PART 2 (old bats:952, 964), switching errexit OFF for everything after it.
bats runs tests with errexit ON and detects `assert_*` failures through it;
with errexit off the assertion messages print but the test still reports ok.
Reproduced during this fix: with the fixture already failing, bats printed
`assert_status: expected 0, got 1` and still reported `ok 1` (exit 0).

### What changed (RO-1)

- PART 1 kept as a FIXTURE SELF-CHECK, not a production guard: the stub must
  still produce exit 141 through pipe-to-head, otherwise the production
  assertion below would pass vacuously (current bats:960-976). It now toggles
  ONLY pipefail, only around the pipeline, and keeps the pipeline in a `||`
  list; errexit is never touched, so every later assertion really fails the
  test.
- PART 2 (the test-local re-implementation of the fix) deleted - it guarded
  nothing.
- New PART 2 = the PRODUCTION GUARD (current bats:978-1004): the real
  `.opencode/scripts/validate-skills.sh` with the SIGPIPE stub on PATH and a
  fixture that DECLARES `requires_bash: "4.0"` (current bats:988-996), the
  only consumer of the probe. Assertions: status 0, contains `ok:` /
  `passed`, not contains `FAIL:`, not contains `bash version unknown`.
  Reverted fix => probe dies with SIGPIPE inside the pipe => version unknown
  => FAIL => script exit 1 => `assert_status 0` fails.
- Header comment (current bats:904-921) documents the three reasons and the
  two-part shape.

### What changed (RO-2)

- All non-ASCII removed from the same file, comments only, no behaviour
  change: 11 em-dash comments replaced with `-`, and the 3 Cyrillic
  occurrences of the Ukrainian localized word for "version" transliterated to
  `versiya` (the stub still emits the real UTF-8 via the existing
  `\xd0\xb2...` printf byte escapes, unchanged).

### Reverse-verification (working tree only; the revert was never committed)

Revert state: `.opencode/scripts/validate-skills.sh` carried the uncommitted
revert of the production fix a9f4e20d (pipe-to-head form) - present in the
tree when this lane started, confirmed by
`git diff --stat -- .opencode/scripts/validate-skills.sh` ->
`1 insertion(+), 2 deletions(-)` (the exact fix hunk).

- OLD test, fix reverted: `scripts/__tests__/vendor/bats-core/bin/bats
--filter 'SIGPIPE' scripts/__tests__/validate-skills.bats` ->
  `ok 1 validate-skills: SIGPIPE ...`, EXIT=0 (proof of RO-1).
- REWRITTEN test, fix reverted (reverse verification): same command ->
  `not ok 1`, EXIT=1, key output:
  `assert_status: expected 0, got 1` and
  `FAIL: skill 'sigpipe-ok': requires_bash '4.0' cannot be satisfied, bash version unknown`.
- Fix restored: `git diff -- .opencode/scripts/validate-skills.sh` empty
  (0 diff lines; restored by direct edit because `git checkout -- <path>` is
  permission-denied in this environment), then same command ->
  `ok 1 validate-skills: SIGPIPE ...`, EXIT=0.

### Suites

- `bash scripts/__tests__/bats-wrapper.sh --filter validate-skills` -> exit 0
  (37/37 ok)
- `make test-shell` -> exit 0 (full suite green)
- `grep -P '[^\x00-\x7F]' scripts/__tests__/validate-skills.bats` -> empty,
  exit 1 (no non-ASCII bytes)

### Follow-up after re-review (three accepted-to-fix observations, this change)

- OBS-1: corrected the Scope/commit-state narrative above (committed artifact
  7b3025f9 vs the never-committed working-tree revert/restore of the
  production script at 0 diff lines).
- OBS-2 (PART 1 flakiness ceiling): the stub no longer races a 0.2s sleep. It
  writes line 1, waits for the pipe reader to actually close (select.poll
  POLLERR/POLLHUP on the write end, 1s hang-guard), and only then writes
  line 2, so the SIGPIPE-triggering write can never land before head closes;
  a false self-check fail would need head to hold the pipe open for >1s
  (it closes within milliseconds of reading line 1). Fixture self-check
  only, never a production claim.
- OBS-3 (pipefail restoration): PART 1 captures `[[ -o pipefail ]]` before
  toggling and restores exactly that prior state instead of unconditionally
  switching pipefail off.

## Re-verify

- Verdict: all-closed - both prior findings verified-closed:
  - RO-1 (test could not fail when the production fix is reverted):
    verified-closed.
  - RO-2 (non-ASCII Cyrillic in test comments): verified-closed.
- Fixed point: fd7e64e2.
- Reviewed artifact commit: 7b3025f9.
- Reviewing lane session id: ses_f1b2db65effeBqr5nL8NY1KCYZ.
- New observations from that re-review, developer disposition ACCEPTED TO FIX,
  all three landed in this change:
  - OBS-1 [Minor] ticket narrative drift ("nothing committed" vs the
    committed artifact) - fixed: Scope paragraph corrected above.
  - OBS-2 [Suggestion] PART 1 flakiness ceiling (0.2s sleep race could
    false-fail) - fixed: read-then-close handshake in the stub.
  - OBS-3 [Suggestion] `set +o pipefail` restored pipefail to OFF
    unconditionally - fixed: prior state captured and restored exactly.
- Residual notes dispositioned as accepted-risk: none recorded for this
  ticket, and none are invented here (no developer accepted-risk disposition
  was given to this lane).
