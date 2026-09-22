## 1. Setup and State Structure

- [ ] 1.1 Add `ContextPolicyState` interface to `delegation-observer.ts` with fields: `lastUsage: number`, `warned60: boolean`, `compacted: boolean`, `warned85PostCompact: boolean`. **Blocks**: 1.2, 2.1, 3.1, 4.1, 5.1. **Acceptance**: Interface compiles, fields match spec.

- [ ] 1.2 Add in-memory `Map<string, ContextPolicyState>` to `delegation-observer.ts` for per-session state tracking. **Blocks**: 2.1, 3.1, 4.1, 5.1. **Acceptance**: Map is accessible to policy logic, keyed by session ID.

## 2. Boot Seeding from registry.jsonl

- [ ] 2.1 Implement boot seeding logic: parse `registry.jsonl` for most recent events (`context-warning-60`, `context-compact-85`, `context-new-session-post-compact`, `session.compacted`) and reconstruct `ContextPolicyState` for each session. **Depends on**: 1.1, 1.2. **Blocks**: 3.1. **Acceptance**: After plugin restart, state matches recent registry.jsonl events. Malformed JSON fails soft (empty state).

## 3. Hook Integration and Usage Monitoring

- [ ] 3.1 Integrate usage monitoring into most frequent existing suitable plugin hook (`session.status` or `session.updated` — code inspection determines which). Call `context_usage` tool to retrieve `usage_fraction`, store as `lastUsage` in state. **Depends on**: 1.1, 1.2, 2.1. **Blocks**: 4.1, 5.1. **Acceptance**: `lastUsage` updates on each hook fire. Tool errors emit `context-policy-error` event and continue without blocking.

## 4. Threshold Crossing Detection and Event Emission

- [ ] 4.1 Implement 60% readiness warning: detect upward crossing (`currentUsage > 60 && lastUsage <= 60`), emit `context-warning-60` event to `registry.jsonl`, show user short readiness warning, set `warned60 = true`. Rate-limit: reset `warned60 = false` when usage drops to ≤60%. **Depends on**: 1.1, 1.2, 2.1, 3.1. **Blocks**: 5.1. **Acceptance**: First upward crossing emits event + message. Subsequent crossings while `warned60 = true` do not emit. After drop to ≤60% and re-crossing, emits again.

- [ ] 4.2 Implement 85% proactive compaction (no prior compaction): detect upward crossing (`currentUsage > 85 && lastUsage <= 85`), check `compacted = false`, emit `context-compact-85` event, show user concise continuation instruction + request manual `/compact`. **Depends on**: 4.1. **Blocks**: 5.1. **Acceptance**: First upward crossing of 85% (before compaction) emits event + instruction + `/compact` request. Does not force compaction. Does not create `HANDOFF.md`.

- [ ] 4.3 Implement post-compaction handoff: detect upward crossing of 85% when `compacted = true`, emit `context-new-session-post-compact` event, show user concise continuation instruction + recommend new session. **Depends on**: 4.2. **Blocks**: 5.1. **Acceptance**: After compaction, next upward crossing of 85% emits event + instruction + new-session recommendation. Occurs before second manual `/compact`.

## 5. Compaction Event Tracking

- [ ] 5.1 Detect compaction completion via `session.compacted` hook or `experimental.compaction.autocontinue` (code inspection determines which is available). Set `compacted = true` and `warned85PostCompact = false` in state. **Depends on**: 1.1, 1.2, 2.1, 3.1, 4.1, 4.2, 4.3. **Acceptance**: After native compaction, state reflects `compacted = true`. Next 85% crossing triggers post-compaction handoff (4.3).

## 6. Error Handling and Edge Cases

- [ ] 6.1 Implement fail-soft for `context_usage` tool errors: emit `context-policy-error` event, continue session without blocking, leave `lastUsage` unchanged. **Depends on**: 3.1. **Acceptance**: Tool error does not crash plugin or block session. Error event appears in registry.jsonl.

- [ ] 6.2 Implement fail-soft for malformed `registry.jsonl` during boot seeding: start with empty state, continue operation. **Depends on**: 2.1. **Acceptance**: Malformed JSON does not crash plugin. State is empty but functional.

## 7. Testing

- [ ] 7.1 Write unit tests for policy logic: threshold crossing detection (60%, 85%), state transitions (`warned60`, `compacted`, `warned85PostCompact`), rate limiting (60% warning reset after drop). **Depends on**: 4.1, 4.2, 4.3. **Acceptance**: Tests pass, cover all spec scenarios.

- [ ] 7.2 Write integration tests for boot seeding: parse registry.jsonl with recent events, verify state reconstruction. Test malformed JSON handling. **Depends on**: 2.1, 6.2. **Acceptance**: Tests pass, verify state matches registry.jsonl events.

- [ ] 7.3 Write integration tests for `context_usage` tool integration: mock tool responses (success, error), verify `lastUsage` updates and error handling. **Depends on**: 3.1, 6.1. **Acceptance**: Tests pass, verify tool errors emit `context-policy-error` event.

## 8. Validation and Rollback

- [ ] 8.1 Run `openspec validate "adaptive-session-compaction"` to verify all artifacts are valid. **Depends on**: 1.1-7.3. **Acceptance**: Validation passes with no errors.

- [ ] 8.2 Document rollback plan: remove policy code from `delegation-observer.ts`, no data migration needed (registry.jsonl events are additive). **Depends on**: 8.1. **Acceptance**: Rollback plan documented in design.md (already present).
