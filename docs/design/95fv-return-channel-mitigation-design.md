# DIA-260827-95fv return-channel mitigation design (DESIGN ONLY, no implementation)

Ticket: DIA-260827-95fv 'bug-task-returns-task-cancelled-while-background-session-is-live-or-stopped-without-result-return-channel-false-state'
Scope: verification + local mitigation design only. No .ts edits were made.
Worktree: /workspace/.worktrees/feature-second-session-c3d4-95fv-ezyv-x3y4
Date: 2026-09-10 (UTC)
Author role: verification/design lane, campaign ticket DIA-260827-95fv

## 1. Problem restatement

Two memory-manager dispatches (ses_fbac184f0ffe3FSifm3603HDpa,
ses_fbac0ba05ffeL1AmqRmdmCN9Li) returned the string "Task cancelled" on the
task() return channel, yet both sessions later appeared on the Background Job
Board as stopped / unreconciled WITHOUT a terminal task result. The return
channel reported a false terminal state. Failure modes: (1) duplicate
re-dispatch of in-flight work; (2) misclassification that breaks the
truncated-lane recovery protocol (DIA-099), which needs a distinct
stopped-without-result state.

## 2. Verification steps performed (read-only)

All checks below were read-only (read/grep/git status/log). No .ts file was
edited. Observer lifecycle untouched.

V1. Read the ticket file at
docs/dev-infra-audit/tickets/DIA-260827-95fv-bug-task-returns-task-cancelled-while-background-session-is-live-or-stopped-without-result-return-channel-false-state.md
(status OPEN, severity Major). Confirmed Description/Verification/Fix sections
are still placeholders; Evidence/Impact/Fix-direction blocks match the summary
in section 1 above.

V2. Confirmed return-channel parse path exists and is the single choke point:
.opencode/oh-my-opencode-slim/src/utils/task.ts, function
parseTaskStateFromOutput (lines 71-89). It maps task output to one of
'running' | 'completed' | 'error' | 'cancelled' via <task state="..."> XML
attr or a `state:` header line. There is NO 'stopped-without-result' state in
TaskOutputState (line 5). Any downstream consumer can therefore only see
'cancelled', never the true stopped-without-result condition. This is the
false-state source.

V3. Confirmed board reconciliation path:
.opencode/oh-my-opencode-slim/src/hooks/task-session-manager/index.ts
(createTaskSessionManagerHook, 771 lines). Key observations:

- updateBackgroundJobFromOutput / updateFromInjectedCompletion parse output
  via parseTaskStatusOutput and call backgroundJobBoard.updateStatus.
- Late-cancel normalization exists (isLateCancelledTaskError +
  normalizeLateCancelledTaskOutput + formatCancelledTaskStatusOutput): when
  board state is cancelled/cancellationRequested, an 'error' return is
  rewritten to 'state: cancelled'. This path AMPLIFIES the false state if the
  board was wrongly marked cancelled first.
- Idle reconciliation (session.idle handler, ~line 605) marks a running job
  'completed (reconciled from idle event)'. A session that stops WITHOUT
  result and WITHOUT an idle/completion event stays terminalUnreconciled and
  has no distinct return-channel token.
- session.deleted handler (~line 715) drops board state via
  backgroundJobBoard.drop(sessionId). If the return channel already emitted
  "Task cancelled" before delete, the board evidence is gone and the
  orchestrator cannot re-verify.

V4. Confirmed observer path: .opencode/plugins/delegation-observer.ts.
grep shows 'cancelled' stays reserved for real cancel_task events (line 242)
and one heuristic-signal comment (line 558). Observer does NOT currently emit
or guard the "Task cancelled" return-channel string; it is not the source,
but its lifecycle hooks run alongside the task-session-manager hooks, so any
future mitigation that touches observer lifecycle must be sequenced AFTER the
task-session-manager fix (see risk R3).

V5. Confirmed board state model:
.opencode/oh-my-opencode-slim/src/utils/background-job-board.ts. States
include 'cancelled' (line 70); record fields include cancellationRequested,
terminalUnreconciled, terminalState (lines 22+). markRunningFromLiveSession
(line 245) can reopen running state from a live busy event; markReconciled
(line 277) clears terminalUnreconciled. No 'stopped-without-result' state or
reopen-guard exists yet.

V6. Intersection (sibling-slice) risk check for shared return-channel files:

- This worktree (branch feature/second-session-c3d4-95fv-ezyv-x3y4, base
  3bc5810) has NO .ts modifications; git status shows only pre-existing
  M turbo.json and ?? docs/runbook/ plus this new design file.
- Main tree (/workspace) status shows unrelated modifications (opencode.jsonc,
  ticket-gate tests/lib, book-rag SKILL.md, AGENTS.md, Makefile, one ticket
  file, README rollup, validate-changelog.sh). NONE of them touch the three
  return-channel paths (task.ts, task-session-manager, delegation-observer.ts).
- Recent log on the three paths (b35229f8 observer-seam extract, ced942ca
  stale boot sweep, 54e2dc16 handoff/ticket-gate harden, b42a1a73 Bun-parseable
  fix) shows the observer file is a hot spot. CONCLUSION: intersection risk is
  LOW today but the observer lifecycle is contention-prone; mitigations A-D
  below deliberately avoid observer-lifecycle edits (local task.ts +
  task-session-manager + board + orchestrator-procedure changes only).

## 3. Mitigations A-D (draft, NOT implemented)

Mitigation A - return-channel check before trusting 'cancelled' (local,
task-session-manager only, no observer edit).

- WHY: the return channel is trusted blindly today; the board holds ground
  truth (live busy timestamp, cancellationRequested flag).
- WHAT (draft): in the tool.execute.after task branch, when parsed status is
  'cancelled', query backgroundJobBoard.get(taskID) FIRST: if no record, or
  record.state is 'running', or lastLiveBusyAt is recent, or
  !cancellationRequested, do NOT propagate 'cancelled'. Rewrite output to a
  provisional 'state: running' + '<task_result>return-channel-unverified;
  board state=<state></task_result>' marker and leave the board entry intact.
- Test sketch: unit test on the after-hook with a fake board: cancelled output
  - running board entry => output rewritten, board untouched. (To be written
    by a RED instance per DIA-175 instance separation.)

Mitigation B - distinct stopped-without-result state (task.ts + board).

- WHY: four-state TaskOutputState cannot express the observed condition, so
  every layer collapses it to 'cancelled'.
- WHAT (draft): extend TaskOutputState with 'stopped-without-result';
  parseTaskStateFromOutput recognizes `state: stopped-without-result` header
  and <task state="stopped-without-result">; background-job-board maps it to a
  terminalUnreconciled record with terminalState 'stopped-without-result'
  (NOT 'cancelled'); formatForPrompt renders it distinctly so DIA-099 resume
  triggers instead of dead-lane handling.
- Compatibility note: keep the four legacy states byte-identical on the wire;
  the new token only appears when the board confirms stopped-without-result
  (see mitigation C). No observer change needed.

Mitigation C - board reopen guard (background-job-board only).

- WHY: today a 'cancelled' write can clobber a live/running entry, and
  session.deleted drops evidence, making the false state irreversible.
- WHAT (draft): in updateStatus, refuse transition running->cancelled unless
  cancellationRequested is true on the record; refused writes keep state and
  set a needsReview flag. In the session.deleted handler, do NOT drop a
  terminalUnreconciled record; tombstone it (state kept, deletedAt set) so the
  orchestrator verify step (mitigation D) can still inspect it.
- Test sketch: board unit tests: running + !cancellationRequested + cancelled
  write => state stays running + needsReview; deleted + unreconciled =>
  tombstoned, still listable.

Mitigation D - orchestrator verify step (procedure + resume-truncated-lane).

- WHY: even with A-C, a stale "Task cancelled" string may already be in flight
  (as in the two cited sessions). The orchestrator must not treat it as death.
- WHAT (draft): on receiving "Task cancelled", the orchestrator MUST before
  re-dispatch: (1) task_result/task_status lookup for the session id;
  (2) Background Job Board lookup for the task id; (3) if board says running
  or terminalUnreconciled/stopped-without-result, follow the DIA-099
  resume-truncated-lane path (resume, not re-dispatch); (4) only when board
  confirms cancelled + cancellationRequested may it treat the lane as dead.
  Append this 4-step check to the resume-truncated-lane skill notes.
- No code change; doc/procedure change only. Safe to land first.

Suggested landing order (for the implementing lane): D (procedure, zero risk),
then A (local guard), then C (board guard), then B (new state token, needs
A+C in place). Each step independently testable; B depends on C.

## 4. Files touched (this design lane)

- NEW: docs/design/95fv-return-channel-mitigation-design.md (this file).
- Pre-existing, NOT touched by this lane: M turbo.json, ?? docs/runbook/
  (were already present before this lane started; left as-is).
- Explicitly NOT touched: any .ts file (especially delegation-observer.ts
  lifecycle), README, CHANGELOG, memory, ticket files, rollup.

## 5. Open questions for implementer

1. Exact recency threshold for lastLiveBusyAt in mitigation A (suggest reuse
   of existing idle/stale constants rather than a new magic number).
2. Whether 'stopped-without-result' should be a full TaskOutputState member or
   a board-only terminalState with a distinct formatForPrompt rendering
   (cheaper wire-compat option).
3. Tombstone retention window for mitigation C (suggest bounded size like the
   existing MAX_PROCESSED_INJECTED_COMPLETIONS=500 pattern).
