# DIA-220 - Apoptosis & Paracrine: dual-key graceful shutdown + state signals

---

id: DIA-220
title: "Apoptosis & Paracrine: dual-key graceful shutdown + state signals"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [DIA-211, DIA-217, DIA-218]
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

Phase 4 of DIA-211 harness evolution. Implement dual-key self-termination (apoptosis) and discrete state signals (paracrine).

**Apoptosis (dual-key shutdown):**

- If an agent encounters a fatal state (circuit.open == true) AND receives session.idle or session.error event
- Autonomous: trigger log_decision(handoff), dump context to handoffs/, remove active worktrees, exit cleanly
- No orchestrator intervention needed

**Paracrine (state signals):**

- Emit discrete state events into messages.jsonl: build.passed, tests.failed, review.complete
- Orchestrator watches these events to drive next dispatch (replaces reading massive chat logs)

**Files to modify:**

- `.opencode/plugins/delegation-observer.ts` (add apoptosis logic + paracrine events)
- `.opencode/plugins/__tests__/delegation-observer.*.test.mjs` (add shutdown + signal tests)

## Verification

- `make test-config` exit 0
- Plugin typecheck + lint exit 0
- Test: circuit.open + session.error -> worktree removed + handoff written
- Test: state events emitted correctly into messages.jsonl

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
