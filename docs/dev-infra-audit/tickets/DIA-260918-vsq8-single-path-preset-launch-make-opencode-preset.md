# DIA-260918-vsq8 - single-path preset launch make opencode PRESET

---

id: DIA-260918-vsq8
title: "single-path preset launch make opencode PRESET"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-18
source: inventory
date: 2026-09-18
created: 2026-09-18
updated: 2026-09-18

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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Evidence

Host smoke 2026-09-18 provided by developer, recorded verbatim:

1. git log HEAD d59e9fc plus 8690921 plus fe29b95 plus 793d40b plus e50c1de on branch omo-slim-changes.
2. make presets prints free muse-balanced openai-first-cost-balanced promo-union-alpha exit 0.
3. make preset NAME=free prints deprecation Use make opencode PRESET plus make presets, make exit 2, STUB_EXIT=2.
4. make opencode PRESET=does-not-exist prints Unknown preset plus Available presets list, make exit 2, EXIT=2, no container started.

Remaining live check: make opencode PRESET=free and PRESET=muse-balanced Effective lines at TUI startup, to be captured on next interactive launch.
