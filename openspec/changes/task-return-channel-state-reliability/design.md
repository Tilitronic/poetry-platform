# Design: Reliable task return-channel lifecycle states

**Governing ticket:** DIA-260827-95fv "bug-task-returns-task-cancelled-while-background-session-is-live-or-stopped-without-result-return-channel-false-state"

**Ownership:** substance: AI; structure: AI; interview_depth: full; interview_reason: Developer confirmed the complete 10-question transcript and explicitly approved synthesis.

## Context

See `proposal.md` for motivation and `specs/task-return-channel-lifecycle/spec.md` for behavioral requirements. The existing return channel can collapse lifecycle uncertainty to `cancelled`, while the Board separately retains lifecycle evidence. `docs/design/95fv-return-channel-mitigation-design.md` identifies task-output parsing, task-session reconciliation, and Board state as the existing path.

`.sdd/opencode-config/architecture.md` governs task-session workflow. Its ADR 4 requires exact-session resumes for fix work; this design uses the same exact-session principle for stopped-without-result recovery. No new module boundary or technology is introduced, so no architecture escalation is required.

## Goals / Non-Goals

**Goals:**

- Project return-channel terminal states only from confirmed Board evidence.
- Preserve enough Board evidence to recover stopped sessions without duplicate work.
- Bound retained stopped-session tombstones independently of other Board counters.
- Keep the legacy four state values compatible.
- Give the orchestrator deterministic recovery choices.

**Non-Goals:**

- Changing the meaning of successful task completion or task errors.
- Adding a time-based tombstone setting or a dependency.
- Inferring terminal state from an old return-channel line.
- Treating a missing `task_id` as a persisted Board lifecycle state.
- Automatically replacing unresolved or failed-resume work.

## Decisions

1. **Board authority:** The Background Job Board is the sole source of truth for terminal lifecycle outcomes. The return channel projects confirmed Board state and never derives terminal outcomes.
2. **Cancellation contract:** Return `cancelled` only when `terminalState=cancelled` and `cancellationRequested=true`; a cancellation receipt alone cannot satisfy the contract.
3. **Stopped classification:** Persist and project `stopped-without-result` only when a Board record is non-live, `terminalUnreconciled=true`, and has no terminal result. All absent, live, contradictory, or unconfirmed evidence is `return-channel-pending`.
4. **Recovery route:** Pending work waits and rechecks. Stopped work resumes its exact task session with tombstone evidence. A replacement dispatch is permitted only for confirmed cancellation.
5. **State compatibility:** Add exactly `return-channel-pending` and `stopped-without-result`; preserve `running`, `completed`, `error`, and confirmed `cancelled` unchanged.
6. **Recovery metadata:** Each new state carries `task_id`, `board_state`, `cancellationRequested`, and `terminalUnreconciled`. No code may infer or synthesize `terminalState`.
7. **Retention:** Keep stopped tombstones until explicit recovery or oldest-first eviction by the dedicated 500-entry Board tombstone cap. Do not add time-based retention or configuration.
8. **Acceptance-test battery:** Test live receipt-to-pending projection, cancellation without a request, tombstone state and all required metadata, confirmed cancellation, and legacy parsing stability.
9. **State persistence:** Persist stopped-without-result explicitly in the Board; return output is only a projection of that stored lifecycle state.
10. **Failed-resume handling:** A failed or result-less exact-session resume keeps the tombstone non-terminal for manual or retry recovery and never creates an automatic replacement.
11. **Dedicated tombstone capacity:** The Board keeps at most 500 stopped-without-result tombstones and evicts the oldest first. This internal cap is separate from `MAX_PROCESSED_INJECTED_COMPLETIONS` and `maxReusablePerAgent=6`, shares neither capacity nor eviction behavior with them, and has no time-based setting.
12. **Missing identifier rejection:** A missing `task_id` rejects Board projection before any Board read or write. The return channel emits exactly:

```text
state: return-channel-unverifiable
<task_result>reason=missing-task-id; task_id=; board_state=unavailable; cancellationRequested=unavailable; terminalUnreconciled=unavailable</task_result>
```

This is a transport diagnostic, not a persisted Board lifecycle state. It neither maps to nor changes the legacy `error` or `cancelled` semantics. Recovery requires manual identifier correlation; no replacement dispatch is allowed until a valid task ID permits the normal recovery protocol.

### Approach

The return channel first validates `task_id`. Without it, it rejects projection with the fixed `return-channel-unverifiable` diagnostic and does not touch the Board. With it, the existing Board-to-return-channel path reads the Board record and classifies a result without trusting a receipt as terminal. A confirmed Board state provides `cancelled` or an existing legacy state. A non-live unreconciled record produces and retains `stopped-without-result`; retention is bounded by the dedicated 500-entry oldest-first tombstone cap. All other uncertainty produces `return-channel-pending`. The recovery procedure consumes only the projected state and its required metadata.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'darkMode': true, 'background': '#1e1e2e', 'primaryColor': '#2d3a5c', 'primaryTextColor': '#e0e0e0', 'primaryBorderColor': '#5b8def', 'lineColor': '#5b8def', 'secondaryColor': '#3d3520', 'tertiaryColor': '#2a2a36', 'signalColor': '#5b8def', 'signalTextColor': '#e0e0e0', 'labelTextColor': '#e0e0e0', 'noteTextColor': '#e0e0e0', 'noteBkgColor': '#3d3520', 'actorLineColor': '#5b8def', 'actorBorderColor': '#5b8def', 'actorBkg': '#2d3a5c', 'actorTextColor': '#e0e0e0', 'sequenceNumberColor': '#e0e0e0', 'activationBorderColor': '#5b8def', 'activationBkgColor': '#2d3a5c'}}}%%
sequenceDiagram
    participant R as Return channel
    participant B as Background Job Board
    participant O as Orchestrator
    alt Missing task ID
        R-->>O: return-channel-unverifiable diagnostic
    else Valid task ID
        R->>+B: Read task lifecycle evidence
    alt Confirmed cancelled and requested
        B-->>-R: terminal cancelled
        R-->>O: cancelled
    else Non-live, unreconciled, no result
        B-->>-R: tombstoned stopped record
        R-->>O: stopped-without-result plus metadata
        O->>B: Resume exact session
    else Live or unconfirmed evidence
        B-->>-R: non-terminal evidence
        R-->>O: return-channel-pending plus metadata
    end
    end
```

### Seams

The developer-confirmed test seams are:

- **Task-output parsing to return-channel projection:** legacy parsing and the two new projected states.
- **Task identifier validation to return-channel rejection:** fixed missing-ID wire format, no Board access, and no legacy-state coercion.
- **Return-channel projection to Background Job Board:** cancellation confirmation, live/pending classification, and stopped classification.
- **Background Job Board to task recovery protocol:** tombstone metadata, exact-session resumption, and no duplicate dispatch after failed recovery.

## Risks / Trade-offs

- **A Board record may be missing or contradictory** -> return `return-channel-pending`, preserving safety over a possibly wrong terminal outcome.
- **Tombstones consume bounded history capacity** -> use the dedicated 500-entry oldest-first cap instead of an unbounded store or a time-based retention setting.
- **Tombstone eviction could affect unrelated counters** -> use a separate 500-entry oldest-first cap that does not share `MAX_PROCESSED_INJECTED_COMPLETIONS` or `maxReusablePerAgent=6`.
- **A missing task ID prevents a trustworthy Board projection** -> emit the fixed unverifiable diagnostic, preserve legacy error/cancelled semantics, and require manual correlation without replacement dispatch.
- **Exact-session resume can fail** -> preserve the tombstone and require manual or retry recovery rather than starting duplicate work.
- **New state consumers can be incomplete** -> keep all legacy values unchanged and test their parsing stability.

## Migration Plan

1. Add task-ID validation and the fixed unverifiable diagnostic before Board projection, then add Board-confirmed state projection and Board persistence for stopped-without-result behind the established task lifecycle seam.
2. Add RED tests for every developer-confirmed acceptance case, then implement with a different GREEN coder instance as required by `.sdd/opencode-config/architecture.md` ADR 3.
3. Add the dedicated 500-entry oldest-first tombstone cap independently of other Board counters, then update the recovery procedure to wait/recheck pending work and exact-resume stopped work; missing IDs require manual correlation and never replacement dispatch.
4. Validate focused tests, configuration checks, and a live lifecycle smoke case before release.
5. If unsafe behavior appears, revert the change as a unit, including the dedicated tombstone cap; preserve Board records and require explicit identifier and lifecycle verification before any replacement dispatch.
