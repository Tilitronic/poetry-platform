# DIA-260827-wawy - Heavy infra cleanup not guaranteed after test failure

---

id: DIA-260827-wawy
title: "Heavy infra cleanup not guaranteed after test failure"
area: docker
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: baseline
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

Makefile:141-144 runs smoke, Python, then docker compose down as the final recipe command. If smoke or Python fails after the leave-up path, Make aborts before teardown, leaving changed service state and increasing cross-run flakiness.

## Verification

Bring-up/test/teardown wrapped in one shell with an EXIT trap; original failure status preserved.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
