## Why

The current context-pressure measurement mechanism (`getContextPressure()` in `delegation-observer.ts:1968`) is nonfunctional — it returns zero, making the 50/80/95 context-pressure logic inoperative. Without working context monitoring, sessions silently accumulate context rot until OpenCode's native auto-compaction fires at 96-99% (often too late, per research consensus that 85-90% is optimal). This change introduces an adaptive session-compaction policy that provides early warning, proactive compaction guidance, and structured handoff after compaction, preventing information loss and maintaining session quality.

## What Changes

- **Restore context measurement**: Replace broken `getContextPressure()` with direct measurement via `context_usage.usage_fraction` (token-accurate, compaction-aware).
- **Add 60% readiness warning**: On first upward crossing of 60%, emit `context-warning-60` event to `registry.jsonl` and show user a short readiness warning. No snapshot, no pause, no compaction. Rate-limited: next warning only after usage drops below 60% and crosses upward again.
- **Add 85% proactive compaction**: On first upward crossing of 85%, emit `context-compact-85` event, show user a concise continuation instruction, and request manual `/compact`. No forced compaction, no separate `HANDOFF.md`. Native OpenCode compaction at 96-99% remains the safety net.
- **Add post-compaction handoff**: After one completed compaction, the next upward crossing of 85% triggers a plugin-managed session handoff with concise continuation instruction and recommendation to begin a new session. This occurs before a second `/compact`.
- **Track policy state**: In-memory `Map<string, ContextPolicyState>` in `delegation-observer.ts`, seeded from `registry.jsonl` at boot, holding `lastUsage`, `warned60`, `compacted`, `warned85PostCompact`.
- **User-directed triggers**: Task/domain switch and confirmed context rot remain user-directed triggers (not automated).

## Capabilities

### New Capabilities

- `context-management-policy`: Adaptive session-compaction policy with 60% warning, 85% proactive compaction, post-compaction handoff, and state tracking. Covers measurement, threshold logic, event emission, and state persistence.

### Modified Capabilities

(none — no existing spec-level behavior changes)

## Impact

- **Code**: `.opencode/plugins/delegation-observer.ts` — add `ContextPolicyState` interface, in-memory `Map`, boot seeding from `registry.jsonl`, hook integration for usage monitoring, policy logic for 60%/85%/post-compaction thresholds.
- **Data**: `registry.jsonl` — new event types `context-warning-60`, `context-compact-85`, `context-new-session-post-compact`, `context-policy-error`.
- **Dependencies**: None (uses existing `context_usage` tool and `registry.jsonl` infrastructure).
- **Systems**: Orchestrator session lifecycle — adds advisory layer over native OpenCode compaction. Does not change native compaction behavior.

## Testing Decisions

**What makes a good test**: Unit tests for policy logic (threshold crossing detection, state transitions, rate limiting). Integration tests for `registry.jsonl` seeding and event emission. No E2E tests needed (policy is advisory, not critical path).

**Modules to test**: `delegation-observer.ts` policy logic (new functions), `registry.jsonl` parser (existing pattern at line 629).

**Prior art**: `compactionSuppress` Map pattern (line 299-306), `registry.jsonl` malformed JSON handling (line 629), `context_usage` tool integration (line 4284-4575).

## Alternatives considered

- **Status quo (broken `getContextPressure()`)**: Rejected — nonfunctional, leaves sessions vulnerable to context rot. Evidence: res1 §7.1 (85-90% optimal, 96-99% too late), code inspection showing `getContextPressure()` returns 0.
- **3+ compaction handoff threshold (res1 §7.3)**: Rejected by developer — single-compaction handoff is more conservative, prevents compounding information loss. Evidence: developer decision Q4.
- **Separate state file (`.opencode/session/context-policy-state.json`)**: Rejected — YAGNI, adds file I/O complexity. Evidence: developer decision Q5, settled architecture (registry.jsonl = canonical semantic event store per ana007/DIA-136).
- **HANDOFF.md for continuation state**: Rejected — YAGNI, continuation instruction shown in message is sufficient. Evidence: developer decision Q3.
- **Forced compaction at 85%**: Rejected — OpenCode has no programmatic compaction API. Evidence: res1 §3 (native compaction at 96-99% only).
- **Chosen option**: Adaptive policy with 60%/85%/post-compaction thresholds, in-memory state seeded from registry.jsonl — because it restores working context measurement, provides progressive guidance, and uses settled architecture patterns (registry.jsonl, in-memory Map) with minimal diff.
