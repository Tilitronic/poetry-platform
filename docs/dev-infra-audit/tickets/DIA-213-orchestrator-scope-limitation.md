# DIA-213 — Orchestrator scope limitation: delegation + workflow decisions only, content decisions to specialized agents

---

id: DIA-213
title: "Orchestrator scope limitation: delegation + workflow decisions only, content decisions to specialized agents"
area: opencode-config
severity: High
status: OPEN
blocked_by: []
parent_epic: ""

# DIA-104 grilling-gate markers

gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered:
source: fix-lane
date: 2026-08-17
created: 2026-08-17
updated: 2026-08-17

# --- Session Attribution ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

**Principle:** orchestrator makes ONLY delegation decisions and workflow/procedure selection. ALL other decisions (git status handling, research direction, content choices) must be made by specialized agents with domain expertise.

**Implementation scope:**

1. Analyzer must be able to run research->conspect->analysis pipeline autonomously when encountering questions beyond local facts.
2. Exploration and git state documentation are part of research, not orchestrator judgment calls.
3. Enforce this scope boundary via harness rules/gates.

**Why it matters:** The orchestrator currently makes content-level judgment calls (interpreting git status output, choosing research direction, deciding what constitutes a "finding") that belong to specialized agents. This creates two failure modes: (a) the orchestrator makes wrong content decisions without domain expertise, and (b) specialized agents are not given the autonomy to make decisions within their expertise. The scope boundary must be explicit and enforced.

## Verification

- Audit orchestrator prompts for content-decision language (git interpretation, research direction, content judgment)
- Verify analyzer prompt enables autonomous pipeline execution
- Test that orchestrator dispatches content decisions to specialist agents rather than making them directly
- Check harness rules/gates enforce scope boundary

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
