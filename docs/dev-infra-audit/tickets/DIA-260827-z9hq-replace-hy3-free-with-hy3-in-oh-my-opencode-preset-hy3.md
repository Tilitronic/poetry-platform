# DIA-260827-z9hq - replace HY3 Free with HY3 in oh-my-opencode preset HY3

---

id: DIA-260827-z9hq
title: "replace HY3 Free with HY3 in oh-my-opencode preset HY3"
area: opencode-config
severity: Minor
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Replace HY3 Free with HY3 in oh-my-opencode preset HY3 (7ac48a5, shared with x99j).

## Re-verify

Commits: 7ac48a5
Tests: make test-config exit 0
Confirm: oh-my-opencode preset HY3 Free -> HY3 verified.
