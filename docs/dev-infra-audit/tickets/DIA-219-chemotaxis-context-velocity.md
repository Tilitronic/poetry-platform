# DIA-219 - Chemotaxis: context growth velocity monitoring

---

id: DIA-219
title: "Chemotaxis: context growth velocity monitoring"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [DIA-211, DIA-217]
discovered: 2026-08-18
gate_state: partial
gate_triggers: [cross-boundary]

# --- Session Attribution ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Phase 3 of DIA-211 harness evolution. Track the velocity (delta) of context window growth, not just absolute threshold.

Currently, context_usage reports absolute percentage. This phase adds velocity tracking to trigger early compaction or crisis events when context grows too fast.

**Concrete change:**

- Enhance `context_usage` tool to return `velocity_percent_per_cycle` (delta from last measurement)
- Track last measurement per session in plugin memory
- If velocity > 15% in a single cycle: emit `context.crisis` event with velocity info
- If velocity > 25% in a single cycle: emit `context.emergency` event, recommend immediate compaction

**Files to modify:**

- `.opencode/plugins/delegation-observer.ts` (enhance context_usage)
- `.opencode/plugins/__tests__/delegation-observer.*.test.mjs` (add velocity tests)

## Verification

- [x] Tests: 6/6 pass (context-velocity.test.mjs)
- [x] Existing tests: DIA-217 5/5, circuit-breaker 10/10, parallel-handoff 10/10 (no regressions)
- [x] make test-config: 170/171 pass (DIA-220 pre-existing)
- [x] Typecheck: pre-existing errors only
- [x] git status: only intended files changed

## Fix

> To be filled at fix time.

## Re-verify

> 2026-08-18: Minor findings fixed (velocity semantics documented, rounding to integer, verification evidence added), 0 regressions
