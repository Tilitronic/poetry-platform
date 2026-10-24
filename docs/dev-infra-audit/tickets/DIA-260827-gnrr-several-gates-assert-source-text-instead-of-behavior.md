# DIA-260827-gnrr - Several gates assert source text instead of behavior

---

id: DIA-260827-gnrr
title: "Several gates assert source text instead of behavior"
area: tests
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

scripts/test-ticket-gate.sh:3-28 is a static probe; 44-100 pass on grep literals and comments. scripts/**tests**/test-config-wiring.bats:16-22 searches the entire Makefile despite claiming to check the test-config recipe body. Impact: dead code/comments/references in unrelated targets can keep a gate green after real wiring or runtime behavior breaks.

## Verification

Makefile parsing scoped to recipe blocks; plugin grep checks replaced with real hook execution using controlled ticket fixtures.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
