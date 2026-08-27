# DIA-260827-xsah - jcte error-path S2 guard runs before apoptosis check (stuck-failed half-fixed)

---

id: DIA-260827-xsah
title: "jcte error-path S2 guard runs before apoptosis check (stuck-failed half-fixed)"
area: delegation-observer
severity: Minor
status: OPEN
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
updated: 2026-08-27

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
evidence: []

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

In `delegation-observer.ts` `session.error` handler, moved the apoptosis dual-key check (`toolCircuitBreaker.getState(sessionID) === "OPEN" -> runApoptosis + return`) to BEFORE the S2 forward-only transition guard (right after `role` resolution, ~:4104). Mirrors the idle-path fix at ~:3937. A session that errored with CLOSED circuit (terminal `failed` row) then errors AGAIN with OPEN circuit now hits the apoptosis check before the S2 guard's early return, so it reaches apoptosis.

## Re-verify

Code inspection confirms the apoptosis check precedes the S2 guard. `bun test .opencode/plugins/__tests__/dia220-apoptosis-paracrine.test.mjs` -> 16 pass / 0 fail. Existing error+OPEN apoptosis tests (test 1, safeRemoveWorktree error trigger) still pass; the reorder does not change their behavior.
