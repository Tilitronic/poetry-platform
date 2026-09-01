# DIA-260831-p5q6 - PoetryState duplicate line ids corrupt map/order invariant

---

id: DIA-260831-p5q6
title: "PoetryState duplicate line ids corrupt map/order invariant"
area: js-tooling
severity: High
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-H4) evidence: packages/editor-engine/src/state/PoetryState.ts:16-25 overwrites the Map entry but appends the same id to order; removeLine() at :29-31 deletes all duplicates. Impact: display order contains several identical ids pointing to one atom, and the prior atom becomes orphaned for state. Correct fix: enforce a uniqueness invariant: reject duplicates or upsert without re-appending; add duplicate/removal tests.

## Verification

Add tests for adding a duplicate line id and for removeLine on a duplicated id; assert order has no duplicates and no orphaned atoms.

## Fix

Enforce a uniqueness invariant in PoetryState: reject duplicate line ids or upsert without re-appending to order; add duplicate-insertion and removal regression tests.

## Re-verify

> To be filled at re-verify time.
