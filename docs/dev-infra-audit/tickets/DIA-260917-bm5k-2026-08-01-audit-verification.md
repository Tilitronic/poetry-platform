# DIA-260917-bm5k - 2026-08-01 audit verification

---

id: DIA-260917-bm5k
title: "2026-08-01 audit verification"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-17
source: inventory
date: 2026-09-17
created: 2026-09-17
updated: 2026-09-17

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Update 2026-09-17 -- M6 decision (prod image postponed)

- Decision: postponing a separate production Dockerfile for apps/api-server. Reason (developer ruling): still working in the dev environment and fixing it; too early to create a prod image.
- Current state: apps/api-server has pyproject.toml + uv.lock and no Dockerfile\*; dev coverage via Dockerfile.dev + docker-compose.yml stands.
- Revisit trigger: dev environment stabilizes / production deployment of api-server is planned.
