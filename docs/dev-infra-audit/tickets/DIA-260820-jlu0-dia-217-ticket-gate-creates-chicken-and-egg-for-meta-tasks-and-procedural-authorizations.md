# DIA-260820-jlu0 - DIA-217 ticket gate creates chicken-and-egg for meta-tasks and procedural authorizations

---

id: DIA-260820-jlu0
title: "DIA-217 ticket gate creates chicken-and-egg for meta-tasks and procedural authorizations"
area: dev-infra
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-20
source: baseline
date: 2026-08-20
created: 2026-08-20
updated: 2026-08-20

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

The DIA-217 ticket gate requires ticket_id for all task() dispatches, but
certain meta-tasks cannot have a pre-existing ticket:

1. **Ticket creation itself** -- requires task() to create ticket, but
   task() requires ticket_id (this is the exact bug we hit right now).
2. **Applying ai-auditor recommendations** -- ai-auditor approval IS the
   authorization, but current workflow requires second ai-auditor review
   because it is an AI infra change.
3. **Bootstrap operations** -- first-time setup, permission grants,
   signal-based workflows.

This creates circular dependencies and token waste.

Required: design a capability/stamp-based authorization system that allows
procedural tasks to bypass the ticket gate reliably. Research frontier
agentic approaches: capability tokens, stamp chains, key-based access
control. The solution must maintain audit trail while eliminating circular
dependencies.

Related: DIA-217 (the gate), DIA-229 (ticket creation bypasses),
DIA-260820-y268 (scripts-over-readme, hit this bug).

## Verification

- [ ] Design document describing the authorization bypass mechanism
- [ ] Capability/stamp tokens defined with audit trail
- [ ] Ticket creation can proceed without pre-existing ticket_id
- [ ] ai-auditor recommendation application does not require second review
- [ ] Bootstrap operations documented and working
- [ ] No regression: legitimate ticket gate enforcement still works

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
