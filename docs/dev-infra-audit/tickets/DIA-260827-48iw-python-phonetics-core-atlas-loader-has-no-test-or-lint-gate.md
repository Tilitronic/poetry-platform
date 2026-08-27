# DIA-260827-48iw - Python phonetics-core atlas loader has no test or lint gate

---

id: DIA-260827-48iw
title: "Python phonetics-core atlas loader has no test or lint gate"
area: tests
severity: Major
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

Python loader exported at packages/phonetics-core/package.json:21; corruption handling, indexing, iteration, loading APIs at packages/phonetics-core/src/atlas/load_atlas.py:43-298. Python verification covers only API server and analytics at scripts/verify-python.sh:37-38. Impact: the 316-line Python implementation can drift from the well-tested TypeScript loader or mishandle corrupt binaries without signal.

## Verification

A Python project/test target for phonetics-core added; the committed atlas and corruption fixtures run through both implementations; cross-language parity asserted.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
