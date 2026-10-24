# Design: dia-221-harness-testing-hardening

> **Proposal:** `openspec/changes/dia-221-harness-testing-hardening/proposal.md`
> **Ticket:** DIA-221
> **Governing tickets:** DIA-085 (parallel handoff slots), DIA-099 (empty-result protocol), DIA-206 (systemic empty-return)
> **Scope:** plugin hardening (delegation-observer.ts) + test infrastructure (S1/S2/S3) + Makefile target
> **Routing:** plugin changes -> section 10 (AI Devtools Modernization Workflow); test infra + Makefile -> section 2.4 (dev-infra)

## Context

The delegation-observer plugin (`~4250 lines`, 5 hooks) is the single point of failure for the orchestration harness. It writes registry.jsonl, messages.jsonl, handoff slots, boot.json, and health.json. Two CRITICAL bugs (F-1 archive collision, F-3 slot identity collapse) remain unfixed from the DIA-085 implementation review. The plugin has 6 test files in `__tests__/` but the two CRITICAL bugs have no regression tests, and the highest-frequency failure class (empty results, 7+ incidents) has only procedural enforcement.

The council consensus scoped this change to: fix F-1/F-3, add mechanical empty-result detection, add a 3-failure cap, establish 5 regression test contracts, and wire `make test-harness`. Everything else from ana025/ana026 is excluded.

## Goals / Non-Goals

**Goals:**

1. Fix F-1 (archive collision) -- same-ms writes produce distinct archive filenames
2. Fix F-3 (slot identity) -- pre-dispatch sessions use sessionId, never "unknown"
3. Mechanical empty-result detection at plugin level (D1/D2/D5 signals)
4. 3-failure cap with cooldown window (warning events, not auto-dispatch)
5. 5 regression test contracts (C1-C5) across 3 test layers (S1/S2/S3)
6. `make test-harness` target wired into `test-infra`

**Non-Goals:**

- Metrics dashboard (excluded by council)
- Incident ledger (excluded by council)
- Evolution cycle formalization (excluded by council)
- Context calibration (excluded by council)
- Batch-dispatch enforcement upgrade (excluded by council)
- DIA-206 root-cause fix (provider-level, referenced not owned)
- Handoff simplification (excluded by council)

## Decisions

### D1: F-1 fix -- UUID suffix for archive disambiguation

**Decision:** append `randomUUID()` to the archive filename: `${sessionId}.${iso}.${uuid}.json`.

**Rationale:** monotonic counter requires process-global state (another Map, cleanup on restart). UUID is zero-state, collision-resistant, and the archive directory is never human-browsed (machine-only). The `renameSync` at line 1355 becomes collision-free because no two UUIDs are the same.

**Alternative considered:** monotonic counter per sessionId (rejected: requires `Map<string, number>`, cleanup on process restart, counter reset risk).

**Code change:** line 1353, `delegation-observer.ts`:

```
// BEFORE:
const archiveName = `${sessionId}.${iso}.json`

// AFTER:
const archiveName = `${sessionId}.${iso}.${randomUUID()}.json`
```

`randomUUID` is already imported at line 42 (`import { createHash, randomUUID } from "node:crypto"`).

### D2: F-3 fix -- sessionId as last-resort slot identity

**Decision:** replace all 5 occurrences of `?? "unknown"` in the slot-identity fallback chain with `?? sessionID` (the actual child session ID from the event context).

**Rationale:** the `"unknown"` fallback was a defensive default that became a correctness bug. The child session ID is always available in the `session.idle` / `session.error` event handlers (it is the `sessionID` parameter). Using it as the last-resort identity means every session gets a unique slot, even pre-dispatch orchestrator sessions that have not yet set `parentSessionId`.

**Code changes:** 5 locations in `delegation-observer.ts`:

| Line | Current                                              | Fixed                                                                                          |
| ---- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| 1196 | `sessionID ?? parentSessionId ?? "unknown"`          | `sessionID ?? parentSessionId ?? sessionID` (no-op, but removes the "unknown" literal)         |
| 3305 | `parentSessionId ?? sessionID ?? "unknown"`          | `parentSessionId ?? sessionID ?? "unidentified-session"` (explicit sentinel, not a shared key) |
| 3512 | `parentSessionId ?? sessionID ?? "unknown"`          | `parentSessionId ?? sessionID ?? "unidentified-session"`                                       |
| 3743 | `parentSessionId ?? args.lane_id ?? "unknown"`       | `parentSessionId ?? args.lane_id ?? context?.sessionID ?? "unidentified-session"`              |
| 3948 | `context?.sessionID ?? parentSessionId ?? "unknown"` | `context?.sessionID ?? parentSessionId ?? "unidentified-session"`                              |

**Key insight:** the fix is NOT to eliminate the fallback -- it is to make the fallback a unique-per-session value (`"unidentified-session"` is a literal sentinel that will never collide because it is only reached when NO session ID is available, which should be impossible in practice; if it IS reached, the unique sentinel makes the bug visible rather than silently merging slots).

**Wait -- reconsidering:** the council consensus says "use actual sessionId as last resort, never 'unknown'". The correct fix at line 3743 (the log_decision handoff path) is:

```
// BEFORE:
const handoffSessionId = parentSessionId ?? args.lane_id ?? "unknown"

// AFTER:
const handoffSessionId = parentSessionId ?? args.lane_id ?? context?.sessionID ?? "unidentified-session"
```

This adds `context?.sessionID` as a fallback BEFORE the sentinel. The sentinel `"unidentified-session"` is a last-resort that should never be reached in practice (there is always SOME session ID available), but if it IS reached, it produces a visible unique key rather than silently merging into `"unknown"`.

### D3: Empty-result detection -- plugin-level SILENT_FAILURE

**Decision:** add empty-result detection in the `session.idle` event handler. When a session goes idle with:

- An empty/whitespace-only task result (check the session's accumulated output)
- AND no files touched (check `sessionWorktrees.get(sessionID)` or the file-edit registry)

Then emit a registry.jsonl row with `dispatch_state: SILENT_FAILURE` and a messages.jsonl warning event.

**Detection signals (DIA-099):**

- D1: `session_complete` + no `task_success` + no file edits -> ~80% SILENT_FAILURE
- D2: `session_failed` with MAXIMUM STEPS -> ~95% CRASH/STEP_CAP
- D5: `stall_detected` with no terminal -> ~90% STALLED

**Implementation approach:** the `session.idle` handler already runs the "A3 silent-failure scan" (line 31 comment). Extend it to:

1. Check if the session produced any file edits (via the `tool.execute.after` hook's edit tracking)
2. Check if the session's accumulated output is empty/whitespace
3. If both are true, emit `SILENT_FAILURE` to registry.jsonl

**Code location:** inside the `session.idle` event handler, after the existing A3 scan logic.

### D4: 3-failure cap -- per-lane counter with cooldown

**Decision:** add a `Map<string, { count: number; firstFailure: number }>` keyed by lane_id. On each SILENT_FAILURE detection (D3), increment the counter. If count reaches 3 within a cooldown window (default 10 minutes), emit a warning event to messages.jsonl. Reset the counter when a non-empty result is observed.

**Why warning-only (not auto-dispatch):** the council consensus explicitly chose warning events over auto-dispatch. Auto-dispatch could prevent legitimate recovery paths (e.g., the empty result might be a reporting artifact, not a failure -- cod-8/cod-9 in ana026). The orchestrator observes the warning and decides.

**Cooldown window:** 10 minutes (configurable via a constant). After 10 minutes without a new failure, the counter resets. This prevents a single bad lane from accumulating failures across hours.

### D5: Rule classification table (advisory vs mechanical)

| Rule                     | Current                    | DIA-221         | Classification       |
| ------------------------ | -------------------------- | --------------- | -------------------- |
| A1 batch-dispatch check  | Advisory (console.warn)    | Unchanged       | ADVISORY             |
| A2 task_id capture       | Mechanical                 | Unchanged       | MECHANICAL           |
| A3 silent-failure scan   | Retroactive (session.idle) | Extended (D3)   | MECHANICAL           |
| A4 append-only registry  | Mechanical                 | Unchanged       | MECHANICAL           |
| A5 final-message gate    | Mechanical                 | Unchanged       | MECHANICAL           |
| C3 forward-only status   | Mechanical                 | Unchanged       | MECHANICAL           |
| DIA-105 edit-time format | Mechanical (non-fatal)     | Unchanged       | MECHANICAL           |
| F-1 archive collision    | BUG (unfixed)              | Fixed (D1)      | MECHANICAL           |
| F-3 slot identity        | BUG (unfixed)              | Fixed (D2)      | MECHANICAL           |
| Empty-result detection   | Procedural (prompt rule)   | Mechanical (D3) | MECHANICAL           |
| 3-failure cap            | Procedural (prompt rule)   | Mechanical (D4) | MECHANICAL (warning) |

### D6: Test maintenance cost estimate

| Test                       | Lines    | Maintenance trigger          | Estimated cost                           |
| -------------------------- | -------- | ---------------------------- | ---------------------------------------- |
| C1: Archive collision      | ~80      | F-1 fix regression           | Low (stable API)                         |
| C2: Slot identity          | ~100     | F-3 fix regression           | Low (stable API)                         |
| C3: Empty-result detection | ~120     | D3 detection logic change    | Medium (detection heuristics may evolve) |
| C4: Failure cap            | ~100     | D4 cap threshold change      | Low (stable API)                         |
| C5: Scenario replay        | ~150     | New incident added to corpus | Medium (new scenarios added over time)   |
| **Total**                  | **~550** |                              | **~2 days/year maintenance**             |

The maintenance cost is low because:

- C1/C2 test fixed bugs -- they only break if the fix is reverted
- C3/C4 test new mechanical enforcement -- they break if the enforcement logic changes (which is the point)
- C5 replays historical incidents -- new incidents add new scenarios, old scenarios never change

### D7: SLO / exit criteria

| SLO                                 | Metric                        | Target                            |
| ----------------------------------- | ----------------------------- | --------------------------------- |
| Zero F-1/F-3 regressions            | C1 + C2 pass rate             | 100% for 30 days                  |
| Empty-result detection coverage     | D1/D2/D5 signals caught by D3 | 100%                              |
| Failure cap prevents infinite loops | C4 pass rate                  | 100%                              |
| All 5 regression contracts pass     | C1-C5                         | 100% on every `make test-harness` |

**Exit criteria for DIA-221:**

1. F-1 fix verified: C1 test passes (two same-ms writes produce distinct archive filenames)
2. F-3 fix verified: C2 test passes (pre-dispatch sessions use sessionId, never "unknown")
3. Empty-result detection verified: C3 test passes (SILENT_FAILURE row emitted)
4. Failure cap verified: C4 test passes (warning event after 3 consecutive failures)
5. Scenario replay verified: C5 test passes (3 incident scenarios replay correctly)
6. `make test-harness` exits 0 with all 5 contracts passing
7. `make test-infra` exits 0 (test-harness wired as dependency)

## Risks / Trade-offs

### R1: Plugin change requires restart

The delegation-observer plugin is loaded at OpenCode process startup. Changes to `delegation-observer.ts` require a hard process restart (kill PID, restart TUI). This is the established pattern (DIA-070 lesson).

**Mitigation:** the test suite (C1-C4) runs against the plugin in isolation (bun test with mock), so tests pass without a full restart. The restart is only needed for live verification.

### R2: "unidentified-session" sentinel could collide

If two sessions both reach the `"unidentified-session"` fallback, they would collide on the same slot. This is the same class as F-3 but at the sentinel level.

**Mitigation:** the sentinel should be unreachable in practice (there is always SOME session ID available). If it IS reached, the collision is a visible bug (two sessions on `"unidentified-session"`) rather than a silent merge (two sessions on `"unknown"`). The visibility is the improvement.

### R3: Empty-result detection false positives

The D3 detection heuristic (empty result + no file edits) could misclassify ambiguous-empty cases (cod-8/cod-9 in ana026: empty result but work actually landed). The detection would emit SILENT_FAILURE incorrectly.

**Mitigation:** the detection emits a registry row and a warning event, NOT an auto-dispatch. The orchestrator observes the warning and applies the verify-first protocol (DIA-099 Variant A2). False positives are cheap (one extra verify-first read) compared to false negatives (silent data loss).

### R4: Failure cap cooldown window tuning

The 10-minute cooldown is a guess. Too short: legitimate retries across a brief outage are counted as a loop. Too long: a real loop runs for 10 minutes before the warning fires.

**Mitigation:** the cooldown is a configurable constant. Start with 10 minutes, adjust based on observed behavior. The warning is informational, not blocking, so tuning is low-risk.

## Cross-references

| Ticket  | Relationship                                                                                  |
| ------- | --------------------------------------------------------------------------------------------- |
| DIA-085 | F-1/F-3 are unfixed findings from the DIA-085 implementation review                           |
| DIA-099 | Empty-result detection implements the mechanical enforcement DIA-099 called for               |
| DIA-206 | Referenced as a DIA-206-class failure; root cause is provider-level, not owned by this change |
| DIA-120 | Terminal-status filter for handoff writer (already fixed, not affected by this change)        |
| DIA-124 | Handoff-before-presentation rule (procedural, not affected by this change)                    |
| DIA-130 | coder-escalated silent failure -- one of the incidents D3 would have caught                   |
| DIA-132 | Empty-result detection research (res020) -- grounds the D3 design                             |
| DIA-175 | Instance separation -- tests follow RED/GREEN instance separation                             |

## Seams

| Seam                       | What it is                                      | Test location                                                         | Test type                   |
| -------------------------- | ----------------------------------------------- | --------------------------------------------------------------------- | --------------------------- |
| **F-1 archive collision**  | `atomicWriteHandoff` archive name generation    | `.opencode/plugins/__tests__/handoff-archive-collision.test.mjs` (C1) | bun hermetic test           |
| **F-3 slot identity**      | `log_decision` handoff slot identity resolution | `.opencode/plugins/__tests__/handoff-slot-identity.test.mjs` (C2)     | bun hermetic test           |
| **Empty-result detection** | `session.idle` handler SILENT_FAILURE emission  | `.opencode/plugins/__tests__/empty-result-detection.test.mjs` (C3)    | bun hermetic test           |
| **Failure cap**            | Per-lane consecutive-failure counter            | `.opencode/plugins/__tests__/failure-cap.test.mjs` (C4)               | bun hermetic test           |
| **Scenario replay**        | End-to-end incident reproduction                | `scripts/__tests__/harness-scenario-replay.bats` (C5)                 | bats (S3)                   |
| **Makefile target**        | `test-harness` wiring                           | `Makefile`                                                            | `make test-harness` exits 0 |

## Files changed

| File                                                             | Change                                                                                | Notes              |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ------------------ |
| `.opencode/plugins/delegation-observer.ts`                       | F-1 fix (line 1353), F-3 fix (5 locations), D3 empty-result detection, D4 failure cap | Plugin hardening   |
| `.opencode/plugins/__tests__/handoff-archive-collision.test.mjs` | New file (~80 lines)                                                                  | C1 regression test |
| `.opencode/plugins/__tests__/handoff-slot-identity.test.mjs`     | New file (~100 lines)                                                                 | C2 regression test |
| `.opencode/plugins/__tests__/empty-result-detection.test.mjs`    | New file (~120 lines)                                                                 | C3 regression test |
| `.opencode/plugins/__tests__/failure-cap.test.mjs`               | New file (~100 lines)                                                                 | C4 regression test |
| `scripts/__tests__/harness-scenario-replay.bats`                 | New file (~150 lines)                                                                 | C5 scenario replay |
| `Makefile`                                                       | New `test-harness` target, wired into `test-infra`                                    | Gate wiring        |
