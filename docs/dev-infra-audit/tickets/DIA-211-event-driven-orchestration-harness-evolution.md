# DIA-211 - Event-driven orchestration harness evolution

---

id: DIA-211
title: "Event-driven orchestration harness evolution"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: []
parent_epic: ""

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered:
source: developer-requirement
date: 2026-08-17
created: 2026-08-17
updated: 2026-08-17

# --- Session Attribution (v2 schema, optional - GRANDFATHERED for DIA-001..049) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

Evolutionary expansion of delegation-observer harness infrastructure based on
intercellular communication patterns, logical signal categories, and declarative
workflow routing.

Includes:

1. **Teaching conspect update** with event-driven orchestration section
2. **Research on biological signal taxonomy** -- paracrine/endocrine/juxtacrine
   analogies for agent-to-agent communication patterns
3. **Analysis of current harness signal mapping** -- how delegation-observer
   events map to orchestration decisions today
4. **Architectural plan for evolution phases** -- incremental phases from
   current imperative dispatch to declarative event-driven routing

This is a TRACKING/SCOPING ticket. No implementation happens here; it records
scope + routing only. Implementation slices will be spawned as separate tickets
once the architectural plan is approved.

## Verification

Acceptance criteria at fix time:

- [ ] Teaching conspect updated with event-driven orchestration section
- [ ] Biological signal taxonomy research artifact produced
- [ ] Current harness signal mapping analysis completed
- [ ] Evolution phases architectural plan documented and reviewed

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
