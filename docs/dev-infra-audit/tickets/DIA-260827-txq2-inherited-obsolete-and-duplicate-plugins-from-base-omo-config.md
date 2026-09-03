# DIA-260827-txq2 - Inherited obsolete and duplicate plugins from base OMO config

---

id: DIA-260827-txq2
title: "Inherited obsolete and duplicate plugins from base OMO config"
area: opencode-config
severity: High
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: test-lane
date: 2026-08-27
created: 2026-08-27
updated: 2026-08-27

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

- DIA-260827-wfcx

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; S-H1) confirms /home/mimic/.config/opencode/opencode.jsonc:4 enables opencode-snip@latest, @tarquinen/opencode-dcp@latest, and a local Ponytail; the project separately enables Ponytail at .opencode/opencode.jsonc:713-718; opencode debug shows 'snip binary not found'; stale DCP config remains in ~/.config/opencode/dcp.jsonc. Impact: a DCP thought removed is active, Ponytail hooks/skills duplicate, and 'latest' creates supply-chain drift. Correct fix: remove global snip/DCP/local Ponytail and the stale DCP config; keep one project-pinned Ponytail.

## Verification

opencode debug shows no global snip/DCP/local Ponytail loaded; only the project-pinned Ponytail is active; ~/.config/opencode/dcp.jsonc removed.

## Fix

Remove the global snip, DCP, and local Ponytail plugins and the stale dcp.jsonc from the global user config; keep a single project-pinned Ponytail. Resolve the merged runtime to the intended project preset.

## Re-verify

> To be filled at re-verify time.
