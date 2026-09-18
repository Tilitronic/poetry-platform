# DIA-260918-mm2u - retire or repoint promo-preset-apply stale promo target plus overcapture

---

id: DIA-260918-mm2u
title: "retire or repoint promo-preset-apply stale promo target plus overcapture"
area: scripts
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

scripts/promo-preset-apply still targets a `promo` key that no longer exists:
find_preset_block(text, "promo") at line 113 misses, so a run would take the
insert path and INSERT a fresh `promo` block before `free` (line 215 anchor),
resurrecting the removed preset. Worse, find_promo_region lines 121-139 walks
upward over the contiguous hand-written comment stack, so a second run would
delete the hand-written promo provenance comments (s95f Fix block). Retargeting
lines 113/173 to `muse-balanced` is UNSAFE (the generator would overwrite the
live active preset block). Decision needed: retire the generator vs repoint it
to a live target, then fix the overcapture. DO NOT run the script until fixed.

## Verification

- [ ] retire-vs-repoint decision recorded (retire generator or repoint to a live target)
- [ ] do-not-run guard holds until the overcapture fix lands (no script runs in the meantime)
- [ ] make test-config exit 0 after the fix

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
