# DIA-260819-8kwm - unified ID generation: all artifact types should use same datetime-based pattern

---

id: DIA-260819-8kwm
title: "unified ID generation: all artifact types should use same datetime-based pattern"
area: dev-infra
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

Artifact types across the project use inconsistent ID generation patterns, creating collision risks and no shared allocation mechanism:

- **Tickets** (`scripts/tickets new`): `DIA-NNN` (sequential) or `DIA-YYMMDD-XXXX` (datetime)
- **Research conspects** (manual): `resNNN` (sequential, scanned from `knowledge/` dir)
- **Analysis reports** (manual): `anaNNN` (sequential)
- **Teaching materials** (manual): `tchNNN` (sequential)
- **Sessions**: `ses_<random>` (OpenCode-generated, out of scope)

**Root cause**: no shared ID allocation script. Each artifact type was added incrementally with its own ad-hoc allocation. Sequential IDs are collision-prone under concurrent sessions (two agents scanning `knowledge/` at the same time both see the same "next" number).

**Current allocation scripts**:

- `scripts/tickets new` (line 1, ~200 lines) handles only DIA ticket IDs
- Research/analysis/teaching IDs are manually allocated by agents scanning directories

**Expected fix**: a single `scripts/allocate-id <type> <name>` script that:

1. Accepts type (`res`, `ana`, `tch`, `DIA`, or future types)
2. Generates `<type>-YYMMDD-<random4>-<slug>` (collision-proof: datetime + random suffix)
3. Returns the allocated ID to stdout
4. Is callable from: `scripts/tickets new` (internally), research-pipeline skill, analysis workflow, any agent

## Verification

- [ ] `scripts/allocate-id res test-slug` outputs `res-<YYMMDD>-<XXXX>-test-slug`
- [ ] `scripts/allocate-id ana test-slug` outputs `ana-<YYMMDD>-<XXXX>-test-slug`
- [ ] `scripts/allocate-id tch test-slug` outputs `tch-<YYMMDD>-<XXXX>-test-slug`
- [ ] `scripts/allocate-id DIA test-slug` outputs `DIA-<YYMMDD>-<XXXX>-test-slug`
- [ ] Two rapid consecutive calls produce different IDs (no collision)
- [ ] Invalid type (e.g., `scripts/allocate-id xyz name`) exits non-zero with usage message
- [ ] `scripts/tickets new` still works (regression: internally delegates to `allocate-id`)
- [ ] research-pipeline skill uses `allocate-id` for res ID allocation (no manual scanning)
- [ ] `make test-shell` passes (bats tests for `allocate-id`)

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
