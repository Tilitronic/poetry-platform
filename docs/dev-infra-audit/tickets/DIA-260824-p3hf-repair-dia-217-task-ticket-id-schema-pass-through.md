# DIA-260824-p3hf - Repair DIA-217 task ticket ID schema pass-through

---

id: DIA-260824-p3hf
title: "Repair DIA-217 task ticket ID schema pass-through"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-24
source: inventory
date: 2026-08-24
created: 2026-08-24
updated: 2026-09-01

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

OpenCode 1.18.20 exposes the native `task` tool with `command`, `description`,
`prompt`, `subagent_type`, and `task_id`, but no project-specific `ticket_id`
field. The DIA-217 observer gate nevertheless required that missing field.
Strict schema-following models therefore could not dispatch any subagent.

Runtime evidence from the `cebula-ox-alpha` preset shows four consecutive
lane-0 dispatches rejected despite a prompt containing the campaign ticket;
the orchestrator eventually used capability-token bypasses. Bridge the native
schema to the project policy in `tool.execute.before`: materialize a tagged
`campaign ticket DIA-...` from task text, with a one-unique-literal fallback,
then run the existing format and ticket-file checks unchanged.

## Verification

- [x] A task with one literal DIA ID and no schema field is attributed.
- [x] A `campaign ticket DIA-...` marker wins over policy/reference DIA IDs.
- [x] A task with no unambiguous governing ID remains hard-blocked.
- [x] Existing explicit `ticket_id` calls remain compatible.
- [x] Full observer and config suites pass.
- [ ] OpenCode is restarted and a task dispatch succeeds without a capability.

## Fix

The DIA-217 hook now prefers a unique `campaign ticket`/`governing ticket`
marker, falls back to one unique literal DIA ID, and writes the resolved value
into the task args before the existing gate validates it. Orchestrator prompts,
the canonical append, and AGENTS.md now describe the real native-schema
contract instead of asking models to invent an unavailable argument.

## Re-verify

Commits: 112bca1
Tests: make test-config exit 0; bun test dia217-ticket-gate.test.mjs 22 pass (89 expect) --cwd **tests**
Confirm: campaign-ticket DIA-id extraction pass-through verified.
