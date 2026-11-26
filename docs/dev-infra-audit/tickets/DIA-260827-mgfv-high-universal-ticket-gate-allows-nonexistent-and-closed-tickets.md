# DIA-260827-mgfv - [HIGH] Universal ticket gate allows nonexistent and closed tickets

---

id: DIA-260827-mgfv
title: "[HIGH] Universal ticket gate allows nonexistent and closed tickets"
area: opencode-config
severity: High
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
date: 2026-08-27
created: 2026-08-27
updated: 2026-09-01

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence:

- .opencode/plugins/delegation-observer.ts:3027-3081; policy AGENTS.md:28-29,198-205

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-H1) confirms the gate at .opencode/plugins/delegation-observer.ts:3074-3109 checks only filename existence; a not-found id emits a warning and proceeds, and status is never read. Impact: a fabricated DIA id or a CLOSED ticket becomes formal 'authorization' for engineering work. Correct fix: exact lookup through a single ticket scanner, require OPEN status, fail closed on scan failure or not found.

## Verification

Unit test: a fabricated id and a CLOSED ticket both fail closed; a valid OPEN ticket passes; scan failure fails closed.

## Fix

Detail: gate checks filename existence only, never OPEN status; nonexistent valid IDs warn and proceed. Impact: general engineering can start under fabricated or closed tickets.

Fix: fail closed and require an existing OPEN ticket for every task.

## Re-verify

Re-verify 2026-09-01 - CLOSED.

Fix commits: 54e2dc1 (gate fails closed on not-found/unreadable ticket) + 93ea6ff (tests for fail-closed behavior).

Test gate:

- Command: bun test --cwd .opencode/plugins/**tests** dia217-ticket-gate.test.mjs
- Exit code: 0 (22 pass / 0 fail / 89 expect calls)
- Relevant passing assertions:
  - DIA-260827-mgfv: dispatch with valid ticket_id, ticket not found -> FAIL CLOSED (blocked)
  - DIA-260827-mgfv: dispatch referencing a CLOSED ticket -> FAIL CLOSED (blocked)
  - DIA-217: dispatch with valid ticket_id, ticket found -> proceeds (no error) (OPEN ticket passes)
- Additional host gate: bun test --cwd .opencode/plugins/**tests** parallel-handoff.test.mjs -> 12 pass / 0 fail (no regression).

One-line confirmation: gate now fails closed - a referenced ticket that is not found, unreadable, or not OPEN hard-blocks the dispatch (no warn-and-allow).
