# DIA-260831-d9e0 - CommandBus serves only no-op producer

---

id: DIA-260831-d9e0
title: "CommandBus serves only no-op producer"
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-L1) evidence: opusDecorator.ts:33-40 is the only production producer and its execute is () => {}; command-bus.ts:16-40 still sorts the queue and runs flush. Impact: document/viewport updates do extra work and mask the real formatting flow. Correct fix: safe deletion of the no-op enqueue. The public CommandBus Seam itself should be removed only after a design decision.

## Verification

Confirm removing the no-op enqueue does not change observable formatting; CommandBus remains as a documented seam.

## Fix

Delete the no-op producer enqueue path. Remove the public CommandBus Seam only after a design decision.

## Re-verify

> To be filled at re-verify time.
