# DIA-260821-5r03 - runtime observer plugin duplicate-registration audit and hardening

---

id: DIA-260821-5r03
title: "runtime observer plugin duplicate-registration audit and hardening"
area: opencode-config
severity: Major
status: CLOSED
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
updated: 2026-09-14

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

- gate:scripts/validate-observer-dedupe.sh
- runtime:unique-session-boot-2026-09-14

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

- [x] Effective-config audit attempted in the rebuilt container; because the CLI
      truncates the large resolved JSON at 65,536 bytes before its plugin list,
      the finding is supported by global/project source inspection plus runtime
      boot evidence instead of claiming an unreadable list.
- [x] Each of `delegation-observer.ts` and `needs-input-observer.ts` is
      registered in exactly ONE config source (project or global), not both.
- [x] An automated check (the existing `validate-observer-dedupe.sh` in
      `make test-config`) inspects all project config layers and
      asserts unique explicit plugin basenames and no collision with the
      auto-discovered plugin set; it FAILS on duplicates and passes when unique.
- [x] `make test-config` and the observer-dedupe validator exit 0 after the
      deduplication.

## Fix

Observer plugins now have one source: `.opencode/plugins/*.ts` auto-discovery.
`scripts/validate-observer-dedupe.sh`, wired into `make test-config`, rejects an
explicit config entry matching any auto-discovered plugin and rejects duplicate
basenames within a plugin array.

## Re-verify

- Container global config contains no delegation-observer or
  needs-input-observer reference.
- `scripts/validate-observer-dedupe.sh`: PASS across opencode.jsonc, OMO preset,
  TUI config, and retained legacy config.
- `make test-config`: 57/57 PASS.
- Last 20 runtime `session_boot` rows have 20 unique boot IDs (no duplicate
  plugin boot emission).
- `opencode debug config` starts correctly but its large prompt payload is
  truncated at 65,536 bytes before valid JSON completion; this CLI display
  limitation does not override the source-layer gate and runtime boot evidence.
