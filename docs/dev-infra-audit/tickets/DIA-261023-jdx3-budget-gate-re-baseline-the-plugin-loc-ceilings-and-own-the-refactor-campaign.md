# DIA-261023-jdx3 - budget gate: re-baseline the plugin LOC ceilings and own the refactor campaign

---

id: DIA-261023-jdx3
title: "budget gate: re-baseline the plugin LOC ceilings and own the refactor campaign"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-23
source: inventory
date: 2026-10-23
created: 2026-10-23
updated: 2026-10-23

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

The plugin LOC ceilings in `scripts/budget-baselines.json` were frozen on
2026-09-09 at prod 5900 / shell 4037 (measured then: prod 5814). Live today:
prod 7546 / shell 4148 = +1646 / +111 over the frozen ceilings, after 351
commits of legitimate feature growth. The gate never compared feature
commits, so the ceiling is an aged snapshot, but any refactor commit now
blocks fail-closed because both prior campaigns (DIA-260903-o7n0,
DIA-260909-zeik) are CLOSED.

Measured per-file growth since 2026-09-09 (plugin src/ unless noted):

| File                       | Growth |
| -------------------------- | ------ |
| registry.ts                | +852   |
| journal-persistence.ts     | +242   |
| permission-fast-resolve.ts | +216   |
| routing-gate.ts            | +152   |
| ticket-gate.ts             | +73    |
| stall-sweep.ts             | +65    |
| handoff.ts                 | +21    |
| shell scripts              | +111   |

Re-baseline decision: raise the ceilings to prod 7800 / shell 4300 (live
plus deliberate headroom) and register this ticket as the approved
refactor-scope campaign in the manifest (see DIA-261022-5n2v commit).

Follow-up scope owned by this ticket (the shrink, NOT part of the
re-baseline commit): reduce `scripts/check-budget-gate.sh` to ~55 lines
while keeping both measurement sets, both call modes, the duplication
detector, the manifest-edit guard and backing check; delete the
never-used Budget-Exception flow.

## Verification

- [ ] Manifest ceilings read prod 7800 / shell 4300; campaign entry
      `{ticket: DIA-261023-jdx3, scope: refactor, status: approved}` present
- [ ] `bash scripts/check-budget-gate.sh --range <range>` exits 0 on the
      re-baseline commit and on a feature commit range
- [ ] Shrink (later): check-budget-gate.sh <= ~60 lines, all budget-gate
      bats tests green, manifest-edit guard and backing check intact

## Fix

Shrink landed 2026-10-23 (this ticket's follow-up scope):

- `scripts/check-budget-gate.sh`: 735 lines (pre-shrink, including the
  DIA-261022 pipefail fix) -> 139 lines. The ~55-60 line target was NOT met:
  the nine preserved behaviors (both measurement sets, hook + range modes with
  tree-first ticket resolution, the unconditional duplication detector with
  its pipefail-suspension pattern, the manifest-edit guard, OPEN-ticket
  backing, the pre-manifest range exemption, the report kill-switch, the
  exit-code contract, the BUDGET_PLUGIN_ROOT fixture seam) plus the
  home-qualt guard and the fail-closed jq schema check need 139 lines of
  honest shell; nothing was dropped to chase the number.
- DELETED: the entire Budget-Exception flow (try_exception, TRY_EXCEPTION_LINE,
  the four Exception-\* field checks, commit/expiry applicability rules,
  ~180 lines) - never used by a real commit (zero `Budget-Exception:` in git
  history - also drops the dead ZERO_SHA constant.
- Tests: `budget-gate.bats` (664 lines / 37 cases) +
  `budget-gate-range-exemption.bats` (249 lines / 6 cases) -> single
  `budget-gate.bats` of 161 lines / 10 cases (613 total lines folded away);
  the 6 range cases fold in, both SIGPIPE regressions retained (hook-mode
  > 64KB early match, range-mode in-tree ticket with opening match), all green.

## Re-verify

> To be filled at re-verify time.
