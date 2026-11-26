# DIA-260918-ubxv - ADR supersession promo two-preset pointer vs 4-preset muse-balanced tree

---

id: DIA-260918-ubxv
title: "ADR supersession promo two-preset pointer vs 4-preset muse-balanced tree"
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

.opencode/memory/adr.md lines 2142-2150 still record the two-preset promo
contract (pointer `"preset": "promo"`), but the working tree carries 4
presets keyed at .opencode/oh-my-opencode-slim.jsonc lines 19
(promo-union-alpha), 262 (muse-balanced), 491 (free), 722
(openai-first-cost-balanced) with the root pointer on `muse-balanced`.
Variant B (DIA-260917-s95f) flagged this without touching ADR content.
Needed: an ADR supersession note recording the promo -> muse-balanced rename
(and the free re-add), plus a lessons entry for the promo -> muse-balanced
rename so future preset work reads the tree, not the stale ledger.

## Verification

- [ ] ADR supersession note landed (promo two-preset pointer superseded by 4-preset muse-balanced tree)
- [ ] lessons entry for the promo -> muse-balanced rename recorded
- [ ] interview/drift tests match the ADR (muse-balanced + openai-first-cost-balanced tuples)

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
