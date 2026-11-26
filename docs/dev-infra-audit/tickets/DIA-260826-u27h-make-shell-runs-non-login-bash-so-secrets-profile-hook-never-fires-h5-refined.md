# DIA-260826-u27h - make shell runs non-login bash so secrets profile hook never fires (H5 refined)

---

id: DIA-260826-u27h
title: "make shell runs non-login bash so secrets profile hook never fires (H5 refined)"
area: dev-infra
severity: Major
status: CLOSED
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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Make shell non-login bash so secrets profile hook never fires; add platform detection to needs-input observer (9f1da995).

## Re-verify

Commits: 9f1da995
Tests: make test-config exit 0; bun test needs-input-observer.platform-gate.test.mjs pass
Confirm: non-login bash platform detection wired.
