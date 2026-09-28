# DIA-260927-shgj - test-config: run the read-only validators in parallel

---

id: DIA-260927-shgj
title: "test-config: run the read-only validators in parallel"
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

test-config runs ~20 read-only bash validators sequentially (~1.6 s). Run them concurrently (background jobs + wait, or xargs -P). File: Makefile:235-268. [ESTIMATE] ~1.0 s saved (1.6 s -> ~0.4 s). Risk: low (validators are pure read-only, no shared state or output deps). Constraint: preserve correct exit-code propagation and non-interleaved failure output.

## Verification

- [ ] `make test-config` exit 0
- [ ] Record before/after wall time

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
