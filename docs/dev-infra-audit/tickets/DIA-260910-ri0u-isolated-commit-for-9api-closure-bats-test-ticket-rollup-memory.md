# DIA-260910-ri0u - Isolated commit for 9api closure (Bats test + ticket + rollup/memory)

---

id: DIA-260910-ri0u
title: "Isolated commit for 9api closure (Bats test + ticket + rollup/memory)"
area: scripts
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-10
source: inventory
date: 2026-09-10
created: 2026-09-10
updated: 2026-09-10

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

Tracking ticket governing the isolated commit for the CLOSED DIA-260909-9api
'make compose-env.bats hermetic to inherited COMPOSE_ENGINE' closure
(closed 2026-09-10).

Background: the 9api closure commit scope was fully engineered and verified,
but its isolated commit lane was blocked by the section-10 ticket gate
(no OPEN correlating ticket at commit time). This ticket provides the OPEN
governing ticket that unblocks that commit. No new engineering is covered
by this ticket.

Commit allow-list (exact scope, no additions):

- scripts/**tests**/compose-env.bats (hermetic COMPOSE_ENGINE test)
- 9api ticket file (DIA-260909-9api closure update)
- tickets README rollup (scripts/tickets rollup output)
- .opencode/memory/lessons.md (closure lesson entry)

## Verification

- [ ] Isolated commit contains ONLY the four allow-listed paths above
- [ ] Commit message references DIA-260909-9api (closed) and this ticket
- [ ] No new engineering changes in the commit diff

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
