# DIA-260827-5blh - [MEDIUM] Handoff identity permits path traversal

---

id: DIA-260827-5blh
title: "[MEDIUM] Handoff identity permits path traversal"
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
updated: 2026-10-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched:

- '.opencode/plugins/delegation-observer.ts'
- '.opencode/plugins/**tests**/parallel-handoff.test.mjs'
  artifacts: []
  evidence:
- '.opencode/plugins/delegation-observer.ts#L3672'
- '.opencode/plugins/**tests**/parallel-handoff.test.mjs#DIA-260827-5blh'
- '.opencode/plugins/delegation-observer.ts:1678-1713,1746,4446-4448'

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-M4) confirms raw identity enters join() at delegation-observer.ts:1709,1729-1731,1765; caller-provided lane_id precedes trusted context at :4475-4476. Impact: ../ can overwrite session state outside handoffs/. Correct fix: only runtime session id; anchored safe-id grammar; resolved-path containment.

## Verification

A lane_id of '../active' cannot escape the handoffs directory; resolved path containment enforced.

## Fix

Handoff slot selection now uses only the trusted runtime context.sessionID. If it is missing, the plugin skips the slot write and logs the condition; args.lane_id is never used as a file identity. The handoff writer also validates session IDs and resolves slot/temp/archive paths within their target directories.

## Re-verify

In poetry-dev, bun test parallel-handoff.test.mjs passed 13/13 (102 assertions), including traversal inputs and lane_id ses_someone_else with no runtime ID. make test-config exited 0, and TypeScript diagnostics for delegation-observer.ts were clear.
