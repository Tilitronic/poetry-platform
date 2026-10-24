# DIA-260821-8kpc - Disable DCP plugin (context/cache concerns)

---

id: DIA-260821-8kpc
title: "Disable DCP plugin (context/cache concerns)"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
updated: 2026-08-21

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

Disable and remove the DCP plugin from everywhere in the project. Rationale:
models have large context windows, rarely run for very long, frequent DCP
calls consume time and reduce cache-hit rates; the team has doubts about
DCP's usefulness. Scope: identify every DCP reference (dcp.jsonc, plugin
registration, config, prompts, skills, docs) and remove/disable it. This
ticket is the tracking ticket for the removal; the removal itself is a
separate config-change task.

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Completion Summary (2026-08-21)

DCP plugin fully removed and ticket closed. No container rebuild needed; an
opencode restart is required for the running session to drop DCP.

### Removal scope

- Project config stale references removed: AGENTS.md, routing-order-gate.test.mjs,
  delegation-observer.ts regex, oh-my-opencode-slim.jsonc (4 preset prompts),
  inventory.md, memory-shelf annotations.
- Global config removed: /app/.config/opencode/opencode.json plugin array,
  tui.json plugin array, dcp.jsonc deleted.

### Research completed

- res036 (DCP vs Headroom): Headroom is NOT a cache-friendlier replacement;
  cache-mode drifts prefix on the opencode-go/DeepSeek path.
- res037 (Headroom review/videos validation): review 5/6 accurate; the
  60-95% figure is JSON-data-scoped, not general.
- res038 (caveman output economy): 8.5% measured, not 65%; redundant with
  ponytail level:full; do not adopt.

### Memory corrected

- False "enabled:false / disabled since Aug 16" claims in repo.md, adr.md,
  lessons.md corrected to reality: DCP was ENABLED globally until 2026-08-21.

### Decision

- DCP stays removed. Headroom NOT adopted as a cache-fix. Caveman NOT adopted
  (ponytail covers it).

### Verification

- make test-config passed (18 steps).
- routing-order-gate test 36/36.
- Global config grep clean of dcp/tarquinen.
