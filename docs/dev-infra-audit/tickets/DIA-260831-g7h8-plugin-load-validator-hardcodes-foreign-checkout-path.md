# DIA-260831-g7h8 - Plugin load validator hardcodes foreign checkout path

---

id: DIA-260831-g7h8
title: "Plugin load validator hardcodes foreign checkout path"
area: scripts
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

Reaudit (DIA-260827-wfcx, 2026-08-31; W-M6) evidence: scripts/validate-plugin-loads.sh:16,20 hardcodes /home/qualt/Projects/poetry-platform; a local run exits 1. Impact: the Bun-loader regression guard works neither here nor in /workspace. Correct fix: derive the repo root from the script location, use a canonical file URL, and add a test fixture covering two checkout paths.

## Verification

Run scripts/validate-plugin-loads.sh from an arbitrary checkout path; assert it resolves the repo root and passes.

## Fix

Derive the repo root from the script's own location instead of a hardcoded absolute path; use a canonical file URL; add a fixture that exercises two distinct checkout paths.

## Re-verify

> To be filled at re-verify time.
