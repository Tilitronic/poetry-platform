# DIA-260827-6g6r - OpenSpec CLI commands unreachable from skills and agents

---

id: DIA-260827-6g6r
title: "OpenSpec CLI commands unreachable from skills and agents"
area: opencode-config
severity: High
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: test-lane
date: 2026-08-27
created: 2026-08-27
updated: 2026-08-27

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
evidence:

- DIA-260827-wfcx

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-H6) confirms opsx-apply.md:18 uses AskUserQuestion, opsx-continue.md:32 uses TodoWrite, opsx-archive.md:62 uses Claude-style 'Task ... general-purpose'; the commands have no agent binding and the default orchestrator lacks the needed bash/edit rights; host has no openspec, container has 1.7.0. Impact: commands hang, hallucinate tools, or push the orchestrator to bypass policy. Correct fix: native OpenCode tool names/schema, project agent names, explicit owning agent; host/container functional smoke.

## Verification

Each opsx command uses only tools available in OpenCode, has an explicit owning agent, and runs end-to-end on both host and container OpenSpec 1.7.0.

## Fix

Rewrite the OpenSpec commands with native OpenCode tool names and schema, project agent names, and an explicit owning agent; add a host/container functional smoke test.

## Re-verify

> To be filled at re-verify time.
