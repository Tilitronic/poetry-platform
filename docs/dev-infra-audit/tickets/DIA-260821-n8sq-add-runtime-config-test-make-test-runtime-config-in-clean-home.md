# DIA-260821-n8sq - Add runtime config test (make test-runtime-config in clean HOME)

---

id: DIA-260821-n8sq
title: "Add runtime config test (make test-runtime-config in clean HOME)"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
updated: 2026-08-21

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

P1: There is no runtime config test. The merge gate does not catch preset mismatch, plugin duplicates, or version drift before launch. Action: add a make test-runtime-config target that validates the effective runtime config in a clean HOME (fresh OPENCODE_CONFIG / empty config dir), so preset mismatch, duplicate plugin registration, and plugin version drift are caught before launch. This complements the existing make test-config (static validation) with a runtime/clean-HOME check.

Reaudit (DIA-260827-wfcx, 2026-08-31; W-M7) confirms the target from openspec/changes/runtime-config-test/tasks.md:81-95 is still unimplemented; Makefile:194-220 lacks it and make test-runtime-config exits 2. Impact: static tests cannot see the global merge, plugin duplication, model shadowing, or built-in agents. Correct fix: complete the T1/T2 slices with clean-home and real-home fixtures and run them in container CI.

## Verification

make test-runtime-config exits 0 against a clean HOME and a real HOME; it reports preset mismatch, duplicate plugin registration, and version drift.

## Fix

Complete the T1/T2 slices of the runtime-config-test change; add a make test-runtime-config target that validates the effective runtime config in a clean HOME and a real HOME, catching preset mismatch, duplicate plugin registration, and version drift before launch. Wire into container CI.

## Re-verify

> To be filled at re-verify time.
