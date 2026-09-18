# Proposal: Reliable task return-channel lifecycle states

**Governing ticket:** DIA-260827-95fv "bug-task-returns-task-cancelled-while-background-session-is-live-or-stopped-without-result-return-channel-false-state"

**Gate:** DIA-104 mandatory full interview. Trigger: cross-cutting task lifecycle and recovery behavior. No waiver or override.

**Ownership:** substance: AI; structure: AI; interview_depth: full; interview_reason: Developer confirmed the complete 10-question transcript and explicitly approved synthesis.

## Why

`task()` can report `Task cancelled` while its Background Job Board record is still live or has stopped without a terminal result. Treating that receipt as terminal causes duplicate dispatches and prevents exact-session recovery, so the return channel must faithfully report board-confirmed lifecycle state.

## What Changes

- Make the Background Job Board the sole authority for terminal task lifecycle outcomes.
- Return `cancelled` only for a board record with `terminalState=cancelled` and `cancellationRequested=true`.
- Add two explicit return-channel states: `return-channel-pending` for inconclusive or live evidence, and `stopped-without-result` for a non-live, terminal-unreconciled record with no terminal result.
- Preserve `stopped-without-result` records as recoverable tombstones until exact-session recovery or oldest-first eviction by a dedicated internal Board cap of 500. This cap is separate from `MAX_PROCESSED_INJECTED_COMPLETIONS` and `maxReusablePerAgent=6` and has no time-based setting.
- Reject projection when `task_id` is missing and emit the explicit non-persisted `return-channel-unverifiable` wire result rather than coercing it to a legacy error or cancellation state.
- Require recovery behavior that waits and rechecks pending work, resumes stopped work by exact task session, and permits a replacement dispatch only after confirmed cancellation.

## Capabilities

### New Capabilities

- `task-return-channel-lifecycle`: Defines authoritative task return states, required recovery metadata, and non-duplicating recovery behavior.

### Modified Capabilities

None. No existing OpenSpec capability specifies task return-channel lifecycle behavior.

## Impact

- **Affected areas:** task-output parsing and identifier validation, Background Job Board lifecycle projection and bounded tombstones, task-session reconciliation, and the recovery/resume procedure.
- **Governing references:** `.sdd/opencode-config/architecture.md`; `docs/design/95fv-return-channel-mitigation-design.md`.
- **Dependencies:** none new.
- **Rollback:** revert the return-channel, Board-state, and dedicated tombstone-cap changes as one unit. During rollback, retain existing Board records and do not collapse an unresolved record to `cancelled`; operators continue identifier, status, and Board verification before any replacement dispatch.

## Alternatives considered

- **A. Board-confirmed return states with explicit pending and stopped states (chosen):** project terminal outcomes only from the Board, retain recoverable tombstones, and use exact-session recovery. Evidence: Tier-1 `docs/design/95fv-return-channel-mitigation-design.md` sections 1-3 and developer interview decisions 1-10.
- **B. Trust `Task cancelled` as a terminal return receipt:** rejected because it can duplicate live work and loses stopped-without-result recovery. Evidence: Tier-1 `docs/design/95fv-return-channel-mitigation-design.md` sections 1-3.
- **C. Keep only the four legacy states and encode uncertainty as `cancelled`:** rejected because it cannot represent pending or unreconciled stopped work. Evidence: Tier-1 `docs/design/95fv-return-channel-mitigation-design.md` section 2.
- **D. Coerce missing `task_id` to legacy `error` or `cancelled`:** rejected because it fabricates a lifecycle outcome without a Board projection and changes legacy semantics. Evidence: developer-approved amendment.
- **Status-quo / do nothing:** rejected because the observed false terminal state remains and recovery may re-dispatch live work. Evidence: Tier-1 `docs/design/95fv-return-channel-mitigation-design.md` section 1.

Chosen option: A, because Board-confirmed states prevent false cancellation while preserving deterministic, exact-session recovery.

## Testing Decisions

A good test exercises the task-output to Board projection seam and proves that a cancellation receipt alone cannot terminate or duplicate a lane. Tests must cover: a cancellation receipt with a live Board record producing `return-channel-pending`; a cancellation without `cancellationRequested`; a tombstoned unreconciled record producing `stopped-without-result` with all required metadata; oldest-first eviction at the dedicated 500-tombstone cap without touching `MAX_PROCESSED_INJECTED_COMPLETIONS` or `maxReusablePerAgent`; a missing `task_id` producing the unrecoverable wire result without a Board write or replacement dispatch; confirmed cancellation; and unchanged legacy-state parsing.

The tests should use existing task-session and Background Job Board test seams with fake board/lifecycle records. No new dependency, timing configuration, or implementation code is introduced by this specification.
