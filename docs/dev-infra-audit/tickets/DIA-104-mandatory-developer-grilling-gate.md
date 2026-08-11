# DIA-104 - Mandatory developer grilling/design review gate: trigger conditions, stages, exit criteria, blocking conditions

---

id: DIA-104
title: "mandatory developer grilling/design review gate: trigger conditions, stages, exit criteria, blocking conditions"
area: docs
severity: Medium
status: OPEN
blocked_by: ["DIA-103"] # DIA-NNN refs, or empty
discovered:
source: inventory
date: 2026-08-11
created: 2026-08-11
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

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

Define a mandatory developer grilling/design review gate before significant
changes. ana004 (spec-authoring-philosophy audit) scored current enforcement
52/100 ("embedded as intent, not enforcement"). 4 hard bypass paths outrank 4
soft ALIGNED layers. This ticket defines: (a) trigger conditions (what counts
as "significant change" - new module, cross-boundary, API change); (b) stages
(grill to design review to implementation); (c) required challenges
(assumptions, trade-offs, alternatives); (d) exit criteria (what must be
documented before proceeding); (e) blocking conditions (what prevents
proceeding without the gate); (f) exceptions for trivial changes (typo fix,
version bump, single-param tweak). Practice-protected zone: the agent guides,
the developer writes.

### Investigation requirements

1. Read practice-protected.md for current zones.
2. Read ana004 audit for bypass paths and ALIGNED layers.
3. Define trigger conditions (change scope thresholds).
4. Define stages (grill to design to implement, with gates between).
5. Define exit criteria (documented decisions, ADRs, trade-off analysis).
6. Define exceptions (trivial change criteria).

### Deliverables

- Grilling-gate reference (triggers, stages, challenges, exit criteria).
- Blocking conditions (what prevents proceeding).
- Exception criteria (trivial changes that skip the gate).
- Integration with practice-protected.md.

## Verification

- (a) Trigger conditions defined (3+ criteria for "significant change").
- (b) Stages documented with gates between them.
- (c) Exit criteria tested (grill to design to implement completes).
- (d) Exception criteria defined (trivial changes listed).
- (e) practice-protected.md updated to reference the gate.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
