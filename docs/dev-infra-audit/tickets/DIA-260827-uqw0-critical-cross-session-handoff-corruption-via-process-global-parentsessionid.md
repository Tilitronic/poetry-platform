# DIA-260827-uqw0 - [CRITICAL] Cross-session handoff corruption via process-global parentSessionId

---

id: DIA-260827-uqw0
title: "[CRITICAL] Cross-session handoff corruption via process-global parentSessionId"
area: opencode-config
severity: Critical
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
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

DUPLICATE of DIA-260827-y9n9 (same root cause: cross-session handoff corruption via process-global parentSessionId). Consolidated into y9n9, the canonical ticket referenced by the reaudit (DIA-260827-wfcx, W-C1). Closed 2026-08-31 to avoid split effort; all work tracks in DIA-260827-y9n9.

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
