# DIA-260827-4aqb - Agent routing bypasses tdd-craftsman RED-GREEN workflow

---

id: DIA-260827-4aqb
title: "Agent routing bypasses tdd-craftsman RED-GREEN workflow"
area: opencode-config
severity: High
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: test-lane
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

- DIA-260827-wfcx

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-H2) confirms .opencode/opencode.jsonc:760-764 directly runs a single coder, and the template performs both RED and GREEN; AGENTS.md and the promo prompt require different coder instances. Impact: the test author implements against its own tests and bypasses the DIA-175 independence gate. Correct fix: command owner is the orchestrator; separate RED and GREEN dispatches under a campaign ticket.

## Verification

A /tdd-cycle dispatch yields two distinct coder instances (RED then GREEN) with separate session ids; no single coder runs both phases.

## Fix

Make the command owner the orchestrator; issue separate RED and GREEN dispatches with a campaign ticket so different coder instances own test authoring and implementation (DIA-175).

## Re-verify

> To be filled at re-verify time.
