# DIA-260831-h3i4 - Built-in build plan write-capable bypass of orchestrator rules

---

id: DIA-260831-h3i4
title: "Built-in build plan write-capable bypass of orchestrator rules"
area: opencode-config
severity: High
status: OPEN
blocked_by: []
parent_epic: DIA-260827-wfcx
gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered: 2026-08-31
source: inventory
date: 2026-08-31
created: 2026-08-31
updated: 2026-08-31

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-H4) evidence: .opencode/opencode.jsonc:127-133 disables only explore/general; opencode agent list shows 'build (primary)' and 'plan (primary)'; the effective build inherits broad edit/bash. Impact: a user or command can enter a lane outside the orchestrator ticket/delegation rules. Correct fix: disable or strictly restrict build/plan and validate the resolved agent inventory.

## Verification

opencode agent list shows no write-capable build/plan primary; resolved agent inventory passes validation.

## Fix

Disable or strictly restrict the built-in build and plan agents (broad edit/bash), and add validation of the resolved agent inventory so no write-capable lane escapes the orchestrator rules.

## Re-verify

> To be filled at re-verify time.
