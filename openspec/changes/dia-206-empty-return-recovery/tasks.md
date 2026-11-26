# Tasks: dia-206-empty-return-recovery

> **Proposal:** `openspec/changes/dia-206-empty-return-recovery/proposal.md`
> **Design:** `openspec/changes/dia-206-empty-return-recovery/design.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice. This is a plugin behavior change - tasks modify `delegation-observer.ts` and add one test file. The @coder follows tdd-craftsman: author the RED test (T3) BEFORE the GREEN implementation (T1/T2), then run the suite. The dependency edges below reflect logical completion order, not the RED/GREEN authoring order.

## Dependency graph

```
T1 (per-lane map + recovery signal on empty_result_detected, below cap)
  └──▶ T2 (at-cap "stopped" transition + failure_cap_reached stop/escalated + idempotency)
        └──▶ T3 (unit test suite: per-lane counting, signal fields, reset, cooldown, exemption)
              └──▶ T4 (verification: openspec validate + bun test in poetry-dev container)
```

**Critical path:** T1 -> T2 -> T3 -> T4
**RED/GREEN note:** T3's test file is authored first (RED) and must FAIL against current code; T1/T2 make it GREEN. T4 runs after T3 is green.

---

## T1 - Per-lane failure map + recovery signal (below cap)

**Blockers:** none
**Vertical slice:** introduce the per-lane state machine and emit `lane_id` + `recovery_action="redispatch"` on every `empty_result_detected` row. This is the core behavioral change: detection now tracks per lane, not per session.

### What changes

1. In `delegation-observer.ts` (~872), replace the per-session `failureCap` map with `laneFailureCap: Map<string, LaneFailureState>` keyed by lane id (agent name from `childSessionAgent.get(sessionID)`, fallback `"subagent"`). Keep `FAILURE_CAP_THRESHOLD=3` and `FAILURE_CAP_COOLDOWN_MS=600_000`.
2. In the `session.idle` empty-result branch (~4054-4087), resolve `laneId`, then look up / increment the per-lane counter (with cooldown-expiry reset, mirroring the existing logic). On each empty result below cap, append the `empty_result_detected` message row with two new fields: `lane_id` and `recovery_action="redispatch"`.
3. Preserve existing reset-on-non-empty and cooldown-expiry delete semantics, now operating on the per-lane map.

### Acceptance criteria (user perspective)

- A lane returning empty on 1 or 2 distinct session ids emits `empty_result_detected` with `lane_id` equal to the lane (e.g. `"coder"`) and `recovery_action="redispatch"`.
- The counter is keyed by lane, so 2 empty results on 2 different session ids for the SAME lane count as 2 consecutive failures (not reset).
- A non-empty result (file edit) for the lane deletes the per-lane entry (reset).
- `READ_ONLY_LANES` and verification-only lanes (DIA-260826-zvu4) remain exempt - no `empty_result_detected` row.

### Verification procedure

- **VP-1:** Drive 2 coder tasks (distinct session ids) with zero edits each; assert 2 `empty_result_detected` rows, both with `lane_id="coder"`, `recovery_action="redispatch"`.
- **VP-2:** Drive 1 coder task with an edit then idle; assert NO `empty_result_detected` row (reset path intact).

### Testing

- Seam O1 (messages.jsonl). No new seam. Test authored in T3 (RED first).

---

## T2 - At-cap "stopped" transition + failure_cap_reached stop signal

**Blockers:** T1
**Vertical slice:** complete the state machine - when a lane reaches the threshold, transition to `"stopped"` and emit `failure_cap_reached` with `recovery_action="stop"` and `resolution_status="escalated"`. Add the idempotency guard so a capped lane does not re-emit.

### What changes

1. In the increment path, when `count` reaches `FAILURE_CAP_THRESHOLD`, set `state="stopped"` and emit `failure_cap_reached` (existing row) now carrying `lane_id`, `recovery_action="stop"`, and `resolution_status="escalated"` (was `"in-flight"`).
2. Add idempotency: if the lane is already `"stopped"`, do not re-increment or re-emit `failure_cap_reached` on subsequent empty results (avoid orchestrator spam). The `empty_result_detected` row may still be emitted for observability, but the cap event is emitted once.
3. Non-empty result or cooldown expiry deletes the entry (already in T1; confirm it also clears a `"stopped"` state).

### Acceptance criteria (user perspective)

- A lane returning empty on 3 distinct session ids emits exactly ONE `failure_cap_reached` row with `lane_id="coder"`, `recovery_action="stop"`, `resolution_status="escalated"`.
- A 4th empty result for the same already-capped lane does NOT emit a second `failure_cap_reached`.
- A non-empty result after cap resets the lane (next empty result starts a fresh count from 1).

### Verification procedure

- **VP-3:** Drive 3 coder tasks (distinct session ids) with zero edits; assert exactly one `failure_cap_reached` with `recovery_action="stop"`, `resolution_status="escalated"`, `lane_id="coder"`.
- **VP-4:** Drive a 4th empty coder task; assert no additional `failure_cap_reached`.
- **VP-5:** After cap, drive an edit + idle (non-empty) then 1 empty; assert counter reset (no new cap).

### Testing

- Seam O1. Test authored in T3 (RED first).

---

## T3 - Unit test suite (empty-return-recovery.test.mjs)

**Blockers:** T1, T2 (logical; RED authored before T1/T2)
**Vertical slice:** a hermetic test file covering the full per-lane recovery behavior, reusing the proven harness from `failure-cap.test.mjs` and `empty-result-detection.test.mjs`.

### What changes

1. **`.opencode/plugins/__tests__/empty-return-recovery.test.mjs`** (new file):
   - Hermetic harness: mkdtemp workspace, `@opencode-ai/plugin` mock registered before import, dynamic `import("../delegation-observer.ts")`, process-exit cleanup (mirror existing suites).
   - Helpers: `registerChild`, `driveTaskDispatch(parentID, childID, agent, prompt)`, `driveToolEdit`, `idleEmpty`, `readNewMessages`, `countMessages`.
   - **Test A (per-lane counting across distinct sessions):** dispatch 3 coder tasks with distinct session ids, idle each with zero edits -> assert `failure_cap_reached` with `lane_id="coder"`, `recovery_action="stop"`. (VP-3)
   - **Test B (signal on each below-cap empty):** 2 coder tasks distinct ids, zero edits -> assert 2 `empty_result_detected` rows with `lane_id="coder"`, `recovery_action="redispatch"`. (VP-1)
   - **Test C (reset on non-empty):** 2 empty + 1 edit + 2 empty for same lane -> no `failure_cap_reached`. (VP-2 + reset)
   - **Test D (cooldown expiry):** 2 empty, advance `Date.now` past `FAILURE_CAP_COOLDOWN_MS`, 1 empty -> no cap.
   - **Test E (idempotency):** 3 empty (cap) + 1 more empty -> exactly one `failure_cap_reached`. (VP-4)
   - **Test F (exemption regression):** coder dispatched with `verification-only` marker + zero edits -> NO `empty_result_detected` (guards DIA-260826-zvu4).

### Acceptance criteria (user perspective)

- All 6 tests exist and assert on seam O1 rows (`lane_id`, `recovery_action`, `resolution_status`).
- Tests are hermetic (fresh mkdtemp per harness, no real project files touched).
- Tests are ASCII-only (DIA-079).
- The file runs via `bun test empty-return-recovery.test.mjs` in the poetry-dev container.

### Verification procedure

- **VP-6:** Run the suite in the container; all 6 tests green. A developer reading the file can trace each assertion to a proposal success criterion.

### Testing

- This IS the test task. No separate automated test of the test.

---

## T4 - Verification and validation

**Blockers:** T3
**Vertical slice:** run the project gates against the change and capture evidence for the @reviewer pass.

### What changes

1. Run `openspec validate` for this change (config gate).
2. Run `bun test empty-return-recovery.test.mjs` inside the poetry-dev container (docker gate per DIA-094 - container must be Up).
3. Run the existing `failure-cap.test.mjs` and `empty-result-detection.test.mjs` to confirm no regression.
4. Capture exit codes + summary lines as verification evidence.

### Acceptance criteria (user perspective)

- `openspec validate` exits 0 for `dia-206-empty-return-recovery`.
- New test suite passes (6/6).
- Existing empty-result + failure-cap suites still pass (no regression).
- Evidence (exit codes + summary) is recorded for the @reviewer two-axis pass.

### Verification procedure

- **VP-7:** `openspec validate` -> 0. `bun test` on the three suites -> all green. Record outputs.

### Testing

- This task runs the tests; no new tests.

---

## Implementation order (suggested)

1. **T3 (RED):** author `empty-return-recovery.test.mjs` first; confirm it FAILS against current code (per tdd-craftsman).
2. **T1 (GREEN part 1):** implement per-lane map + below-cap signal.
3. **T2 (GREEN part 2):** implement at-cap transition + idempotency.
4. **T3 re-run:** confirm 6/6 green.
5. **T4:** `openspec validate` + full suite in container; capture evidence.

## Out of scope for these tasks

- Orchestrator prompt changes (DIA-099 consumer side) - separate change.
- Auto-dispatch/resume in the plugin - explicitly excluded.
- Registry schema / persistence changes.
- Any application code outside `delegation-observer.ts` and the one test file.

---

<!--
ownership:
  substance: AI
  structure: AI
  interview_depth: compressed
-->
