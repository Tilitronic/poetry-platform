# DIA-260827-ld2l - [MEDIUM] Memory-manager and designer over-granted permissions

---

id: DIA-260827-ld2l
title: "[MEDIUM] Memory-manager and designer over-granted permissions"
area: opencode-config
severity: Medium
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

- .opencode/opencode.jsonc:503-506,518-528

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-M2) confirms designer has no permission block (opencode.jsonc:503-506); memory-manager restricts only edit (:518-528) and inherits global capabilities. Impact: artifact boundaries are prompt-only and shell can bypass edit scoping. Correct fix: explicit deny-first permission blocks for both roles.

## Verification

designer and memory-manager have explicit deny-first blocks; neither can write outside its ownership.

## Fix

Detail: memory-manager lacks bash/task denies; designer has no permission block. Both inherit broad global capabilities. Impact: artifact boundaries are prompt-only and shell can bypass edit scoping.

Fix: add explicit denies / permission block.

## Re-verify

> To be filled at re-verify time.
