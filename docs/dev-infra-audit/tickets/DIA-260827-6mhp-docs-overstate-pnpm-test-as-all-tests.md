# DIA-260827-6mhp - Docs overstate pnpm test as all tests

---

id: DIA-260827-6mhp
title: "Docs overstate pnpm test as all tests"
area: docs
severity: Low
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

docs/onboarding.md:43-50 and 290-299 call pnpm test "all tests". It runs only four workspace test tasks, omitting shell/config/Python/plugin/embedded OMO suites.

## Verification

Rename to "workspace JS tests"; document one canonical all-suite command.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
