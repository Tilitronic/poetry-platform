# DIA-260827-gnsv - [MEDIUM] Concurrent permission asks lose ticker visibility

---

id: DIA-260827-gnsv
title: "[MEDIUM] Concurrent permission asks lose ticker visibility"
area: opencode-config
severity: Medium
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
evidence:

- .opencode/plugins/needs-input-observer.ts:407-436,501-505,1238-1256

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Detail: permission watches are per request, but one reply or timeout clears the whole session waiting entry; another pending permission becomes invisible.

Fix: clear waiting only when no request remains for that session.

## Re-verify

> To be filled at re-verify time.
