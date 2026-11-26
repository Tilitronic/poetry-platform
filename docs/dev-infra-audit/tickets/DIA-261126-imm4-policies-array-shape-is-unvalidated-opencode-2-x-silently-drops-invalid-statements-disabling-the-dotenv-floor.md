# DIA-261126-imm4 - policies array shape is unvalidated - OpenCode 2.x silently drops invalid statements, disabling the dotenv floor

---

id: DIA-261126-imm4
title: "policies array shape is unvalidated - OpenCode 2.x silently drops invalid statements, disabling the dotenv floor"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-26
source: fix-lane
date: 2026-11-26
created: 2026-11-26
updated: 2026-11-26

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

Neither `scripts/validate-opencode-config.sh` (the `make test-config` JSONC
validator) nor `scripts/audit-agent-tool-coverage.sh` validates the SHAPE of
the top-level `policies` array. The validator does JSONC syntax and
documentation-drift checks only; the audit script only looks for a top-level
`permissions` list (it keys on `permissions`, not on `policies`) and reports
nothing about `policies` entries.

Meanwhile OpenCode 2.x silently DROPS an invalid policy statement at load time
with only a log warning and keeps applying the remaining statements. So a typo
such as `"action": "tool_use"` (instead of `tool.use`) or `"effect": "block"`
(instead of `deny`) passes `make test-config` cleanly while silently disabling
the enforced dotenv floor at runtime - the failure is invisible until someone
reads a `.env` file on the V2 runtime.

Proposed check (add to the config validator and/or the audit):

- `action` is a member of the closed V2 enum (currently `tool.use`).
- `effect` is exactly `allow` or `deny`.
- `resource` is non-empty and, for `action: tool.use`, matches
  `<action>:<pattern>` (i.e. starts with `tool.use:` and has a non-empty
  glob after the colon).
- No unknown keys in a policy entry.
- Fail (non-zero) on any violation instead of warning, because a dropped
  statement silently removes protection.

Campaign ticket: DIA-261112-exon 'opencode-version-migration-breaking-change-inventory-blockers-and-remove-or-adapt-rating'.

## Verification

- [ ] Validator rejects `"action": "tool_use"` with a non-zero exit.
- [ ] Validator rejects `"effect": "block"` with a non-zero exit.
- [ ] Validator rejects an empty `resource` or a `tool.use` resource lacking the `tool.use:` prefix.
- [ ] Validator rejects an unknown key in a policy entry.
- [ ] `make test-config` passes on the current valid `policies` block in `.opencode/opencode.jsonc`.
- [ ] A regression test covers each rejected shape and the valid baseline.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
