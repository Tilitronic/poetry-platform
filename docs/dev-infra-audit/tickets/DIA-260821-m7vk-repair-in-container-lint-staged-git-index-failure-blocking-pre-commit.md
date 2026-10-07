# DIA-260821-m7vk - Repair in-container lint-staged Git index failure blocking pre-commit

---

id: DIA-260821-m7vk
title: "Repair in-container lint-staged Git index failure blocking pre-commit"
area: dev-infra
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
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

Align container UID/GID + migrate .git ownership at boot to fix lint-staged index (c19ed6b).

## Re-verify

Commits: c19ed6b
Tests: make test-config exit 0; bats-wrapper exit 0; verify-pre-commit-uid-mismatch.bats pass
Confirm: UID/GID alignment + .git ownership migration verified.
