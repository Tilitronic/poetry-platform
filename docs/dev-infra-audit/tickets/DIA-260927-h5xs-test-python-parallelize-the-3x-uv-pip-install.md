# DIA-260927-h5xs - test-python: parallelize the 3x uv pip install

---

id: DIA-260927-h5xs
title: "test-python: parallelize the 3x uv pip install"
area: tests-infra
severity: Low
status: OPEN
blocked_by: [DIA-260927-0zii] # DIA-NNN refs, or empty
parent_epic: DIA-260927-k8nh
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-27
source: fix-lane
date: 2026-09-27
created: 2026-09-27
updated: 2026-09-27

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

The 3 per-package `uv pip install` calls run sequentially; overlap them. File: Makefile:191-196. [ESTIMATE] ~2 s saved. Risk: low. Blocked by DIA-260927-0zii (both edit the same Makefile:191-196 region; this ticket builds on the consolidated exec from DIA-260927-0zii).

## Verification

- [ ] `make test-python` green in-container
- [ ] Record before/after wall time

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
