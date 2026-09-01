# DIA-260831-c3d4 - Turbo test cache ignores test config inputs

---

id: DIA-260831-c3d4
title: "Turbo test cache ignores test config inputs"
area: tests-infra
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

Reaudit (DIA-260827-wfcx, 2026-08-31; T-M6) evidence: turbo.json:21-27 inputs do not include vitest.config.ts or tsconfig\*.json; the whole root run was replayed from cache. Impact: a change to the test environment can reuse a stale green result. Correct fix: add $TURBO_DEFAULT$ or explicit config inputs, or disable caching for test.

## Verification

Touch vitest.config.ts and confirm turbo reruns the test task rather than replaying cache.

## Fix

Add vitest.config.ts and tsconfig\*.json to the test task inputs in turbo.json (or use $TURBO_DEFAULT$); alternatively disable caching for the test task.

## Re-verify

> To be filled at re-verify time.
