# DIA-260827-uv - Routing-order regression suite copies logic and is orphaned

---

id: DIA-260827-uv
title: "Routing-order regression suite copies logic and is orphaned"
area: scripts
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

scripts/**tests**/routing-order-gate.test.mjs:23-90 redefines CONFIG_WORK_PATTERN, hasPriorAiSpecialistDispatch, and the gate flow instead of importing production code; its control-flow test at 374-388 only calls the local simulation; error-prefix test at 428-455 constructs both error strings inside the test. test-config runs only batch-d-infra.test.mjs at Makefile:194-215; the Bats wrapper syntax-checks MJS in quick mode. Impact: production routing order/regex/error handling can diverge while all 36 copied-logic tests stay green.

Reaudit (DIA-260827-wfcx, 2026-08-31) confirms: .opencode/scripts/**tests**/routing-order-gate.test.mjs:23-90,374-455 copies the regex/decision logic; production already has dcp.jsonc at .opencode/plugins/delegation-observer.ts:3267-3346 but the copy does not; Makefile:194-215 does not run the suite. Impact: the test stays green after production diverges. Correct fix: extract pure helpers or test the real hook and wire it into make test-config.

## Verification

Production gate functions extracted into an importable module; the Node suite tests those exact exports; an end-to-end hook case added; the Node suite wired into test-config.

## Fix

Extract the routing-order gate functions into an importable module; have the Node suite test those exact exports plus an end-to-end hook case; wire the suite into make test-config.

FIX APPLIED (2026-09-22, bounded implementation lane):
(a) Import-over-copy: new seam .opencode/plugins/lib/routing-gate.ts exports
CONFIG_WORK_PATTERN, isConfigWorkDispatch, hasPriorAiSpecialistDispatch,
isCoderAgent, evaluateRoutingGate, ROUTING_GATE_PREFIX, buildRoutingGateError.
delegation-observer.ts imports and uses all three (pattern, gate decision,
error builder); the inline pattern/scan/decision/error-string copies deleted.
scripts/**tests**/routing-order-gate.test.mjs imports the same seam (Node 24
strips erasable TS by default); local copies deleted, all 36 tests keep intent.
(b) Wiring: `node scripts/__tests__/routing-order-gate.test.mjs` added to the
make test-config recipe (after batch-d-infra.test.mjs).
(c) Token consistency: stale dcp.jsonc token deleted from BOTH production
regexes (delegation-observer.ts routing pattern, ticket-gate.ts CONFIG_PATH_RE);
seam pattern carries no dcp token. Status stays OPEN -- closure is separate approval.

## Re-verify

RE-VERIFY EVIDENCE (2026-09-22):

- node scripts/**tests**/routing-order-gate.test.mjs: exit 0, tests 36 pass 36 fail 0
- make test-config: exit 0 (suite runs inside it, 36/36)
- make test-shell: exit 0
- bun build delegation-observer.ts --target node: exit 0 (11 modules bundled)
- scripts/validate-plugin-structure.sh: all structural gates PASS
- grep dcp.jsonc over both production regexes + seam + suite: zero regex hits
  (only the seam's explanatory comment mentions dcp)
