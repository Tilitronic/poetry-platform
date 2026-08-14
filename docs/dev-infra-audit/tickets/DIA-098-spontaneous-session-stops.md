# DIA-098 - Spontaneous subagent/session stops: stalled-agent detection, auto-resume, complete-vs-interrupted classification

<!-- UPDATE 2026-08-13 (STOP-POINT ANALYSIS COMPLETE - ana-3): report
     knowledge/ana016-stop-point-stall-analysis/ (memory-shelf
     analyses[16]). Eight stop-point classes from registry.jsonl (~1108
     sessions since 2026-08-04): SP1 normal completion 996, SP2
     crash/model-error 17 (error=[object Object] USELESS - serialization
     bug), SP3 false-positive failed 3 (complete-then-failed backward
     transition), SP4 silent failure 30 (reactive), SP5 gate-blocked 30,
     SP6 true orphan 2, SP7 recovered fail 12, SP8 auxiliary-only 69.
     Seven failure classes: F1 permission-ask stall (PARTIAL detect -
     needs-input-observer ENTER, no CLEAR within 5min), F2 silent-empty
     result (PARTIAL - DIA-130), F3 tool-error loop (YES -
     a1_violation>3), F4 gate-blocked (YES), F5 crash (YES but error
     useless), F6 orphan (PARTIAL - reactive), F7 normal (89.9%).
     STALL-DETECTION DESIGN: primary = periodic 60s sweep for
     RUNNING/DISPATCHED rows older than threshold (subagent 10min,
     orchestrator 20min, dead session 60min) emitting stall_detected +
     crisis; fallback = permission-ask timeout 5min via
     needs-input-observer -> POST /session/:id/permissions/:id
     {response: reject} + permission_auto_rejected log.
     COMPLETE-vs-INTERRUPTED CLASSIFIER: 6-rule pseudocode (validated
     1003/1108 = 90.5%, 0 false negatives). AUTO-RESUME = FAIL-FAST not
     auto-resume (auto-reject permission stall, notify orchestrator via
     log_decision crisis, human decides; auto-resume risks doom_loop
     DIA-078). GAPS: G1 error-field serialization [object Object] HIGH,
     G2 permission events not in registry HIGH, G3 10-day window, G4 no
     native stall event (setInterval ok), G5 fail-fast is design
     decision, G6 task_success uses task_id not session_id. Top-3 for
     DIA-126(b): fix error serialization, proactive stall timer,
     permission watchdog - all section-10. This ticket stays OPEN - the
     design is analysis-phase only; implementation is section-10 plugin
     work feeding DIA-126(b). -->

---

id: DIA-098
title: "spontaneous subagent/session stops: stalled-agent detection, auto-resume, complete-vs-interrupted classification"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered:
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Root-cause investigation of spontaneous agent/session stops beyond the DIA-080
context_usage fix (which addressed one root cause: cumulative proxy reading
100%). Broader problem: (a) detect stalled agents (no progress for N seconds);
(b) auto-resume vs manual "continue" nudge; (c) distinguish completion (agent
done) from interruption (agent truncated/stopped). DIA-080's session-scoping
fix is a partial solution; this ticket addresses residual failure classes
(delegation-observer idle handling, step-budget truncation,
empty-first-response pattern).

### Investigation requirements

1. Correlate stop points with registry.jsonl session outcomes + messages.jsonl.
2. Enumerate failure classes: context_usage threshold, idle-turn semantic
   event, step-budget exhaustion, empty-first-response, permission-denied
   silent halt, wait_for_user misuse.
3. Design stalled-agent detection signal (duration without tool call? message
   count plateau?).
4. Evaluate auto-resume mechanism (persistence-pending.json? registry retry?).
5. Define complete-vs-interrupted classifier.

### Deliverables

- Failure-class taxonomy with evidence from 3+ sessions.
- Detection-signal design (which registry/messages fields indicate stall).
- Auto-resume mechanism proposal (or explicit "manual nudge required" ruling).
- Complete-vs-interrupted classifier design.

## Verification

- (a) Taxonomy covers 5+ failure classes with session evidence.
- (b) Detection signal defined (fields + thresholds).
- (c) Auto-resume decision documented (implement vs defer with rationale).
- (d) Classifier design documented with test cases.
- (e) Cross-linked with DIA-099 (truncated returns).
- [x] Stop-point correlation + failure-class enumeration + stall-detection design + complete-vs-interrupted classifier delivered (ana-3, 2026-08-13, see top UPDATE).

## Fix

> To be filled at fix time.

Analysis phase COMPLETE 2026-08-13 (ana-3): stop-point/failure-class taxonomy, stall-detection design (60s sweep + permission-ask timeout), fail-fast classifier, gaps G1-G6. Implementation (section-10): error serialization fix, proactive stall timer, permission watchdog - routed to DIA-126(b) and section-10 follow-up tickets.

## Re-verify

> To be filled at re-verify time.
