# DIA-260819-97fg - memory-manager permission: scoped write access for learnings directory

---

id: DIA-260819-97fg
title: "memory-manager permission: scoped write access for learnings directory"
area: opencode-config
severity: Low
status: CLOSED
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
updated: 2026-10-13

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

- .opencode/opencode.jsonc#memory-manager

---

## Description

The `memory-manager` agent tries to use the `write` tool to create files in `.opencode/learnings/external-patterns/`, gets blocked by permission rules, then falls back to bash -- wasting tokens on a failed attempt.

**Root cause:** memory-manager's permission config (in `.opencode/opencode.jsonc`) does not include write access to `.opencode/learnings/external-patterns/*`, but it has bash access. The agent does not know this upfront and tries `write` first.

**Fix:** Add scoped write permission for `.opencode/learnings/external-patterns/*` to memory-manager's permission block in `.opencode/opencode.jsonc`. This aligns with memory-manager's purpose (it writes learnings files) and eliminates the wasted-token fallback path.

## Verification

- [ ] `memory-manager`'s permission block in `.opencode/opencode.jsonc` includes a write entry for `.opencode/learnings/external-patterns/*`
- [ ] `make test-config` passes (permission config is schema-valid)
- [ ] No other agent's permissions were modified

## Fix

No implementation change was needed. The existing memory-manager permission grants edit access to .opencode/learnings/external-patterns/\* while the general edit pattern is denied. No other agent permissions were changed.

## Re-verify

opencode debug agent memory-manager resolved the scoped edit allow for .opencode/learnings/external-patterns/\*. make test-config exited 0. The ticket's requested behavior was already satisfied by the existing configuration.
