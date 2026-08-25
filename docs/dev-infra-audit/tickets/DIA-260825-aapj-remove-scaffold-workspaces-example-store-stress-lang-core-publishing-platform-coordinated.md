# DIA-260825-aapj - remove scaffold workspaces example-store stress-lang-core publishing-platform coordinated

---

id: DIA-260825-aapj
title: "remove scaffold workspaces example-store stress-lang-core publishing-platform coordinated"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-25
source: inventory
date: 2026-08-25
created: 2026-08-25
updated: 2026-08-25

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## UPDATE (2026-08-25, DIA-260825-wprb fix-all disposition)

Developer disposition on the audit's example-store finding (F7): **KEEP**
`apps/author-studio/src/stores/` - the developer's keep-decision of
2026-08-25 overrides the audit consensus for this item. The prior disposition
recorded in `docs/PONYTAIL-DEBT.md` stands unchanged. No files under
`apps/author-studio/src/stores/` were touched by the fix-all pass.
