---
id: DIA-224
title: 'D3 empty-result detection in delegation-observer session.idle handler'
area: tests-infra
severity: Major
status: CLOSED
blocked_by: [DIA-222]
discovered:
  source: council-consensus
  date: 2026-08-18
created: 2026-08-18
updated: 2026-08-18
session_id: ''
lane_id: ''
agent: ''
model: ''
parent_session_id: ''
attempts: 0
lease_expires_at: ''
files_touched: []
artifacts: []
evidence: []
---

## Description

Add mechanical empty-result detection in the `session.idle` handler. After this slice, empty results with no file edits emit a SILENT_FAILURE registry row.

**Sub-step (a): Extend session.idle handler**

In the `session.idle` event handler (around line 3200+), after the existing A3 silent-failure scan:

1. Check if the session produced any file edits (via the `tool.execute.after` hook's edit tracking)
2. Check if the session's accumulated output is empty/whitespace
3. If both are true, emit a registry.jsonl row with `dispatch_state: SILENT_FAILURE`
4. Emit a messages.jsonl warning event with `gen_ai.operation.name: 'empty_result_detected'`

**Routing:** section 10 (plugin change) -> @coder implementation

## Verification

- [x] Empty-result detection emits crisis event with `resolution_status: "escalated"` and `content_ref: "empty-result-requires-redispatch"`
- [x] Orchestrator protocol mandates redispatch on this crisis signal (see orchestrator_append.md L347-351)
- [x] Detection does NOT auto-dispatch -- orchestrator retains control over redispatch decision
