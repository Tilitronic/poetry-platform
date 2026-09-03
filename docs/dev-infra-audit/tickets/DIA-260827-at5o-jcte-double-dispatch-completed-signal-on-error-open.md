# DIA-260827-at5o - jcte double dispatch.completed signal on error+OPEN

---

id: DIA-260827-at5o
title: "jcte double dispatch.completed signal on error+OPEN"
area: delegation-observer
severity: Info
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

- commit:22944c6
- re-review-observation-fix:double-signal-removed

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Removed the standalone `emitStateSignal(sessionID, "dispatch.completed", { result: "error", ... })` on the `session.error` path (~:4154). The OPEN-circuit case now returns early via `runApoptosis` (which owns the single `dispatch.completed` signal, result "apoptosis"); the CLOSED-circuit case intentionally emits no `dispatch.completed` here. Net result: one session emits exactly one `dispatch.completed`.

## Re-verify

Repurposed test `dispatch.completed emitted exactly once (apoptosis) on session.error+OPEN, no double` asserts exactly one `dispatch.completed` (result "apoptosis") for the error+OPEN case. `bun test .opencode/plugins/__tests__/dia220-apoptosis-paracrine.test.mjs` -> 16 pass / 0 fail. No double signal remains.
