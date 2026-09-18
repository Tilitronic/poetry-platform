## Why

The delegation-observer plugin emits a `session_boot` registry row and writes a `boot.json` marker unconditionally at plugin load (L955, L966), then starts a 60s stall-sweep interval (L2409). On a real in-process reload (plugin re-evaluated without full process restart), the plugin body re-runs: a second `session_boot` row is appended, a second `boot.json` is written with a new `boot_id`, and a second `stallSweepInterval` is created. The prior interval is only cleared in the `dispose` hook (L4632); if reload does not invoke `dispose` first, two intervals run concurrently, doubling every sweep and the `stall_detected` emission risk. The registry accumulates duplicate boot evidence that breaks the "one boot_id per process start" invariant DIA-123 boot determinism relies on.

## What Changes

- Add process-scoped boot identity via `globalThis`: before emitting boot evidence, check `globalThis[Symbol.for("delegation-observer.bootEmitted")]`; if true, skip `appendRow` + `atomicWriteBootMarker` (plugin module re-evaluation in same process); if false, emit boot evidence and set the flag. A full OpenCode process restart always emits a new `session_boot` (no time-based dedup across restarts).
- Keep `boot.json` as the persisted audit marker (DIA-123 design), not process identity. `boot.json` is written on every boot emission but not read for dedup.
- Make the stall-sweep ticker disposal-safe and single-instance: store the interval handle in `globalThis[Symbol.for("delegation-observer.stallSweepInterval")]` so a reload clears/reuses the prior interval rather than stacking a second one. `dispose` clears the `globalThis` Symbol.
- Add two focused deterministic unit tests: (1) process-scoped boot identity — invoke factory twice in same process, assert second invocation suppresses boot emission (no new `session_boot` row); (2) interval singleton — invoke factory twice, assert `globalThis` Symbol handle is replaced (prior cleared), assert `dispose()` clears the Symbol.

## Capabilities

### New Capabilities

None. This is a reliability fix within an existing plugin; no new capabilities are introduced.

### Modified Capabilities

None. The plugin's observable behavior (boot evidence emission, stall detection) does not change at the spec level — only the internal dedup and singleton mechanics change to prevent duplicate emissions on reload.

## Impact

- **Code:** `.opencode/plugins/delegation-observer.ts` — three sites modified:
  - L927-966: boot evidence emission block wrapped in `if (!shouldSkipBootDedup())` guard
  - L2405-2417: `stallSweepInterval` creation preceded by `globalThis` Symbol check + clear
  - L4630-4633: `dispose` hook updated to clear `globalThis` Symbol
- **Tests:** `.opencode/plugins/__tests__/delegation-observer.reload-dedup.test.mjs` — new test file with two tests
- **Dependencies:** None
- **APIs:** None (internal plugin mechanics)
- **Systems:** Registry (`registry.jsonl`) and boot marker (`boot.json`) — dedup prevents duplicate writes on reload

## Alternatives considered

- **`boot.json` 30-second time-based dedup (rejected after smoke test):** read `boot.json`, check if `process_started_at` is within 30s of now, suppress emission if yes. Rejected because live 26-second stop/start smoke test showed this conflates real restart with in-process reload — a full OpenCode process restart within 30s would incorrectly suppress the new boot, breaking DIA-123 boot determinism. Evidence: developer smoke test 2026-08-22 (Tier-1, live observation).
- **Registry scan for dedup (rejected):** read most-recent `session_boot` row from `registry.jsonl`. Rejected because `registry.jsonl` grows unboundedly; finding latest `session_boot` row requires full scan; couples boot dedup to registry read logic. Evidence: DIA-123 design (Tier-1, committed code L936-944).
- **Module-level `let` for interval singleton (rejected):** store interval handle in module-scoped variable. Rejected because ticket explicitly describes "plugin re-evaluated" (module re-loaded), so module-level state resets on each reload. `globalThis` survives module re-evaluation. Evidence: ticket L47-55 (Tier-1, committed ticket).
- **Remove `boot.json` entirely (rejected):** since `boot.json` is not used for dedup, remove it. Rejected because `boot.json` is the DIA-123 persisted audit marker — it carries `boot_id` + `process_started_at` + `config_load_signal` so a later verifier proves "process started at T1 AFTER config mtime T0" without relying on registry seq. Evidence: DIA-123 design (Tier-1, committed code L936-944).
- **Status-quo / do nothing (rejected):** accept duplicate boot rows and stacked intervals on reload. Rejected because it breaks DIA-123 boot determinism invariant and doubles stall-sweep emissions on reload. Evidence: DIA-123 design (Tier-1, committed code), DIA-260822-oldn ticket (Tier-1, committed ticket).

Chosen option: process-scoped `globalThis` boot identity + `globalThis` Symbol interval singleton + `boot.json` as audit marker (not dedup source) — because it distinguishes in-process reload (suppress) from full process restart (emit new boot), preserves DIA-123 boot determinism, prevents interval stacking on module re-evaluation, and keeps `boot.json` as the persisted audit trail.
