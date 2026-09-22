# DIA-260901-r0hx - Replace QN3.7 Plus with QN3.8 Flash in all presets

---

id: DIA-260901-r0hx
title: "Replace QN3.7 Plus with QN3.8 Flash in all presets"
area: presets
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-01
source: inventory
date: 2026-09-01
created: 2026-09-01
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
evidence: []

---

## Description

Swap the model identifier 'QN3.7 Plus' for 'QN3.8 Flash' across every preset that references it. Presets are the model-definition entries the assistant loads; this updates all of them to the newer model. The actual swap implementation must follow the project's standard change-review workflow (research gate, implementation, independent review, validation).

## Verification

- A content search shows zero remaining references to 'QN3.7 Plus' in any preset
- All updated presets reference 'QN3.8 Flash'
- The project validation suite passes
- A restart smoke test loads presets without error

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
