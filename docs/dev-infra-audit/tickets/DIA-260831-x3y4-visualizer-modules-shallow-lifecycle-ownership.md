# DIA-260831-x3y4 - Visualizer modules shallow lifecycle ownership

---

id: DIA-260831-x3y4
title: "Visualizer modules shallow lifecycle ownership"
area: js-tooling
severity: Medium
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-M4) evidence: the 2D visualizer takes an unused any Orchestrator and has an empty update() (visualizer-2d/src/interactive/index.ts:8,47-54); VisualizerContainer.vue:31-50 never calls destroy; the 3D visualizer takes an unused any and on unmount disposes the renderer but not geometry/material (visualizer-3d/src/index.ts:7,32-40,56-59). Impact: the Interface leaks the whole Orchestrator without leverage; remount can leave GPU resources; SSR/interactive render placeholders, not contract data. Correct fix: keep the visualizer Seam but deepen it around a typed contract snapshot plus scene model plus complete lifecycle ownership.

## Verification

Add a test that remounts the visualizer and asserts GPU resources are disposed; assert the interface takes a typed contract snapshot, not any.

## Fix

Deepen the visualizer seam around a typed contract snapshot, a scene model, and full lifecycle ownership (dispose geometry/material, call destroy); remove the unused any Orchestrator.

## Re-verify

> To be filled at re-verify time.
