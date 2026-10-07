# DIA-260909-fkiy - extract repeated workspace-cleanup retry loops into helpers plugin-harness

---

id: DIA-260909-fkiy
title: "extract repeated workspace-cleanup retry loops into helpers plugin-harness"
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

Post-audit cleanup item 3 from ponytail audit /tmp/architecture-review-20260909-170245.html (ephemeral; substance carried here). Parent context: DIA-260903-o7n0 de-bloat + observer-lib extraction work. Item 1 ALREADY FIXED at 420ce4f.

Extract repeated workspace-cleanup retry loops from 16 Bun suites into helpers/plugin-harness.mjs. Today 16 Bun suites duplicate the same tmpdir cleanup with retry/backoff (fs.rm with retries, EAGAIN/EBUSY handling, setTimeout loops). Centralize into a shared helper: `cleanupWorkspace` or `createTempWorkspace`/`cleanupTempWorkspace` pair in .opencode/plugins/**tests**/helpers/plugin-harness.mjs.

Estimated savings: -120..-200 LOC deduplicated. The helper already hosts mockOpencodePlugin / harness scaffolds per DIA-260903-o7n0 disposition D - extend it, do not create a new helper file.

Guard (MANDATORY): do NOT delete the 7 extracted production modules, capability loader guards, or independent checksum logic. This ticket is test-helper extraction only - no production module deletions.

Constraints from DIA-260903-o7n0 disposition:

- .mjs rationale is repo-wide node-runnable convention (Bun transpiles TS natively), not strip-types
- Helper imports ONLY `mock` from `bun:test`, never `test`/`expect` (harness scenarios run under bun run)
- Idempotent mocks, explicit cleanup handles, exit handler is fail-safe only

Source: ponytail audit item 3, DIA-260903-o7n0 follow-up. Campaign ticket DIA-260901-91qy.

## Verification

- [ ] 16 Bun suites no longer contain inline cleanup retry loops (grep for retry/fs.rm loops confined to helper)
- [ ] helpers/plugin-harness.mjs exports cleanup helper(s) and all 16 suites import it
- [ ] Helper handles EAGAIN/EBUSY with bounded retries, removes path from exit-handler registry on success
- [ ] 7 extracted production modules, capability loader guards, checksum logic untouched
- [ ] LOC delta -120..-200 verified via git diff --stat
- [ ] All 16 Bun suites pass with helper in place

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
