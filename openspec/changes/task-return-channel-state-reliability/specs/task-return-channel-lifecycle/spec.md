## Purpose

Define reliable task return-channel lifecycle states so orchestrators do not mistake an unverified cancellation receipt for a terminal task outcome.

## ADDED Requirements

### Requirement: Board-confirmed cancellation

The system MUST return `cancelled` only when the Background Job Board record has `terminalState=cancelled` and `cancellationRequested=true`. A return-channel receipt by itself MUST NOT establish cancellation.

#### Scenario: Confirmed cancellation is projected

- **GIVEN** a task Board record has `terminalState=cancelled` and `cancellationRequested=true`
- **WHEN** the return channel projects the task state
- **THEN** it returns `cancelled`
- **SEAM** task return-channel to Background Job Board projection

#### Scenario: Cancellation without a request is not projected

- **GIVEN** a task Board record reports cancellation without `cancellationRequested=true`
- **WHEN** the return channel projects the task state
- **THEN** it does not return `cancelled`
- **SEAM** task return-channel to Background Job Board projection

### Requirement: Explicit non-terminal lifecycle states

The system MUST return `return-channel-pending` for absent, live, contradictory, or otherwise unconfirmed Board evidence. It MUST return `stopped-without-result` only for a non-live Board record with `terminalUnreconciled=true` and no terminal result. The Board MUST persist `stopped-without-result` as the confirmed source state.

#### Scenario: Live work is pending despite a cancellation receipt

- **GIVEN** the return channel receives a cancellation receipt and the Board record is live
- **WHEN** the return channel projects the task state
- **THEN** it returns `return-channel-pending`, not `cancelled`
- **SEAM** task return-channel to Background Job Board projection

#### Scenario: Unreconciled stopped work is distinct

- **GIVEN** a non-live Board record has `terminalUnreconciled=true` and no terminal result
- **WHEN** the return channel projects the task state
- **THEN** it returns `stopped-without-result`
- **SEAM** task return-channel to Background Job Board projection

### Requirement: Recovery metadata and tombstone preservation

Every `return-channel-pending` and `stopped-without-result` result MUST include `task_id`, `board_state`, `cancellationRequested`, and `terminalUnreconciled`. The system MUST NOT infer or synthesize `terminalState`. A stopped-without-result record MUST remain tombstoned until explicit recovery or oldest-first eviction by an internal Board tombstone cap of 500. This cap MUST be separate from `MAX_PROCESSED_INJECTED_COMPLETIONS` and `maxReusablePerAgent=6`, and MUST NOT have a time-based setting.

#### Scenario: Tombstone preserves recovery evidence

- **GIVEN** a task is stopped without a terminal result
- **WHEN** its state is returned for recovery
- **THEN** the response includes all required metadata and its Board tombstone remains recoverable
- **SEAM** Background Job Board to task recovery protocol

#### Scenario: Dedicated tombstone cap evicts the oldest record

- **GIVEN** the Board holds 500 stopped-without-result tombstones and receives another tombstone
- **WHEN** it retains the new tombstone
- **THEN** it evicts only the oldest tombstone and does not change `MAX_PROCESSED_INJECTED_COMPLETIONS` or `maxReusablePerAgent`
- **SEAM** Background Job Board tombstone retention

### Requirement: Missing task identifier rejects projection

The system MUST reject Board projection when `task_id` is missing. It MUST emit this exact wire format:

```text
state: return-channel-unverifiable
<task_result>reason=missing-task-id; task_id=; board_state=unavailable; cancellationRequested=unavailable; terminalUnreconciled=unavailable</task_result>
```

The result MUST provide the `missing-task-id` diagnostic, MUST NOT read or write a Board lifecycle record, and MUST NOT create a replacement dispatch. It is not a persisted Board lifecycle state and MUST NOT map to or alter legacy `error` or `cancelled` semantics. Recovery MUST require manual identifier correlation; after a valid task ID is recovered, the normal Board-backed recovery protocol applies.

#### Scenario: Missing task ID is rejected without a Board mutation

- **GIVEN** task output cannot supply a task ID
- **WHEN** the return channel attempts lifecycle projection
- **THEN** it returns the exact `return-channel-unverifiable` wire result, records the missing-ID diagnostic, does not mutate the Board, and starts no replacement dispatch
- **SEAM** task identifier validation to return-channel rejection

### Requirement: Non-duplicating recovery

The orchestrator MUST wait and recheck lifecycle and Board evidence for `return-channel-pending`. It MUST resume the exact task session for `stopped-without-result`. It MUST allow a replacement dispatch only after confirmed cancellation. If an exact-session resume fails or has no terminal result, it MUST preserve the tombstone and keep the task non-terminal for manual or retry recovery.

#### Scenario: Stopped work resumes the exact session

- **GIVEN** a task returns `stopped-without-result` with its tombstone evidence
- **WHEN** the orchestrator starts recovery
- **THEN** it resumes the exact task session and does not create a replacement dispatch
- **SEAM** task recovery protocol to task session lifecycle

#### Scenario: Failed resume remains non-terminal

- **GIVEN** exact-session recovery fails or yields no terminal result
- **WHEN** recovery completes
- **THEN** the tombstone remains and no replacement dispatch is created automatically
- **SEAM** task recovery protocol to Background Job Board

### Requirement: Legacy state compatibility

The system MUST preserve the existing values and semantics of `running`, `completed`, `error`, and confirmed `cancelled`.

#### Scenario: Legacy state parsing remains unchanged

- **GIVEN** a task output carrying a legacy lifecycle state
- **WHEN** the return channel parses and projects it
- **THEN** it returns the same legacy state with its existing semantics
- **SEAM** task-output parsing to return-channel projection
