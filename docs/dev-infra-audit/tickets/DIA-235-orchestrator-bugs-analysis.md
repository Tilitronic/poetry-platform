# DIA-235 -- Orchestrator bugs analysis and fix

---

id: DIA-235
title: "Orchestrator bugs analysis and fix"
area: opencode-config
severity: Critical
status: OPEN
blocked_by: []
parent_epic: ""

gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered:
source: fix-lane
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Investigate 4 critical orchestrator bugs from session ses_fe5a29aa1ffeJmz7Pu3Bjeryb0:

1. **Batch-approval gate violation** -- dispatched lane-0 without explicit approval.
   The orchestrator bypassed the batch-approval gate and dispatched a worker lane
   before receiving developer confirmation. This violates the batch-dispatch
   contract and risks unreviewed code reaching the codebase.

2. **DCP observability gap** -- lane-0 errored silently, no visible DCP output.
   When lane-0 encountered an error, there was no visible diagnostic output in the
   DCP (Delegation Context Protocol) stream. The error was swallowed silently,
   making it impossible to diagnose the failure without manual log inspection.

3. **Repetition loop** -- orchestrator repeated acknowledgments and failed file reads.
   The orchestrator entered a loop where it repeatedly acknowledged the same state
   and retried failed file reads without progressing. This wasted context window
   tokens and stalled the workflow.

4. **Orchestrator asking developer for information it could find itself** -- ana<NN>
   ID allocation. The orchestrator asked the developer to provide analysis IDs
   (ana<NN>) that it should have allocated or looked up autonomously. This breaks
   the autonomous delegation model and stalls the workflow for no reason.

These bugs affect the core orchestration workflow and block reliable autonomous operation.

## Verification

- Reproduce each bug condition from session ses_fe5a29aa1ffeJmz7Pu3Bjeryb0 logs
- Verify batch-approval gate enforcement (dispatch blocked until explicit approval)
- Verify DCP error propagation (lane errors surface in delegation context)
- Verify no repetition loops (orchestrator progresses after acknowledgment)
- Verify ID allocation autonomy (orchestrator allocates ana IDs without developer input)

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
