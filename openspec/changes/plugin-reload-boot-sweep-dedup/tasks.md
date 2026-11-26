## 1. Process-Scoped Boot Identity

- [ ] 1.1 Add `BOOT_EMITTED_KEY = Symbol.for("delegation-observer.bootEmitted")` constant at module scope in delegation-observer.ts
- [ ] 1.2 Before boot evidence emission (L955), check `globalThis[BOOT_EMITTED_KEY]`; if true, skip `appendRow` + `atomicWriteBootMarker` and discard fresh UUID
- [ ] 1.3 After boot evidence emission, set `globalThis[BOOT_EMITTED_KEY] = true`
- [ ] 1.4 Verify: invoke plugin factory twice in same process, assert second invocation suppresses boot emission (no new `session_boot` row in registry.jsonl)

## 2. Interval Singleton

- [ ] 2.1 Add `STALL_SWEEP_KEY = Symbol.for("delegation-observer.stallSweepInterval")` constant at module scope
- [ ] 2.2 Before `setInterval` (L2409), read `globalThis[STALL_SWEEP_KEY]`; if present, `clearInterval` the prior handle
- [ ] 2.3 After `setInterval`, assign new handle to `globalThis[STALL_SWEEP_KEY]`
- [ ] 2.4 Verify: invoke plugin factory twice in same process, assert `globalThis[STALL_SWEEP_KEY]` is replaced (new handle ≠ old handle)

## 3. Dispose Update

- [ ] 3.1 Update `dispose` hook (L4632) to read `globalThis[STALL_SWEEP_KEY]`, `clearInterval` if present, then set `globalThis[STALL_SWEEP_KEY] = undefined`
- [ ] 3.2 Verify: invoke factory, call `dispose()`, assert `globalThis[STALL_SWEEP_KEY]` is undefined

## 4. Unit Tests

- [ ] 4.1 Create `.opencode/plugins/__tests__/delegation-observer.reload-dedup.test.mjs`
- [ ] 4.2 Write test (1) process-scoped boot identity: invoke factory, assert `session_boot` row emitted + `globalThis[BOOT_EMITTED_KEY]` set; invoke factory again, assert no new `session_boot` row + flag still set; clear flag (simulate process restart), invoke factory, assert new `session_boot` row emitted
- [ ] 4.3 Write test (2) interval singleton: invoke factory twice, assert `globalThis[STALL_SWEEP_KEY]` replaced; invoke `dispose()`, assert Symbol cleared
- [ ] 4.4 Run `make test-harness` (bun plugin test suite), assert all tests pass

## 5. Validation

- [ ] 5.1 Run `openspec validate plugin-reload-boot-sweep-dedup`, assert validation passes
- [ ] 5.2 Run `make test-config`, assert no regressions
- [ ] 5.3 Grep delegation-observer.ts for `setInterval`, assert only one stall-sweep interval creation site remains
