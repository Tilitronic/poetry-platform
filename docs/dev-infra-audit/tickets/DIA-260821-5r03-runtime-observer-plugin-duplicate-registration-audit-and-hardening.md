# DIA-260821-5r03 - runtime observer plugin duplicate-registration audit and hardening

---

id: DIA-260821-5r03
title: "runtime observer plugin duplicate-registration audit and hardening"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260821-bqy7
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
updated: 2026-08-21

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

ana033 rank 12 (P0 / HIGH reliability). Parent epic: DIA-260821-bqy7 'audit
repository risks and prioritize unresolved remediation'. Evidence:
knowledge/ana033-next-remediation-bugs/ana033-next-remediation-bugs-report.md
Section 4 Rank 12; live source `.opencode/opencode.jsonc` registers both
`delegation-observer.ts` and `needs-input-observer.ts` (grep returns 2
matches).

Problem: the project config (`.opencode/opencode.jsonc`) registers the
delegation and needs-input observer plugins. If the host global OpenCode
config ALSO registers them, each observer fires TWICE per event, doubling
registry writes and risking double handoff-archive writes / duplicate side
effects. This is a P0 reliability gap with no existing ticket, confirmed live
by ana032.

Required outcome:

- Effective-config audit: run `opencode debug config` in a clean HOME and
  capture the resolved, merged plugin list to confirm whether duplicates
  actually load.
- Single registration source: ensure each observer is registered in exactly
  ONE place (project OR global), eliminating the double-load path.
- Automated unique-plugin assertion: a `make test-runtime-config` (or
  equivalent) target that runs `opencode debug config` in a clean HOME and
  FAILS if any plugin id appears more than once.

## Verification

- [ ] Effective-config audit artifact exists: `opencode debug config` output
      (clean HOME) showing the resolved plugin list, with a finding on whether
      delegation-observer / needs-input-observer are duplicated.
- [ ] Each of `delegation-observer.ts` and `needs-input-observer.ts` is
      registered in exactly ONE config source (project or global), not both.
- [ ] An automated check (e.g. `make test-runtime-config`) runs
      `opencode debug config` in a clean HOME and asserts a unique plugin id
      list; it FAILS on duplicates (exit non-zero) and passes when unique.
- [ ] `make test-config` (and the new runtime-config target) exit 0 after the
      deduplication.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
