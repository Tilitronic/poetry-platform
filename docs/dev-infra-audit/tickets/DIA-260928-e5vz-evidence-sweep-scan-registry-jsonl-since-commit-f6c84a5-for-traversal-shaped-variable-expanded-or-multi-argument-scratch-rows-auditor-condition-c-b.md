# DIA-260928-e5vz - evidence sweep: scan registry.jsonl since commit f6c84a5 for traversal-shaped, variable-expanded or multi-argument .scratch rows (auditor condition C-B)

---

id: DIA-260928-e5vz
title: "evidence sweep: scan registry.jsonl since commit f6c84a5 for traversal-shaped, variable-expanded or multi-argument .scratch rows (auditor condition C-B)"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-28
source: inventory
date: 2026-09-28
created: 2026-09-28
updated: 2026-09-28

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

Auditor condition C-B attached to the DIA-260926-5vin verdict (SOUND-with-conditions).

Scope: scan .opencode/session/registry.jsonl for rows dated after commit f6c84a5 that show a .scratch command in a traversal-shaped, variable-expanded or multi-argument form.

Interpretation: any such row means real traffic already exercises those shapes, which flips the marginal verdict to live and triggers the wrapper/guard work; a clean sweep is the evidence that keeps the current decision justified.

Note: this is now partially superseded by the separate High-severity finding that a multi-argument rm rides along on the broad "rm \*" allow. Keep this ticket scoped to gathering historical traffic evidence.

Evidence format per qualifying row: capture the registry line index, the resolved action pattern that won, the action outcome (allow/ask/deny), the argument shape class (traversal-shaped / variable-expanded / multi-argument), and the raw command text.

Acceptance criterion: the sweep is complete only when the exact command used to scan the registry for rows since commit f6c84a5 is recorded verbatim in this ticket, together with either the bounded finding (row count plus the qualifying rows) or an explicit clean-sweep statement with that command and a zero count.

## Re-verify

> To be filled at re-verify time.
