# DIA-260827-95fv - [BUG] task() returns 'Task cancelled' while background session is live or stopped-without-result (return-channel false state)

---

id: DIA-260827-95fv
title: "[BUG] task() returns 'Task cancelled' while background session is live or stopped-without-result (return-channel false state)"
area: opencode-config
severity: Major
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

- session:ses_fbac184f0ffe3FSifm3603HDpa
- session:ses_fbac0ba05ffeL1AmqRmdmCN9Li

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

## Evidence

Two memory-manager dispatches in this orchestrator session returned the string
"Task cancelled" from the task() return channel:

- mem-1: session ses_fbac184f0ffe3FSifm3603HDpa
- mem-2: session ses_fbac0ba05ffeL1AmqRmdmCN9Li

Both later appeared on the Background Job Board as "stopped, unreconciled" ?
i.e. the background sessions ended WITHOUT a terminal task result. They did
not actually complete, and were not genuinely user-cancelled. The task() return
channel reported a false "Task cancelled" state instead of the true state.

## Impact

The orchestrator may wrongly treat a live or stopped-without-result session as
dead. This causes two failure modes:

1. Duplicate re-dispatch of work that is still in flight or already stopped.
2. Misclassification of a stopped-without-result lane, breaking the
   truncated-lane recovery protocol (DIA-099), which expects a distinct
   stopped-without-result state to trigger the correct resume path.

## Fix direction

Reconcile the task() return value with the actual session lifecycle state
reported by the Background Job Board. Do NOT emit "Task cancelled" when the
session is live or stopped-without-result. Surface a distinct state
(e.g. "stopped-without-result" / "return-channel-unverified") so the
orchestrator applies the correct recovery path instead of assuming death.

## Re-verify

> To be filled at re-verify time.
