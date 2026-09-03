# DIA-260827-nkvf - Exposed MCP credential in OpenCode config plaintext

---

id: DIA-260827-nkvf
title: "Exposed MCP credential in OpenCode config plaintext"
area: secrets
severity: Critical
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

Global user-state incident (not a committed project secret). Reaudit (DIA-260827-wfcx, 2026-08-31; S-C1) confirms /home/mimic/.config/opencode/opencode.jsonc:10 contains a non-empty literal Context7 credential, not {env:...}. Project config already uses safe env substitution at .opencode/opencode.jsonc:739-744. Impact: a config dump, backup, support log, or read access can exfiltrate the key. Correct fix: revoke/rotate immediately, replace the literal with {env:CONTEXT7_API_KEY}, and audit logs/backups.

## Verification

grep the global config for the literal credential returns nothing; opencode debug shows the credential resolved from env; rotate the key in the provider console.

## Fix

Revoke and rotate the exposed Context7 credential immediately. Replace the literal in /home/mimic/.config/opencode/opencode.jsonc:10 with {env:CONTEXT7_API_KEY}. Audit config dumps, backups, and support logs for the leaked value. Project config already uses safe env/file substitution, not plaintext.

Progress 2026-08-31: user rotated the key at the provider. Remaining step is blocked on agent tooling - the global config lives outside the repo at /home/mimic/.config/opencode/opencode.jsonc and is not writable by agent tools. User must: (1) export CONTEXT7_API_KEY in the OpenCode launch environment, (2) replace the literal on line 10 with {env:CONTEXT7_API_KEY}. Re-verify: opencode debug shows the credential resolved from env and grep of the global config finds no literal key.

## Re-verify

> To be filled at re-verify time.
