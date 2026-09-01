# DIA-260831-i9j0 - Opus formatting filter destroys CodeMirror transaction semantics

---

id: DIA-260831-i9j0
title: "Opus formatting filter destroys CodeMirror transaction semantics"
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-H1) evidence: packages/editor-engine/src/view/opusFormattingFilter.ts:282-295 replaces the transaction with {changes, selection} holding a single cursor. Impact: extensions lose StateEffects/annotations, explicit scroll disappears, and multi-cursor editing silently breaks (a two-cursor edit is reduced to one range). Correct fix: map all selection ranges through the final ChangeSet; preserve effects, annotations, user event, and scroll; add interface regression tests.

## Verification

Add a regression test with a two-cursor edit and a transaction carrying effects/scroll; assert ranges, effects, and scroll survive the filter.

## Fix

Rewrite opusFormattingFilter to map every selection range through the final ChangeSet and preserve StateEffects, annotations, userEvent, and scrollIntoView; add interface regression tests.

## Re-verify

> To be filled at re-verify time.
