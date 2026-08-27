# DIA-260827-gt8l - No enforced CI and pre-push gate fails open

---

id: DIA-260827-gt8l
title: "No enforced CI and pre-push gate fails open"
area: config
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

.github/workflows is absent. scripts/verify-pre-push.sh:79-81 exits 0 when the dev container is unavailable. Impact: a contributor can push without any tests by stopping the container; remote branches have no independent verification.

## Verification

CI added for root JS, embedded OMO, plugin, shell/config, and Python suites; local fail-open retained only as developer convenience, never the sole merge gate.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
