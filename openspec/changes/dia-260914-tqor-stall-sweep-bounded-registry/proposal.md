# Proposal: Bound the delegation-observer stall sweep and registry

**Governing ticket:** DIA-260914-tqor "stop delegation-observer stall sweep from re-emitting dead sessions forever and bound registry scan cost"

**Gate:** DIA-104 Full interview completed. The developer approved the lifecycle, performance, persistence, error, observability, and acceptance contracts before synthesis.

## Why

The delegation-observer stall sweep can re-emit `stall_detected` for the same dead session indefinitely. The active `.opencode/session/registry.jsonl` has grown to about 44.85 MB and 128,347 rows, including about 119,125 `stall_detected` rows. The periodic sweep reads the full history every minute, while `lib/registry.ts` also scans the full file before each append to allocate `seq`. A backlog of stale sessions therefore creates repeated full scans plus repeated writes and can keep OpenCode busy for hours.

The existing DIA-260902-eqgg SRP design already assigns durable registry writes to `lib/registry.ts`, stall detection to `lib/stall-sweep.ts`, and composition to `delegation-observer.ts`. This change fixes behavior inside those established seams without adding a service or changing the external event schema.

## What Changes

- Emit at most one `dead` escalation per `(session_id, lifecycle_generation, escalation_type)` until an explicit recovery or new dispatch advances the generation.
- Replace full-history periodic scans with a process-local incremental active-session index updated by canonical registry appends and new bytes, and reconstructed once at startup when required.
- Replace per-append full-file counter scans with durable `.opencode/session/registry.seq` and `.opencode/session/messages.row-id` high-water marks protected by one short inter-process persistence lock.
- Keep `seq` globally unique and monotonic across processes, restarts, and compaction. Gaps after a reserved-but-not-appended number are valid; reuse is forbidden.
- Route `needs-input-observer.ts` registry and message writes through the canonical `lib/registry.ts` persistence adapter instead of its independent scan-and-append implementation.
- Reuse one narrow functional journal-persistence helper for locking, named counters, checked append/fsync, and dependency injection; keep semantic registry, message, rotation, and observer behavior in explicit wrappers.
- Return a discriminated durable append result; send a stall notification only after the corresponding stall row is durably appended.
- Keep only live, recoverable, pending, and unreconciled lifecycle state in the active registry/projection. Move terminal and reconciled history into verified immutable archives.
- Archive the current registry before compaction with a manifest containing archive path, row count, `first_seq`, `last_seq`, and SHA-256. This ticket never deletes an archive.
- Preserve `stopped-without-result` and other unreconciled tombstones through ordinary history compaction.
- Add bounded, rate-limited local diagnostics without external telemetry or prompt/output capture.
- Preserve existing event names and stable fields. New generation, dedup, rotation, and diagnostic fields are additive.

## Capabilities

### New Capabilities

- `bounded-stall-registry`: Maintains a restart-safe active lifecycle projection, one-shot stall escalation per lifecycle generation, monotonic concurrent sequence allocation, and recoverable registry archives.

### Modified Capabilities

None. No existing OpenSpec capability defines bounded registry persistence or generation-scoped stall escalation.

## Impact

- **Primary implementation seams:** one narrow `.opencode/plugins/lib/journal-persistence.ts` functional helper, `.opencode/plugins/lib/registry.ts`, `.opencode/plugins/lib/stall-sweep.ts`, `.opencode/plugins/delegation-observer.ts`, and `.opencode/plugins/needs-input-observer.ts`.
- **Primary tests:** `.opencode/plugins/__tests__/registry.test.mjs`, `.opencode/plugins/__tests__/stall-sweep.test.mjs`, plus a focused rotation/concurrency integration fixture if the existing files cannot express the boundary cleanly.
- **Reader compatibility:** `scripts/session-query.mjs` and `.opencode/scripts/jsonl-cross-check.sh` become explicit archive-aware historical readers. Periodic sweep remains active-file-only.
- **Runtime state:** `.opencode/session/registry.seq`, `.opencode/session/messages.row-id`, an inter-process lock record, and immutable registry archives/manifests. The active index is process-local; runtime artifacts are not committed.
- **Dependencies:** Node standard library only. No database, daemon, network service, new package, class hierarchy, or generic logging framework.
- **External compatibility:** current JSONL event names and stable fields remain readable. Historical archives are excluded from periodic sweep work and included only by explicit diagnostic/history queries.

## Alternatives considered

- **A. Durable high-water mark, active projection, and immutable archives (chosen):** bounded steady-state work, safe parallel allocation, restart-safe dedup, and preserved evidence. Evidence: approved Q2-Q7 interview; Tier-1 current `lib/registry.ts` and `lib/stall-sweep.ts`; Tier-1 DIA-260902-eqgg SRP design.
- **B. Process-local cached `seq` and last ten rows:** rejected because independent OpenCode processes can allocate the same number; caching more rows does not create mutual exclusion.
- **C. Keep the full registry and only increase the dead retry interval:** rejected because the system still performs unbounded scans and eventually repeats the same false escalation.
- **D. Delete terminal history immediately:** rejected because it destroys audit, handoff, ticket attribution, and recovery evidence.
- **E. Status quo:** rejected because the observed registry can continue growing and current-lifetime stalls can restart the runaway loop.

Chosen option: A, because it removes the repeated work at its source while preserving truthful lifecycle state and recoverable history.

## Testing Decisions

RED tests must prove each behavioral defect before GREEN implementation. The RED author and GREEN implementer for the same slice must be different coder instances per `.sdd/opencode-config/architecture.md` ADR 3. Tests assert observable work units such as bytes read, full-scan calls, rows emitted, lock ownership, and persisted state rather than flaky wall-clock timing. Full validation includes focused plugin tests, the complete plugin suite, `make test-shell`, `make test-config`, restart and non-empty orchestrator smoke, and multiple sweep intervals with no additional `stall_detected` when lifecycle state is unchanged.
