# DIA-260827-48iw - Python phonetics-core atlas loader has no test or lint gate

---

id: DIA-260827-48iw
title: "Python phonetics-core atlas loader has no test or lint gate"
area: tests
severity: High
status: CLOSED
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

Python loader exported at packages/phonetics-core/package.json:21; corruption handling, indexing, iteration, loading APIs at packages/phonetics-core/src/atlas/load_atlas.py:43-298. Python verification covers only API server and analytics at scripts/verify-python.sh:37-38. Impact: the 316-line Python implementation can drift from the well-tested TypeScript loader or mishandle corrupt binaries without signal.

Reaudit (DIA-260827-wfcx, 2026-08-31) confirms: packages/phonetics-core/src/atlas/load_atlas.py:43-316 is 316 lines of runtime code; scripts/verify-python.sh:37-38 does not check it; no Python test target exists. Impact: mmap lifetime, corruption handling, Unicode normalization, and TS/Python parity can break silently. Correct fix: ship the Python adapter as an installable artifact and add import/load/corruption fixtures plus a cross-language parity test to the Python/CI gate.

## Verification

A Python project/test target for phonetics-core added; the committed atlas and corruption fixtures run through both implementations; cross-language parity asserted.

## Fix

Package the Python atlas loader as an installable artifact; add import/load/corruption fixtures and a cross-language (TS vs Python) parity test to the Python and CI gates.

## Re-verify

Merged to omo-slim-changes at 0fa1342 fix(tests): add Python atlas loader gate (DIA-260827-48iw).

Fix: packaged python atlas loader as installable artifact; added import/load/corruption fixtures and cross-language parity test to Python/CI gate.

Re-verify evidence (2026-09-01):

- merge commit: 0fa1342 (parent f36490b) on branch omo-slim-changes, verified via git cat-file -p
- phonetics-core Python tests: 26 pass / 1 skip (pytest packages/phonetics-core)
- scripts/verify-python.sh: exit 0
- ruff check: clean
- TS/Python parity asserted via committed atlas and corruption fixtures
  Status: developer-approved completion, CLOSED 2026-09-01.
