# DIA-260831-b7c8 - Delegation observer plugin too broad extract deep modules

---

id: DIA-260831-b7c8
title: "Delegation observer plugin too broad extract deep modules"
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-M6) evidence: .opencode/plugins/delegation-observer.ts is 4985 lines and in one closure combines ticket authorization, lifecycle/apoptosis, handoff persistence, routing policy, formatting, telemetry, context budgeting, and tools. Impact: cross-gate control flow is hard to prove locally; prior bugs arose exactly between gates and lifecycle paths. Correct fix: do not split for size alone. Extract deep pure Modules on real seams: ticket authorization, handoff identity/store, lifecycle state machine, routing policy; keep the plugin an Adapter to OpenCode hooks. Design-gated: extract on real seams (ticket auth, handoff store, lifecycle state machine, routing policy).

## Verification

After extraction, confirm each extracted Module has unit tests and the plugin delegates to them; existing behavioral coverage (apoptosis, reload dedupe, ticket gates) still passes.

## Fix

Extract pure Modules on real seams: ticket authorization, handoff identity/store, lifecycle state machine, routing policy. Keep delegation-observer a thin Adapter over OpenCode hooks. Design-gated: split only on genuine seams, not by line count.

## Re-verify

> To be filled at re-verify time.
