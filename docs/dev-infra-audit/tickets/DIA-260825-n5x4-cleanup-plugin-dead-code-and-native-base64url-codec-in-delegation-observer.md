# DIA-260825-n5x4 - cleanup plugin dead code and native base64url codec in delegation-observer

---

id: DIA-260825-n5x4
title: "cleanup plugin dead code and native base64url codec in delegation-observer"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-25
source: inventory
date: 2026-08-25
created: 2026-08-25
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

Native base64url codec via Buffer, delete dead health-store/selector code (15338aa); sync capability-tokens test helpers.

## Re-verify

Commits: 15338aa
Tests: make test-config exit 0; bun test capability-tokens.test.mjs pass (within 53-suite)
Confirm: native base64url codec, dead plugin code removed.
