# DIA-260827-ft3z - [HIGH] Shell permissions bypass write scopes via curl/wget redirection

---

id: DIA-260827-ft3z
title: "[HIGH] Shell permissions bypass write scopes via curl/wget redirection"
area: opencode-config
severity: High
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
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

- .opencode/opencode.jsonc:485-500,586-601

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; W-H2) confirms researcher/resource-manager can curl -o, wget -O, and redirect (opencode.jsonc:493-500,595-601); coder has node _, bun _, python3 _ (:337-342); the section-2.5 edit gate does not intercept bash (delegation-observer.ts:3114-3124). Impact: a lane with edit: knowledge/_ can write anywhere; coder can change .opencode/ and bypass the AI-specialist gate. Correct fix: path-validating fetch/write adapters, a protected-path shell gate, and removal of broad interpreters where unneeded.

## Verification

Verify a narrow edit-scoped lane cannot write outside its directory via curl/wget/redirection; coder loses broad interpreters unless required.

## Fix

Detail: researcher/resource-manager edit scopes are narrow, but allowed curl/wget/shell commands can write anywhere through output flags or redirection. Impact: externally influenced lanes can overwrite config or source outside their artifact directories.

Fix: use path-validating fetch wrappers or non-shell fetch plus scoped edit.

## Re-verify

> To be filled at re-verify time.
