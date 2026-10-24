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

## Audit correction (DIA-261022-5n2v)

Verdict: UNSAFE_AS_SPECIFIED - the repo over-engineering audit's P2 proposal (delete the whole phonetic-atlas loader chain) self-breaks; blocking prerequisites before any deletion:

- packages/phonetics-core/package.json:6-27 makes src/atlas/load-atlas.ts the package main/types/exports and packages/editor-engine/package.json:20 + tsconfig.json:6 depend on it; scripts/gen-jsconfig.sh:119 hard-errors inside make test-infra on a missing declared entry.
- scripts/generate_phonetic_atlas.py:138-139,323-330,485-494 imports the generated Python bindings the proposal deletes (plus flatbuffers/pandas/panphon); test_parity.py/test_load_atlas.py are the only FlatBuffers schema-drift guard.
- The two .bin copies are not redundant (package.json:23-24 vs load_atlas.py:331 vs turbo.json:10 vs .gitignore:13).
  Honest cost: ~3,095 lines, but every part is load-bearing today (package main, test-infra gate, schema-drift guard); net zero until the prerequisites land.
