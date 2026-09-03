# DIA-260826-uozv - sync OMO pin in opencode-docker config to project version (H4)

---

id: DIA-260826-uozv
title: "sync OMO pin in opencode-docker config to project version (H4)"
area: opencode-config
severity: High
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260825-wprb
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
date: 2026-08-26
created: 2026-08-26
updated: 2026-08-26

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

Reaudit (DIA-260827-wfcx, 2026-08-31; S-H5) confirms project runtime 2.2.17 (opencode.jsonc:709-718), Docker 2.2.14 (tools/opencode-docker/config/opencode.json:24-27), embedded metadata 2.2.11 (oh-my-opencode-slim/package.json:2-5), and REFERENCE-ONLY.md:1-3 claims 2.2.13. Impact: host, container, and audited vendored code can behave differently; docs mislead. Correct fix: one source-of-truth policy, sync pins/docs, and an effective version assertion in the runtime gate.

## Verification

All surfaces report one pinned version; a runtime-gate assertion fails on version drift.

## Fix

Establish one source-of-truth version policy, sync the Docker and embedded pins with docs, and add an effective-version assertion in the runtime config gate.

## Re-verify

> To be filled at re-verify time.
