# DIA-260827-uv - Routing-order regression suite copies logic and is orphaned

---

id: DIA-260827-uv
title: "Routing-order regression suite copies logic and is orphaned"
area: scripts
severity: Major
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

scripts/**tests**/routing-order-gate.test.mjs:23-90 redefines CONFIG_WORK_PATTERN, hasPriorAiSpecialistDispatch, and the gate flow instead of importing production code; its control-flow test at 374-388 only calls the local simulation; error-prefix test at 428-455 constructs both error strings inside the test. test-config runs only batch-d-infra.test.mjs at Makefile:194-215; the Bats wrapper syntax-checks MJS in quick mode. Impact: production routing order/regex/error handling can diverge while all 36 copied-logic tests stay green.

## Verification

Production gate functions extracted into an importable module; the Node suite tests those exact exports; an end-to-end hook case added; the Node suite wired into test-config.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
