# DIA-260903-oj59 - self-rerun thresholds: 60% primary / 75% safety-net (new default)

---

id: DIA-260903-oj59
title: "self-rerun thresholds: 60% primary / 75% safety-net (new default)"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-03
source: inventory
date: 2026-09-03
created: 2026-09-03
updated: 2026-09-03

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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Resolution

Obsolete 2026-11-04: 60/75 self-rerun thresholds never landed; live context_usage gates are 15/25 (delegation-observer.ts:4079-4080); closed by DIA-261104-rhez - no work required.
