# DIA-260829-kxqu - log_decision tool unavailable to orchestrator -- delegation-observer plugin tool not exposed to orchestrator agent

---

id: DIA-260829-kxqu
title: "log_decision tool unavailable to orchestrator -- delegation-observer plugin tool not exposed to orchestrator agent"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-29
source: inventory
date: 2026-08-29
created: 2026-08-29
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

Make delegation-observer Bun-parseable and expose log_decision tool (b42a1a7, 54e2dc1, ddcb2a2); harden handoff/ticket gates.

## Re-verify

Commits: b42a1a7, 54e2dc1, ddcb2a2
Tests: make test-config exit 0; bun test plugin-load-smoke.test.mjs 7 pass; validate-plugin-loads script path-hardcoded (bun smoke green)
Confirm: delegation-observer Bun-parseable, log_decision exposed, gates hardened.
