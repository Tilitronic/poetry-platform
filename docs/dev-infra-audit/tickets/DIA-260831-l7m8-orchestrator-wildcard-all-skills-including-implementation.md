# DIA-260831-l7m8 - Orchestrator wildcard all skills including implementation

---

id: DIA-260831-l7m8
title: "Orchestrator wildcard all skills including implementation"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: []
parent_epic: DIA-260827-wfcx
gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered: 2026-08-31
source: inventory
date: 2026-08-31
created: 2026-08-31
updated: 2026-08-31

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-M3) evidence: .opencode/oh-my-opencode-slim.jsonc:1162-1168; the effective runtime sees project, global, and two Ponytail roots. Impact: a delegation-only role receives browser/RAG/implementation prompts, causing trigger collisions and extra context surface. Correct fix: an explicit minimal orchestration allow-list; deny implementation skills.

## Verification

opencode debug shows the orchestrator skill list is a minimal allow-list with implementation skills denied.

## Fix

Replace the orchestrator wildcard with an explicit minimal orchestration allow-list and deny implementation/browser/RAG skills not needed for delegation.

## Re-verify

> To be filled at re-verify time.
