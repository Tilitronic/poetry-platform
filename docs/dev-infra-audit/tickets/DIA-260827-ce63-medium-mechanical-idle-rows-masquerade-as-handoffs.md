# DIA-260827-ce63 - [MEDIUM] Mechanical idle rows masquerade as handoffs

---

id: DIA-260827-ce63
title: "[MEDIUM] Mechanical idle rows masquerade as handoffs"
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

- .opencode/plugins/delegation-observer.ts:3968-4002

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-M5) confirms delegation-observer.ts:4012-4030 writes event_type: handoff with no prognosis/slot; scripts/session-log:67-79 shows it as a handoff. Impact: recovery consumers cannot tell batch completion from a terminal prognosis. Correct fix: a separate delegation_batch_complete; reserve handoff for slot-producing terminal events.

## Verification

Idle rows emit delegation_batch_complete, not handoff; handoff rows always carry a slot/prognosis.

## Fix

Detail: every post-delegation idle emits event_type:"handoff" without writing a handoff slot; audit consumers can mistake idle telemetry for DIA-124 compliance.

Fix: use a distinct event type or add explicit handoff_written:false.

## Re-verify

> To be filled at re-verify time.
