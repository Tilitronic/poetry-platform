# DIA-261022-m6l8 - delegation-observer: two app.log promises near the handoff path remain unawaited

---

id: DIA-261022-m6l8
title: "delegation-observer: two app.log promises near the handoff path remain unawaited"
area: opencode-config
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-22
source: inventory
date: 2026-10-22
created: 2026-10-22
updated: 2026-10-22

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
evidence: []

---

## Description

`.opencode/plugins/delegation-observer.ts` - two `ctx.client.app.log(...)`
calls inside the log_decision terminal-handoff path are floating promises
(no await, no `.catch`):

- line 3563: literal-"JSON.stringify(...)" prognosis warn, inside
  `parsePrognosis`, which runs at line 3646 immediately before the handoff
  slot write
- line 3599: prognosis-parse-failed debug log, same helper

Their neighbours on the same handoff path all carry `.catch(() => {})`
(3674-3680, 3694-3700, 3726-3732, 3814-3820) precisely because the file
documents (3691-3693) that app.log returns an SDK promise that must never
surface as an unhandled rejection inside the handoff path. The same floating
pattern also exists OUTSIDE the handoff path (tuiSafeWarn helper at 779, and
2022, 2984, 3039, 3837) - out of this ticket's scope, noted for a future
sweep.

Decision needed: pin the two handoff-path calls with `.catch(() => {})`
(match the neighbours) or await them inside the async execute?

Recommended option: add `.catch(() => {})` to lines 3563 and 3599 - smallest
diff, matches the documented telemetry convention; awaiting inside
`parsePrognosis` (a synchronous helper) would force signature churn.

Alternative: first teach the tuiSafeWarn-style helper to swallow rejections,
then route these call sites through it (broader sweep - ticket separately).

## Verification

- [ ] Both handoff-path app.log calls no longer float (catch or await)
- [ ] bun parallel-handoff suite stays green
- [ ] No new unhandled-rejection warnings in a live TUI session smoke test

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
