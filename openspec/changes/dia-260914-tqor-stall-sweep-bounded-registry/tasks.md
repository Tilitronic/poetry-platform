# Tasks: Bound delegation-observer stall sweep and registry

**Governing ticket:** DIA-260914-tqor "stop delegation-observer stall sweep from re-emitting dead sessions forever and bound registry scan cost"

**Workflow:** Each behavioral slice uses a RED test-author and a different GREEN implementer. Record `RED:<session> -> GREEN:<session>` and fixed-point commits in the ticket. Accepted fixes resume the original GREEN session. Every commit subject or body includes `DIA-260914-tqor`.

**YAGNI boundary:** Reuse one functional journal-persistence helper for the proven duplicated lock/counter/checked-append mechanics only. Do not add inheritance, virtual classes, a general logging framework, or migrate unrelated logs.

## 0. Pre-flight and baseline

- [x] 0.1 Confirm the ticket is OPEN, the container is reachable, and the registered section 2.5 research/learnings gate is complete.
- [x] 0.2 Record registry bytes, row count, valid/malformed counts, maximum `seq`, maximum message `row_id`, `stall_detected` count, duplicate-dead distribution, and current startup/sweep timing without changing runtime files.
- [x] 0.3 Capture focused test baselines and every production reader/writer of registry and messages JSONL. Freeze allowed files per slice.

**Acceptance:** Ticket evidence exists; no migration or production edit occurred.

## 1. Functional journal persistence and both durable counters

- [x] 1.1 **RED-A:** A test-only coder adds failing production-interface cases for one-time recovery of registry `seq` and message `row_id`, repeated writes without full scans, two deterministic processes receiving unique monotonic IDs, live-owner lock refusal, expired/dead-owner reclamation, corrupt/lower counters, atomic counter failure, checked append/fsync failure, and allowed crash gaps that are never reused.
- [x] 1.2 **GREEN-A, different instance:** Add the minimal functional `.opencode/plugins/lib/journal-persistence.ts` helper and wire explicit `lib/registry.ts` registry/message wrappers to it. The helper owns only DI, the shared inter-process lock, named durable counters, and checked append/fsync.
- [x] 1.3 Make both wrappers return the approved discriminated durable result. Prove a reserved ID is never reported as persisted after append/fsync failure.

**Dependencies:** 0. **Acceptance:** Both counters are unique and monotonic across writers/restart; subsequent appends perform no full JSONL scan; no OOP or unrelated-log abstraction; registry tests exit 0.

## 2. Centralize needs-input observer writes

- [x] 2.1 **RED-B:** A different test-only coder proves concurrent delegation-observer and needs-input writes cannot duplicate `seq` or `row_id`, and that needs-input event payloads/cardinality remain unchanged.
- [x] 2.2 **GREEN-B, different instance:** Replace `needs-input-observer.ts` independent `maxJsonlNumber`/`appendFileSync` writers with the canonical `lib/registry.ts` wrappers. Do not refactor observer semantics.

**Dependencies:** 1. **Acceptance:** All plugin registry/message writes use the canonical adapter; focused needs-input and concurrency tests exit 0.

## 3. Exact lifecycle generations and process-local index

- [x] 3.1 **RED-C:** A test-only coder adds failing cases for the transition table: first authoritative non-terminal `seq` anchors generation; a real child `session_spawn` opens a generation when no earlier dispatch row exists; repeated running/progress, `session_spawn`, stall, and `task_success` stay in that generation; terminal closes it; explicit recovery or dispatch after closure starts a new anchor; restart never increments; terminal-only/missing-ID chains never become sweep-eligible.
- [x] 3.2 Add legacy fixture cases ordered by `seq`, timestamp, then offset, including deterministic legacy generation mapping, duplicate/out-of-order rows, and byte-identical archived history.
- [x] 3.3 **GREEN-C, different instance:** Implement the bounded process-local incremental index in `lib/registry.ts`, with active-file bootstrap and inode/rotation-aware ingestion of only new bytes. Do not add a durable active-index sidecar.
- [x] 3.4 Prove terminal/reconciled removal, tombstone preservation, bound fail-loud behavior, and dirty local-index rebuild before sweep resumes.

**Dependencies:** 1, 2. **Acceptance:** Transition-table and legacy tests pass; no sensitive content enters the index; ordinary bounds never evict live or unreconciled entries.

## 4. Locked cross-process stall compare-and-append

- [x] 4.1 **RED-D:** A test-only coder adds failing cases for one dead escalation across repeated intervals and two plugin processes, restart/bootstrap dedup, explicit recovery/new generation, current-lifetime stalls, hundreds of historical stale sessions without cascade, and suppression count without repeated rows.
- [x] 4.2 **GREEN-D, different instance:** Change `lib/stall-sweep.ts` to consume the process-local index and call a canonical locked compare-and-append operation. Under lock, ingest new bytes, compare durable generation/tier evidence, and append only if absent.
- [x] 4.3 Wire `delegation-observer.ts` minimally. Emit TUI/crisis notification only after `{ok:true}` stall append. On notification failure, retain the durable dedup row and emit only a rate-limited warning.

**Dependencies:** 3. **Acceptance:** One dead row per generation/tier across processes; no full-history sweep; failed append sends no success notification; current fresh stalls remain detected.

## 5. Error and malformed-input behavior

- [x] 5.1 **RED-E:** A test-only coder adds failing cases for empty/missing registry no-op, isolated malformed rows with aggregated bounded warning examples, valid rows after corruption, missing IDs without synthetic keys, read failure suppressing sweep, rate-limited warnings, discriminated failures at lock/counter/append/index stages, and dirty-index rebuild.
- [x] 5.2 **GREEN-E, different instance:** Implement only the approved fail-soft/fail-closed paths in the canonical persistence, registry, and stall seams.

**Dependencies:** 1, 3, 4. **Acceptance:** Infrastructure errors never synthesize terminal state or stall success; warning paths cannot form another loop; focused tests exit 0.

## 6. Verified archive and active compaction

- [x] 6.1 **RED-F:** A test-only coder adds real-filesystem failing tests for immutable archive creation, manifest/checksum, lifecycle retention, sequence continuity, atomic replacement, concurrent append serialization, and fail-closed copy/fsync/checksum/manifest/rename failures.
- [x] 6.2 **GREEN-F, different instance:** Add explicit rotation to `lib/registry.ts` using the shared persistence lock and approved migration order. Never invoke it from periodic sweep or hot hooks.
- [x] 6.3 Preserve both counter high-water marks, rebuild process-local indexes, and append one `registry_rotated` event only after verified success. Add no archive deletion API.

**Dependencies:** 1, 3, 5. **Acceptance:** Failure leaves the original active registry authoritative; success creates a verified immutable archive/manifest and compact active state; counters never decrease.

## 7. Explicit archive-aware historical readers and diagnostics

- [x] 7.1 **RED-G:** A test-only coder extends `scripts/__tests__/session-query.bats` for archived session recall and active-only operational mode, and `scripts/__tests__/jsonl-cross-check.bats` for verified archive inclusion, duplicate avoidance, and rejection of unverified archives.
- [x] 7.2 Add failing registry-health cases for active bytes/counts, last counters, archive count/bytes, local-index health, last rotation, suppression count, and bounded malformed examples.
- [x] 7.3 **GREEN-G, different instance:** Make `scripts/session-query.mjs` explicitly archive-aware for historical recall and `.opencode/scripts/jsonl-cross-check.sh` explicitly archive-aware for historical completeness. Keep sweep and active decisions archive-blind.
- [x] 7.4 Add the smallest read-only diagnostic surface and audit other readers. Apply only compatibility changes required by the explicit active/history contract.

**Dependencies:** 6. **Acceptance:** Archived evidence remains queryable and cross-checkable exactly once; unverified archives fail closed; diagnostics are local/read-only and expose no sensitive content; Bats suites pass.

## 8. Migrate the current registry

- [x] 8.1 At the documented safe point, acquire the common lock and run explicit migration once against the current approximately 44.85 MB registry.
- [x] 8.2 Record archive path, source/archive bytes, row and malformed counts, first/last sequence, SHA-256, retained active/tombstone counts, both counter high-water marks, and elapsed time.
- [x] 8.3 Independently verify manifest/checksum and every retained live/recoverable/unreconciled generation before accepting compact active state.
- [x] 8.4 Confirm runtime registry/archive files remain outside Git and no archive is deleted.

**Dependencies:** 6, 7. **Acceptance:** Migration is verified and recoverable; any failure preserves the original authoritative source.

## 9. Full verification and runtime smoke

- [ ] 9.1 Run focused registry, persistence, stall-sweep, needs-input, session-query, and jsonl-cross-check tests, then the complete plugin suite.
- [x] 9.2 Run `make test-shell`, `make test-config`, and `git diff --check`; record exit codes and summaries.
- [x] 9.3 Restart OpenCode, run a non-empty orchestrator smoke, and capture registry diagnostics.
- [x] 9.4 Observe multiple unchanged sweep intervals and prove `stall_detected` does not increase. Exercise one fresh stall and one recovery/new-generation case.
- [x] 9.5 Record steady-state scan/byte counts proving `O(active sessions + new bytes)` and no per-append full scan. Record startup duration as evidence, not a flaky CI gate.

**Dependencies:** 2-8. **Acceptance commands:**

```bash
bun test "$PWD/.opencode/plugins/__tests__/registry.test.mjs"
bun test .opencode/plugins/__tests__/stall-sweep.test.mjs
bun test .opencode/plugins/__tests__
bats scripts/__tests__/session-query.bats
bats scripts/__tests__/jsonl-cross-check.bats
make test-shell
make test-config
git diff --check
```

All commands exit 0; runtime smoke is non-empty; unchanged sweeps emit no new stall row.

## 10. Independent review, fix loop, and closure

- [ ] 10.1 Review the committed fixed point for concurrency, lifecycle transitions, append/notification ordering, archive safety, YAGNI boundary, privacy, performance, and OpenSpec fidelity.
- [ ] 10.2 Present findings for developer disposition. Apply accepted fixes through the original GREEN session for the affected slice; targeted re-review is capped at two cycles.
- [ ] 10.3 Re-run complete gates, register reusable findings, add changelog, and attach migration/rollback evidence.
- [ ] 10.4 Close the ticket only after accepted findings are verified closed or residual risk is explicitly accepted.

**Dependencies:** 9. **Acceptance:** Review chain, tests, archive receipt, smoke, changelog, and rollback instructions are complete.

## Dependency and lane plan

```text
0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10
```

RED lanes may use separate worktrees after dependencies are met. GREEN work touching shared persistence or registry code is serialized. A RED author never implements its own slice. No unit-test lane may migrate or delete the live registry.
