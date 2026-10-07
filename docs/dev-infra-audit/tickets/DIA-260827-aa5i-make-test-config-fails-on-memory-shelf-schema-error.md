# DIA-260827-aa5i - make test-config fails on memory-shelf schema error

---

id: DIA-260827-aa5i
title: "make test-config fails on memory-shelf schema error"
area: tests-infra
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: test-lane
date: 2026-08-27
created: 2026-08-27
updated: 2026-09-11

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
evidence:

- .scratch/DIA-260827-aa5i-test-config.log
- DIA-260827-wfcx

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

Verification run for DIA-260827-aa5i

- Command: make test-config
- Exit code: 0
- Memory-shelf proof: ok: /workspace/scripts/../.opencode/memory-shelf.yaml (shelf shape matches scripts/schemas/memory-shelf.schema.json)
- Config suite proof: tests 57, pass 57, fail 0
- Structural proof: validate-plugin-structure.sh: all structural gates PASS
- Full output artifact: .scratch/DIA-260827-aa5i-test-config.log
- Implementation files changed: none by this verification lane
