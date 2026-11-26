# DIA-260827-95fv - [BUG] task() returns 'Task cancelled' while background session is live or stopped-without-result (return-channel false state)

---

id: DIA-260827-95fv
title: "[BUG] task() returns 'Task cancelled' while background session is live or stopped-without-result (return-channel false state)"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "grilled" # grilled | waived | bypassed | partial | skipped
gate_triggers: [schema-state, cross-cutting] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
date: 2026-08-27
created: 2026-08-27
updated: 2026-09-14

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

- session:ses_fbac184f0ffe3FSifm3603HDpa
- session:ses_fbac0ba05ffeL1AmqRmdmCN9Li

---

## Description

The task return channel trusted a textual `cancelled` receipt even when the
Background Job Board still described a live task or had no confirmed cancel
request. This could discard a stopped session, synthesize a false terminal
state, and trigger duplicate replacement work.

The approved contract makes the Board authoritative: cancellation requires a
Board terminal state plus `cancellationRequested=true`; uncertainty projects as
`return-channel-pending`; a deleted non-live task without a terminal result is
retained as `stopped-without-result` for exact-session recovery.

## Verification

- [x] Live or unconfirmed cancellation receipts remain non-terminal.
- [x] Confirmed cancellation requires an explicit Board cancel request.
- [x] Stopped-without-result tombstones retain required metadata and survive
      parent prompt injection and idle reconciliation.
- [x] Tombstones use a dedicated FIFO cap of 500 and exact-task-ID recovery.
- [x] Failed exact-session resume retains the tombstone without replacement.
- [x] Missing task IDs emit the exact non-persisted diagnostic without Board
      mutation.
- [x] Focused and full reference-package suites, typecheck, Biome, and
      `git diff --check` pass.
- [x] Rebuilt runtime resolves OMO 2.2.19 and passes a real task lifecycle smoke.

## Fix

- Added explicit `return-channel-pending` and `stopped-without-result` Board
  states without changing legacy running/completed/error semantics.
- Added Board-confirmed cancellation, bounded tombstones, exact-ID recovery,
  truthful metadata projection, and a fail-closed missing-ID diagnostic.
- Kept unconfirmed cancellation text as non-terminal diagnostic evidence and
  excluded stopped tombstones from automatic terminal reconciliation.
- Reconciled legacy cancellation tests to call `markCancelled()` when the test
  intends an explicit user cancellation.

## Evidence

Two memory-manager dispatches in this orchestrator session returned the string
"Task cancelled" from the task() return channel:

- mem-1: session ses_fbac184f0ffe3FSifm3603HDpa
- mem-2: session ses_fbac0ba05ffeL1AmqRmdmCN9Li

Both later appeared on the Background Job Board as "stopped, unreconciled" ?
i.e. the background sessions ended WITHOUT a terminal task result. They did
not actually complete, and were not genuinely user-cancelled. The task() return
channel reported a false "Task cancelled" state instead of the true state.

## Impact

The orchestrator may wrongly treat a live or stopped-without-result session as
dead. This causes two failure modes:

1. Duplicate re-dispatch of work that is still in flight or already stopped.
2. Misclassification of a stopped-without-result lane, breaking the
   truncated-lane recovery protocol (DIA-099), which expects a distinct
   stopped-without-result state to trigger the correct resume path.

## Fix direction

Reconcile the task() return value with the actual session lifecycle state
reported by the Background Job Board. Do NOT emit "Task cancelled" when the
session is live or stopped-without-result. Surface a distinct state
(e.g. "stopped-without-result" / "return-channel-unverified") so the
orchestrator applies the correct recovery path instead of assuming death.

## Re-verify

- RED fixed points: `7f580c5` (stopped-without-result) and `1b70c88`
  (false cancelled), integrated before GREEN.
- Focused lifecycle suites after fix: 103/103, then `test:red-b` 64/64.
- Full package: 1379 passed, 0 failed, 3125+ assertions.
- `bun run typecheck`: exit 0.
- Biome on both production files: exit 0.
- `git diff --check`: exit 0.
- Independent review: initial NO-GO found two critical lifecycle regressions and
  one missing acceptance test; same-session fix plus separate regression-test
  lane resolved all findings. Targeted re-review cycle 1/2: PASS, all four
  findings verified closed.
- Rebuilt Podman runtime resolved npm OMO 2.2.19. A real orchestrator run
  dispatched two code-navigator tasks in parallel, waited for both terminal
  results, and returned the expected non-empty lines:
  `A:poetry-platform-monorepo` and `B:2.2.19` (exit 0, 2026-09-14).
