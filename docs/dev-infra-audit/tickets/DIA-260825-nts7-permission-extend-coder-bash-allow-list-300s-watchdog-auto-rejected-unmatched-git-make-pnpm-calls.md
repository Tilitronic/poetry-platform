# DIA-260825-nts7 - permission: extend coder bash allow-list - 300s watchdog auto-rejected unmatched git/make/pnpm calls

---

id: DIA-260825-nts7
title: "permission: extend coder bash allow-list - 300s watchdog auto-rejected unmatched git/make/pnpm calls"
area: scripts
severity: Medium
status: OPEN
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
updated: 2026-08-25

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

Root cause: the coder agent bash permission is a deny-by-default allow-list MAP
at opencode.jsonc:312-324. It does NOT inherit the global "\*": "allow" baseline.
Commands outside the list default to "ask", and the needs-input-observer
plugin (hardcoded 300s watchdog, env PERMISSION_STALL_TIMEOUT_MINUTES) auto-
rejects unanswered prompts with "no_human_response_within_threshold". Three
fix-lane sessions died this way before any work started: cod-2, cod-3, cod-4.

Gate verdict: APPROVE-WITH-NOTES by ai-specialist session
ses_fc6f516efffeO0DdLJ4kEH4r2J (generation 17, cross-ref DIA-260825-e9ou).

coder-escalated has the same gap: its bash allow-list (opencode.jsonc:342-349)
contains zero allows, so it also defaults to "ask" and hits the 300s watchdog.

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
