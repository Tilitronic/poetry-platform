# DIA-261006-y72h - at-sign agent-mention hygiene: strip leading at-sign from agent mentions on the instruction surface, codify the dispatch-payload mention rule, reconcile CAUSE A

---

id: DIA-261006-y72h
title: "at-sign agent-mention hygiene: strip leading at-sign from agent mentions on the instruction surface, codify the dispatch-payload mention rule, reconcile CAUSE A"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-06
source: inventory
date: 2026-10-06
created: 2026-10-06
updated: 2026-10-06

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

OpenCode core appends a synthetic, UI-invisible "call the task tool with subagent: <name>" part to a CHILD prompt when a dispatch payload contains a leading at-sign before an agent name (upstream packages/opencode/src/session/prompt.ts). The instruction surface carried 236 leading at-sign agent mentions across 23 files, re-triggering the defect.

## Verification

- [x] `make test-config` exit 0
- [x] `scripts/validate-agent-names.sh` exit 0 (26 passed)
- [x] token-aware negative grep over the manifest == 0
- [x] the rule codified at `.opencode/oh-my-opencode-slim/orchestrator_append.md` (subsection A8) and `AGENTS.md` (section 6 gate 4)

## Fix

Token-aware strip (236 -> 0) across 23 instruction-surface .md files; rule codification; durable rationale at `.opencode/learnings/external-patterns/2026-10-06-opencode-core-synthetic-task-tool-append.md`.

CAUSE A, originally diagnosed in DIA-260926-ch1d (CLOSED), is recorded durably at the learnings path above and reconciled here.

## Re-verify

> To be filled at re-verify time.
