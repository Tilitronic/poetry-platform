## Context

The delegation-observer plugin's boot evidence emission (L927-966) and stall-sweep interval (L2405-2417) run unconditionally at plugin load. On in-process reload (module re-evaluation without full process restart), duplicate boot rows and stacked intervals occur. See proposal.md for motivation.

Constraints:

- `boot.json` is the DIA-123 persisted audit marker (L936-944); registry seq is known non-monotonic
- Plugin may be re-evaluated (module re-loaded) or factory re-invoked (module cached); design must handle both
- Process-scoped boot identity: in-process reload suppresses boot emission; full process restart always emits new boot
- No new dependencies, no new files beyond test

**Design evolution:** initial design used `boot.json` 30-second time-based dedup (Q1-Q5 interview). Live 26-second stop/start smoke test revealed this conflates real restart with in-process reload — a full OpenCode process restart within 30s would incorrectly suppress the new boot. Design revised to process-scoped `globalThis` state.

## Goals / Non-Goals

**Goals:**

- Prevent duplicate `session_boot` registry rows on in-process plugin reload (module re-evaluation)
- Prevent stacked `stallSweepInterval` timers on reload
- Preserve legitimate boot evidence on full process restart (new process always emits new boot)
- Maintain `dispose` as the single teardown path
- Keep `boot.json` as the persisted audit marker (DIA-123 design)

**Non-Goals:**

- Cross-process dedup (only in-process reloads)
- Time-based dedup across restarts (rejected after smoke test)
- Change 60s sweep cadence or stall thresholds
- Alter registry seq recomputation logic (DIA-098 ai-auditor finding 1)
- Remove `boot.json` (it remains the audit marker)

## Decisions

### D1: Process-scoped boot identity via `globalThis`

**Decision:** Before emitting boot evidence, check `globalThis[Symbol.for("delegation-observer.bootEmitted")]`; if true, skip `appendRow` + `atomicWriteBootMarker` (plugin module re-evaluation in same process); if false, emit boot evidence and set the flag. A full OpenCode process restart always emits a new `session_boot` (no time-based dedup across restarts).

**Rationale:** Process-scoped state distinguishes in-process reload (suppress) from full process restart (emit new boot). `globalThis` survives module re-evaluation. No time-based heuristics that conflate restart with reload. `boot.json` remains the persisted audit marker (DIA-123 design) but is not read for dedup.

**Alternatives considered:**

- `boot.json` 30-second time-based dedup: rejected after live 26-second stop/start smoke test showed this conflates real restart with in-process reload — a full OpenCode process restart within 30s would incorrectly suppress the new boot, breaking DIA-123 boot determinism
- Registry scan: rejected because `registry.jsonl` grows unboundedly; finding latest `session_boot` row requires full scan; couples boot dedup to registry read logic

### D2: `globalThis` + Symbol for interval singleton

**Decision:** Store interval handle in `globalThis[Symbol.for("delegation-observer.stallSweepInterval")]`. Clear prior interval before creating new one.

**Rationale:** Survives module re-evaluation (ticket's stated reload semantics); works for both module re-eval and factory-only re-invocation; no collision risk; grep-friendly via Symbol registry.

**Alternatives considered:**

- Module-level `let`: rejected because module-level state resets on module re-evaluation; ticket explicitly describes "plugin re-evaluated"
- File-based lock: rejected because over-engineered for a runtime timer; `boot.json` is persisted because it carries semantic boot identity, not because timers need persistence

### D3: Skip emission + discard UUID on process-scoped dedup

**Decision:** If `globalThis[Symbol.for("delegation-observer.bootEmitted")]` is true, skip `appendRow` + `atomicWriteBootMarker` entirely. Discard the fresh `bootId` (local `const` only used in emission block).

**Rationale:** `bootId` is local `const` at L949, referenced only at L957 (`appendRow`) and L966 (`atomicWriteBootMarker`); not stored in module state, not referenced by other hooks; if emission is skipped, UUID is never used. Process-scoped check is deterministic (no time-based heuristics).

**Alternatives considered:**

- Read existing `boot_id` from `boot.json` and store: rejected because `bootId` is never referenced after emission block; reading adds complexity for no functional benefit
- Time-based dedup: rejected after smoke test (see D1 alternatives)

### D4: Two focused deterministic unit tests

**Decision:** Test (1) process-scoped boot identity — invoke factory twice in same process, assert second invocation suppresses boot emission (no new `session_boot` row); verify full process restart emits new boot (separate test process or clear `globalThis` flag). Test (2) interval singleton — invoke factory twice, assert `globalThis` Symbol handle is replaced (prior cleared), assert `dispose()` clears the Symbol.

**Rationale:** Isolation of failure modes; process-scoped boot identity testable by invoking factory twice; interval singleton requires factory re-invocation; acceptance criteria map cleanly (AC1 → test 1, AC2/AC4 → test 2).

**Alternatives considered:**

- One integration test: rejected because if both mechanisms break, single test fails for either reason, requiring diagnosis; two tests pinpoint the regression
- Pre-write `boot.json` for test (1): rejected because new design does not read `boot.json` for dedup

## Risks / Trade-offs

**Risk:** `globalThis` boot flag persists across module re-evaluations but resets on process restart.
→ **Mitigation:** This is the intended behavior. In-process reload (module re-eval) should suppress duplicate boot; full process restart should emit new boot. `globalThis` is process-scoped, so it naturally distinguishes these cases.

**Risk:** If `globalThis` is somehow cleared between reloads (unlikely), duplicate boot row is emitted.
→ **Mitigation:** Same outcome as today (no dedup); safe degradation. `globalThis` is not cleared by normal plugin lifecycle.

**Risk:** Test (2) cannot directly assert "prior interval was cleared" (no API to inspect active timers).
→ **Mitigation:** Assert `globalThis` Symbol is replaced (new handle ≠ old handle); assert `dispose()` clears the Symbol. Indirect evidence is sufficient.

**Trade-off:** Process-scoped state means each process start emits a boot, even if the previous process crashed mid-boot.
→ **Mitigation:** This is correct behavior. A crashed process did not complete boot; the new process should emit its own boot. `boot.json` is overwritten atomically, so the audit trail reflects the latest successful boot.

## Seams

**Test seam:** `.opencode/plugins/__tests__/delegation-observer.reload-dedup.test.mjs`

**Test boundaries:**

- Test (1) process-scoped boot identity: invoke factory → assert `session_boot` row emitted + `globalThis[Symbol.for("delegation-observer.bootEmitted")]` set → invoke factory again → assert no new `session_boot` row + flag still set → clear flag (simulate process restart) → invoke factory → assert new `session_boot` row emitted
- Test (2) interval singleton: invoke factory twice → assert `globalThis[Symbol.for("delegation-observer.stallSweepInterval")]` handle replaced → invoke `dispose()` → assert Symbol cleared

**No new production seams:** all changes are internal to existing plugin functions; no new public APIs, no new module boundaries.
