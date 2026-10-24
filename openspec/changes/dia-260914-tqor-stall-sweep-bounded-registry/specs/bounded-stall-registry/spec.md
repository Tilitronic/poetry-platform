## ADDED Requirements

### Requirement: Generation-scoped stall escalation

The delegation observer MUST emit each stall escalation tier at most once for a `(session_id, lifecycle_generation)` pair. `lifecycle_generation` MUST equal the `seq` of the first authoritative non-terminal row that opens the generation. A non-terminal `session_spawn` carrying a real child session ID and a distinct real `parent_session` MUST open the generation when the producer persisted no earlier dispatch/invocation row; when a generation is already open it MUST remain in that generation and MUST NOT increment it. Progress, stall, and `task_success` MUST remain in the open generation and MUST NOT increment it. A restart or elapsed time MUST NOT advance lifecycle generation. A confirmed new dispatch after closure or explicit recovery MUST open a new generation. Legacy rows MUST map deterministically by sequence, timestamp, and file offset; chains without an authoritative non-terminal anchor MUST remain historical and ineligible for sweep. `dead` MUST remain diagnostic and MUST NOT be projected as a terminal lifecycle state.

#### Scenario: Repeated sweeps do not repeat dead escalation

- **GIVEN** a non-terminal session generation already has a durable `dead` escalation
- **WHEN** any number of sweeps run without an authoritative lifecycle change
- **THEN** no additional `dead` row is appended for that generation

#### Scenario: Recovery permits later escalation

- **GIVEN** a session generation was escalated and then explicitly recovered
- **WHEN** the new generation later exceeds the dead threshold
- **THEN** exactly one `dead` escalation is permitted for the new generation

#### Scenario: Real child spawn opens a generation

- **GIVEN** the first durable row for a real child session is a non-terminal `session_spawn` carrying a distinct real `parent_session`
- **WHEN** no earlier authoritative dispatch or invocation row exists for that child session
- **THEN** the spawn row's `seq` anchors one active lifecycle generation

### Requirement: Bounded active lifecycle projection

Each plugin process MUST maintain a bounded incremental active index containing the latest authoritative state for live, pending, recoverable, and unreconciled session generations. The periodic stall sweep MUST consume this index and newly appended bytes rather than parsing total registry history. Before a stall append, the canonical writer MUST perform a locked cross-process compare-and-append against newly durable state. Terminal or reconciled generations MUST leave the index. Missing session/task identifiers MUST NOT produce synthetic keys or lifecycle mutations.

#### Scenario: Historical backlog does not drive sweep work

- **GIVEN** an archive contains thousands of historical terminal and stall rows and the active projection contains a small number of live sessions
- **WHEN** a steady-state sweep runs
- **THEN** its work is proportional to active sessions and new bytes, and it does not parse the archive or full historical registry

#### Scenario: Unreconciled tombstone survives compaction

- **GIVEN** a `stopped-without-result` or other unreconciled tombstone exists
- **WHEN** terminal history is compacted
- **THEN** the tombstone remains in active recoverable state and ordinary history bounds do not evict it

### Requirement: Concurrent monotonic sequence allocation

The canonical registry persistence adapter MUST allocate globally unique monotonic registry `seq` and message `row_id` values from separate durable high-water marks protected by one inter-process lock contract. All plugin writers, including needs-input-observer, MUST use the adapter. Normal append MUST NOT scan full JSONL files after initialization. A reserved number MUST NOT be reused after a crash, and counter gaps MUST be accepted.

#### Scenario: Parallel writers allocate unique sequences

- **GIVEN** two plugin processes share a registry and durable high-water mark
- **WHEN** they append concurrently
- **THEN** the shared lock serializes allocation and each row receives a distinct increasing sequence

#### Scenario: Lock or sidecar failure fails closed

- **GIVEN** the writer cannot acquire the lock or atomically persist the next high-water mark
- **WHEN** it attempts an append
- **THEN** it returns an explicit retryable error and does not use a process-local fallback or duplicate a sequence

#### Scenario: Durable append result gates notification

- **GIVEN** a stall candidate passes the locked cross-process comparison
- **WHEN** the canonical append returns its discriminated result
- **THEN** notification is emitted only for `{ok:true}`, while `{ok:false}` exposes its failure stage and never produces a success notification

### Requirement: Verified immutable registry archive

Compaction MUST preserve the complete source registry in an immutable archive with a verified manifest containing archive path, byte and row counts, first and last valid sequence, malformed-row count, and SHA-256. Active replacement MUST retain every live, pending, recoverable, and unreconciled projection. This change MUST NOT delete archives or add archive garbage collection.

#### Scenario: Successful rotation is recoverable

- **GIVEN** registry writers are serialized by the common lock
- **WHEN** archive copy, fsync, checksum, manifest verification, and compact active replacement all succeed
- **THEN** the immutable archive and manifest are published, the active registry contains all required projections, and sequence allocation continues above the prior high-water mark

#### Scenario: Rotation failure preserves source

- **GIVEN** any archive, checksum, manifest, verification, or rename step fails
- **WHEN** rotation aborts
- **THEN** the original active registry remains authoritative, no unverified replacement is accepted, and no success event is emitted

### Requirement: Truthful and bounded diagnostics

Registry and sweep errors MUST NOT synthesize terminal lifecycle states. Isolated malformed lines MUST be skipped with an aggregated bounded warning while later valid lines continue. Repeated identical warnings and duplicate stall detections MUST be suppressed or rate-limited. Local diagnostics MUST report active size and counts, last sequence, archive totals, projection health, last rotation, and suppressed duplicates without prompts, credentials, tokens, or full agent outputs.

#### Scenario: Malformed row does not stop valid recovery

- **GIVEN** a registry contains an isolated malformed line followed by valid lifecycle rows
- **WHEN** bootstrap or explicit diagnostics parse it
- **THEN** one aggregated warning identifies bounded line/offset examples and the valid rows are still processed

#### Scenario: Projection update fails after append

- **GIVEN** a registry row was durably appended but active projection persistence fails
- **WHEN** the next sweep is due
- **THEN** the projection is marked dirty, sweep decisions are disabled until controlled rebuild succeeds, and the durable row is not rewritten as a different lifecycle outcome

### Requirement: Explicit historical readers include archives

Session recall and JSONL completeness validation MUST treat verified registry archives plus the active registry as historical input when historical mode is requested. Periodic sweep and ordinary active-state decisions MUST remain active-file/index-only.

#### Scenario: Archived session remains queryable

- **GIVEN** a terminal session was removed from the compact active registry and is present in a verified archive
- **WHEN** session-query performs historical recall for that session
- **THEN** it returns the archived rows without making the stall sweep read the archive

#### Scenario: Cross-check includes verified archives

- **GIVEN** task-success evidence moved from the active registry into a verified archive
- **WHEN** jsonl-cross-check runs its explicit historical completeness check
- **THEN** it includes the archived evidence once, rejects unverified archive inputs, and preserves its existing pass/fail semantics
