# DIA-260827-x99j - replace opencode/hy3-free with opencode-go/hy3 in cebula-hy3 preset

---

id: DIA-260827-x99j
title: "replace opencode/hy3-free with opencode-go/hy3 in cebula-hy3 preset"
area: opencode-config
severity: Minor
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
evidence: []

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Replace opencode/hy3-free with opencode-go/hy3 in cebula-hy3 preset (7ac48a5, shared with z9hq).

## Re-verify

Commits: 7ac48a5
Tests: make test-config exit 0
Confirm: cebula-hy3 preset hy3-free -> hy3 verified.
