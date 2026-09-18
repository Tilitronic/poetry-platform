## Context

See proposal.md — Why. Current state: `getContextPressure()` in `delegation-observer.ts:1968` returns 0 (nonfunctional). The 50/80/95 context-pressure logic is inoperative. Native OpenCode auto-compaction fires at 96-99% (often too late per research consensus). This design restores working context measurement and adds progressive guidance.

Constraints:

- Must use existing `context_usage` tool (token-accurate, compaction-aware)
- Must use existing `registry.jsonl` infrastructure (canonical semantic event store per ana007/DIA-136)
- Must follow settled architecture patterns (in-memory Map seeded from registry.jsonl, like `compactionSuppress` at line 299-306)
- Must not change native OpenCode compaction behavior (advisory layer only)

## Goals / Non-Goals

**Goals:**

- Restore working context measurement via `context_usage.usage_fraction`
- Provide progressive guidance: 60% warning → 85% proactive compaction → post-compaction handoff
- Track policy state that survives plugin restarts (seeded from registry.jsonl)
- Fail-soft on errors (never block session)

**Non-Goals:**

- Automate task/domain switch detection (user-directed)
- Automate context rot detection (user-directed)
- Force compaction (OpenCode has no programmatic API)
- Create separate state files (YAGNI — use in-memory Map + registry.jsonl)
- Create HANDOFF.md files (YAGNI — continuation instruction shown in message is sufficient)

## Decisions

### Decision 1: Use `context_usage.usage_fraction` for measurement

**Choice**: Direct measurement via `context_usage` tool (token-accurate, compaction-aware).

**Rationale**: The tool already implements correct logic (last assistant message tokens / model context limit). Fallback proxy via registry.jsonl is less accurate and adds complexity.

**Alternatives considered**:

- Fallback proxy via registry.jsonl activity signals: rejected — less accurate, more complex parsing.

### Decision 2: In-memory `Map<string, ContextPolicyState>` seeded from registry.jsonl

**Choice**: In-memory Map in `delegation-observer.ts`, seeded from registry.jsonl at boot.

**Rationale**: Zero new files, follows settled architecture (registry.jsonl = canonical semantic event store), pattern already exists (`compactionSuppress` at line 299-306). State loss on crash is acceptable (policy is advisory, not critical).

**Alternatives considered**:

- Separate state file (`.opencode/session/context-policy-state.json`): rejected — YAGNI, adds file I/O complexity.
- Use registry.jsonl as state store (parse events on each check): rejected — complex parsing, slower than in-memory lookup.

### Decision 3: Hook integration via `session.status` or `session.updated`

**Choice**: Use the most frequent existing suitable plugin hook after code inspection. Developer approved this default.

**Rationale**: Policy needs frequent usage checks to detect threshold crossings. `session.status` fires on state changes; `session.updated` fires on updates. Code inspection will determine which is more frequent and suitable.

**Alternatives considered**:

- Custom polling loop: rejected — adds complexity, existing hooks are sufficient.

### Decision 4: Upward-crossing detection without hysteresis

**Choice**: Detect upward crossing as `currentUsage > threshold && lastUsage <= threshold`. No hysteresis beyond rate limiting.

**Rationale**: Simple logic, matches developer decision. Rate limiting (60% warning only after drop below 60% and re-crossing) prevents spam without adding hysteresis complexity.

**Alternatives considered**:

- Hysteresis band (e.g., 59% → 61% not a crossing): rejected — adds complexity, rate limiting is sufficient.

### Decision 5: State structure

**Choice**: `ContextPolicyState` interface with fields:

- `lastUsage: number` — most recent usage_fraction
- `warned60: boolean` — whether 60% warning was emitted
- `compacted: boolean` — whether compaction occurred
- `warned85PostCompact: boolean` — whether post-compaction 85% warning was emitted

**Rationale**: Minimal state needed to implement policy logic. Each field maps to a specific threshold or event.

**Alternatives considered**:

- Additional fields (e.g., `compactionCount`, `lastWarningTimestamp`): rejected — YAGNI, not needed for current policy.

## Risks / Trade-offs

**Risk**: State loss on crash before registry.jsonl persistence.
→ **Mitigation**: Acceptable — policy is advisory, not critical. Native OpenCode compaction at 96-99% remains safety net.

**Risk**: Hook does not fire frequently enough to detect threshold crossings.
→ **Mitigation**: Code inspection will determine most frequent suitable hook. If neither `session.status` nor `session.updated` is sufficient, escalate to @architector.

**Risk**: `context_usage` tool returns error or malformed data.
→ **Mitigation**: Fail-soft — emit `context-policy-error` event, continue session without blocking. `lastUsage` remains unchanged.

**Risk**: Malformed registry.jsonl prevents state seeding.
→ **Mitigation**: Fail-soft — start with empty state, continue operation. Existing pattern at line 629 handles malformed JSON.

**Risk**: Policy emits too many events, polluting registry.jsonl.
→ **Mitigation**: Rate limiting (60% warning only after drop and re-crossing). Post-compaction handoff fires only once per compaction cycle.

## Migration Plan

**Deployment**:

1. Add `ContextPolicyState` interface and in-memory Map to `delegation-observer.ts`.
2. Add boot seeding logic (parse registry.jsonl for recent events).
3. Add hook integration (usage monitoring on session status/update).
4. Add policy logic (threshold crossing detection, event emission, user messages).
5. Test with existing session to verify behavior.

**Rollback**:

- Remove policy code from `delegation-observer.ts`.
- No data migration needed (registry.jsonl events are additive, not breaking).
- Native OpenCode compaction at 96-99% remains unchanged.

## Seams

**Public boundaries for testing**:

- `delegation-observer.ts` policy logic (new functions): unit tests for threshold crossing detection, state transitions, rate limiting.
- `registry.jsonl` parser (existing pattern at line 629): integration tests for event seeding.
- `context_usage` tool integration (existing at line 4284-4575): mock tool responses for error handling.

**No new seams**: Policy logic lives within existing `delegation-observer.ts` plugin. No new modules, no new APIs.

## Open Questions

**Which hook to use**: `session.status` vs `session.updated` — code inspection will determine which is more frequent and suitable. Developer approved this default (most frequent existing suitable hook).

**How to detect compaction**: Via `session.compacted` hook or `experimental.compaction.autocontinue` — code inspection will determine which is available and reliable.
