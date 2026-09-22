# DIA-260827-ic3r - [MEDIUM] Resource-manager can delegate any lane (task allow unrestricted)

---

id: DIA-260827-ic3r
title: "[MEDIUM] Resource-manager can delegate any lane (task allow unrestricted)"
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

- .opencode/opencode.jsonc:581-602

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-M2) confirms resource-manager has unrestricted task: allow (opencode.jsonc:586-602). Impact: a narrow role can delegate an arbitrary writer or write outside ownership via shell. Correct fix: explicit deny-first blocks; resource-manager task map limited to researcher/conspecter.

## Verification

resource-manager cannot delegate lanes other than researcher/conspecter; deny-first blocks present.

## Fix

Detail: "task":"allow" is unrestricted although the contract names only researcher and conspecter.

Fix: deny \*, allow only those two.

## Re-verify

> To be filled at re-verify time.
