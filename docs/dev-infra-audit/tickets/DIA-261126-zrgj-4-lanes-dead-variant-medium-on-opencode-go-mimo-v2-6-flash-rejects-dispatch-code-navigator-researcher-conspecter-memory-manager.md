# DIA-261126-zrgj - 4 lanes dead: variant medium on opencode-go/mimo-v2.6-flash rejects dispatch (code-navigator, researcher, conspecter, memory-manager)

---

id: DIA-261126-zrgj
title: "4 lanes dead: variant medium on opencode-go/mimo-v2.6-flash rejects dispatch (code-navigator, researcher, conspecter, memory-manager)"
area: opencode-config
severity: Critical
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-26
source: test-lane
date: 2026-11-26
created: 2026-11-26
updated: 2026-11-26

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

### Symptom

Any dispatch to `code-navigator`, `researcher`, `conspecter` or
`memory-manager` fails immediately with:

```
Model "opencode-go/mimo-v2.6-flash" has no variants. Omit the variant.
```

Observed live: the code-navigator lane was rejected at dispatch time with
exactly that error. The subagent never starts, so four lanes are dead.

### Location

`.opencode/oh-my-opencode-slim.jsonc`, preset `mimo-balanced`. The
combination `"model": "opencode-go/mimo-v2.6-flash"` plus
`"variant": "medium"` appears on four lanes: `code-navigator`,
`researcher`, `conspecter`, `memory-manager`. `mimo-v2.6-pro` must be
checked for the same pattern, because the upstream cause affects the whole
v2.6 series.

### Root cause (catalog bug in OpenCode 2.x, NOT a model regression)

- At the API level the effort levels still work: MiMo-V2.6-Flash supports
  `reasoning_effort`, and through OpenCode Go `/v1/chat/completions` the
  values `low`, `medium`, `high` succeed; only `max` and `minimal` return
  400 at the Go gateway (anomalyco/opencode#50818).
- After the 1.19 -> 2.x move, the Xiaomi MiMo v2.6 models (flash, pro,
  ultraspeed) got `reasoning_options=[toggle]` in the provider catalog and
  run through `@ai-sdk/openai-compatible`. OpenCode 2.x builds no variants
  list at all for toggle-type models on that package - known open bug
  anomalyco/opencode#51541, duplicates #58897 and #60916.
- Consequence: `/variant` in the TUI reports "does not support any
  variants", and any subagent whose config declares `"variant"` fails
  before it starts.

### Fix (planned, NOT applied in the ticket-creation lane)

Drop the `"variant"` key everywhere the primary model is
`opencode-go/mimo-v2.6-flash` (and on `mimo-v2.6-pro` if present), so the
lanes run with the model default reasoning effort. No plugin/script change
is expected; if `scripts/validate-model-ids.sh` turns out to assert
variant/model combinations, it is repaired in the same commit.

### Scheduling

Fix lands immediately after Group 4a (the permission-ask watchdog
tests/implementation), before Group 5, because `memory-manager` is required
at campaign cycle end and `researcher`/`conspecter` are needed by the
research pipeline.

## Verification

Acceptance criteria:

- [ ] No `"variant"` entry remains beside a `mimo-v2.6-*` model id in any
      preset (`grep -n "variant" .opencode/oh-my-opencode-slim.jsonc`, then
      check every remaining hit's sibling `model` line).
- [ ] `make test-config` exits 0.
- [ ] A real dispatch to each of the four lanes
      (`code-navigator`, `researcher`, `conspecter`, `memory-manager`)
      starts successfully. Evidence must be an actual dispatch, not a config
      parse - a passing `make test-config` does not prove the bug is gone.
- [ ] The interaction with `scripts/validate-model-ids.sh` is checked; if
      that validator asserts variant/model combinations it is repaired in the
      same commit.

Defect reproduction (before the fix): dispatch any of the four lanes and
observe the rejection `Model "opencode-go/mimo-v2.6-flash" has no variants.
Omit the variant.` before the lane starts.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
