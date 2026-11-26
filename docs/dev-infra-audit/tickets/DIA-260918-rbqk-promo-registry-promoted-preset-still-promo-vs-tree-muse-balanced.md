# DIA-260918-rbqk - promo-registry promoted_preset still promo vs tree muse-balanced

---

id: DIA-260918-rbqk
title: "promo-registry promoted_preset still promo vs tree muse-balanced"
area: config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-18
source: inventory
date: 2026-09-18
created: 2026-09-18
updated: 2026-09-18

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

.opencode/promo-registry.json line 5 still reads `"promoted_preset": "promo"`,
and history entries (create DIA-260828-qtsi, registry-refresh DIA-260917-s95f)
reference a `promo` preset key that no longer exists in the working tree:
presets are promo-union-alpha + muse-balanced (active root pointer line 3) +
free + openai-first-cost-balanced in .opencode/oh-my-opencode-slim.jsonc.
Variant B (DIA-260917-s95f) deliberately left the registry untouched pending
owner confirmation. Decision needed: flip `promoted_preset` (and any live
`preset` refs) to `muse-balanced`, or keep the promo refs as history and only
annotate. Check the promo-review SKILL pointer while here - it must resolve to
a live preset key, not the removed `promo` key.

## Verification

- [ ] registry `promoted_preset` resolves to a live preset key in oh-my-opencode-slim.jsonc
- [ ] promo-review SKILL pointer valid (no dangling `promo` preset reference)
- [ ] make test-config exit 0 (validate-changelog + drift + interview gates green)

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
