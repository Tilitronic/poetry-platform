# DIA-261112-exon - OpenCode version migration: breaking-change inventory, blockers, and remove-or-adapt rating

---

id: DIA-261112-exon
title: "OpenCode version migration: breaking-change inventory, blockers, and remove-or-adapt rating"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-12
source: inventory
date: 2026-11-12
created: 2026-11-12
updated: 2026-11-12

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

- commit:5b9118c
- file:.opencode/learnings/external-patterns/2026-11-26-dia-261112-exon-plugin-vs-plugins-key.md
- gate:make-test-config-exit-0
- gate:validate-model-ids-exit-0

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Task 1.4 (ponytail) closed 2026-11-26 as a no-op: keep @dietrichgebert/ponytail as-is, no code or config change. The ruleset plugin imposes no V2 key or API constraint.

Canonical plugin-key work (dispatch label 1.5; the actual tasks.md entries are 8.3 and 9.5) applied 2026-11-26:

- 8.3 partial: .opencode/opencode.jsonc now uses the canonical OpenCode 2.x `plugins` key with the existing string entries preserved. The `skills.urls` and `mcp.servers` conversions remain pending.
- 9.5 partial: scripts/validate-observer-dedupe.sh reads `cfg.plugins ?? cfg.plugin` and handles V2 `{package, options}` entries (plus V1 tuple entries); the jsonc-parse.js --doc-drift agents reader remains pending.
- The same vacuous-read fix was applied to scripts/**tests**/batch-d-infra.test.mjs:641.

Numbering note: tasks.md entry 1.5 is the envsitter provisional-removal task, not the plugin-key work; it was left unchanged.

Rename commit: 5b9118c (fix(opencode-config): use the canonical plugins key on the V2 tree).

Boundary constraint: after this change the migration tree is V2-only for plugin loading. Running a V1 1.18.32 container against this tree would silently load no plugins because V1 knows only the `plugin` key. V1 work must happen on omo-slim-changes.

## Re-verify

> To be filled at re-verify time.
