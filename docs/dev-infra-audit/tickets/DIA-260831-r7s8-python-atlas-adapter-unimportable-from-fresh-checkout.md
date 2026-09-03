# DIA-260831-r7s8 - Python atlas adapter unimportable from fresh checkout

---

id: DIA-260831-r7s8
title: "Python atlas adapter unimportable from fresh checkout"
area: python-tooling
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-M1) evidence: load_atlas.py:50-76 looks for dist/python while committed bindings live in scripts/generated/python; analytics-pipeline/pyproject.toml:5-9 declares no flatbuffers, numpy, panphon, or adapter dependency; a direct import raised ImportError. Impact: the architecture-declared Python Adapter does not work from a fresh checkout; not a safe deletion because the cross-language seam is intended. Correct fix: one canonical generated path, an installable Python package, declared deps, and a clean-checkout import/load test.

## Verification

From a fresh checkout, pip install the adapter and import load_atlas; run an import/load test in CI.

## Fix

Adopt a single canonical generated path, ship the Python adapter as an installable package with declared deps (flatbuffers, numpy, panphon), and add a clean-checkout import/load test.

## Re-verify

> To be filled at re-verify time.
