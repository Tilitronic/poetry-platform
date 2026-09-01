# DIA-260827-y9n9 - [CRITICAL] Cross-session handoff corruption via process-global parentSessionId

---

id: DIA-260827-y9n9
title: "[CRITICAL] Cross-session handoff corruption via process-global parentSessionId"
area: opencode-config
severity: Critical
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

- .opencode/plugins/delegation-observer.ts:1112,3562-3564,4439-4457

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-C1) confirms the root cause. Evidence: .opencode/plugins/delegation-observer.ts:1131,3591-3593,4475-4476 stores the first task-calling session in a process-global parentSessionId, and the terminal handoff picks it ahead of context.sessionID. The test .opencode/plugins/**tests**/parallel-handoff.test.mjs:596-625 actually pins this unsafe precedence. Impact: session A calls task first; session B later writes the terminal handoff and overwrites A's slot and pointer with the wrong identity. Duplicate ticket DIA-260827-uqw0 tracks the same root cause; consider closing one to avoid split effort.

## Verification

Add a parallel-session regression where B's terminal handoff writes B's slot/identity; assert context.sessionID is the sole source of handoff identity; grep that parentSessionId no longer drives slot selection.

## Fix

Detail: process-global parentSessionId captures the first task-calling orchestrator and takes precedence over current context.sessionID; a second orchestrator writes and archives the first session's slot. Impact: wrong active.json, missing second-session slot, lost/misattributed prognosis.

Fix: require current runtime session ID for handoff identity; validate any fallback ID. (Related prior work DIA-222/DIA-223 addressed archive collision + "unknown" fallback but kept parentSessionId precedence, so this root cause remains open.)

## Re-verify

> To be filled at re-verify time.
