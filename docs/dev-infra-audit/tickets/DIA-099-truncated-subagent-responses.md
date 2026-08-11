# DIA-099 - Truncated/partial subagent responses: detect-preserve-resume-validate mechanism

---

id: DIA-099
title: "truncated/partial subagent responses: detect-preserve-resume-validate mechanism"
area: opencode-config
severity: Major
status: OPEN
blocked_by: ["DIA-098"] # DIA-NNN refs, or empty
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

Design and implement a reliable mechanism for handling truncated or partial
structured responses from subagent lanes. Known incidents: ai--1 (session-6,
one intro sentence only, 3m38s), cod-5 (session-6, empty return after 11m09s,
longest lane), cod-7 (partial structured response). Current workaround: resume
via task_id in a new lane. Goal: detect truncation reliably, preserve partial
output, resume from preserved state, validate resumed output completes the
task. Investigate jointly with DIA-098 (cross-link findings on
complete-vs-interrupted).

### Investigation requirements

1. Reproduce truncation pattern (controlled task with known step-budget).
2. Identify registry/messages signals that distinguish truncation from
   legitimate short output.
3. Evaluate preservation strategy (write partial to persistence-pending.json?
   append to registry with truncation flag?).
4. Design resume prompt strategy (full remaining state + partial output as
   context).
5. Define validation: resumed lane must produce output that (a) covers the
   original task scope, (b) acknowledges the partial it extends.

### Deliverables

- Reproduction script (controlled truncation test).
- Detection signals documented (fields + thresholds).
- Preservation mechanism (file format + location).
- Resume-prompt template.
- Validation checklist.

## Verification

- (a) Reproduction: truncation triggered on demand in test.
- (b) Detection: signal identifies truncation with >=80% precision.
- (c) Preservation: partial output survives session boundary.
- (d) Resume: resumed lane completes original task scope.
- (e) Cross-linked with DIA-098 (joint investigation findings).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
