# DIA-260909-9i1o - consolidate duplicated budget-gate bats fixture setup

---

id: DIA-260909-9i1o
title: "consolidate duplicated budget-gate bats fixture setup"
area: scripts
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

Post-audit cleanup item 4 from ponytail audit /tmp/architecture-review-20260909-170245.html (ephemeral; substance carried here). Parent context: DIA-260903-o7n0 de-bloat + observer-lib extraction work. Item 1 ALREADY FIXED at 420ce4f.

Consolidate duplicated budget-gate bats fixture setup. Multiple bats tests duplicate the same budget-gate fixture setup (tmpdir, ledger scaffolding, env wiring for budget/threshold gates). Extract into a shared bats helper or fixture function (e.g., `setup_budget_gate` in `tests/helpers/` or existing bats helper lib).

Estimated savings: -90..-140 LOC.

Developer directive: only after the current push lands - do not start until the in-flight push (containing 420ce4f and related ledger commits) is on the remote. This ticket is BLOCKED until push verification; it must not rebase onto unpushed ledger state.

Guard (MANDATORY): do NOT delete the 7 extracted production modules, capability loader guards, or independent checksum logic. This ticket touches bats fixtures only.

Source: ponytail audit item 4, DIA-260903-o7n0 follow-up. Campaign ticket DIA-260901-91qy.

## Verification

- [ ] Current push containing 420ce4f verified on remote (`git ls-remote` or `git log origin/...`)
- [ ] Budget-gate bats fixtures deduplicated into single helper, all callers updated
- [ ] No duplicated setup blocks remain (grep confirms single definition)
- [ ] 7 extracted production modules, capability loader guards, checksum logic untouched
- [ ] LOC delta -90..-140 verified via git diff --stat
- [ ] `make test-shell` (bats) passes

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
