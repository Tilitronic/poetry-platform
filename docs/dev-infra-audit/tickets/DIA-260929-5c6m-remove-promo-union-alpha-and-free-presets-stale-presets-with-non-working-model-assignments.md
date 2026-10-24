# DIA-260929-5c6m - remove promo-union-alpha and free presets: stale presets with non-working model assignments

---

id: DIA-260929-5c6m
title: "remove promo-union-alpha and free presets: stale presets with non-working model assignments"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-29
source: inventory
date: 2026-09-29
created: 2026-09-29
updated: 2026-09-29

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

Remove two stale presets from .opencode/oh-my-opencode-slim.jsonc and retire
the promo generator insert path:

- Delete the `promo-union-alpha` preset (lines 20-262) INCLUDING its stale
  generated header (lines 15-19), and the `free` preset (lines 507-735)
  from .opencode/oh-my-opencode-slim.jsonc.
- RETIRE the promo generator's insert path in scripts/promo-preset-apply:
  the find_preset_block(raw,"free") anchor dependency (around lines
  212-218) and the stale literal target "promo" (around lines 113 and
  173), which currently matches no preset key in the tree.
- Update the .opencode/skills/promo-review/SKILL.md steps that invoke the
  generator (around lines 55 and 134-135), including the stale "promo"
  preset name.
- Update the three test files that hardcode the `free` preset key:
  - .opencode/plugins/**tests**/preset-model-guard.dia260918-t5.test.mjs
    (lines 81/84/96)
  - scripts/**tests**/preset-single-path.bats (lines 28/31/55/60)
  - scripts/**tests**/workspace-preset-selection.bats (lines 17/20/28/30)

Decision record:

- On 2026-09-29 the developer chose to RETIRE the generator insert path
  rather than repair the anchor, because the anchor key it depends on
  (`free`) is being deleted and the generator's real target key never
  existed.
- Preserved history MUST NOT be deleted to complete this change:
  .opencode/CHANGELOG.yaml entries, the CLOSED DIA-092 ticket,
  knowledge/archive/res009-011, .opencode/memory/ post-mortems,
  point-in-time knowledge/ana-_ and knowledge/res-_ reports,
  docs/dev-infra-audit-plan.md line 47.

## Verification

- [ ] Neither `promo-union-alpha` nor `free` remains in
      .opencode/oh-my-opencode-slim.jsonc.
- [ ] No hardcoded `free` preset reference remains in the three named test
      files.
- [ ] Running the promo generator path cannot fail with an anchor error
      and cannot exit 2: it either reports a clear retired/no-op state or the
      listener path is gone.
- [ ] `make test-config` and `make test-shell` both exit 0.
- [ ] A tree-wide check finds no remaining LIVE reference to the snip-free
      preset keys outside preserved history.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
