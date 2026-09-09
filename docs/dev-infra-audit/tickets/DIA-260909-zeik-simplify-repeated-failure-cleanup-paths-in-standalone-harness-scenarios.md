# DIA-260909-zeik - simplify repeated failure-cleanup paths in standalone harness scenarios

---

id: DIA-260909-zeik
title: "simplify repeated failure-cleanup paths in standalone harness scenarios"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "DIA-260903-o7n0"
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-09
source: inventory
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-09

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

Post-audit cleanup item 5 from ponytail audit /tmp/architecture-review-20260909-170245.html (ephemeral; substance carried here). Parent context: DIA-260903-o7n0 de-bloat + observer-lib extraction work. Item 1 ALREADY FIXED at 420ce4f.

Simplify repeated failure-cleanup paths in standalone harness scenarios. Standalone harness scenario files (run under `bun run`, not `bun test`) duplicate failure-cleanup logic (remove temp dirs, reset fixtures, restore env) across multiple `catch`/`finally` branches. Extract into a shared `withCleanup` wrapper or deduped finally block in helpers/plugin-harness.mjs or scenario helper.

Estimated savings: -45..-70 LOC.

Guard (MANDATORY): do NOT delete the 7 extracted production modules, capability loader guards, or independent checksum logic. Failure-cleanup simplification must preserve independent checksum/parity assertions - only deduplicate the cleanup mechanics.

Source: ponytail audit item 5, DIA-260903-o7n0 follow-up. Campaign ticket DIA-260901-91qy.

## Verification

- [ ] Standalone harness scenarios no longer duplicate failure-cleanup paths (single cleanup path per scenario)
- [ ] Cleanup helper or shared finally block covers all failure branches without losing error context
- [ ] 7 extracted production modules, capability loader guards, checksum logic untouched
- [ ] LOC delta -45..-70 verified via git diff --stat
- [ ] Harness scenarios pass under `bun run`

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
