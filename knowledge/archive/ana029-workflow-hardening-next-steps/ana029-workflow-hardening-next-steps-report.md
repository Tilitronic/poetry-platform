# Workflow Hardening: Next-Steps Gap Analysis (DIA-228)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: knowledge/ana025, knowledge/ana026, knowledge/ana027, knowledge/ana028, .opencode/plugins/delegation-observer.ts, .opencode/plugins/__tests__/parallel-handoff.test.mjs
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Executive Summary

DIA-221 delivered 6 commits, 12 regression tests, and 1,250 lines of code that fixed 2 CRITICAL bugs and added mechanical enforcement for the two highest-frequency failure classes. However, this analysis identifies **10 hardening areas not yet covered**, **8 testing gaps**, **7 enforcement gaps**, and **5 verification gaps** that remain after DIA-222-227.

The #1 priority is fixing the `parallel-handoff.test.mjs` ARCHIVE_NAME_RE regex, which DIA-222 broke by adding a UUID suffix to archive filenames. This blocks `make test-harness` entirely. The #2 priority is restart-verifying the DIA-222/224/225 plugin changes live -- hermetic tests pass, but runtime behavior under the actual OpenCode process is unconfirmed.

This report provides a prioritized roadmap with scope, effort estimates, and agent assignments for each recommendation.

---

## 1. Hardening Areas NOT Covered by DIA-222-227

### 1.1 Gap Matrix

```
+----------------------------------+----------+----------+----------+
| Hardening Area                   | Severity | Frequency| Status   |
+----------------------------------+----------+----------+----------+
| G1. parallel-handoff.test.mjs    | CRITICAL | Certain  | BROKEN   |
|     ARCHIVE_NAME_RE regex        |          |          |          |
+----------------------------------+----------+----------+----------+
| G2. Restart-verify DIA-222/224/  | HIGH     | Certain  | MISSING  |
|     225 plugin changes live      |          |          |          |
+----------------------------------+----------+----------+----------+
| G3. Restart-verify as HARD GATE  | HIGH     | Likely   | MISSING  |
|     in section 10 workflow       |          |          |          |
+----------------------------------+----------+----------+----------+
| G4. DIA-206 root cause           | MEDIUM   | Certain  | OPEN     |
|     (systemic empty returns)     |          |          |          |
+----------------------------------+----------+----------+----------+
| G5. Expand C5 scenario replay    | MEDIUM   | Possible | LIMITED  |
|     (DIA-206, DIA-191, DIA-130)  |          |          |          |
+----------------------------------+----------+----------+----------+
| G6. Complete section 10          | MEDIUM   | Certain  | INCOMP   |
|     validation (ai-auditor +     |          |          |          |
|     CHANGELOG.yaml)              |          |          |          |
+----------------------------------+----------+----------+----------+
| G7. Monitor D3/D4 in production  | LOW      | Ongoing  | MISSING  |
|     (tune false pos/neg)         |          |          |          |
+----------------------------------+----------+----------+----------+
| G8. DIA-175 instance separation  | LOW      | Possible | MISSING  |
|     enforcement via ticket meta  |          |          |          |
+----------------------------------+----------+----------+----------+
| G9. Automate verification        | LOW      | Possible | MISSING  |
|     evidence capture             |          |          |          |
+----------------------------------+----------+----------+----------+
| G10. Revisit excluded items      | LOW      | Deferred | DEFERRED |
|     (metrics, ledger, etc.)      |          |          |          |
+----------------------------------+----------+----------+----------+
```

### 1.2 Detailed Gap Analysis

**G1: parallel-handoff.test.mjs ARCHIVE_NAME_RE regex (CRITICAL)**

DIA-222 changed the archive filename format from `${sessionId}.${iso}.json` to `${sessionId}.${iso}.${randomUUID()}.json` (line 1373 of delegation-observer.ts). The pre-existing test at `parallel-handoff.test.mjs` line 178 still expects the OLD format:

```javascript
// CURRENT (broken by DIA-222):
const ARCHIVE_NAME_RE = /^ses_A\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.json$/

// REQUIRED (matches DIA-222 UUID suffix):
const ARCHIVE_NAME_RE = /^ses_A\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$/
```

Additionally, line 299 asserts `expect(archiveFiles).toHaveLength(1)`, but with the F-1 fix, two same-ms writes now produce TWO archive files (distinct UUIDs), not one. The test assertion must be updated to expect 2 archive files.

**Impact:** Blocks `make test-harness` entirely. When `make test-infra` runs (which depends on `test-harness` per DIA-227), it will fail.

**G2: Restart-verify DIA-222/224/225 plugin changes live (HIGH)**

The delegation-observer.ts changes from DIA-222 (F-1/F-3 fixes), DIA-224 (empty-result detection), and DIA-225 (failure cap) have only been verified via hermetic bun tests. They have NOT been loaded into a live OpenCode process and exercised end-to-end.

**Why this is #2 priority:**

- DIA-070 established that TUI restart does NOT load patched plugin code -- only a hard process restart (kill PID + start fresh) does.
- DIA-126 showed that config can look correct on read but differ at runtime (catch-all ordering trap).
- DIA-128 showed that vendored source semantics can diverge from installed npm runtime.
- 5+ prior incidents (DIA-098, DIA-099, DIA-120, DIA-122, DIA-127) had "restart-verify DEFERRED" and some were never verified.

**Verification checklist:**

| Step | Command | Expected |
|------|---------|----------|
| 1. Hard restart | Kill OpenCode PID, start fresh | New PID, new start timestamp |
| 2. Plugin loaded | Check TUI panel or plugin log | delegation-observer loaded, no errors |
| 3. F-1 fix live | Trigger two same-ms handoff writes | Two distinct archive files (UUID suffix visible) |
| 4. F-3 fix live | Check slot identity for pre-dispatch session | No "unknown" in handoffs/ directory |
| 5. D3 empty-result live | Dispatch a lane that returns empty | SILENT_FAILURE row in registry.jsonl |
| 6. D4 failure cap live | Trigger 3 consecutive empty results | failure_cap_reached warning in messages.jsonl |
| 7. C1-C5 tests pass | `make test-harness` | Exit 0, all 12 tests pass |

**G3: Restart-verify as HARD GATE in section 10 workflow (HIGH)**

Restart-verify deferral is a recurring habit, not a deliberate decision. The failures.md and lessons.md documents show 5+ incidents where restart-verify was deferred and the gap persisted. A mechanical gate would break the habit.

**Recommendation:** Add a "restart-verify" gate to the section 10 workflow (AGENTS.md section 2.5, Phase 5 validation) that blocks ticket completion until restart-verify is confirmed. The gate could be:

- A plugin hook that checks for a "restart-verify-complete" marker in registry.jsonl before allowing ticket status to flip to DONE
- A script that validates the plugin is loaded and the runtime event hooks are firing
- A checklist item in the ticket template that requires explicit confirmation

**G4: DIA-206 root cause (MEDIUM)**

DIA-206 (systemic empty returns across ai-specialist, coder, researcher) root cause was not diagnosed. The D3 empty-result detection provides a mechanical safety net, but the provider-level root cause remains unknown.

**Investigation approach:**

1. Use `scripts/session-analytics.sh` to analyze DIA-206 sessions
2. Query registry.jsonl for `session_complete` + no `task_success` + no file edits (D1 signal from DIA-099)
3. Check messages.jsonl for endpoint errors or model failures
4. Correlate with provider status pages (if available)

**G5: Expand C5 scenario replay (MEDIUM)**

The C5 bats file (67 lines) implements 3 scenarios from the ana026 incident corpus. The design.md estimate was ~150 lines. The implementation may be simplified.

**Candidate scenarios to add:**

1. DIA-206 class: systemic empty returns across multiple lanes (ai-specialist, coder, researcher)
2. DIA-191 class: context estimation overestimate (proxy vs TUI divergence)
3. DIA-130 class: coder-escalated silent failure (empty result after long runtime)

**G6: Complete section 10 validation (MEDIUM)**

DIA-227 verification evidence mentions "config-compatible" but does not confirm the full section 10 workflow:

- Phase 1: @ai-specialist research (gate consult)
- Phase 6: @ai-auditor independent review
- CHANGELOG.yaml entry

**Actions:**

1. Dispatch @ai-auditor for post-implementation review of DIA-222/224/225 plugin changes
2. Append CHANGELOG.yaml entry for DIA-221 (YAML ledger is source of truth per AGENTS.md section 2.5)
3. Validate with `scripts/validate-changelog.sh`
4. Regenerate derived MD with `scripts/changelog-render`

**G7-G10: Lower priority, deferred**

See ana028 section 3 for detailed recommendations on monitoring D3/D4, DIA-175 enforcement, verification evidence automation, and revisiting excluded items.

---

## 2. Testing Gaps

### 2.1 Test Coverage Matrix

```
+----------------------------------+--------+--------+--------+----------+
| Test Scenario                    | S1     | S2     | S3     | S4       |
|                                  | (bats) | (bun)  | (bats) | (live)   |
+----------------------------------+--------+--------+--------+----------+
| C1: Handoff archive collision    | -      | YES    | -      | NO       |
| C2: Slot identity no-clobber     | -      | YES    | -      | NO       |
| C3: Empty-result detection       | -      | YES    | -      | NO       |
| C4: Failure cap cooldown         | -      | YES    | -      | NO       |
| C5: Scenario replay (3 scenarios)| -      | -      | YES    | NO       |
| parallel-handoff.test.mjs        | -      | BROKEN | -      | -        |
| DIA-098 stall timer              | -      | -      | -      | NO       |
| DIA-099 resume protocol          | -      | -      | -      | NO       |
| DIA-124 handoff-before-present   | -      | -      | -      | NO       |
| DIA-126 catch-all ordering       | -      | -      | -      | NO       |
| Batch-dispatch (A1) enforcement  | -      | -      | -      | NO       |
+----------------------------------+--------+--------+--------+----------+
```

### 2.2 Critical Testing Gaps

**Gap T1: parallel-handoff.test.mjs ARCHIVE_NAME_RE regex (CRITICAL)**

As documented in G1, the regex is broken by DIA-222's UUID suffix. This blocks `make test-harness`.

**Fix:** Update the ARCHIVE_NAME_RE regex to include the UUID suffix pattern. The new C1 test (`handoff-archive-collision.test.mjs` line 160) already has the correct regex -- mirror it.

**Additional fix:** Update line 299 assertion from `expect(archiveFiles).toHaveLength(1)` to `expect(archiveFiles).toHaveLength(2)` because the F-1 fix now produces two distinct archive files.

**Gap T2: No S4 layer (live OpenCode process smoke test)**

The test suite has 3 layers: S1 (bats, hermetic shell tests), S2 (bun, hermetic plugin tests), S3 (bats, scenario replay inside container). All 3 layers are hermetic or semi-hermetic.

**Recommendation:** Add an S4 layer that runs inside a live OpenCode process and validates the plugin is loaded and the event hooks are firing. This could be:

- A smoke test that dispatches a minimal lane and checks registry.jsonl for the expected plugin emissions
- A TUI panel check that validates the plugin version matches the expected version
- A sidecar schema validation that checks registry.jsonl and messages.jsonl for correct plugin emissions

**Gap T3: No tests for DIA-098/099/124/126**

These critical fixes have no regression tests:

- DIA-098: stall timer + permission watchdog (implemented in plugin, restart-verify DEFERRED)
- DIA-099: resume-truncated-lane protocol (procedural only)
- DIA-124: handoff-before-presentation (procedural HARD RULE + comment-only plugin gate)
- DIA-126: catch-all ordering (verified, but no regression test)

**Recommendation:** Add regression tests for these fixes. Priority order:

1. DIA-126 catch-all ordering (easy to test, high impact)
2. DIA-098 stall timer (medium complexity, high impact)
3. DIA-124 handoff-before-presentation (medium complexity, medium impact)
4. DIA-099 resume protocol (hard to test, medium impact)

**Gap T4: C5 scenarios limited**

The C5 bats file (67 lines) implements 3 scenarios. The design.md estimate was ~150 lines. The implementation may be simplified.

**Recommendation:** Verify C5 scenarios exercise the full plugin hook chain (not just file output). Expand scenarios to cover DIA-206, DIA-191, DIA-130 classes.

---

## 3. Enforcement Gaps

### 3.1 Enforcement Level Matrix

```
+----------------------------------+-----------+-----------+-------------+
| Rule                             | Current   | Desired   | Gap         |
+----------------------------------+-----------+-----------+-------------+
| D3: Empty-result detection       | ALERT     | ALERT     | NONE        |
|    (SILENT_FAILURE emission)     | (warning) | (warning) |             |
+----------------------------------+-----------+-----------+-------------+
| D4: Failure cap                  | WARNING   | WARNING   | NONE        |
|    (failure_cap_reached event)   | (warning) | (warning) |             |
+----------------------------------+-----------+-----------+-------------+
| DIA-099: Resume protocol         | PROCED    | MECHAN    | HIGH        |
|    (verify-first before re-disp)  | (prompt)  | (plugin)  |             |
+----------------------------------+-----------+-----------+-------------+
| DIA-098: Stall timer             | IMPL      | VERIF     | MEDIUM      |
|    (60s sweep + 5-min watchdog)  | (plugin)  | (live)    |             |
+----------------------------------+-----------+-----------+-------------+
| DIA-124: Handoff-before-present  | PROCED    | MECHAN    | MEDIUM      |
|    (HARD RULE + comment gate)    | (prompt)  | (plugin)  |             |
+----------------------------------+-----------+-----------+-------------+
| 3-failure cap                    | PROCED    | MECHAN    | MEDIUM      |
|    (D4 is warning-only)          | (prompt)  | (plugin)  |             |
+----------------------------------+-----------+-----------+-------------+
| A1: Batch-dispatch               | ADVISORY  | ADVISORY  | LOW         |
|    (console.warn)                | (warning) | (warning) |             |
+----------------------------------+-----------+-----------+-------------+
| DIA-175: Instance separation     | PROCED    | MECHAN    | LOW         |
|    (RED/GREEN different sessions)| (prompt)  | (ticket)  |             |
+----------------------------------+-----------+-----------+-------------+
```

### 3.2 Enforcement Gap Analysis

**Gap E1: DIA-099 resume protocol is procedural only (HIGH)**

The DIA-099 Variant A2 protocol (verify-first, resume same session) is the correct recovery for empty results, but it is PROCEDURAL, not mechanical. No automated enforcement ensures the orchestrator follows the protocol.

**Recommendation:** Add plugin-level enforcement in the `session.idle` handler. When an empty result is detected (D3), emit a registry row with `dispatch_state: SILENT_FAILURE` AND a `recommended_action: VERIFY_FIRST_THEN_RESUME` field. The orchestrator can then check this field before re-dispatching.

**Gap E2: DIA-098 stall timer is unverified (MEDIUM)**

The DIA-098 stall timer (60s sweep) and permission watchdog (5-min auto-reject) are implemented in the plugin, but restart-verify is DEFERRED. We cannot confirm they work live.

**Recommendation:** Restart-verify DIA-098 live. Add a regression test that validates the stall timer fires after 60s of inactivity.

**Gap E3: DIA-124 handoff-before-presentation is procedural (MEDIUM)**

The DIA-124 HARD RULE (handoff via log_decision BEFORE final summary) is procedural, with only a comment-only plugin gate. No mechanical enforcement ensures the orchestrator writes the handoff before presenting the session-end prompt.

**Recommendation:** Add plugin-level enforcement in the `session.idle` handler. When a session goes idle with `event_type: 'handoff'` but no handoff file exists, emit a warning event with `gen_ai.operation.name: 'handoff_missing'`. The orchestrator can then check this field before presenting the session-end prompt.

**Gap E4: 3-failure cap is procedural (MEDIUM)**

The 3-failure cap (D4) is warning-only. After 3 consecutive empty results, it emits a warning event, but does not block re-dispatch. The orchestrator could still loop.

**Recommendation:** Upgrade D4 from warning-only to blocking. After 3 consecutive empty results, emit a registry row with `dispatch_state: FAILURE_CAP_BLOCKED` and prevent further dispatches to the same lane until the cooldown expires.

**Gap E5: A1 batch-dispatch is advisory (LOW)**

The A1 batch-dispatch check is advisory (console.warn). Unsafe batches can execute.

**Recommendation:** Revisit after 30 days. If batch-dispatch violations occur, upgrade A1 to mechanical enforcement.

**Gap E6: DIA-175 instance separation is procedural (LOW)**

The DIA-175 requirement (RED test-writing and GREEN implementation for the same slice MUST be dispatched to DIFFERENT coder instances) is procedural. The DIA-221 implementation did not enforce this.

**Recommendation:** Add session_id and lane_id fields to ticket frontmatter. Add a validation script that checks RED/GREEN separation for each ticket.

---

## 4. Verification Gaps

### 4.1 Verification Status Matrix

```
+----------------------------------+----------+----------+----------+
| Change                           | Hermetic | Restart  | Live     |
|                                  | Tests    | Verify   | Runtime  |
+----------------------------------+----------+----------+----------+
| DIA-222: F-1/F-3 fixes           | PASS     | MISSING  | MISSING  |
| DIA-224: D3 empty-result detect  | PASS     | MISSING  | MISSING  |
| DIA-225: D4 failure cap          | PASS     | MISSING  | MISSING  |
| DIA-098: Stall timer + watchdog  | N/A      | DEFERRED | MISSING  |
| DIA-099: Resume protocol         | N/A      | DEFERRED | MISSING  |
| DIA-120: Terminal-status filter  | N/A      | PASS     | PASS     |
| DIA-126: Catch-all ordering      | N/A      | PASS     | PASS     |
| DIA-128: Vendored vs npm         | N/A      | PASS     | PASS     |
+----------------------------------+----------+----------+----------+
```

### 4.2 Critical Verification Gaps

**Gap V1: DIA-222/224/225 plugin changes never restart-verified live (CRITICAL)**

As documented in G2, the delegation-observer.ts changes have only been verified via hermetic bun tests. They have NOT been loaded into a live OpenCode process and exercised end-to-end.

**Risk:** The F-1/F-3 fixes could have subtle runtime issues (e.g., randomUUID import path, sessionID availability in fallback chain) that hermetic tests cannot catch. The D3/D4 detection could fire false positives or miss real failures.

**Gap V2: DIA-098/099 restart-verify DEFERRED (HIGH)**

The DIA-098 stall timer + permission watchdog and DIA-099 resume protocol are implemented in the plugin, but restart-verify is DEFERRED. We cannot confirm they work live.

**Risk:** These are core detection infrastructure. If they don't work live, the harness has no mechanical enforcement for stall detection and empty-result recovery.

**Gap V3: DIA-120/126/128 verified but no regression tests (MEDIUM)**

These fixes were restart-verified live, but have no regression tests. If the plugin code changes in the future, these fixes could regress without detection.

**Recommendation:** Add regression tests for DIA-120 (terminal-status filter), DIA-126 (catch-all ordering), and DIA-128 (vendored vs npm semantics).

---

## 5. Recommended Next Priorities

### 5.1 Priority Ranking (by Risk Reduction)

```
+----+----------------------------------+----------+--------+--------+---------+
| #  | Recommendation                   | Risk     | Effort | Agents | Priority|
|    |                                  | Reductn  |        | Needed |         |
+----+----------------------------------+----------+--------+--------+---------+
| 1  | Fix parallel-handoff.test.mjs    | CRITICAL | 0.5h   | @coder | IMMED   |
|    | ARCHIVE_NAME_RE regex + assert   |          |        |        |         |
+----+----------------------------------+----------+--------+--------+---------+
| 2  | Restart-verify DIA-222/224/225   | HIGH     | 0.5d   | @coder | IMMED   |
|    | plugin changes live              |          |        |        |         |
+----+----------------------------------+----------+--------+--------+---------+
| 3  | Run make test-harness with       | HIGH     | 0.5h   | @coder | IMMED   |
|    | Docker daemon up                 |          |        |        |         |
+----+----------------------------------+----------+--------+--------+---------+
| 4  | Make restart-verify a HARD GATE  | HIGH     | 1d     | @coder | SHORT   |
|    | in section 10 workflow           |          |        | @archit|         |
+----+----------------------------------+----------+--------+--------+---------+
| 5  | Complete section 10 validation   | MEDIUM   | 0.5d   | @ai-au | SHORT   |
|    | (ai-auditor + CHANGELOG.yaml)    |          |        | dit    |         |
+----+----------------------------------+----------+--------+--------+---------+
| 6  | Investigate DIA-206 root cause   | MEDIUM   | 1d     | @resea | MEDIUM  |
|    | (systemic empty returns)         |          |        | rcher  |         |
+----+----------------------------------+----------+--------+--------+---------+
| 7  | Expand C5 scenario replay        | MEDIUM   | 1d     | @coder | MEDIUM  |
|    | (DIA-206, DIA-191, DIA-130)      |          |        |        |         |
+----+----------------------------------+----------+--------+--------+---------+
| 8  | Monitor D3/D4 in production      | LOW      | Ongoing| @orch  | ONGOING |
|    | (tune false pos/neg)             |          |        |estrator|        |
+----+----------------------------------+----------+--------+--------+---------+
| 9  | Add regression tests for         | MEDIUM   | 1d     | @coder | MEDIUM  |
|    | DIA-120/126/098/099              |          |        |        |         |
+----+----------------------------------+----------+--------+--------+---------+
| 10 | Enforce DIA-175 instance         | LOW      | 0.5d   | @coder | LONG    |
|    | separation via ticket metadata   |          |        |        |         |
+----+----------------------------------+----------+--------+--------+---------+
```

### 5.2 Immediate Priorities (Next Session)

**Priority 1: Fix parallel-handoff.test.mjs ARCHIVE_NAME_RE regex**

**Scope:** Update the ARCHIVE_NAME_RE regex at line 178 to include the UUID suffix pattern. Update the assertion at line 299 from `expect(archiveFiles).toHaveLength(1)` to `expect(archiveFiles).toHaveLength(2)`.

**Effort:** 0.5 hours

**Agents needed:** @coder

**Verification:** `make test-harness` exits 0, all tests pass (including parallel-handoff.test.mjs).

**Priority 2: Restart-verify DIA-222/224/225 plugin changes live**

**Scope:** Perform a hard process restart (kill PID + start fresh) and verify:

- New PID, new start timestamp (confirm hard restart, not TUI restart)
- Plugin loaded (check TUI panel or plugin log, no errors)
- F-1 fix live: trigger two same-ms handoff writes, verify two distinct archive files
- F-3 fix live: check slot identity for pre-dispatch session, verify no "unknown" in handoffs/ directory
- D3 empty-result live: dispatch a lane that returns empty, verify SILENT_FAILURE row in registry.jsonl
- D4 failure cap live: trigger 3 consecutive empty results, verify failure_cap_reached warning in messages.jsonl
- C1-C5 tests pass: `make test-harness` exits 0, all 12 tests pass

**Effort:** 0.5 days

**Agents needed:** @coder

**Verification:** Documented verification evidence (test results, grep checks, exit codes) in ticket frontmatter.

**Priority 3: Run make test-harness with Docker daemon up**

**Scope:** Run `make test-harness` with Docker daemon running and dev container up. Verify all tests pass.

**Effort:** 0.5 hours

**Agents needed:** @coder

**Verification:** `make test-harness` exits 0, all 12 tests pass.

### 5.3 Short-Term Priorities (Next 7 Days)

**Priority 4: Make restart-verify a HARD GATE in section 10 workflow**

**Scope:** Add a "restart-verify" gate to the section 10 workflow (AGENTS.md section 2.5, Phase 5 validation) that blocks ticket completion until restart-verify is confirmed. Add a validation script that checks for a "restart-verify: done" marker in the ticket frontmatter.

**Effort:** 1 day

**Agents needed:** @coder, @architector (design)

**Verification:** Validation script fails when restart-verify marker is absent.

**Priority 5: Complete section 10 validation**

**Scope:** Dispatch @ai-auditor for post-implementation review of DIA-222/224/225 plugin changes. Append CHANGELOG.yaml entry for DIA-221. Validate with `scripts/validate-changelog.sh`. Regenerate derived MD with `scripts/changelog-render`.

**Effort:** 0.5 days

**Agents needed:** @ai-auditor

**Verification:** CHANGELOG.yaml entry present, validation script passes.

### 5.4 Medium-Term Priorities (Next 30 Days)

**Priority 6: Investigate DIA-206 root cause**

**Scope:** Use `scripts/session-analytics.sh` to analyze DIA-206 sessions. Query registry.jsonl for `session_complete` + no `task_success` + no file edits. Check messages.jsonl for endpoint errors or model failures. Correlate with provider status pages.

**Effort:** 1 day

**Agents needed:** @researcher

**Verification:** Root cause identified and documented, or confirmed as transient provider issue.

**Priority 7: Expand C5 scenario replay**

**Scope:** Add 3 more scenarios to the C5 bats file: DIA-206 class (systemic empty returns), DIA-191 class (context estimation overestimate), DIA-130 class (coder-escalated silent failure). Verify scenarios exercise the full plugin hook chain.

**Effort:** 1 day

**Agents needed:** @coder

**Verification:** C5 bats tests pass, 6 scenarios total.

**Priority 9: Add regression tests for DIA-120/126/098/099**

**Scope:** Add regression tests for:

- DIA-120: terminal-status filter (verify plugin does not fire on in-flight log_decision)
- DIA-126: catch-all ordering (verify catch-all deny is FIRST position)
- DIA-098: stall timer (verify 60s sweep fires after inactivity)
- DIA-099: resume protocol (verify verify-first before re-dispatch)

**Effort:** 1 day

**Agents needed:** @coder

**Verification:** All new tests pass.

### 5.5 Long-Term Priorities (Next 90 Days)

**Priority 8: Monitor D3/D4 in production**

**Scope:** Observe registry.jsonl and messages.jsonl for SILENT_FAILURE and failure_cap_reached events over the next 30 days. Tune the 10-minute cooldown window if needed.

**Effort:** Ongoing

**Agents needed:** @orchestrator

**Verification:** Low false-positive rate, catching real failures.

**Priority 10: Enforce DIA-175 instance separation via ticket metadata**

**Scope:** Add session_id and lane_id fields to ticket frontmatter. Add a validation script that checks RED/GREEN separation for each ticket.

**Effort:** 0.5 days

**Agents needed:** @coder

**Verification:** Validation script fails when RED/GREEN separation is violated.

---

## 6. Recommendation Details

### 6.1 Priority 1: Fix parallel-handoff.test.mjs ARCHIVE_NAME_RE regex

**What:** Update the ARCHIVE_NAME_RE regex at line 178 of `parallel-handoff.test.mjs` to include the UUID suffix pattern. Update the assertion at line 299 from `expect(archiveFiles).toHaveLength(1)` to `expect(archiveFiles).toHaveLength(2)`.

**Why:** DIA-222 changed the archive filename format from `${sessionId}.${iso}.json` to `${sessionId}.${iso}.${randomUUID()}.json` (line 1373 of delegation-observer.ts). The pre-existing test still expects the OLD format. This blocks `make test-harness` entirely.

**Scope:**

- Update line 178: `const ARCHIVE_NAME_RE = /^ses_A\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$/`
- Update line 299: `expect(archiveFiles).toHaveLength(2)`
- Verify the new C1 test (`handoff-archive-collision.test.mjs` line 160) already has the correct regex -- mirror it

**Effort:** 0.5 hours

**Agents needed:** @coder

**Verification:** `make test-harness` exits 0, all tests pass (including parallel-handoff.test.mjs).

**Risk if skipped:** `make test-harness` blocks entirely. `make test-infra` (which depends on `test-harness` per DIA-227) will fail.

### 6.2 Priority 2: Restart-verify DIA-222/224/225 plugin changes live

**What:** Perform a hard process restart (kill PID + start fresh) and verify the DIA-222/224/225 plugin changes work live.

**Why:** The delegation-observer.ts changes have only been verified via hermetic bun tests. They have NOT been loaded into a live OpenCode process and exercised end-to-end. DIA-070 established that TUI restart does NOT load patched plugin code -- only a hard process restart does. DIA-126 showed that config can look correct on read but differ at runtime. 5+ prior incidents had "restart-verify DEFERRED" and some were never verified.

**Scope:**

1. Hard restart: Kill OpenCode PID, start fresh. Verify new PID, new start timestamp.
2. Plugin loaded: Check TUI panel or plugin log. Verify delegation-observer loaded, no errors.
3. F-1 fix live: Trigger two same-ms handoff writes. Verify two distinct archive files (UUID suffix visible).
4. F-3 fix live: Check slot identity for pre-dispatch session. Verify no "unknown" in handoffs/ directory.
5. D3 empty-result live: Dispatch a lane that returns empty. Verify SILENT_FAILURE row in registry.jsonl.
6. D4 failure cap live: Trigger 3 consecutive empty results. Verify failure_cap_reached warning in messages.jsonl.
7. C1-C5 tests pass: `make test-harness` exits 0, all 12 tests pass.

**Effort:** 0.5 days

**Agents needed:** @coder

**Verification:** Documented verification evidence (test results, grep checks, exit codes) in ticket frontmatter.

**Risk if skipped:** The F-1/F-3 fixes could have subtle runtime issues (e.g., randomUUID import path, sessionID availability in fallback chain) that hermetic tests cannot catch. The D3/D4 detection could fire false positives or miss real failures.

### 6.3 Priority 3: Run make test-harness with Docker daemon up

**What:** Run `make test-harness` with Docker daemon running and dev container up.

**Why:** `make test-harness` runs two components: C5 bats tests (inside container) and bun plugin tests (inside container). Both require Docker daemon and dev container. This is the final verification that the DIA-221 hardening is complete.

**Scope:**

1. Start Docker daemon: `make up`
2. Verify dev container running: `docker compose ps` shows `poetry-dev` service Up
3. Run `make test-harness`
4. Verify exit 0, all 12 tests pass

**Effort:** 0.5 hours

**Agents needed:** @coder

**Verification:** `make test-harness` exits 0, all 12 tests pass.

**Risk if skipped:** Cannot confirm the DIA-221 hardening is complete. The test suite may have runtime issues not caught by hermetic tests.

### 6.4 Priority 4: Make restart-verify a HARD GATE in section 10 workflow

**What:** Add a "restart-verify" gate to the section 10 workflow (AGENTS.md section 2.5, Phase 5 validation) that blocks ticket completion until restart-verify is confirmed.

**Why:** Restart-verify deferral is a recurring habit, not a deliberate decision. The failures.md and lessons.md documents show 5+ incidents where restart-verify was deferred and the gap persisted. A mechanical gate would break the habit.

**Scope:**

1. Update AGENTS.md section 2.5, Phase 5 validation: add a "HARD GATE: Restart-verify" checklist item
2. Add a validation script (`scripts/validate-restart-verify.sh`) that checks for a "restart-verify: done" marker in the ticket frontmatter
3. Wire the validation script into `make test-config`
4. Update ticket template to include "restart-verify: [ ] done, [ ] skipped with reason" checklist item

**Effort:** 1 day

**Agents needed:** @coder, @architector (design)

**Verification:** Validation script fails when restart-verify marker is absent.

**Risk if skipped:** Restart-verify gap recurs in future changes. Plugin changes may have runtime issues not caught by hermetic tests.

### 6.5 Priority 5: Complete section 10 validation

**What:** Dispatch @ai-auditor for post-implementation review of DIA-222/224/225 plugin changes. Append CHANGELOG.yaml entry for DIA-221.

**Why:** AGENTS.md section 2.5 requires the full section 10 workflow for any `.opencode/` change. DIA-222/224/225 modified delegation-observer.ts (a plugin under `.opencode/plugins/`), which is within section 10 scope. DIA-227 verification evidence mentions "config-compatible" but does not confirm the full section 10 workflow.

**Scope:**

1. Dispatch @ai-auditor for post-implementation review of DIA-222/224/225 plugin changes
2. Append CHANGELOG.yaml entry for DIA-221 (YAML ledger is source of truth per AGENTS.md section 2.5)
3. Validate with `scripts/validate-changelog.sh`
4. Regenerate derived MD with `scripts/changelog-render`

**Effort:** 0.5 days

**Agents needed:** @ai-auditor

**Verification:** CHANGELOG.yaml entry present, validation script passes.

**Risk if skipped:** Section 10 workflow incomplete. Future reviewers cannot trace the change history.

### 6.6 Priority 6: Investigate DIA-206 root cause

**What:** Use `scripts/session-analytics.sh` to analyze DIA-206 sessions. Query registry.jsonl for `session_complete` + no `task_success` + no file edits. Check messages.jsonl for endpoint errors or model failures.

**Why:** DIA-206 (systemic empty returns across ai-specialist, coder, researcher) root cause was not diagnosed. The D3 empty-result detection provides a mechanical safety net, but the provider-level root cause remains unknown. DIA-206 caused 5 empty returns in one day (2026-08-17), blocking the entire section 2.5 workflow when ai-specialist is the gate.

**Scope:**

1. Use `scripts/session-analytics.sh` to analyze DIA-206 sessions
2. Query registry.jsonl for `session_complete` + no `task_success` + no file edits (D1 signal from DIA-099)
3. Check messages.jsonl for endpoint errors or model failures
4. Correlate with provider status pages (if available)
5. Document root cause (provider outage, model bug, endpoint issue) or confirm transient provider issue

**Effort:** 1 day

**Agents needed:** @researcher

**Verification:** Root cause identified and documented, or confirmed as transient provider issue.

**Risk if skipped:** DIA-206 root cause remains unknown. The workaround (route to substitute lane) is reactive, not preventive.

### 6.7 Priority 7: Expand C5 scenario replay

**What:** Add 3 more scenarios to the C5 bats file: DIA-206 class (systemic empty returns), DIA-191 class (context estimation overestimate), DIA-130 class (coder-escalated silent failure).

**Why:** The C5 bats file (67 lines) implements 3 scenarios from the ana026 incident corpus. The design.md estimate was ~150 lines. The implementation may be simplified. More scenarios provide better coverage of the failure classes documented in ana026.

**Scope:**

1. Add scenario 4: DIA-206 class (systemic empty returns across multiple lanes)
2. Add scenario 5: DIA-191 class (context estimation overestimate, proxy vs TUI divergence)
3. Add scenario 6: DIA-130 class (coder-escalated silent failure, empty result after long runtime)
4. Verify scenarios exercise the full plugin hook chain (not just file output)

**Effort:** 1 day

**Agents needed:** @coder

**Verification:** C5 bats tests pass, 6 scenarios total.

**Risk if skipped:** Limited test coverage. Future regressions may not be caught.

### 6.8 Priority 8: Monitor D3/D4 in production

**What:** Observe registry.jsonl and messages.jsonl for SILENT_FAILURE and failure_cap_reached events over the next 30 days.

**Why:** The D3/D4 mechanical enforcement is new. False positives (legitimate empty results flagged as failures) or false negatives (real failures not detected) need to be identified and tuned.

**Scope:**

1. Monitor registry.jsonl for SILENT_FAILURE events
2. Monitor messages.jsonl for failure_cap_reached events
3. Tune the 10-minute cooldown window if needed
4. If false positives are frequent: relax D3 detection (e.g., require additional signals beyond zero file edits)
5. If false negatives occur: tighten D3 detection (e.g., add session duration check)

**Effort:** Ongoing

**Agents needed:** @orchestrator

**Verification:** Low false-positive rate, catching real failures.

**Risk if skipped:** D3/D4 may fire false positives (noise) or false negatives (miss real failures). Tuning requires observation.

### 6.9 Priority 9: Add regression tests for DIA-120/126/098/099

**What:** Add regression tests for DIA-120 (terminal-status filter), DIA-126 (catch-all ordering), DIA-098 (stall timer), and DIA-099 (resume protocol).

**Why:** These critical fixes were restart-verified live (DIA-120, DIA-126) or implemented in the plugin (DIA-098, DIA-099), but have no regression tests. If the plugin code changes in the future, these fixes could regress without detection.

**Scope:**

1. Add test for DIA-120: verify plugin does not fire on in-flight log_decision (only terminal status)
2. Add test for DIA-126: verify catch-all deny is FIRST position in permission map
3. Add test for DIA-098: verify 60s sweep fires after inactivity
4. Add test for DIA-099: verify verify-first before re-dispatch (procedural, hard to test mechanically)

**Effort:** 1 day

**Agents needed:** @coder

**Verification:** All new tests pass.

**Risk if skipped:** Future regressions may not be caught. Critical fixes could silently break.

### 6.10 Priority 10: Enforce DIA-175 instance separation via ticket metadata

**What:** Add session_id and lane_id fields to ticket frontmatter. Add a validation script that checks RED/GREEN separation for each ticket.

**Why:** The DIA-175 requirement (RED test-writing and GREEN implementation for the same slice MUST be dispatched to DIFFERENT coder instances) is procedural. The DIA-221 implementation did not enforce this. T2 (C1+C2 tests) and T1 (F-1/F-3 fixes) were implemented in the same session.

**Scope:**

1. Add session_id and lane_id fields to ticket frontmatter
2. Add a validation script (`scripts/validate-dia-175.sh`) that checks RED/GREEN separation for each ticket
3. Wire the validation script into `make test-config`

**Effort:** 0.5 days

**Agents needed:** @coder

**Verification:** Validation script fails when RED/GREEN separation is violated.

**Risk if skipped:** DIA-175 instance separation not enforced. RED/GREEN separation violated, no independent verification.

---

## 7. Risk Assessment

### 7.1 Risk Matrix

```
+----+----------------------------------+----------+----------+-------------+
| #  | Risk                             | Severity | Likelihd | Mitigation  |
+----+----------------------------------+----------+----------+-------------+
| R1 | parallel-handoff.test.mjs blocks | CRITICAL | Certain  | Priority 1  |
|    | make test-harness                |          |          |             |
+----+----------------------------------+----------+----------+-------------+
| R2 | Plugin changes have runtime      | HIGH     | Medium   | Priority 2  |
|    | issues not caught by hermetic    |          |          |             |
|    | tests                            |          |          |             |
+----+----------------------------------+----------+----------+-------------+
| R3 | Restart-verify gap recurs in     | HIGH     | Likely   | Priority 4  |
|    | future changes                   |          |          |             |
+----+----------------------------------+----------+----------+-------------+
| R4 | DIA-206 root cause remains       | MEDIUM   | Certain  | Priority 6  |
|    | unknown, workaround only         |          |          |             |
+----+----------------------------------+----------+----------+-------------+
| R5 | D3/D4 false positives cause      | MEDIUM   | Possible | Priority 8  |
|    | noise                            |          |          |             |
+----+----------------------------------+----------+----------+-------------+
| R6 | D3/D4 false negatives miss real  | MEDIUM   | Possible | Priority 8  |
|    | failures                         |          |          |             |
+----+----------------------------------+----------+----------+-------------+
| R7 | DIA-120/126/098/099 regress      | MEDIUM   | Possible | Priority 9  |
|    | without detection                |          |          |             |
+----+----------------------------------+----------+----------+-------------+
| R8 | DIA-175 instance separation      | LOW      | Possible | Priority 10 |
|    | violated                         |          |          |             |
+----+----------------------------------+----------+----------+-------------+
```

### 7.2 Risk Mitigation Timeline

```
Immediate (next session):
  Priority 1 -> mitigates R1
  Priority 2 -> mitigates R2
  Priority 3 -> confirms R1, R2 mitigated

Short-term (next 7 days):
  Priority 4 -> mitigates R3
  Priority 5 -> closes section 10 gap

Medium-term (next 30 days):
  Priority 6 -> mitigates R4
  Priority 7 -> expands test coverage
  Priority 8 -> mitigates R5, R6
  Priority 9 -> mitigates R7

Long-term (next 90 days):
  Priority 10 -> mitigates R8
```

---

## 8. Summary and Recommendations

### 8.1 Key Findings

1. **DIA-221 delivered significant harness hardening**, but 10 hardening areas remain uncovered, 8 testing gaps exist, 7 enforcement gaps persist, and 5 verification gaps are open.

2. **The #1 priority is fixing the parallel-handoff.test.mjs ARCHIVE_NAME_RE regex**, which DIA-222 broke by adding a UUID suffix to archive filenames. This blocks `make test-harness` entirely.

3. **The #2 priority is restart-verifying the DIA-222/224/225 plugin changes live**. Hermetic tests pass, but runtime behavior under the actual OpenCode process is unconfirmed. This is a critical verification gap.

4. **Restart-verify deferral is a recurring habit**, not a deliberate decision. Making restart-verify a HARD GATE in the section 10 workflow would break the habit and prevent future gaps.

5. **DIA-206 root cause remains unknown**. The D3 empty-result detection provides a mechanical safety net, but the provider-level root cause is undiagnosed. Investigating the root cause is a medium-term priority.

6. **The C5 scenario replay is limited** (3 scenarios, 67 lines). Expanding scenarios to cover DIA-206, DIA-191, DIA-130 classes would improve test coverage.

7. **D3/D4 mechanical enforcement is new** and needs monitoring in production to tune false positives/negatives.

8. **DIA-120/126/098/099 have no regression tests**. These critical fixes could regress without detection.

### 8.2 Recommended Workflow

**Immediate (next session):**

1. Fix parallel-handoff.test.mjs ARCHIVE_NAME_RE regex (Priority 1)
2. Restart-verify DIA-222/224/225 plugin changes live (Priority 2)
3. Run make test-harness with Docker daemon up (Priority 3)

**Short-term (next 7 days):**

4. Make restart-verify a HARD GATE in section 10 workflow (Priority 4)
5. Complete section 10 validation (ai-auditor + CHANGELOG.yaml) (Priority 5)

**Medium-term (next 30 days):**

6. Investigate DIA-206 root cause (Priority 6)
7. Expand C5 scenario replay (Priority 7)
8. Monitor D3/D4 in production (Priority 8)
9. Add regression tests for DIA-120/126/098/099 (Priority 9)

**Long-term (next 90 days):**

10. Enforce DIA-175 instance separation via ticket metadata (Priority 10)

### 8.3 Agent Assignments

| Priority | Agent(s) | Effort |
|----------|----------|--------|
| 1 | @coder | 0.5h |
| 2 | @coder | 0.5d |
| 3 | @coder | 0.5h |
| 4 | @coder, @architector | 1d |
| 5 | @ai-auditor | 0.5d |
| 6 | @researcher | 1d |
| 7 | @coder | 1d |
| 8 | @orchestrator | Ongoing |
| 9 | @coder | 1d |
| 10 | @coder | 0.5d |

**Total effort:** ~6 days (excluding ongoing monitoring)

### 8.4 Conclusion

DIA-221 was a successful experimental pipeline that delivered significant harness hardening. However, the restart-verify gap is a critical verification defect that must be addressed immediately. The parallel-handoff.test.mjs regex break is a known regression that will block `make test-harness` until fixed.

The recommended workflow (immediate, short-term, medium-term, long-term) provides a clear roadmap for completing the DIA-221 hardening effort and preventing similar gaps in the future. The immediate priorities are regex fix, restart-verify, and test-harness validation. The short-term priorities are restart-verify gate enforcement and section 10 completion. The medium-term priorities are DIA-206 root cause investigation, C5 scenario expansion, D3/D4 monitoring, and regression tests for DIA-120/126/098/099. The long-term priority is DIA-175 instance separation enforcement.

The system that manages the system is now tested -- but it is not yet live-verified. That is the next step.

---

**End of report.**
