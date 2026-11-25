# DIA-261125-aqz6 - V2 container is missing openai/\* models (47 of 163) - developer elected to skip the openai oauth import on 2026-11-25

---

id: DIA-261125-aqz6
title: "V2 container is missing openai/\* models (47 of 163) - developer elected to skip the openai oauth import on 2026-11-25"
area: docker
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-25
source: inventory
date: 2026-11-25
created: 2026-11-25
updated: 2026-11-25

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

The dev-v2 container exposes 163 model IDs, of which 47 are `openai/*` and are
absent. The cause is that the openai oauth import was never performed inside
`dev-v2` (`opencode auth login openai`).

DEVELOPER DECISION (2026-11-25): skip the openai oauth import. This ticket
records the gap as a known, elected gap, not a defect to fix now.

Impact: any lane or preset that routes on `openai/*` cannot dispatch from
`dev-v2` - most directly the `openai-first-cost-balanced` preset, whose agents
route on `openai/gpt-5.6-sol` and `openai/gpt-5.6-luna`. The v1 container is
unaffected by this decision.

Remedy if it is ever wanted: run `opencode auth login openai` inside `dev-v2`,
restart the container, then re-check the model count (see Verification).

## Verification

- [ ] Baseline that documents the gap: `opencode models | grep -c '^openai/'`
      inside dev-v2 returns `0`, and `opencode models | wc -l` returns `163`.
- [ ] If the elected remedy is applied: the same two commands return `47` and
      `163` after `opencode auth login openai` plus a container restart.
- [ ] While the import is skipped, no `openai/*` model ID is added to any agent
      preset that dev-v2 loads.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
