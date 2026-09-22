# DIA-260824-8k62 - retire legacy tools/opencode-docker only after unified-runtime acceptance

---

id: DIA-260824-8k62
title: "retire legacy tools/opencode-docker only after unified-runtime acceptance"
area: docker
severity: Medium
status: OPEN
blocked_by: [DIA-260821-x5nj] # DIA-NNN refs, or empty
parent_epic: DIA-260824-iirx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-24
source: inventory
date: 2026-08-24
created: 2026-08-24
updated: 2026-09-22

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

## UPDATE 2026-09-22

Blocking edges reduced by developer disposition:

- DIA-260821-m7vk - already CLOSED (blocker cleared).
- DIA-260821-aoag - already CLOSED (blocker cleared).
- DIA-260824-ifcf - CLOSED as obsolete placeholder (see that ticket).
- DIA-260821-n8sq - DECOUPLED by developer disposition 2026-09-22: it is independent scripts/CI test work (its `test-runtime-config` make target is verified ABSENT - `grep -n "test-runtime-config" Makefile` exits 1, no match in scripts/). It stays OPEN as independent work but no longer gates this ticket.
- DIA-260821-x5nj - RETAINED. Its substantive criteria were verified 6/7 SATISFIED (lane cod-2, session ses_f37350954ffeHKJRXubvEUp1it) against openspec/changes/dia-260821-x5nj-unified-docker-dev-runtime/ and .sdd/dev-infra/architecture.md:94-104 (ADR 11). Criterion (g) 'no Dockerfile/compose/config file modified' is PARTIAL (x5nj-era commits created 4 compose overlays). Formal disposition is pending an analysis report; this edge is retained until that disposition lands.
