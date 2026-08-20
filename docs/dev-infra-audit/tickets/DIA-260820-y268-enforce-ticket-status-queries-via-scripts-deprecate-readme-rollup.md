# DIA-260820-y268 - enforce ticket-status queries via scripts, deprecate README rollup

---

id: DIA-260820-y268
title: "enforce ticket-status queries via scripts, deprecate README rollup"
area: dev-infra
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-20
source: baseline
date: 2026-08-20
created: 2026-08-20
updated: 2026-08-20

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

Agents (especially the orchestrator) currently read the `docs/dev-infra-audit/tickets/` directory directly via the read tool to assess ticket status, instead of using the purpose-built scripts (`scripts/tickets frontier`, `scripts/tickets stats`, `scripts/tickets list`, `scripts/tickets show`). This wastes tokens (reading 196 directory entries + individual ticket files) and produces stale results. The README.md rollup in the tickets directory is a static snapshot that can drift from actual state. Scripts provide live, filtered, structured output on demand.

**Correlated with:** DIA-229 (ticket creation bypasses scripts/tickets)

Required changes:

1. Add a rule to AGENTS.md: When querying ticket status, use `scripts/tickets` subcommands. Do NOT read the `tickets/` directory directly. Do NOT rely on `README.md` for status.
2. Evaluate whether `README.md` should be removed entirely, or kept as a human-only convenience with a deprecation notice.
3. Ensure all `scripts/tickets` subcommands work correctly and cover the use cases agents need.
4. Add a `scripts/tickets` help/usage summary to AGENTS.md or a reference doc so agents know which subcommand to use.

## Verification

- [ ] AGENTS.md contains a rule directing agents to use `scripts/tickets` subcommands for ticket status queries (full path: `docs/dev-infra-audit/tickets/`)
- [ ] AGENTS.md contains a `scripts/tickets` usage summary or pointer to one
- [ ] README.md in tickets directory has a deprecation notice (or is removed, if that is the chosen approach)
- [ ] `scripts/tickets --help` output is complete and covers all agent use cases
- [ ] At least one agent dispatch uses `scripts/tickets` instead of reading the directory directly (verified in session log) — **PENDING: will be verified in next orchestrator session that queries ticket status**

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
