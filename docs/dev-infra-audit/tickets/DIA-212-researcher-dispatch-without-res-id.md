# DIA-212 — Researcher dispatched without pre-allocated res ID — extra iteration required

---

id: DIA-212
title: "Researcher dispatched without pre-allocated res ID -- extra iteration required"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: []
parent_epic: ""

gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered:
source: fix-lane
date: 2026-08-17
created: 2026-08-17
updated: 2026-08-17

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

Bug: orchestrator dispatched @researcher for intercellular communication research (DIA-211) WITHOUT first pre-allocating a res ID (Phase 1 of research-pipeline skill). Researcher returned PERSISTENCE_RECOMMENDED: true but could not write to sources/ because no res ID was allocated. This forced a second dispatch (Phase A source capture) to fetch the same URLs, wasting a full agent cycle.

Root cause: orchestrator skipped Phase 1 (ID pre-allocation) of the research-pipeline skill.

Fix: add a gate/enforcement that ensures research dispatches always carry a pre-allocated res ID, similar to how DIA-063 ticket gate ensures no engineering without a ticket. This should be part of the DIA-211 event-driven orchestration evolution.

## Verification

1. Grep orchestrator prompt/rules for research-pipeline Phase 1 gate check
2. Confirm that dispatching @researcher without a pre-allocated res ID is blocked or warned
3. Verify the researcher receives a res ID in its dispatch payload

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
