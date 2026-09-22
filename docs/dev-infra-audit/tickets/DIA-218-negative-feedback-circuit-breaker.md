# DIA-218 - Negative Feedback: circuit breaker on tool execution errors

---

id: DIA-218
title: "Negative Feedback: circuit breaker on tool execution errors"
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

Phase 2 of DIA-211 harness evolution. Implement a 3-state Circuit Breaker (CLOSED/OPEN/HALF_OPEN) for `tool.execute.after` events.

**Concrete change:**

- Add `CircuitBreaker` module in delegation-observer plugin
- Track `tool.execute.error` events in a sliding window array (last 5 calls per agent)
- 3 errors in window -> state transitions CLOSED->OPEN
- When OPEN: intercept prompt continuation, force fallback to orchestrator with `circuit.open` event
- HALF_OPEN: after cooldown (5 min), allow 1 test call; success -> CLOSED, failure -> back to OPEN

**Files to modify:**

- `.opencode/plugins/delegation-observer.ts` (add CircuitBreaker class)
- `.opencode/plugins/__tests__/delegation-observer.*.test.mjs` (add circuit breaker tests)

## Verification

- `make test-config` exit 0
- Plugin typecheck + lint exit 0
- Test: 3 sequential tool errors -> circuit opens
- Test: circuit open blocks continuation
- Test: cooldown + 1 success -> circuit closes

## Fix

> To be filled at fix time.

## Re-verify

2026-08-18: all findings verified-closed (F1-F3), 0 regressions, cycle 2/2 clean
