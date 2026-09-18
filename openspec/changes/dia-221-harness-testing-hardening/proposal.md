# Proposal: dia-221-harness-testing-hardening

> **Status:** proposed
> **Scope:** plugin hardening (delegation-observer.ts) + test infrastructure (S1/S2/S3 layers) + Makefile target
> **Ticket:** DIA-221 "Evolutional harness infrastructure testing and hardening"
> **Governing tickets:** DIA-085 (parallel handoff slots), DIA-099 (empty-result protocol), DIA-206 (systemic empty-return)
> **Evidence basis:** ana025 (harness research conspect), ana026 (agentic flow failures analysis), council consensus synthesis
> **Routing:** AGENTS.md section 2.5 (OpenCode Configuration Changes) -- delegation-observer.ts is a plugin, plugin changes route through section 10 workflow. Test infrastructure (Makefile, bats, bun tests) is dev-infra (section 2.4).

## Why

The orchestration harness has **two unfixed CRITICAL design falsifications** (DIA-085 F-1 archive collision, F-3 slot identity collapse) that silently destroy handoff prognoses under parallel sessions, and **zero mechanical enforcement** for its most critical runtime protocols (empty-result detection, failure caps). These are not theoretical risks -- ana026 documents 35+ incidents across 2026-08-03 to 2026-08-17, with 7+ silent-delegation incidents alone.

The council consensus corrects a key baseline error in ana025: the claim of "zero tests" is wrong. Six plugin test files exist in `.opencode/plugins/__tests__/` (parallel-handoff.test.mjs, circuit-breaker.test.mjs, context-velocity.test.mjs, dia217-ticket-gate.test.mjs, dia220-apoptosis-paracrine.test.mjs, needs-input-observer.dia189.test.mjs), and `batch-d-infra.test.mjs` has 56 tests wired into `make test-config`. The real gap is: **tests exist but are not wired into gates, and the two CRITICAL bugs have no regression tests**.

This change fixes the two CRITICAL bugs, adds mechanical enforcement for the two highest-frequency failure classes (empty results, infinite retry loops), establishes a 3-layer regression test suite, and wires it all into a `make test-harness` target.

## What Changes

### P0: Fix F-1/F-3 (archive collision + slot identity)

**F-1 (CRITICAL):** `archiveName` at line 1353 uses `${sessionId}.${iso}.json` where `iso` is millisecond-resolution ISO timestamp. Same-millisecond double-fire produces identical `archiveName`; POSIX `renameSync` silently replaces the first archived prognosis. Fix: append a monotonic counter or UUID suffix to disambiguate.

**F-3 (CRITICAL):** Slot identity fallback chain `parentSessionId ?? lane_id ?? "unknown"` at lines 1196, 3305, 3512, 3743, 3948 collapses pre-dispatch parallel sessions to the same `"unknown"` key, causing last-writer-wins clobber on `handoffs/unknown.json`. Fix: use actual `sessionId` (the child session ID from the event) as the last-resort identity, never `"unknown"`.

### P1: Mechanical empty-result detection

Add plugin-level detection in the `session.idle` handler: when a task result is empty/whitespace AND no files were touched by the session, emit a `SILENT_FAILURE` dispatch_state to registry.jsonl and a warning event to messages.jsonl. This covers DIA-099 signals D1 (session_complete + no task_success + no file edits), D2 (session_failed with MAXIMUM STEPS), and D5 (stall_detected with no terminal). Detection is mechanical (plugin-level), not procedural (orchestrator prompt rule).

### P2: 3-failure cap with cooldown window

Add a plugin-level counter per lane that tracks consecutive empty results. After 3 consecutive failures within a cooldown window (configurable, default 10 minutes), emit a warning event to messages.jsonl. The cap does NOT auto-dispatch or auto-block -- it emits a warning that the orchestrator can observe. This prevents the infinite retry loop pattern documented in ana026 section 4.1 (5+ occurrences).

### P3: 5 regression test contracts

| Contract                   | Layer     | Location                                                         | What it tests                                                            |
| -------------------------- | --------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------ |
| C1: Archive collision      | S2 (bun)  | `.opencode/plugins/__tests__/handoff-archive-collision.test.mjs` | F-1 fix: two same-ms writes produce distinct archive filenames           |
| C2: Slot identity          | S2 (bun)  | `.opencode/plugins/__tests__/handoff-slot-identity.test.mjs`     | F-3 fix: pre-dispatch sessions use sessionId, never "unknown"            |
| C3: Empty-result detection | S2 (bun)  | `.opencode/plugins/__tests__/empty-result-detection.test.mjs`    | P1: session.idle with empty result + no file edits -> SILENT_FAILURE row |
| C4: Failure cap            | S2 (bun)  | `.opencode/plugins/__tests__/failure-cap.test.mjs`               | P2: 3 consecutive empties within cooldown -> warning event               |
| C5: Scenario replay        | S3 (bats) | `scripts/__tests__/harness-scenario-replay.bats`                 | End-to-end replay of 3 incident scenarios from ana026 corpus             |

### P4: `make test-harness` target

New Makefile target that runs all S1 + S2 + S3 tests. S1 (bats) runs host-fast via `bats-wrapper.sh`. S2 (bun) runs in-container via `docker compose exec dev bun test`. S3 (bats scenario replay) runs via `bats-wrapper.sh`. Wired into `test-infra` (which already pulls in `test-shell`).

### P5: DIA-206 reference (not owned)

DIA-206 is a provider-level systemic issue (5 empty returns across ai-specialist, coder, researcher in one day). This change references DIA-206 in the design.md cross-references but does NOT own its root-cause fix. The P1 empty-result detection provides a mechanical safety net that catches DIA-206-class failures regardless of root cause.

## Capabilities

### New Capabilities

- `harness-empty-result-detection`: plugin-level mechanical detection of empty task results (D1/D2/D5 signals)
- `harness-failure-cap`: plugin-level consecutive-failure counter with cooldown window

### Modified Capabilities

(none -- this is a hardening change, not a capability change)

## Impact

**Affected code:**

- `.opencode/plugins/delegation-observer.ts` -- F-1 fix (archive name disambiguation), F-3 fix (slot identity fallback), P1 empty-result detection, P2 failure cap
- `Makefile` -- new `test-harness` target
- `.opencode/plugins/__tests__/` -- 4 new bun test files (C1-C4)
- `scripts/__tests__/` -- 1 new bats file (C5 scenario replay)

**Affected gates:**

- `make test-harness` (new target)
- `make test-infra` (gains `test-harness` as a dependency)

**Not affected:**

- `make test-config` (unchanged -- batch-d-infra.test.mjs already wired here)
- `make test-shell` (unchanged -- S1 bats auto-discovered by bats-wrapper)
- `opencode.jsonc` / `oh-my-opencode-slim.jsonc` (no config changes)
- `.sdd/` (no architecture decisions -- within existing plugin module boundary)

## Testing Decisions

### What makes a good test here

This is harness hardening -- the tests verify **bug fixes and mechanical enforcement**, not business logic. A good test is one that:

- **F-1/F-3 regression tests (C1, C2):** deterministically reproduce the CRITICAL bugs with the OLD code (would fail) and pass with the NEW code. Use the same hermetic harness pattern as `parallel-handoff.test.mjs` (fresh mkdtemp workspace, mock `@opencode-ai/plugin`, dynamic import of the real plugin).
- **Empty-result detection test (C3):** drives the `session.idle` event handler with a fixture that has an empty task result and no file edits, then asserts the registry.jsonl row has `dispatch_state: SILENT_FAILURE`.
- **Failure cap test (C4):** drives 3 consecutive `session.idle` events with empty results within the cooldown window, then asserts a warning event appears in messages.jsonl.
- **Scenario replay (C5):** replays 3 incident scenarios from the ana026 corpus as bats tests, asserting the plugin's observable output (registry rows, messages rows, handoff files) matches the expected post-fix behavior.

### Test infrastructure (3 layers)

| Layer                        | Where                                | What                                                                    | Run                                                  |
| ---------------------------- | ------------------------------------ | ----------------------------------------------------------------------- | ---------------------------------------------------- |
| S1: Host-fast contract tests | `scripts/__tests__/` (bats)          | Validate scripts, handoff, gate logic                                   | `make test-config` (via bats-wrapper auto-discovery) |
| S2: Plugin hermetic tests    | `.opencode/plugins/__tests__/` (bun) | Plugin writer, delegation observer, empty-result detection, failure cap | `bun test` (in-container)                            |
| S3: Scenario replay          | `scripts/__tests__/` (bats)          | Regression tests from incident corpus                                   | `make test-infra` (via bats-wrapper)                 |

### Prior art in the codebase

- **Hermetic plugin test pattern:** `parallel-handoff.test.mjs` (584 lines, 9 tests) -- mock `@opencode-ai/plugin`, dynamic import, fresh mkdtemp workspace, real plugin execution. This is the template for C1-C4.
- **bats-wrapper auto-discovery:** `scripts/__tests__/bats-wrapper.sh` discovers all `.bats` files in `scripts/__tests__/` (excluding vendor/). C5 is auto-discovered.
- **batch-d-infra.test.mjs:** 56 tests wired into `make test-config` via `node scripts/__tests__/batch-d-infra.test.mjs`. This is the existing plugin-adjacent test pattern.

### What we explicitly do NOT test

- DIA-206 root cause (provider-level, not harness-level)
- Metrics dashboard (excluded by council)
- Incident ledger (excluded by council)
- Context calibration (excluded by council)
- Batch-dispatch enforcement upgrade (excluded by council)

## Alternatives considered

- **Status quo (do nothing):** rejected because F-1/F-3 are CRITICAL unfixed design falsifications that silently destroy data. The council consensus is that these must be fixed before any other hardening.
- **Full ana025 recommendation set (P0-P7):** rejected because P1 (incident ledger), P3 (context calibration), P5 (batch-dispatch enforcement), P6 (metrics dashboard), P7 (evolution cycle) are out of scope per council consensus. The council scoped this change to the highest-leverage items: F-1/F-3 fixes, mechanical enforcement, regression tests.
- **S1-only tests (bats, no bun):** rejected because the F-1/F-3 fixes are in the TypeScript plugin, which requires the bun test harness (mock `@opencode-ai/plugin`, dynamic import). bats cannot test TypeScript plugin internals.
- **S2-only tests (bun, no bats):** rejected because scenario replay (C5) needs to drive the full harness (scripts + plugin + file system) end-to-end, which is a bats-shaped test.
- **Blocking failure cap (throw error after 3 failures):** rejected because auto-blocking could prevent legitimate recovery paths. The council consensus is warning-only, letting the orchestrator decide.
- Chosen option: council consensus scope (P0-P4) with 3-layer test infrastructure (S1/S2/S3) -- because it fixes the two CRITICAL bugs, adds mechanical enforcement for the two highest-frequency failure classes, and establishes regression tests without over-reaching into excluded scope.
