# Tasks: dia-221-harness-testing-hardening

> **Proposal:** `openspec/changes/dia-221-harness-testing-hardening/proposal.md`
> **Design:** `openspec/changes/dia-221-harness-testing-hardening/design.md`
> **Ticket:** DIA-221
> **Routing:** plugin changes -> section 10 (AI Devtools Modernization Workflow); test infra + Makefile -> section 2.4 (dev-infra)
> **Instance separation (DIA-175):** RED test-writing and GREEN implementation for the same slice MUST be dispatched to DIFFERENT coder instances.

## Dependency graph

```
T1 -- F-1/F-3 bug fixes (delegation-observer.ts)
 |  fixes archive collision (line 1353) + slot identity (5 locations)
 |  no dependencies
 |
 |  verification: C1 + C2 tests pass (bun test)
 |
 |  +------------------------------------------------------------+
 |  | T2 depends on T1 (tests verify the fix)                     |
 |  +------------------------------------------------------------+
 v
T2 -- C1 + C2 regression tests (bun, hermetic)
 |  handoff-archive-collision.test.mjs + handoff-slot-identity.test.mjs
 |  depends on T1 (tests verify the fix)
 |
 |  verification: bun test passes (2 new test files)
 |
 |  +------------------------------------------------------------+
 |  | T3 depends on T1 (detection logic builds on fixed plugin)   |
 |  +------------------------------------------------------------+
 v
T3 -- D3 empty-result detection (delegation-observer.ts)
 |  plugin-level SILENT_FAILURE emission in session.idle handler
 |  depends on T1 (detection logic builds on fixed plugin)
 |
 |  verification: C3 test passes (bun test)
 |
 |  +------------------------------------------------------------+
 |  | T4 depends on T3 (cap counts SILENT_FAILURE events from D3) |
 |  +------------------------------------------------------------+
 v
T4 -- D4 failure cap + C4 test (delegation-observer.ts + bun test)
 |  per-lane counter with cooldown + failure-cap.test.mjs
 |  depends on T3 (cap counts SILENT_FAILURE events from D3)
 |
 |  verification: C4 test passes (bun test)
 |
 |  +------------------------------------------------------------+
 |  | T5 depends on T1-T4 (scenario replay exercises all fixes)   |
 |  +------------------------------------------------------------+
 v
T5 -- C5 scenario replay (bats) + make test-harness target
 |  harness-scenario-replay.bats + Makefile target
 |  depends on T1-T4 (scenario replay exercises all fixes)
 |
 |  verification: make test-harness exits 0
 |
 |  +------------------------------------------------------------+
 |  | T6 depends on T5 (final gate wiring)                        |
 |  +------------------------------------------------------------+
 v
T6 -- Wire test-harness into test-infra + section 10 validation
   Makefile: test-infra depends on test-harness
   Section 10 workflow: ai-specialist research + ai-auditor review

   verification: make test-infra exits 0 (includes test-harness)
```

**Critical path:** T1 -> T2 -> T3 -> T4 -> T5 -> T6 (linear). Each slice is sized for one fresh context window.

**Rationale for six slices:**

- **T1 (bug fixes):** the two CRITICAL fixes are the foundation. Without them, the regression tests (T2) have nothing to verify.
- **T2 (C1+C2 tests):** the regression tests for F-1/F-3 are tightly coupled (both test the handoff writer). They form one coherent slice.
- **T3 (empty-result detection):** a new feature in the plugin, independent of the bug fixes. Builds on the fixed plugin (T1) because the detection logic lives in the same handler.
- **T4 (failure cap + C4 test):** the cap counts SILENT_FAILURE events from D3, so it depends on T3. The test (C4) is small enough to bundle with the implementation.
- **T5 (C5 scenario replay + Makefile target):** the scenario replay exercises all fixes end-to-end. The Makefile target wires the tests into a single command.
- **T6 (gate wiring + section 10):** final wiring. test-harness becomes a dependency of test-infra. Section 10 validation ensures the plugin change followed the AI Devtools Modernization Workflow.

---

## T1 -- F-1/F-3 bug fixes (delegation-observer.ts)

**Blockers:** none
**Vertical slice:** fix the two CRITICAL bugs in delegation-observer.ts. After T1, the archive name is collision-free and the slot identity never falls back to "unknown".
**Routing:** section 10 (plugin change) -> @ai-specialist research -> @coder implementation -> @ai-auditor review
**DIA-175:** this is the GREEN implementation. The RED tests (T2) are written by a DIFFERENT instance.

### Sub-steps

**Sub-step (a): F-1 fix -- archive name disambiguation**

- Line 1353: change `const archiveName = \`${sessionId}.${iso}.json\``to`const archiveName = \`${sessionId}.${iso}.${randomUUID()}.json\``
- `randomUUID` is already imported at line 42

**Sub-step (b): F-3 fix -- slot identity fallback chain**

- Line 1196: `sessionID ?? parentSessionId ?? "unknown"` -> `sessionID ?? parentSessionId ?? sessionID` (removes the "unknown" literal; the fallback is now the actual session ID)
- Line 3305: `parentSessionId ?? sessionID ?? "unknown"` -> `parentSessionId ?? sessionID ?? "unidentified-session"`
- Line 3512: `parentSessionId ?? sessionID ?? "unknown"` -> `parentSessionId ?? sessionID ?? "unidentified-session"`
- Line 3743: `parentSessionId ?? args.lane_id ?? "unknown"` -> `parentSessionId ?? args.lane_id ?? context?.sessionID ?? "unidentified-session"`
- Line 3948: `context?.sessionID ?? parentSessionId ?? "unknown"` -> `context?.sessionID ?? parentSessionId ?? "unidentified-session"`

**Sub-step (c): Verification**

1. `grep -n '"unknown"' .opencode/plugins/delegation-observer.ts` returns zero matches in the slot-identity fallback chain (5 locations fixed)
2. `grep -n 'randomUUID' .opencode/plugins/delegation-observer.ts` shows the import (line 42) and the new usage (line 1353)
3. TypeScript type-check passes (no new type errors)

### Acceptance criteria (T1)

1. Archive filename includes UUID suffix (line 1353)
2. All 5 slot-identity fallback chains no longer use `"unknown"` as the last-resort key
3. Line 3743 (log_decision handoff path) adds `context?.sessionID` as a fallback before the sentinel
4. No new TypeScript type errors
5. Plugin still loads (no syntax errors)

---

## T2 -- C1 + C2 regression tests (bun, hermetic)

**Blockers:** T1 (tests verify the fix)
**Vertical slice:** two bun test files that verify F-1 and F-3 fixes. After T2, `bun test` passes with 2 new test files.
**Routing:** section 10 (plugin test) -> @coder implementation (DIFFERENT instance from T1 per DIA-175)
**DIA-175:** this is the RED test-writing. A DIFFERENT instance wrote the GREEN implementation (T1).

### Sub-steps

**Sub-step (a): C1 -- handoff-archive-collision.test.mjs**

- New file: `.opencode/plugins/__tests__/handoff-archive-collision.test.mjs` (~80 lines)
- Pattern: mirror `parallel-handoff.test.mjs` (mock `@opencode-ai/plugin`, dynamic import, fresh mkdtemp workspace)
- Test: call `atomicWriteHandoff` twice with the same sessionId within the same millisecond. Assert that two distinct archive files are created (different UUID suffixes).
- Assertion: `readdirSync(archiveDir).length === 2` and the two filenames differ

**Sub-step (b): C2 -- handoff-slot-identity.test.mjs**

- New file: `.opencode/plugins/__tests__/handoff-slot-identity.test.mjs` (~100 lines)
- Pattern: mirror `parallel-handoff.test.mjs`
- Test 1: call `log_decision` with `event_type: 'handoff'` from a session that has no `parentSessionId` set. Assert the slot file is named after the actual `sessionID`, not `"unknown"`.
- Test 2: call `log_decision` from two different sessions with no `parentSessionId`. Assert two distinct slot files are created (not a single `"unknown.json"` clobber).
- Assertion: `existsSync(join(handoffsDir, 'unknown.json')) === false`

**Sub-step (c): Verification**

1. `cd .opencode/plugins/__tests__ && bun test handoff-archive-collision.test.mjs` exits 0
2. `cd .opencode/plugins/__tests__ && bun test handoff-slot-identity.test.mjs` exits 0
3. Both tests FAIL if T1 is reverted (verify the tests actually test the fix)

### Acceptance criteria (T2)

1. C1 test file exists with at least 1 test case
2. C2 test file exists with at least 2 test cases
3. Both tests pass with T1 applied
4. Both tests fail if T1 is reverted (regression detection)
5. Tests follow the hermetic pattern (fresh mkdtemp, mock `@opencode-ai/plugin`, dynamic import)

---

## T3 -- D3 empty-result detection (delegation-observer.ts)

**Blockers:** T1 (detection logic builds on fixed plugin)
**Vertical slice:** add mechanical empty-result detection in the `session.idle` handler. After T3, empty results with no file edits emit a SILENT_FAILURE registry row.
**Routing:** section 10 (plugin change) -> @coder implementation

### Sub-steps

**Sub-step (a): Extend session.idle handler**

- In the `session.idle` event handler (around line 3200+), after the existing A3 silent-failure scan:
  1. Check if the session produced any file edits (via the `tool.execute.after` hook's edit tracking -- the `sessionFileEdits` Map or equivalent)
  2. Check if the session's accumulated output is empty/whitespace (check the session's message history or the task result)
  3. If both are true, emit a registry.jsonl row with `dispatch_state: SILENT_FAILURE`
  4. Emit a messages.jsonl warning event with `gen_ai.operation.name: 'empty_result_detected'`

**Sub-step (b): Verification**

1. C3 test passes (see T4 for the test -- bundled with T4 for efficiency)
2. Manual verification: dispatch a subagent that returns empty, observe registry.jsonl for SILENT_FAILURE row

### Acceptance criteria (T3)

1. `session.idle` handler checks for empty result + no file edits
2. SILENT_FAILURE row emitted to registry.jsonl when both conditions are true
3. Warning event emitted to messages.jsonl
4. Detection does NOT auto-dispatch or auto-block (warning only)
5. No false positives for sessions that produced file edits (even with empty text output)

---

## T4 -- D4 failure cap + C3/C4 tests (delegation-observer.ts + bun tests)

**Blockers:** T3 (cap counts SILENT_FAILURE events from D3)
**Vertical slice:** add per-lane failure counter + two bun test files (C3 empty-result detection, C4 failure cap). After T4, 3 consecutive empty results within the cooldown window emit a warning event.
**Routing:** section 10 (plugin change + tests) -> @coder implementation

### Sub-steps

**Sub-step (a): D4 failure cap implementation**

- Add a `Map<string, { count: number; firstFailure: number }>` keyed by lane_id (or session_id if lane_id is not available)
- On each SILENT_FAILURE detection (T3), increment the counter for that lane
- If count reaches 3 within a cooldown window (default 10 minutes = 600000 ms), emit a warning event to messages.jsonl with `gen_ai.operation.name: 'failure_cap_reached'`
- Reset the counter when a non-empty result is observed from the same lane
- Cooldown: if `Date.now() - firstFailure > 600000`, reset the counter before incrementing

**Sub-step (b): C3 -- empty-result-detection.test.mjs**

- New file: `.opencode/plugins/__tests__/empty-result-detection.test.mjs` (~120 lines)
- Test: simulate a `session.idle` event with an empty task result and no file edits. Assert registry.jsonl contains a row with `dispatch_state: SILENT_FAILURE`.
- Test: simulate a `session.idle` event with file edits present. Assert NO SILENT_FAILURE row is emitted.

**Sub-step (c): C4 -- failure-cap.test.mjs**

- New file: `.opencode/plugins/__tests__/failure-cap.test.mjs` (~100 lines)
- Test: simulate 3 consecutive `session.idle` events with empty results within 10 minutes. Assert messages.jsonl contains a `failure_cap_reached` warning event.
- Test: simulate 2 consecutive empty results, then a non-empty result, then 2 more empty results. Assert NO `failure_cap_reached` event (counter reset on non-empty).
- Test: simulate 2 consecutive empty results, wait 11 minutes (mock Date.now), then 1 more empty result. Assert NO `failure_cap_reached` event (cooldown expired, counter reset).

**Sub-step (d): Verification**

1. `cd .opencode/plugins/__tests__ && bun test empty-result-detection.test.mjs` exits 0
2. `cd .opencode/plugins/__tests__ && bun test failure-cap.test.mjs` exits 0
3. All 4 bun test files pass together: `cd .opencode/plugins/__tests__ && bun test` exits 0

### Acceptance criteria (T4)

1. Failure cap counter tracks consecutive SILENT_FAILURE events per lane
2. Warning event emitted after 3 consecutive failures within 10-minute cooldown
3. Counter resets on non-empty result
4. Counter resets after cooldown window expires
5. C3 test passes (empty-result detection works)
6. C4 test passes (failure cap works)

---

## T5 -- C5 scenario replay (bats) + make test-harness target

**Blockers:** T1-T4 (scenario replay exercises all fixes)
**Vertical slice:** bats scenario replay file + Makefile target. After T5, `make test-harness` exits 0 with all 5 contracts passing.
**Routing:** section 2.4 (dev-infra) -> @coder implementation -> @reviewer review

### Sub-steps

**Sub-step (a): C5 -- harness-scenario-replay.bats**

- New file: `scripts/__tests__/harness-scenario-replay.bats` (~150 lines)
- 3 scenario replays from the ana026 incident corpus:
  1. **Scenario 1 (DIA-130 class):** coder-escalated returns empty result. Assert SILENT_FAILURE row in registry.jsonl.
  2. **Scenario 2 (DIA-085 F-1 class):** two parallel handoff writes within same millisecond. Assert both archive files exist (distinct UUIDs).
  3. **Scenario 3 (DIA-085 F-3 class):** two pre-dispatch orchestrator sessions write handoffs. Assert two distinct slot files (not a single "unknown.json" clobber).
- Each scenario sets up a fresh mkdtemp workspace, drives the plugin, and asserts the observable output.

**Sub-step (b): Makefile test-harness target**

- Add to Makefile:
  ```makefile
  test-harness:
  	bash scripts/__tests__/bats-wrapper.sh --filter harness-scenario-replay
  	docker compose exec -T dev bash -lc 'cd /workspace/.opencode/plugins/__tests__ && bun test'
  ```
- The bats-wrapper runs C5 (S3). The bun test runs C1-C4 (S2). S1 tests are already auto-discovered by `make test-shell` via bats-wrapper.

**Sub-step (c): Verification**

1. `make test-harness` exits 0
2. C5 bats tests pass (3 scenarios)
3. C1-C4 bun tests pass (4 test files)
4. Total: 5 contracts, all passing

### Acceptance criteria (T5)

1. C5 bats file exists with 3 scenario replay tests
2. `make test-harness` target exists in Makefile
3. `make test-harness` exits 0 with all 5 contracts passing
4. Scenarios are reproducible (deterministic, no flaky tests)

---

## T6 -- Wire test-harness into test-infra + section 10 validation

**Blockers:** T5 (test-harness target must exist before wiring)
**Vertical slice:** wire test-harness as a dependency of test-infra. Validate section 10 workflow was followed. After T6, `make test-infra` includes test-harness.
**Routing:** section 2.4 (Makefile) + section 10 (plugin change validation)

### Sub-steps

**Sub-step (a): Makefile wiring**

- Change `test-infra` dependency to include `test-harness`:
  ```makefile
  test-infra: gen-jsconfig test-shell test-harness
  ```
- Or add `test-harness` as a prerequisite of `test-infra` (depending on the desired ordering)

**Sub-step (b): Section 10 validation**

- Verify the section 10 workflow was followed for the plugin change:
  1. @ai-specialist research dispatched and findings registered
  2. User reviewed and approved the design
  3. @coder implemented the approved design
  4. @ai-auditor reviewed the implemented change
  5. CHANGELOG.yaml entry appended
- This is a process validation, not a code change. The orchestrator verifies the workflow was followed.

**Sub-step (c): Verification**

1. `make test-infra` exits 0 (includes test-harness)
2. Section 10 workflow artifacts exist (ai-specialist findings, ai-auditor review, CHANGELOG entry)

### Acceptance criteria (T6)

1. `test-infra` depends on `test-harness` in Makefile
2. `make test-infra` exits 0 with all tests passing (including test-harness)
3. Section 10 workflow was followed for the plugin change
4. CHANGELOG.yaml has a DIA-221 entry

---

## Out of scope for these tasks

- **Metrics dashboard** (excluded by council)
- **Incident ledger** (excluded by council)
- **Evolution cycle formalization** (excluded by council)
- **Context calibration** (excluded by council)
- **Batch-dispatch enforcement upgrade** (excluded by council)
- **DIA-206 root-cause fix** (provider-level, referenced not owned)
- **Handoff simplification** (excluded by council)
- **Section 10 routing for test infrastructure** (N/A -- Makefile/bats/bun are dev-infra, not AI-tooling config)

## Verification gate summary

| Gate                | When          | Required                                                                                 |
| ------------------- | ------------- | ---------------------------------------------------------------------------------------- |
| F-1 fix applied     | T1 sub-step c | `grep -n 'randomUUID' delegation-observer.ts` shows line 1353                            |
| F-3 fix applied     | T1 sub-step c | `grep -n '"unknown"' delegation-observer.ts` returns zero matches in slot-identity chain |
| C1 test passes      | T2 sub-step c | `bun test handoff-archive-collision.test.mjs` exits 0                                    |
| C2 test passes      | T2 sub-step c | `bun test handoff-slot-identity.test.mjs` exits 0                                        |
| C3 test passes      | T4 sub-step d | `bun test empty-result-detection.test.mjs` exits 0                                       |
| C4 test passes      | T4 sub-step d | `bun test failure-cap.test.mjs` exits 0                                                  |
| C5 test passes      | T5 sub-step c | `bats scripts/__tests__/harness-scenario-replay.bats` exits 0                            |
| `make test-harness` | T5 sub-step c | exits 0 with all 5 contracts passing                                                     |
| `make test-infra`   | T6 sub-step c | exits 0 (includes test-harness)                                                          |
| Section 10 workflow | T6 sub-step b | ai-specialist + ai-auditor + CHANGELOG artifacts exist                                   |
