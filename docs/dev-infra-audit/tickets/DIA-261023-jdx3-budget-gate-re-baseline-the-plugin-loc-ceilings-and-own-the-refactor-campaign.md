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
  home-qualt guard and the fail-closed jq schema check need ~121 lines of
  functional shell; the 139 included ~18 lines of compression indirection
  (semicolon-packed statements, 1-2 letter names) which the review-fix pass
  spelled out. Corrected floor statement (review finding S6): ~55 is
  unreachable without dropping the report kill-switch, the jq schema check,
  the pre-manifest skip, tree-first ticket reads, or the double measurement
  modes - that is the honest floor.
- DELETED: the entire Budget-Exception flow (try_exception, TRY_EXCEPTION_LINE,
  the four Exception-\* field checks, commit/expiry applicability rules,
  ~180 lines) - never used by a real commit (zero `Budget-Exception:` in git
  history - also drops the dead ZERO_SHA constant.
- Tests: `budget-gate.bats` (664 lines / 37 cases) +
  `budget-gate-range-exemption.bats` (249 lines / 6 cases) -> single
  `budget-gate.bats` of 161 lines / 10 cases (613 total lines folded away);
  the 6 range cases fold in, both SIGPIPE regressions retained (hook-mode
  > 64KB early match, range-mode in-tree ticket with opening match), all green.

Review-fix pass (same session, developer-accepted findings, 2026-10-23):

- P1 (critical): the shrink had dropped the empty-pattern-set guard - a
  manifest with `"patterns": []` made the B loop run once with an empty
  canonical, and `grep -qF -- ""` matched every scoped .mjs, blanket-blocking
  every evaluated commit. Guarded (`[ -n "$normalized_canonical" ] || continue`)
  with a fixture proving `patterns: []` + clean backed refactor exits 0;
  RED-without-guard / GREEN-with-guard both captured.
- P2: the openspec package (proposal.md, design.md, tasks.md 3.1) and the
  `.husky/commit-msg` comment still promised the deleted exception flow ->
  struck/annotated everywhere, `## REMOVED Requirements` block with Reason +
  Migration added to the delta spec per the schema.
- P3/P5: restored the design-mandated fail-closed coverage (feature-growth
  pass, malformed/missing manifest, staged-vs-loosened-disk manifest,
  unresolvable BUDGET_PLUGIN_ROOT, CLOSED in-tree ticket) plus both range
  boundaries (present-but-malformed manifest fails closed with no
  pre-gate-history line; outside-ledger warn asserted).
- P4: `manifest_load` moved inside `eval_commit` after the fast path (the
  fast path now genuinely never reads the manifest); range mode consumes an
  explicit return-2 skip signal carrying the mandatory pre-gate-history warn.
- S1: cryptic names spelled out (`manifest_touched`, `shell_lines`,
  `is_observer`, `match_status`, `scope_raw`, `pattern_canonical`,
  `pattern_baseline`, `pattern_authorized_site`, `pattern_id`,
  `plugin_root_ok`, `manifest_rel`, `tickets_rel`, ...); worst packed lines
  split. Script 139 -> 292 lines (renames + splits + P4 plumbing; the "~+20"
  estimate undercounted the unpacking the finding itself mandated).
- Battery rewritten one-action-per-line (S4): 161 -> 354 lines, 10 -> 18
  cases, all green. S9: home-qualt guard copy dropped from
  `setup_budget_repo`, kept only in the `_in_repo` fixtures.
- S5/S6/S7: CHANGELOG entry wording corrected (no blanket "all preserved
  behaviors kept" claim) + fix entry carries verification commands with exit
  codes; ticket floor statement corrected (~121 functional lines; ~55
  unreachable without dropping the kill-switch, jq schema check, pre-manifest
  skip, tree-first ticket reads, or double measurement); ADR status set to
  Accepted (supersedes the exception-flow section of the budget-gate design)
  and names the superseded decision.

## Re-verify

> To be filled at re-verify time.
