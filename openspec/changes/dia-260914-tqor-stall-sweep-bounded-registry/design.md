# Design: Bounded stall sweep and recoverable registry

**Governing ticket:** DIA-260914-tqor "stop delegation-observer stall sweep from re-emitting dead sessions forever and bound registry scan cost"

**Authority:** `architecture.md`; `.sdd/opencode-config/architecture.md` ADR 3 and ADR 4; `openspec/changes/dia-260902-eqgg-delegation-observer-srp/`. The prior SRP change fixes module ownership. This design changes behavior within those seams and does not introduce a new service or module boundary.

## Context

`lib/registry.ts` currently computes `seq` by parsing all of `registry.jsonl` before every append. `lib/stall-sweep.ts` receives all registry rows on every interval, projects the latest row per session, and derives prior stall/dead events from full history. A dead escalation row does not make the underlying lifecycle terminal, so the original non-terminal state remains eligible. The dead tier can therefore be emitted again after its throttle window. With many stale sessions, repeated full scans and appends amplify each other.

The registry currently acts as three different stores: append-only audit history, recovery state, and the operational stall index. The approved design separates those responsibilities while retaining one registry writer.

## Goals / Non-Goals

### Goals

- One durable dead escalation per lifecycle generation.
- Steady-state sweep cost `O(active sessions + newly appended bytes)`, never `O(total history)`.
- Amortized `O(1)` append after one controlled initialization.
- Unique monotonic `seq` and message `row_id` allocation across parallel processes and restarts.
- Small active registry/projection containing only live or recoverable state.
- Verified, immutable, no-delete archives for terminal history.
- Fail-closed rotation and truthful lifecycle diagnostics.
- Testable behavior at existing production seams with RED/GREEN instance separation.

### Non-Goals

- No synthetic `cancelled`, `completed`, `failed`, or terminal `dead` state.
- No change to stall thresholds or the 60-second sweep interval.
- No change to existing event names or removal of stable fields.
- No archive garbage collection, time-based retention, or destructive history deletion.
- No new service, database, dependency, or telemetry backend.
- No broad rewrite of handoff or unrelated plugin features. `needs-input-observer.ts`, session-query, and jsonl-cross-check receive only the persistence/history adaptations named below.

## Decisions

### D1. Lifecycle identity and convergence

The operational identity is `(session_id, lifecycle_generation)`. `lifecycle_generation` is the numeric `seq` of the first authoritative non-terminal row that opens that generation. It is an anchor, not a process-local ordinal. This makes the generation stable across restart, archive, and multi-process readers.

| Incoming event/state                                                 | Prior correlated state                                      | Generation action | Result                                                                                                       |
| -------------------------------------------------------------------- | ----------------------------------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------ |
| Authoritative dispatch/invocation with non-terminal `dispatch_state` | No open generation, or prior generation terminal/reconciled | Start             | Set `lifecycle_generation` to this row's allocated `seq`                                                     |
| Explicit exact-session resume/recovery with non-terminal state       | Recoverable stopped/unreconciled generation                 | Start             | Allocate a new row and use its `seq` as the new generation anchor                                            |
| Running/progress update                                              | Open generation                                             | Keep              | Copy the open generation anchor                                                                              |
| `session_spawn` with non-terminal state and real child session ID    | No open generation                                          | Start             | Treat the producer's first durable child-session row as authoritative and anchor the generation to its `seq` |
| `session_spawn`                                                      | Open generation                                             | Keep              | Attach to the current generation; never increment an already-open generation                                 |
| `task_success` or other confirmed terminal result                    | Open generation                                             | Keep and close    | Attach to the current generation, then remove it from the active index                                       |
| `stall_detected`, `dead`, warning, or notification evidence          | Open generation                                             | Keep              | Attach to the current generation; never increment                                                            |
| OpenCode/plugin restart or periodic sweep                            | Any                                                         | Keep              | Reconstruct the same anchor; never increment                                                                 |
| Non-terminal update while the same generation remains open           | Open generation                                             | Keep              | Do not treat repeated `invoked`/`running` rows as a new dispatch without explicit dispatch/resume evidence   |
| Row without a real session/task ID                                   | Any                                                         | None              | Historical diagnostic only; no generation or active entry                                                    |

Legacy rows without `lifecycle_generation` are ordered by valid numeric `seq`, then timestamp, then file offset. For each real ID, the first authoritative non-terminal dispatch/invocation row, or the first non-terminal `session_spawn` row carrying the real child session ID when no earlier dispatch row exists, anchors a legacy generation to its own `seq` after no generation or after a confirmed terminal/reconciled row. Subsequent `session_spawn`, progress, stall, `task_success`, and terminal rows map to that anchor until it closes. A terminal-only or diagnostic-only legacy chain with no authoritative non-terminal anchor remains historical and is never made sweep-eligible. This mapping is deterministic and is persisted only when compaction writes the retained active representation; original archive rows remain byte-preserved.

`dead` remains a diagnostic escalation, not a terminal lifecycle state. Dedup uses `(session_id, lifecycle_generation, escalation_type)`. Once `dead` is durably appended for a generation, subsequent sweeps suppress it until the generation advances. A successful append is the dedup authority even if the accompanying TUI/crisis notification fails.

A terminal or reconciled event removes the generation from the active index. A `stopped-without-result`, `return-channel-pending`, or other unreconciled recoverable record stays active. Missing IDs never receive a synthetic key, generation, index entry, or escalation.

### D2. Process-local incremental active index

Each plugin process owns a bounded in-memory active index keyed by `(session_id, lifecycle_generation)`. `lib/registry.ts` initializes it from the bounded active registry, updates it synchronously after its own successful appends, and consumes only newly appended bytes from other writers using an inode/rotation identity plus byte offset. Each entry contains only latest authoritative lifecycle metadata, emitted escalation tiers, last activity, and recovery/tombstone flags needed by `lib/stall-sweep.ts`. It does not contain prompts, credentials, or full agent output.

Ordering is deterministic: higher numeric `seq` wins; when no valid `seq` distinguishes rows, later valid timestamp wins; file offset is the final tie-breaker. Duplicate rows are idempotent. Terminal/recovered rows remove the matching active entry after their durable registry append.

Cross-process dedup does not trust a process-local index alone. Immediately before emitting a stall tier, the writer acquires the shared lock, ingests newly appended active-registry bytes, compares durable state for `(session_id, lifecycle_generation, escalation_type)`, and appends only if the tier is still absent. The compare and append are one locked operation. This prevents two plugin processes from emitting the same escalation while avoiding a full-file scan.

If local index update fails after a successful append, JSONL remains the source of truth, the index is marked dirty in that process, and sweep is disabled there until a controlled active-file rebuild succeeds. No durable shared active-index sidecar is introduced.

The projection has an explicit bound for ordinary active entries and diagnostic dedup metadata. Reaching the bound fails new projection admission loudly rather than evicting live or unreconciled entries. Ordinary completed/reconciled history is archived. Unreconciled tombstones are never removed by ordinary history limits; any future tombstone eviction policy requires a separate approved change.

### D3. Canonical persistence adapter, durable counters, and locking

`lib/registry.ts` is the only persistence adapter for both `registry.jsonl` and `messages.jsonl`. `delegation-observer.ts` and `needs-input-observer.ts` construct and use that adapter; `needs-input-observer.ts` removes its independent `maxJsonlNumber` plus `appendFileSync` paths. This centralization is required for cross-process counter uniqueness and lock discipline, but does not otherwise refactor needs-input behavior.

The repeated persistence mechanics live in one narrow functional helper, `.opencode/plugins/lib/journal-persistence.ts`. It owns only inter-process lock acquisition/release, durable named-counter reserve/recovery, checked append plus fsync, and injected filesystem/clock/process-liveness dependencies. It exports functions or factory closures, not base classes, inheritance, virtual methods, or a general log framework. `lib/registry.ts` keeps explicit semantic wrappers for registry rows, message envelopes, active-index updates, rotation, and diagnostics. Observers keep explicit event behavior and call those wrappers. Unrelated JSONL logs are out of scope. This is the ponytail/YAGNI boundary: share the proven duplicated mechanism once, then stop generalizing.

`.opencode/session/registry.seq` stores the last reserved global registry sequence and `.opencode/session/messages.row-id` stores the last reserved global message row ID. They are independent of active JSONL files and archives. Both allocation paths use the same short inter-process persistence lock before counter reservation and append.

The lock uses a standard-library atomic ownership primitive and stores owner PID, process-start identity, acquisition time, and lease deadline. A live owner is never preempted. A stale lock may be reclaimed only when its lease has expired and the owner process is confirmed not live. Failure to acquire the lock returns an explicit retryable append error; there is no process-local sequence fallback.

When either counter is absent, corrupt, or lower than known durable history, one process performs a controlled recovery under the exclusive lock. Registry `seq` uses `max(sidecar, active registry, registry archive manifests)`. Message `row_id` uses `max(sidecar, active messages JSONL, existing messages markdown row floor, any future message archive manifest)`. Normal appends never scan all archives or full active files. Counter updates are atomic and fsynced before append. A crash after reservation may leave a gap; neither number is reused.

Both append methods return a discriminated durable result:

```text
{ ok: true, id: number, entry: persistedEntry }
{ ok: false, stage: lock|counter|append|index, retryable: boolean, error: string, reserved_id?: number }
```

Callers must not interpret a reserved ID as a successful append. Stall notification/crisis emission happens only after `{ok:true}` for the `stall_detected` registry row. If notification fails after the append, the durable row still suppresses duplicate escalation and a separate rate-limited notification warning is allowed.

### D4. Stall sweep integration and performance

`lib/stall-sweep.ts` receives process-local active-index entries, not all historical rows. The shell wires the registry index reader and locked compare-and-append callback into the existing sweep factory. The shell owns timer/global singleton lifecycle only; it does not duplicate registry, generation, dedup, persistence, or notification-order logic.

- Startup may perform one controlled bootstrap/rebuild or migration scan. The target for the current approximately 45 MB registry is under 2 seconds on a typical local SSD; exceeding the target emits a diagnostic but never drops data.
- Steady-state sweep is `O(active sessions + newly appended bytes)`.
- Append is amortized `O(1)` after initialization, excluding short lock contention.
- No `tool.execute.before`, `tool.execute.after`, or other hot hook synchronously reads the full registry.
- Rotation and archive hashing run only through an explicit maintenance/bootstrap path, never inside the periodic sweep.
- Performance tests measure scan calls/bytes and emission cardinality. The 2-second target is recorded as runtime evidence, not a flaky CI assertion.

### D5. Active registry, archive, and migration

The active registry contains only the minimum rows required to reconstruct live, pending, recoverable, and unreconciled state plus current diagnostic markers. Terminal/reconciled history moves to immutable archives under a dedicated registry archive directory. Periodic sweep never reads archives. Explicit history/query tooling may opt into them.

Migration of the current registry is an explicit operation:

1. Acquire the shared registry lock and stop registry writers at the common boundary.
2. Read the current active file once, streaming where practical. Warn and skip isolated malformed rows while continuing valid rows.
3. Build the authoritative active projection using `seq`, timestamp, then file offset ordering.
4. Copy the complete original file to a staging archive without altering the original.
5. Fsync the staging archive; compute SHA-256, row count, first valid sequence, last valid sequence, malformed-row count, and byte count.
6. Write and fsync a staging manifest containing those values and the archive filename.
7. Verify the staged archive and manifest against the source snapshot.
8. Atomically publish archive and manifest.
9. Write a compact active registry to a temporary file containing every live/recoverable/unreconciled projection and required diagnostic marker. Fsync it and atomically replace the active registry.
10. Preserve both durable counter high-water marks, rebuild each process-local index from the new active file, then append one `registry_rotated` event with archive path, counts, sequence range, checksum, and retained-active count.
11. Release the lock.

Concurrent writers use the same lock, so no append can enter between source snapshot and active replacement. If copy, fsync, checksum, manifest, verification, or rename fails, the original active registry remains authoritative and is not truncated or replaced. Partially staged files are diagnostic leftovers or are safely removed; a success event is not emitted.

Archives are immutable and never deleted by this change. Rollback preserves all archives and manifests. Archive retention or garbage collection is a separate ticket.

### D6. Error contract

- Missing or empty active registry is a successful no-op.
- An isolated malformed JSONL row produces an aggregated warning with line/offset examples and is skipped; following valid rows are processed.
- Missing `session_id`/`task_id` produces a diagnostic only, never a synthetic ID or lifecycle mutation.
- Registry read failure disables that sweep and emits one rate-limited warning; no stall event is emitted.
- Lock acquisition failure returns an explicit retryable error; no fallback allocator is used.
- Atomic high-water update failure prevents the row append.
- Append failure after reservation leaves an allowed sequence gap.
- Process-local index failure after append marks that index dirty and requires rebuild before sweep decisions resume.
- Archive or compaction verification failure is fail-closed and preserves the old active registry.
- Infrastructure failures never synthesize terminal lifecycle state.
- Repeated identical warnings are rate-limited so recovery cannot become a new log loop.

### D7. Observability

One `stall_detected` row is emitted per generation and tier. Additive fields include lifecycle generation, role, age since authoritative activity, threshold, previous state, escalation tier, and dedup key. Repeated unchanged sweeps increment an in-memory/projected `suppressed_duplicate_count` without writing a row each minute.

Explicit recovery emits one `stall_resolved` row with prior generation, recovery method, stall duration, and suppressed count. Rotation emits one `registry_rotated` row and its manifest. Malformed rows are summarized once per scan, with only a bounded set of examples. Lock warnings include operation, owner/lease evidence, and retryability.

A read-only diagnostic command or existing query extension reports active-registry bytes, live/recoverable/tombstone counts, last sequence, archive count/bytes, dirty/rebuild-needed state, last rotation, and suppressed duplicate count. Diagnostics are local only and never include prompt bodies, secrets, OAuth tokens, or full outputs.

## Exact code and test seams

| Seam                                           | Required change                                                                                                                                                               | Test seam                                                                                                                                    |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `.opencode/plugins/lib/journal-persistence.ts` | Functional DI helper for one lock contract, named durable counters, checked append/fsync, and recovery; no semantic events or generic framework                               | Focused persistence tests imported through production wrappers, plus direct failure injection only where wrapper observation is insufficient |
| `.opencode/plugins/lib/registry.ts`            | Canonical durable append results, both locked counters, process-local incremental index/rebuild, cross-process compare-and-append, rotation/archive/manifest API, diagnostics | `.opencode/plugins/__tests__/registry.test.mjs` plus a focused multi-process integration fixture only if needed                              |
| `.opencode/plugins/lib/stall-sweep.ts`         | Consume process-local index, generation-scoped dedup, resolution/suppression metadata, no full-history reader                                                                 | `.opencode/plugins/__tests__/stall-sweep.test.mjs`                                                                                           |
| `.opencode/plugins/delegation-observer.ts`     | Compose the revised registry and sweep APIs; preserve timer and hook ownership; remove obsolete full-reader wiring                                                            | Existing delegation-observer integration/reload/stale-boot tests                                                                             |
| `.opencode/plugins/needs-input-observer.ts`    | Replace independent registry/message scan-and-append with the canonical adapter; preserve event payloads and timing                                                           | Existing needs-input tests plus canonical-writer concurrency coverage                                                                        |
| `scripts/session-query.mjs`                    | Explicit archive-aware session recall/history and registry health; active-only remains available for operational queries                                                      | `scripts/__tests__/session-query.bats`                                                                                                       |
| `.opencode/scripts/jsonl-cross-check.sh`       | Explicit historical completeness check across active registry plus verified registry archives                                                                                 | `scripts/__tests__/jsonl-cross-check.bats`                                                                                                   |

## TDD and integration strategy

Implementation is divided into behavior slices. For every slice, a RED coder commits only failing tests and records the exact named failure. A different GREEN coder implements the minimum code against that fixed point. Review fixes resume the original GREEN session. Disjoint RED slices may run in separate worktrees, but GREEN integration is serialized in dependency order.

Tests use injected filesystem, clocks, process liveness, lock operations, and timers where existing factories support DI. Real-filesystem tests use disposable directories and processes. Concurrency tests coordinate two writers deterministically; they do not rely on timing sleeps.

## Rollback

Revert production and test commits in reverse dependency order, but never delete an archive or manifest created by migration. Restore the pre-migration active registry from its verified archive only through the same lock and checksum gate. Preserve the highest durable `registry.seq`; rollback must not lower it or reuse sequence numbers. If restoration cannot be verified, keep the current files, disable sweep decisions, and require manual recovery.

## Acceptance commands

Exact focused commands may be narrowed to changed test files, followed by:

```bash
bun test "$PWD/.opencode/plugins/__tests__/registry.test.mjs"
bun test .opencode/plugins/__tests__/stall-sweep.test.mjs
bun test .opencode/plugins/__tests__
make test-shell
make test-config
git diff --check
```

After a real OpenCode restart, run a non-empty orchestrator smoke, inspect the registry diagnostic, and observe multiple sweep intervals. With no lifecycle change, the count of `stall_detected` rows must remain unchanged.

## Open Questions

None. Archive garbage collection and time-based retention are explicitly deferred.
