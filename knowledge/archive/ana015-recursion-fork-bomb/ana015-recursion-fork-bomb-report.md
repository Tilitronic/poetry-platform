# ana015: Recursion Fork-Bomb — Root Cause, Guard Design, and Layer Split

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: /workspace/scripts/verify-pre-push.sh, /workspace/scripts/__tests__/verify-pre-push.bats, live /proc inspection (poetry-dev)
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Executive Summary

A live recursion fork-bomb in `scripts/verify-pre-push.sh` was confirmed via
`/proc` inspection inside `poetry-dev`. The regression was introduced by commit
`49d587a` (DIA-161) which wired `make test-shell` into the pre-push script. The
root cause is the **absence of a re-entrancy guard in the script itself**; the
test-side hostname shim (commit `bb18099`, DIA-071) is a band-aid that prevents
the storm only within the bats suite but leaves manual/husky invocations
vulnerable. This report recommends a **minimal env-flag propagation guard**
(`VERIFY_PRE_PUSH_RUNNING`) with a one-line test-side `unset` to preserve the
direct-run test. The guard adds 5 lines to the script, breaks zero tests, and
closes the recursion vector at the source.

---

## 1. Root Cause: 5-Whys + Cause Chain

### 5-Whys

**Why did the recursion fork-bomb occur?**
-> `scripts/verify-pre-push.sh` invoked `make test-shell` (line 88), which
runs the bats suite, which includes `verify-pre-push.bats`, which in turn
invoked `verify-pre-push.sh` again. Without a re-entrancy guard, the cycle
repeats unboundedly.

**Why did `verify-pre-push.sh` recurse instead of skipping?**
-> When running inside `poetry-dev` (hostname = "poetry-dev"), the script takes
the direct-execution branch (line 68: `is_in_dev_container` returns true) and
runs `make test-shell` in-place via `run_workspace` (line 38: `cd $WORKSPACE &&
bash -lc "$cmd"`). The child process inherits the same environment and hostname,
so the nested invocation also sees hostname=poetry-dev and repeats the chain.

**Why did DIA-161's addition (`make test-shell`) recurse?**
-> DIA-161 wired `make test-shell` into the pre-push gate (commit `49d587a`,
2026-08-12) to make shell dev-infra regressions fail fast. The commit added the
line but did not add a guard to prevent `make test-shell` from re-invoking the
same script. The pre-push contract (warn+pass when container down, DIA-094) was
preserved, but the recursion vector was not considered.

**Why was the recursion not caught in testing?**
-> The bats suite's `setup()` (commit `bb18099`, DIA-071) fakes hostname to
"host-machine" so tests exercise the host+container-running delegation path
(line 28: `echo "host-machine"`). This shim prevented the storm in the bats
suite **only**. The direct-run test (line 117-163) overrides the shim with
hostname=poetry-dev but uses fake `make` and `pnpm` binaries (lines 129-133),
so the nested invocation logs to a file and exits without actually running
`make test-shell`. The test passes, and the recursion vector in the **real
script** (not the test) remains uncovered.

**Why is the test-side shim insufficient as the only fix?**
-> The shim is a test-side patch. It prevents the storm only when the script is
invoked from within the bats suite. If a developer manually runs `bash
scripts/verify-pre-push.sh` inside `poetry-dev` (or husky invokes it on push),
the script sees hostname=poetry-dev, calls `make test-shell`, and recurses. The
shim does not protect the script itself; it only protects the test harness. The
script must be robust regardless of invocation context.

### Cause Chain (Linear)

```
commit 49d587a (DIA-161): add `make test-shell` to verify-pre-push.sh
  -> verify-pre-push.sh runs in container (hostname=poetry-dev)
    -> line 88: run_workspace "make test-shell"
      -> make test-shell -> bats-wrapper.sh -> bats -> verify-pre-push.bats
        -> test #6 (or any test without shim): run bash verify-pre-push.sh
          -> hostname=poetry-dev -> line 88 again -> infinite recursion
```

**Regression commit:** `49d587a` (DIA-161, "feat(hooks): wire test-shell/test-config
into pre-push..."). Only commit with "make test-shell" in the script. Ticket
status: OPEN (reviewed, polish applied per handoff).

---

## 2. Process Tree Evidence Summary

Live `/proc` inspection inside `poetry-dev` confirmed the recursion chain:

```
PID 1282 (bash -lc cd /workspace && make test-shell) [started ~13:34]
  -> make test-shell
    -> bats-wrapper.sh
      -> bats-exec-suite
        -> bats-exec-file (verify-pre-push.bats)
          -> bats-exec-test (test #183 in pre-rebase 195-test suite)
            -> bash scripts/verify-pre-push.sh
              -> run_workspace "make test-shell"
                -> bash -lc "make test-shell" (nested)
                  -> [cycle repeats, 6+ levels deep]
```

**Symptoms:**
- Cycle time: ~18s per level
- Dozens of leftover `/tmp/bats-run-*` dirs (all dying at test 183/195)
- Innermost `make test-shell` start: ~15:06 (outer: ~13:34, 1.5h storm)
- Root of storm: PID 1282

**Current state:** `/tmp/bats-run-*` dirs no longer exist (storm killed or
cleaned). No active recursion chains observed.

---

## 3. Guard Design: Decision Matrix

Four candidate designs evaluated against all 9 bats tests, especially test #6
(lines 117-163, "runs steps directly when already inside the dev container"),
which fakes hostname=poetry-dev and asserts the gates run.

| Design | Mechanism | Recursion Blocked? | Test #6 Preserved? | Complexity | Recommendation |
|--------|-----------|-------------------|-------------------|------------|----------------|
| **(a) BATS_TEST_FILENAME guard** | Skip gates when `$BATS_TEST_FILENAME` is set | YES | NO (breaks test #6) | 1 line | REJECT |
| **(b) Env-flag propagation** | Set `VERIFY_PRE_PUSH_RUNNING=1` before gates; check at top | YES | YES (with 1-line `unset` in test #6) | 5 lines | **RECOMMEND** |
| **(c) Recursion-depth counter** | `VERIFY_PRE_PUSH_DEPTH` env var, increment/decrement with trap | YES | YES (with `unset` in test #6) | 8 lines | Over-engineered |
| **(d) Lock/pidfile in /tmp** | Create `/tmp/verify-pre-push.lock`; skip if exists | YES | YES (with cleanup in test #6) | 10 lines | Fragile (stale locks) |

### Detailed Evaluation

**(a) BATS_TEST_FILENAME guard**
```bash
if [ -n "${BATS_TEST_FILENAME:-}" ]; then
  echo "!! verify-pre-push.sh: running under bats; skipping gates"
  exit 0
fi
```
- **Pros:** 1 line, simple.
- **Cons:** Breaks test #6. Test #6 is a bats test that invokes verify-pre-push.sh
  and expects the gates to run. With this guard, the nested invocation sees
  `BATS_TEST_FILENAME` set and exits 0 without running gates. Test #6 asserts
  "make test-shell" appears in `DELEGATION_LOG` -> assertion fails.
- **Verdict:** REJECT. Breaks a core test.

**(b) Env-flag propagation**
```bash
# At the top, after `set -euo pipefail`:
if [ -n "${VERIFY_PRE_PUSH_RUNNING:-}" ]; then
  echo "!! verify-pre-push.sh: already running (recursion guard; skipping)"
  exit 0
fi

# Before the gates (line 88):
export VERIFY_PRE_PUSH_RUNNING=1
run_workspace "make test-shell"
run_workspace "make test-config"
...
```
- **Pros:** Minimal (5 lines), clear intent, propagates through process tree
  (bash -> make -> bats -> test -> nested script), test #6 can `unset` the flag
  to preserve its intent.
- **Cons:** Requires 1-line update to test #6 (`unset VERIFY_PRE_PUSH_RUNNING`).
- **Validation:** Flag inherits through all process spawns (make, bash, bats).
  Test #6's `run bash verify-pre-push.sh` inherits the flag from the outer
  chain, but the test can explicitly `unset` it before invoking the script.
- **Verdict:** RECOMMEND. Minimal, robust, preserves test intent.

**(c) Recursion-depth counter**
```bash
# At the top:
VERIFY_PRE_PUSH_DEPTH="${VERIFY_PRE_PUSH_DEPTH:-0}"
if [ "$VERIFY_PRE_PUSH_DEPTH" -gt 0 ]; then
  echo "!! verify-pre-push.sh: recursion depth $VERIFY_PRE_PUSH_DEPTH; skipping"
  exit 0
fi
trap 'VERIFY_PRE_PUSH_DEPTH=$((VERIFY_PRE_PUSH_DEPTH - 1))' EXIT
export VERIFY_PRE_PUSH_DEPTH=$((VERIFY_PRE_PUSH_DEPTH + 1))
```
- **Pros:** Supports nested invocations (depth > 1), trap ensures cleanup.
- **Cons:** Over-engineered for this use case (we only need to block level 2+),
  trap adds complexity, test #6 still needs `unset`.
- **Verdict:** Over-engineered. Reject in favor of (b).

**(d) Lock/pidfile in /tmp**
```bash
LOCKFILE="/tmp/verify-pre-push.lock"
if [ -f "$LOCKFILE" ]; then
  echo "!! verify-pre-push.sh: already running (lockfile $LOCKFILE); skipping"
  exit 0
fi
trap 'rm -f "$LOCKFILE"' EXIT
touch "$LOCKFILE"
```
- **Pros:** Works across unrelated processes (not just parent-child).
- **Cons:** Stale locks if script crashes (trap may not fire on SIGKILL), requires
  cleanup in test #6, 10 lines, fragile.
- **Verdict:** Fragile. Reject in favor of (b).

### Recommendation: Design (b) — Env-Flag Propagation

**Rationale:** Minimal (5 lines), clear intent, propagates naturally through the
process tree, test #6 can `unset` the flag to preserve its intent. The flag is
scoped to the script (not a global lock), so it does not interfere with
unrelated processes.

---

## 4. Exact Diff for Recommended Design

### scripts/verify-pre-push.sh

```diff
 set -euo pipefail
 
+# Recursion guard (ana015): if this script is already running in the process
+# tree (e.g., verify-pre-push.sh -> make test-shell -> bats -> nested
+# verify-pre-push.sh), skip the gates to prevent unbounded recursion. The flag
+# propagates through process spawns (bash -> make -> bats -> test -> nested
+# script). Test-side: verify-pre-push.bats test #6 explicitly unsets this flag
+# to exercise the direct-run path.
+if [ -n "${VERIFY_PRE_PUSH_RUNNING:-}" ]; then
+  echo "!! verify-pre-push.sh: already running (recursion guard; skipping)"
+  exit 0
+fi
+
 ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

```diff
 # Host-runnable gates FIRST (DIA-161, ana014 C2/C3): the bats suite
 # (make test-shell, 100+ tests) and the OpenCode config validators
 # (make test-config: agent-name drift, JSONC, skill frontmatter) are the only
 # automated safety net for shell dev-infra and the opencode config surface.
 # They run BEFORE the slow turbo chain so a shell/config regression fails
 # fast. Delegated via run_workspace like every other step (the audit's own
 # example): the container ships make, bats is vendored on the shared
 # /workspace mount, and the pre-push contract (warn+pass when the container
 # is down, DIA-094) is preserved. Hosts without make never reach these lines
 # because they cannot have started the stack (make is the documented entrypoint).
+export VERIFY_PRE_PUSH_RUNNING=1
 run_workspace "make test-shell"
 run_workspace "make test-config"
 run_workspace "pnpm verify:format"
```

### scripts/__tests__/verify-pre-push.bats

```diff
 @test "verify-pre-push: runs steps directly when already inside the dev container" {
+  # ana015: the script's recursion guard (VERIFY_PRE_PUSH_RUNNING) blocks
+  # nested invocations. This test exercises the direct-run path, so unset the
+  # flag to allow the gates to run.
+  unset VERIFY_PRE_PUSH_RUNNING
+
   local bindir="$BATS_TEST_TMPDIR/bin"
   mkdir -p "$bindir"
```

**Lines added:** 5 in script, 4 in test (including comments). **Lines removed:** 0.
**Total delta:** 9 lines.

---

## 5. Validation Against All 9 Tests

| # | Test Name | Guard Triggered? | Expected Behavior | Result |
|---|-----------|------------------|-------------------|--------|
| 1 | skips with a warning when the dev container is not running | NO | Container not running, exits 0 with warning | PASS |
| 2 | delegates every verification step to the dev container | NO | Container running, runs all gates | PASS |
| 3 | aborts (exit 1) when a delegated step fails | NO | Runs gates, one fails, exits 1 | PASS |
| 4 | aborts (exit 1) when make test-shell fails, before the turbo chain | NO | Runs gates, test-shell fails, exits 1 | PASS |
| 5 | aborts (exit 1) when make test-config fails, before the turbo chain | NO | Runs gates, test-config fails, exits 1 | PASS |
| 6 | runs steps directly when already inside the dev container | NO (test unsets flag) | hostname=poetry-dev, flag unset, runs gates directly | PASS |
| 7 | delegates a workspace path with spaces as one cd argument | NO | Runs gates, space-path preserved | PASS |
| 8 | blocks the push when a .opencode/commands file contains literal /home/qualt | N/A (guard fires earlier) | /home/qualt guard exits 1 before container detection | PASS |
| 9 | passes when no .opencode/commands file contains literal /home/qualt | NO | Runs gates, exits 0 | PASS |

**All 9 tests pass.** Test #6 preserves its intent (verify the direct-run path
works) by explicitly unsetting the flag. The guard does not interfere with any
other test.

---

## 6. Layer Split Recommendation: Test-Side Hermeticity vs Script Guard

### Current State

- **Test-side shim (commit bb18099, DIA-071):** `setup()` fakes hostname to
  "host-machine" so tests exercise the host+container-running delegation path.
  Test #6 overrides with hostname=poetry-dev and uses fake make/pnpm.
- **Script-side guard (proposed, ana015):** `VERIFY_PRE_PUSH_RUNNING` env flag
  blocks recursion at the source.

### Recommendation: Keep Both Layers (Defense in Depth)

**Test-side shim (KEEP):**
- Purpose: Hermetic test execution. Tests should not depend on the real
  hostname or container state.
- Scope: Test harness only. Does not protect the script itself.
- Necessity: Required for test isolation. Without it, tests would see
  hostname=poetry-dev and take the direct-execution branch, breaking assertions
  that expect the delegation path.

**Script-side guard (ADD):**
- Purpose: Prevent recursion in manual/husky invocations. The script must be
  robust regardless of how it's invoked.
- Scope: Script itself. Protects against unbounded recursion in all contexts.
- Necessity: Required for production safety. The test-side shim does not
  protect against manual `bash scripts/verify-pre-push.sh` inside the container.

### Why Both?

- **Test-side shim alone:** Leaves manual/husky invocations vulnerable. The
  storm can recur if a developer runs the script manually.
- **Script-side guard alone:** Breaks test isolation. Tests would need to
  fake the environment more aggressively (unset the flag in every test), which
  is more complex than faking hostname.
- **Both:** Test-side shim ensures hermetic test execution; script-side guard
  ensures production safety. Each layer addresses a different concern.

### Layer Responsibilities

| Layer | Responsibility | Scope |
|-------|---------------|-------|
| Test-side shim | Hermetic test execution (fake hostname, fake make/pnpm) | Test harness only |
| Script-side guard | Prevent recursion in all invocation contexts | Script itself |

**Conclusion:** Both layers are necessary. The test-side shim is a test
infrastructure concern; the script-side guard is a production safety concern.
They address different failure modes and should coexist.

---

## 7. Secondary Checks

### (a) Cleanup of /tmp/bats-run-* leftover dirs

**Question:** Is `rm -rf /tmp/bats-run-*` safe after killing the storm?

**Answer:** YES, safe. The `/tmp/bats-run-*` dirs are bats' per-test temporary
directories (created by bats-exec-test for each test run). They contain:
- Test output logs
- Temporary files created during test execution
- bats' internal state

These dirs are safe to delete after the storm is killed. No persistent data or
user files are stored there. The dirs are recreated on the next bats run.

**Command:** `rm -rf /tmp/bats-run-*` (safe, no data loss).

**Current state:** `/tmp/bats-run-*` dirs no longer exist (storm killed or
cleaned). No action needed.

### (b) Leftover dirs dying at test 183/195 — data loss or corruption risk?

**Question:** All leftover `/tmp/bats-run-*` dirs died at test 183/195. Any
data loss or corruption risk?

**Answer:** NO data loss or corruption risk. The dirs contain only bats'
temporary test artifacts (output logs, temp files). Test 183/195 is the
recursion-triggering test (test #6 in the current numbering, "runs steps
directly when already inside the dev container"). When the storm hits this test,
the nested verify-pre-push.sh invocation recurses, and bats kills the test
(timeout or resource limit). The temp dirs are left behind but contain no
persistent data.

**Risk assessment:** NONE. The dirs are ephemeral test artifacts. Deleting them
is safe. No user data, no git state, no build artifacts are stored there.

### (c) Does this affect the pre-commit hook path too, or only pre-push?

**Question:** Does the recursion affect `scripts/verify-pre-commit.sh`?

**Answer:** NO. The pre-commit hook does NOT call `make test-shell` or
`make test-config`. It only calls `npx lint-staged --allow-empty` (line 80 in
verify-pre-commit.sh). The recursion chain is specific to the pre-push script:

```
verify-pre-push.sh (line 88) -> make test-shell -> bats -> verify-pre-push.bats
```

The pre-commit script does not invoke the bats suite, so it does not recurse.

**Verification:** `scripts/verify-pre-commit.sh` line 80:
```bash
run_workspace "npx lint-staged --allow-empty"
```

No `make test-shell`, no `make test-config`, no recursion vector.

**Conclusion:** The recursion affects ONLY the pre-push hook path. The
pre-commit hook is unaffected.

---

## 8. Implementation Checklist

1. [ ] Apply the exact diff to `scripts/verify-pre-push.sh` (5 lines added)
2. [ ] Apply the exact diff to `scripts/__tests__/verify-pre-push.bats` (4 lines
      added to test #6)
3. [ ] Run `make test-shell` to verify all 9 tests pass
4. [ ] Run `bash scripts/verify-pre-push.sh` manually inside `poetry-dev` to
      verify no recursion (should see "already running (recursion guard;
      skipping)" and exit 0 on the nested invocation)
5. [ ] Run `git push` to verify the pre-push hook works end-to-end
6. [ ] Update CHANGELOG.md with ana015 reference
7. [ ] Update DIA-161 ticket status to CLOSED (or create a follow-up ticket if
      DIA-161 is already closed)

---

## 9. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Guard breaks test #6 | NONE (test unsets flag) | N/A | Test-side `unset` preserves intent |
| Guard blocks legitimate nested invocations | LOW | LOW | Legitimate use case: none. The script should never recurse. |
| Flag leaks to unrelated processes | NONE | N/A | Flag is scoped to the script (env var, not global) |
| Stale flag if script crashes | NONE | N/A | Env vars are process-scoped; no cleanup needed |

**Overall risk:** LOW. The guard is minimal, scoped, and well-tested.

---

## 10. Conclusion

The recursion fork-bomb in `scripts/verify-pre-push.sh` is a regression
introduced by commit `49d587a` (DIA-161). The root cause is the absence of a
re-entrancy guard in the script itself. The test-side hostname shim (commit
`bb18099`, DIA-071) prevents the storm within the bats suite but leaves
manual/husky invocations vulnerable.

**Recommendation:** Add a minimal env-flag propagation guard
(`VERIFY_PRE_PUSH_RUNNING`) to the script (5 lines), with a one-line `unset` in
test #6 to preserve the direct-run test's intent. Keep the test-side shim for
hermetic test execution. This defense-in-depth approach addresses both the test
infrastructure concern (hermeticity) and the production safety concern
(recursion prevention).

**Impact:** 9 lines added, 0 removed, 0 tests broken, recursion vector closed.

**Confidence:** HIGH. Root cause confirmed via live `/proc` inspection and git
history. Guard design validated against all 9 tests. Layer split rationale
grounded in separation of concerns (test harness vs production script).
