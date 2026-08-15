# DIA-085 — investigate parallel orchestrator sessions — handoff coordination between them (session IDs, worktrees, handoff-file ownership)

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. DIA-073 (basic
     handoff parallel coordination) is closed; this ticket extends to real
     parallel orchestrator sessions with separate worktrees/checkouts. -->

---

id: DIA-085
title: "investigate parallel orchestrator sessions — handoff coordination between them (session IDs, worktrees, handoff-file ownership)"
area: docs
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: inventory
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-15
gate_state: grilled
gate_triggers: [new-module, schema-state, cross-cutting]
gate_waivers: []
gate_override: none

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0133de7fdffeKc3ClhE6fqFy0X"
lane_id: "docs"
agent: "code-executor"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-085-handoff-parallel-orchestrator-sessions.md"]
artifacts: []
evidence: []

---

## Description

Investigate how to run parallel orchestrator sessions effectively (if possible)
and how handoff coordination works between them (session IDs, worktrees,
handoff-file ownership). DIA-073 covered basic handoff parallel coordination and
is closed; this ticket extends to real parallel orchestrator sessions with
separate worktrees/checkouts.

## Verification

- [ ] Research/verify feasibility of running 2+ orchestrator sessions in parallel (separate worktrees/checkouts).
- [ ] Document handoff coordination mechanics: session IDs, worktrees, handoff-file ownership rules.
- [ ] Run a minimal two-session parallel smoke and confirm handoff files do not collide or clobber.

## Fix

DIA-085 resolved by the OpenSpec change `openspec/changes/parallel-handoff-slots/`
(validated exit 0, isComplete true). Design (developer-approved Option B,
2026-08-15): per-session handoff slots under
`.opencode/session/handoffs/<session-id>.json` (schema unchanged: status,
session_id, cycle_id, timestamp, checksum, prognosis) + `active.json` pointer
({active_session_id, timestamp, pointer_version: 1}) + archive-on-overwrite
(`handoffs/archive/<session-id>.<ts>.json`) + `.reconciled` sidecar (batch-approved
session_ids). Boot-gate resolution chain: active pointer -> mtime scan of
`handoffs/*.json` (reconciled slots filtered) -> legacy `current-handoff.json`
fallback (read-only). Plugin writer flow (`atomicWriteHandoff(content, sessionId)`):
archive_prior -> write_slot -> write_pointer, each atomic (temp -> fsync -> rename
-> fsync dir); slot written BEFORE pointer; terminal-status filter (DIA-120)
preserved; slot identity from `parentSessionId ?? lane_id ?? "unknown"`.

Implementation slices (all DONE): T1.1 plugin writer
(`.opencode/plugins/delegation-observer.ts`); T3.1 slot-aware
`scripts/validate-handoff.sh` (-s flag, env overrides HANDOFFS_DIR/LEGACY_HANDOFF/
HANDOFF_TEMPLATE); T4.1 `scripts/test-parallel-handoff.sh` smoke (six scenarios);
T4.2 bun harness `.opencode/plugins/__tests__/parallel-handoff.test.mjs` (9 tests,
S1 seam); T4.3 `scripts/__tests__/validate-handoff.bats` (S3 seam). Docs/reporting:
T2.1 NEXT-RUN.md section 1/2/7.3/7.8 + AGENTS.md section 6 updated; T5.1 this
ticket.

Wiring decision (T5.1): the S1 bun harness is NOT wired into `make test-config` -
`bun` is absent from the host PATH (test-config is a host gate; bun runs only inside
the dev container) and the direct precedent for plugin bun harnesses is the DIA-189
harness (`needs-input-observer.dia189.test.mjs`), which is manual-run only
(`bun test`, in-container). The wired `batch-d-infra.test.mjs` is a NODE harness
(host-run), so it is not the pattern for a bun suite. Consistency tiebreaker:
DIA-189 manual precedent followed; Makefile unchanged.

## Re-verify

> To be filled at review time.

## Scope extension (batch brief 2026-08-11)

Extended brief from the batch: parallel orchestrator sessions must be a
first-class operational model with explicit coordination semantics. DIA-073
(CLOSED) covered basic handoff parallel coordination; its findings feed this
ticket. DIA-100 (worktrees implementation) provides the isolation mechanism
this model builds on. DIA-098 defines the recovery strategy referenced below.

Scope items to investigate and document:

1. State sharing between parallel sessions: what state must be shared
   (task ledger, handoff files, ticket status, session logs) and what must
   stay private per session.
2. Task ownership representation: adopt a task-level claim + heartbeat model
   as the concrete ownership/locking mechanism (see deliverables).
3. Conflict avoidance / conflict-detection mechanism: define what counts as a
   conflict (same file edited, same task claimed, overlapping artifact
   writes, stale heartbeats) and how a conflict is surfaced to the
   orchestrator (log event, alert, blocked task).
4. Unfinished-work handoff: the handoff-file ownership rules for a session
   that yields partial work to another session.
5. Task-status reconciliation: how the task ledger reconciles when two
   sessions report status for overlapping work.
6. Context reconstruction: what a resuming session needs (session log,
   artifacts, handoff files) to rebuild working context.
7. How parallel sessions communicate: file-based handoff (DIA-073/DIA-100
   conventions) vs any other channel; document the chosen mechanism.
8. Which session owns which task: the determination mechanism (claim order,
   heartbeat freshness, explicit assignment by orchestrator).
9. Unexpected stop: what happens if one session stops without handoff; can
   another session safely resume its work. Cross-reference DIA-098 recovery
   strategy for the failure semantics.
10. Resume-after-stop procedure: the exact step-by-step procedure for a
    resuming session, including stale-claim handling.

Deliverables per brief acceptance criteria:

- A concrete ownership/locking model: task-level claim + heartbeat, with
  claim file location, heartbeat interval, and expiry rules.
- A conflict-detection mechanism definition: conflict categories, detection
  method, surfacing path, and resolution rule.
- A resume-after-stop procedure cross-referenced with DIA-098 (recovery
  strategy): which DIA-098 steps apply, which are parallel-specific.
- At least one worked example walked end-to-end: two sessions, one stops
  mid-task; show claim/heartbeat lifecycle, conflict-free handoff, and
  resume.
- A recommendation that explicitly separates "do now with current tooling"
  (file-based claims, heartbeat timestamps, existing worktree support) from
  "requires new infrastructure" (e.g., lock server, shared task DB,
  supervisor process).

## Verification (extended)

- [ ] Document the task-level claim + heartbeat model (location, interval, expiry).
- [ ] Document the conflict-detection mechanism (categories, detection, surfacing).
- [ ] Document the resume-after-stop procedure with DIA-098 cross-reference.
- [ ] Walk one worked example end-to-end: two sessions, one stops mid-task.
- [ ] Split recommendation into "do now with current tooling" vs "requires new infrastructure".

## Session-11 dispositions (2026-08-11)

Developer decision: DEFER. Build the claim + heartbeat protocol only when
parallel-session work actually starts (DIA-101/100). This is a deferred-build
ticket, not closed.

Report: `knowledge/ana011-parallel-sessions-coordination/ana011-parallel-sessions-coordination-report.md`.

Status: OPEN (deferred build; frontmatter status left unchanged, consistent
with the existing OPEN convention for this ticket).

## DIA-085 activation (2026-08-15)

Activated from deferred-build to build-now after the 2026-08-15 clobber
incident: two parallel orchestrator sessions wrote the same single-slot
current-handoff.json within 65s (DIA-174 prognosis lost from file, recoverable
via NEXT-RUN section 7.8). Scope = per-session handoff slots + pointer +
archive + reconciliation sidecar (Option B, developer-approved 2026-08-15).
OpenSpec change 'parallel-handoff-slots' created (openspec/changes/
parallel-handoff-slots/). The ana011 claim+heartbeat protocol remains a
separate follow-up change.
