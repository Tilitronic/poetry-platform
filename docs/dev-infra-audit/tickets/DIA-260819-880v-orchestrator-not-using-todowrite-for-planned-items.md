# DIA-260819-880v - Orchestrator not using todowrite for planned items

---

id: DIA-260819-880v
title: "Orchestrator not using todowrite for planned items"
area: opencode-config
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

Orchestrator changes plans mid-stream instead of returning to todowrite items.
Observation: when orchestrator creates a todowrite list, it does not return to
pending items but instead changes direction permanently. This violates the
todowrite workflow (pending -> in_progress -> completed).

Root cause hypothesis: orchestrator prompt may not enforce todowrite completion,
or orchestrator lacks discipline to return to planned items.

Investigation scope:

1. Investigate orchestrator prompt for todowrite enforcement
2. Check if todowrite is mentioned in AGENTS.md or orchestrator_append.md
3. Determine if this is a prompt gap or behavioral drift
4. If prompt gap: add todowrite discipline to orchestrator prompt
5. If behavioral: add verification gate (orchestrator must complete or explicitly cancel all todowrite items before session end)

Files to check:

- `.opencode/oh-my-opencode-slim.jsonc` (orchestrator prompt)
- `.opencode/oh-my-opencode-slim/orchestrator_append.md`
- `AGENTS.md`

## Verification

- [ ] Orchestrator prompt reviewed for todowrite enforcement (evidence from prompt text)
- [ ] AGENTS.md and orchestrator_append.md checked for todowrite references
- [ ] Root cause determined (prompt gap vs behavioral drift)
- [ ] If prompt gap: todowrite discipline added to orchestrator prompt
- [ ] If behavioral: verification gate added (orchestrator must complete/cancel all todowrite items before session end)
- [ ] Orchestrator uses todowrite consistently in subsequent sessions (observed behavior)
- [ ] Pending items are either completed or explicitly cancelled (no mid-stream plan changes without todowrite update)

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

<!-- UPDATE 2026-08-19: Todowrite discipline added to 3 surfaces + drift-checker marker #9. make test-config passes. -->
