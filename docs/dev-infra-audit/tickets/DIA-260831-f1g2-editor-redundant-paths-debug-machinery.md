# DIA-260831-f1g2 - Editor redundant paths debug machinery

---

id: DIA-260831-f1g2
title: "Editor redundant paths debug machinery"
area: js-tooling
severity: Low
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-L2) evidence: tokenizer.ts:24-100 exports a punctuation catalog that tokenize() never reads; TokenType.typographical is never emitted; opusFormattingFilter.ts:205-224 duplicates a cursor loop; :235-286 has an unproven allocation micro-optimization; OpusEditorView.ts:85-103 logs every update and publishes a misspelled window.\_\_edotorView. Impact: extra branches and an undocumented global with no leverage. Correct fix: after semantic regression tests, remove the unused table/type member, the debug global/logging, and simplify the micro-optimization.

## Verification

Add semantic regression tests for tokenizer/formatting; confirm removal of the unused table, type member, and debug global does not change behavior.

## Fix

After semantic regression tests, remove the unused punctuation catalog and TokenType.typographical, the duplicated cursor loop, the unproven micro-optimization, and the debug global/logging (window.\_\_edotorView).

## Re-verify

> To be filled at re-verify time.
