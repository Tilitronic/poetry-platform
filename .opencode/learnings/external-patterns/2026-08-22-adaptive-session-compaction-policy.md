# Adaptive Session Compaction Policy - AI-specialist research findings (2026-08-22)

- **Date:** 2026-08-22
- **Source:** DIA-260822-medh - ai-specialist gate research (read-only) for the adaptive-session-compaction OpenSpec change; persisted by @memory-manager before any coder config work (AGENTS.md section 2.5 Phase 6 ordering: research findings persisted BEFORE implementation).
- **Status:** APPROVED - research findings accepted; implementation deferred to coder lane.
- **Ticket:** DIA-260822-medh (openspec-plan permission denial resolved - see below).
- **Cross-ref:** res1-context-handoff-orchestration-strategy (conspect, 2026-08-22) for the underlying context-rot / auto-compaction threshold evidence.

## Finding 1: Direct context_usage measurement needs an async plugin hook + shared async helper, NOT synchronous tool.execute.before

- The `context_usage` tool is the token-accurate, compaction-aware source of truth (`usage_fraction` = last assistant message tokens / model context limit). Reading it requires an **async** call.
- `tool.execute.before` is a **synchronous** hook - it cannot await `context_usage` and cannot perform the measurement inline. Wiring measurement into `tool.execute.before` would block the event loop or yield `undefined` (same class of fail-open bug as DIA-059 `input.args`/`output.args` contract).
- Correct pattern: an **async plugin hook** (e.g. `session.status` / `session.updated`, chosen by code inspection for frequency) that calls a **shared async helper** wrapping `context_usage`. The helper returns a promise; the hook awaits it and updates the in-memory policy state. This matches the settled delegation-observer async style (registry.jsonl writes are already async/fail-soft).

## Finding 2: Compaction signal is experimental.compaction.autocontinue

- Native OpenCode compaction is detected via the `experimental.compaction.autocontinue` signal (fires before continuation-summary generation; `output.prompt` can replace the compaction prompt). This is the reliable hook for detecting "a compaction just happened" - NOT a polling proxy over registry.jsonl activity signals.
- The design's open question ("session.compacted hook vs experimental.compaction.autocontinue") resolves to `experimental.compaction.autocontinue` as the authoritative compaction event source.

## Finding 3: registry.jsonl is semantic event storage; per-session flags are in-memory and fail-soft

- `registry.jsonl` is the **canonical semantic event store** (per ana007 / DIA-136): new event types `context-warning-60`, `context-compact-85`, `context-new-session-post-compact`, `context-policy-error` are appended, additive, non-breaking.
- Per-session policy flags (`warned60`, `compacted`, `warned85PostCompact`, `lastUsage`) live in an **in-memory `Map<string, ContextPolicyState>`** seeded from `registry.jsonl` at boot. State loss on crash is acceptable (policy is advisory; native 96-99% compaction is the safety net).
- Both layers are **fail-soft**: malformed registry.jsonl rows are skipped (existing pattern at delegation-observer.ts:629); a `context_usage` error emits `context-policy-error` and leaves `lastUsage` unchanged; the session is never blocked.

## Finding 4: 60 / 85 / post-first-compaction progressive advisory policy

- **60% readiness warning:** on first upward crossing of 60%, emit `context-warning-60` and show a short readiness warning. No snapshot, no pause, no compaction. Rate-limited: next warning only after usage drops below 60% and crosses upward again.
- **85% proactive compaction:** on first upward crossing of 85%, emit `context-compact-85`, show a concise continuation instruction, and request manual `/compact`. No forced compaction. Native 96-99% compaction remains the safety net.
- **Post-first-compaction handoff:** after one completed compaction, the next upward crossing of 85% triggers a plugin-managed session handoff with a concise continuation instruction and a recommendation to begin a new session - before a second `/compact`.
- All three are **advisory only**; none change native OpenCode compaction behavior.

## Finding 5: No forced compaction API exists

- OpenCode exposes **no programmatic compaction API**. Forced compaction at 85% was explicitly rejected (res1 section 3: native compaction only at 96-99%). The policy can only *request* `/compact` via a user message; it cannot invoke it.

## Documented Risks (carried into implementation + review)

1. **Hook overhead** - the async measurement hook fires on frequent session events; an unbounded `context_usage` call per event risks latency. Mitigation: call only on the chosen frequent hook, keep the shared helper cheap, rate-limit event emission.
2. **Native compaction race** - the policy's 85% advisory and the native 96-99% auto-compaction can both fire; a user `/compact` between the 85% signal and the post-compaction handoff can desync `compacted` state. Mitigation: seed `compacted` from `experimental.compaction.autocontinue`, not from the advisory request.
3. **Velocity-event duplication** - `context_usage` velocity events (context.crisis / context.emergency) may duplicate or race with the policy's own threshold events in registry.jsonl. Mitigation: policy emits its own distinct event types; do not double-count velocity events as policy crossings.
4. **Post-compact timing** - the post-first-compaction handoff must fire on the *next* 85% crossing after a real compaction; if `compacted` is seeded late (boot race) the handoff may be missed or fire prematurely. Mitigation: set `compacted` synchronously on `experimental.compaction.autocontinue`, before any subsequent usage check.

## Prior openspec-plan permission denial - RESOLVED

- A prior attempt to register `openspec/changes/adaptive-session-compaction/` under `shelf.specs` was denied because it was performed by `@openspec-plan`, which is **practice-protected / spec-authoring only** (Socratic interview, never writes config or shelf registrations). Shelf registration is the `@memory-manager` responsibility (AGENTS.md section 2.3 step 6 / section 2.5 Phase 6). This entry is the correct owner's registration and closes that denial.

## Tags

DIA-260822-medh, adaptive-session-compaction, context_usage, experimental.compaction.autocontinue, registry.jsonl, in-memory-policy-state, fail-soft, advisory-compaction, openspec-plan-denial-resolved, section-10
