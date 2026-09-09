# DIA-260909-sazr - remove RED-era factory and alias probes from observer-lib test suites

---

id: DIA-260909-sazr
title: "remove RED-era factory and alias probes from observer-lib test suites"
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

Post-audit cleanup item 2 from ponytail audit /tmp/architecture-review-20260909-170245.html (ephemeral; substance carried here). Parent context: DIA-260903-o7n0 de-bloat + observer-lib extraction work. Item 1 (compound bats split) ALREADY FIXED at 420ce4f - do not re-ticket.

Remove obsolete RED-era factory/alias probes from the 7 new observer-lib test suites. These were TDD RED scaffolding to prove loader wiring before canonical APIs existed; canonical APIs now exist and are tested via DI fakes + loader-contract tests. Keep DI fakes and loader-contract tests intact - they verify useful behavior/parity.

Estimated savings: -150..-300 test LOC. Scope: 7 observer-lib test suites under .opencode/plugins/**tests** (plugin-harness-adjacent lib tests). Pattern: factory function existence checks, alias re-exports, and probe wrappers that duplicate canonical API coverage without adding independent assertions.

Guard (MANDATORY): do NOT delete the 7 extracted production modules themselves, capability loader guards, or independent checksum logic (useful behavior/parity contracts, not bloat). Only delete RED-era probe wrappers in tests where canonical API coverage already exists.

Source: ponytail audit item 2, DIA-260903-o7n0 follow-up. Campaign ticket DIA-260901-91qy.

## Verification

- [ ] 7 observer-lib test suites contain no RED-era factory/alias probe wrappers (grep for probe patterns returns 0)
- [ ] DI fakes + loader-contract tests remain intact and passing
- [ ] 7 extracted production modules untouched (git diff shows no deletions under .opencode/plugins/lib or equivalent)
- [ ] Capability loader guards and independent checksum logic untouched
- [ ] Test LOC delta -150..-300 verified via cloc or git diff --stat
- [ ] `make test-config` and plugin suite pass (or relevant `bun test` harness passes)

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
