# DIA-260827-zmgh - jcte FALSIFICATION-1 stuck-failed scenario missing regression test

---

id: DIA-260827-zmgh
title: "jcte FALSIFICATION-1 stuck-failed scenario missing regression test"
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

Added regression test `stuck-failed scenario: errored (CLOSED) then idle (OPEN) triggers apoptosis` to `.opencode/plugins/__tests__/dia220-apoptosis-paracrine.test.mjs`. It registers a subagent, fires `session.error` while the circuit is CLOSED (writes a terminal `session_failed` row, no apoptosis), trips the circuit to OPEN, then fires `session.idle` and asserts the `apoptosis_complete` row plus a handoff file. This pins the idle-path dual-key reordering (~:3937) so the stuck-failed sequence cannot regress.

## Re-verify

`bun test .opencode/plugins/__tests__/dia220-apoptosis-paracrine.test.mjs` -> 16 pass / 0 fail. New test passes; the already-present idle-path fix is now protected by a dedicated regression test.
