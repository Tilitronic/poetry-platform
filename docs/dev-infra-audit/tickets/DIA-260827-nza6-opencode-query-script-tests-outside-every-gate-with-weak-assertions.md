# DIA-260827-nza6 - OpenCode query-script tests outside every gate with weak assertions

---

id: DIA-260827-nza6
title: "OpenCode query-script tests outside every gate with weak assertions"
area: tests
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: baseline
date: 2026-08-27
created: 2026-08-27
updated: 2026-08-27

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

71 query-script tests in .opencode/scripts/test_query_web.py are outside all gates; Python gates cover only two product packages (Makefile:151-155, verify-python.sh:37-38). Weak assertions: test_query_web.py:495-524 accepts either exit 0 or 1 for three CLI cases; 501-505 contradict the test name; 464-465 accept mutually different encoding behavior. Impact: query CLI regressions and known response-shape bugs do not block any gate.

Reaudit (DIA-260827-wfcx, 2026-08-31) confirms: .opencode/scripts/test_query_web.py:464-465,495-524 accept either exit 0 or 1 and mutually different payload encodings; direct pytest fails for a missing module. Impact: exit-code, escaping, and request regressions pass unnoticed. Correct fix: a dedicated pytest environment with a mocked HTTP/subprocess seam, exact exits and payloads, wired into CI.

## Verification

A dedicated pytest environment/target created; the subprocess HTTP seam mocked; exact exit codes and payloads required; wired into pre-push/CI.

## Fix

Stand up a dedicated pytest environment/target, mock the subprocess/HTTP seam, require exact exit codes and payloads, and wire it into pre-push/CI.

## Re-verify

> To be filled at re-verify time.
