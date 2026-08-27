# DIA-260827-4q3h - [HIGH] Reviewer cannot acquire its required diff (bash denied)

---

id: DIA-260827-4q3h
title: "[HIGH] Reviewer cannot acquire its required diff (bash denied)"
area: opencode-config
severity: Major
status: OPEN
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
evidence:

- .opencode/oh-my-opencode-slim/reviewer.md:7-9; .opencode/opencode.jsonc:292-298

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Detail: contract requires git diff, git log, and ref validation while all bash is denied. Impact: review may inspect current files rather than the requested fixed-point delta.

Fix: supply immutable diff/log in the dispatch or allow only read-only git commands.

## Re-verify

> To be filled at re-verify time.
