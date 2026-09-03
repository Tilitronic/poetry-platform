# DIA-260827-bry9 - OMO version and model-routing drift from baseline

---

id: DIA-260827-bry9
title: "OMO version and model-routing drift from baseline"
area: opencode-config
severity: High
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: test-lane
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
evidence:

- DIA-260827-wfcx

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-H3) confirms the global config sets a root model and overlapping agents; runtime resolves orchestrator/reviewer to the global DeepSeek V4 Pro instead of promo Hy3/Muse (oh-my-opencode-slim.jsonc:1154-1160,1230-1235); legacy architect/tester/writer are also present. Impact: the verified cost/quota/model-diversity and role contracts are not the actual runtime. Correct fix: remove global profiles from the project runtime or drop overlapping agent/model blocks; add a mandatory resolved-config test.

## Verification

opencode agent list / opencode debug shows orchestrator and reviewer resolve to promo Hy3/Muse, not the global DeepSeek V4 Pro; legacy architect/tester/writer absent.

## Fix

Remove the global root model and overlapping agent/model blocks from the project runtime, or eliminate overlapping definitions; add a resolved-config test that asserts the active preset's agents/models.

## Re-verify

> To be filled at re-verify time.
