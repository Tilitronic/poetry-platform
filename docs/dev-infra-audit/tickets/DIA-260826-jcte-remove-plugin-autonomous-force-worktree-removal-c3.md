# DIA-260826-jcte - remove plugin autonomous force worktree removal (C3)

---

id: DIA-260826-jcte
title: "remove plugin autonomous force worktree removal (C3)"
area: delegation-observer
severity: Critical
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260825-wprb
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
date: 2026-08-26
created: 2026-08-26
updated: 2026-09-01

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

DIA-260826-jcte (rev-1) applied 5 fixes to the delegation-observer apoptosis
path and its paracrine test. All are committed in ea06ecd1
("DIA-260826-jcte: remove plugin autonomous force worktree removal").

1. Consolidated shared apoptosis orchestration (rev-1 fix 1).
   The idle (~3859-3941) and error (~4129-4180) dual-key paths were ~90%
   identical blocks that had diverged: the idle path skipped
   logStallResolutionIfStalled, the paracrine signal, and the stall
   resolution. Both now call one helper `runApoptosis(sessionID, role, mode,
errMsg?)` (delegation-observer.ts:1284) with a `mode: "idle" | "error"`
   flag. Only the handoff trigger/note, resume text, stall-resolution reason,
   and the optional error field differ by mode. Idle now also emits the
   paracrine signal + stall resolution, matching error. No external behavior
   changed beyond removing that divergence.

2. Fixed vacuous test 3 (rev-1 fix 2).
   dia220-apoptosis-paracrine.test.mjs "apoptosis attempts worktree cleanup
   for tracked worktrees" now tracks the worktree under the SAME session id
   (ses_apop_test_3) used for the session.error event (lines 285/308/334),
   so the worktree loop is genuinely exercised. Assertion (lines 349-351)
   verifies `git worktree remove` was called with the tracked path.

3. FALSIFICATION-1: stuck-failed sessions can still reach idle-apoptosis
   (rev-1 fix 3). The idle-apoptosis dual-key check (circuit OPEN) now runs
   BEFORE the S2 forward-only transition guard (delegation-observer.ts:3932-
   3941). Previously the guard returned early for a session that had errored
   while the circuit was closed, so a later idle could never trigger
   apoptosis. Reordering lets the fatal check win for stuck-failed sessions.

4. FALSIFICATION-2: dirty probe now sees untracked coder output (rev-1 fix 4).
   safeRemoveWorktree probe changed from `git status --porcelain
--untracked-files=no` to `git status --porcelain`
   (delegation-observer.ts:1227). Untracked files (the common coder output)
   are now dirty and emit `apoptosis_worktree_dirty`; safe-removal is
   preserved (git refuses --force, developer decides). Test
   "dirty worktree on apoptosis" (lines 546+) asserts the dirty row.

5. Stale RED-phase comments removed; role-resolution change documented.
   The role-resolution logic now uses lifecycle registration
   (session.created parentID) which outranks the sticky first-task
   inference, at both the idle path (delegation-observer.ts:3862-3868) and the
   error path (delegation-observer.ts:4101-4103):
   `meta?.role ?? (sessionID === parentSessionId ? "orchestrator" : "unknown")`.
   This prevents registered children that dispatch nested task() calls from
   being misclassified as "orchestrator" (which previously routed their idle
   event into the a5 branch, skipping apoptosis). No stale RED-phase comments
   remain in the test file.

## Re-verify

Commits: ea06ecd1
Tests: make test-config exit 0; bun test dia220-apoptosis-paracrine.test.mjs pass (53 across 4-file suite)
Confirm: autonomous force worktree removal removed; apoptosis helper consolidated.
