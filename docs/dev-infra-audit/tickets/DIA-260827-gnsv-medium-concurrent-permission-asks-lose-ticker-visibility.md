# DIA-260827-gnsv - [MEDIUM] Concurrent permission asks lose ticker visibility

---

id: DIA-260827-gnsv
title: "[MEDIUM] Concurrent permission asks lose ticker visibility"
area: opencode-config
severity: Medium
status: CLOSED
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
updated: 2026-09-11

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

- .opencode/plugins/needs-input-observer.ts:407-436,501-505,1238-1256

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-M3) confirms a waiting entry keyed by session (needs-input-observer.ts:282); any single reply calls clear(sessionID) (:1307-1321); the renderer does not show persisted permissions (scripts/ticker-render.sh:41-49). Impact: a second unclosed permission disappears from the ticker/compaction view. Correct fix: key by request id, or clear the session only when the pending set is empty; render pending permissions.

## Verification

Two concurrent permission asks both remain visible until each is resolved; pending permissions render in the ticker.

## Fix

Landed in 7edeafd: per-permission ticker rows with scoped clearing (two-map design in needs-input-observer.ts). Waiting cleared per request id; session entry cleared only when the pending set is empty; ticker-render.sh renders pending permissions. Harness 7/41 pass, bats 6/6, shell 642 pass per evidence lane; make test-config EXIT 0. R3 evidence attached in lane. ai-auditor: CONFORMANT-WITH-NOTES. Code plus changelog already landed; this lane is bookkeeping only.

## Re-verify

Re-verify gnsv: two-map commit 7edeafd present; harness 7/41, bats 6/6, shell 642 pass per evidence lane; test-config EXIT 0; R3 evidence on file; auditor CONFORMANT-WITH-NOTES. This close-out lane: make test-config EXIT 0, git diff --check EXIT 0 (evidence in .scratch/test-config.log). No code change in this lane; status may go CLOSED.
