# DIA-260831-9zq6 - Wire orchestrator ID ALLOCATION rule to scripts/allocate-id (drop sequential scan)

---

id: DIA-260831-9zq6
title: "Wire orchestrator ID ALLOCATION rule to scripts/allocate-id (drop sequential scan)"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-31
source: inventory
date: 2026-08-31
created: 2026-08-31
updated: 2026-08-31

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

- The unified-ID ticket DIA-260819-8kwm (CLOSED) intended all artifact types (res/ana/tch/DIA) to use datetime-based IDs via scripts/allocate-id, eliminating sequential scanning and teammate collisions.
- However, the orchestrator prompt's ID ALLOCATION rule was never updated: it still instructs "scan knowledge/ for highest existing <type><nnn> and assign the next integer ... never let the agent self-allocate" (inherited from DIA-162 VERIFIED / DIA-235 CLOSED).
- scripts/allocate-id exists and was hardened (DIA-260826-pjm: guarantee 4-char suffix + burst entropy) but is not called by the orchestrator for ana/tch/res.
- Symptom of the drift: the orchestrator still allocates sequential anaNNN IDs by scanning knowledge/, which is exactly the collision-prone pattern DIA-260819-8kwm set out to remove (two agents scanning at once both see the same "next" number).
- Fix: update the ID ALLOCATION rule in oh-my-opencode-slim.jsonc (3 presets) and AGENTS.md to call `scripts/allocate-id <type> <slug>` and pass the returned datetime ID (e.g. ana-260831-a1b2-slug) in the dispatch payload; remove the sequential-scan instruction.
- This is a section-2.5 config change: route through @ai-specialist gate -> register learnings -> @coder implement -> make test-config + restart-verify -> @ai-auditor review -> CHANGELOG.
- Verification: orchestrator dispatches carry allocate-id-generated IDs; no sequential scan; two rapid dispatches get distinct IDs; make test-config passes; related ticket DIA-260831-ezyv (Bun crash during this work) noted for context.

## Verification

- [ ] ID ALLOCATION rule in oh-my-opencode-slim.jsonc (3 presets) calls `scripts/allocate-id <type> <slug>` and passes returned datetime ID in dispatch payload; sequential-scan instruction removed
- [ ] Same rule updated in AGENTS.md
- [ ] `make test-config` passes
- [ ] Two rapid dispatches get distinct IDs (no collision)
- [ ] Restart-verify done; @ai-auditor review + CHANGELOG entry recorded

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
