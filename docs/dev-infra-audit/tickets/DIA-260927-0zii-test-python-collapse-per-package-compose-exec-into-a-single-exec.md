# DIA-260927-0zii - test-python: collapse per-package compose exec into a single exec

---

id: DIA-260927-0zii
title: "test-python: collapse per-package compose exec into a single exec"
area: tests-infra
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
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

The test-python recipe makes separate `compose exec` calls per package (install + pytest for each of 3 packages). Collapse them into a SINGLE exec running a bash loop over the packages. File: Makefile:191-196. [ESTIMATE] ~1.8 s saved (2x ~900 ms exec overhead). Risk: low (shell quoting gets trickier). Origin: recon under DIA-260926-ch1d (lane ses_f1ea8e1b2ffe0gZKORW1VGf23E).

## Verification

- [ ] `make test-python` green in-container
- [ ] Record before/after wall time
- [ ] `make test-infra` green on the HOST

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
