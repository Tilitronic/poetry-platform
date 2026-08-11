# DIA-098 - Spontaneous subagent/session stops: stalled-agent detection, auto-resume, complete-vs-interrupted classification

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

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
