# DIA-260825-f1o7 - misc cleanup run_phase_a v1 os.replace kb-cache phonetics empty placeholders plus doc sync

---

id: DIA-260825-f1o7
title: "misc cleanup run_phase_a v1 os.replace kb-cache phonetics empty placeholders plus doc sync"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-25
source: inventory
date: 2026-08-25
created: 2026-08-25
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

Misc cleanup: os.replace in query_rag, delete run_phase_a.sh + 4 empty phonetics-core placeholders, doc sync (69aa970).

## Re-verify

Commits: 69aa970
Tests: make test-config exit 0; bats-wrapper exit 0
Confirm: misc cleanup applied, os.replace atomicity verified.
