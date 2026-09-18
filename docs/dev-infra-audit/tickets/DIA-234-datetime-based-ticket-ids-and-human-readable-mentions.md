# DIA-234 — Datetime-based ticket IDs (DIA-YYMMDD-XXXX) and human-readable mentions

---

id: DIA-234
title: "Datetime-based ticket IDs (DIA-YYMMDD-XXXX) and human-readable mentions"
area: scripts
severity: Major
status: OPEN
blocked_by: []
parent_epic: ""

gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered:
source: fix-lane
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Sequential DIA IDs (DIA-001, DIA-002, ...) cause TOCTOU races when `scripts/tickets` allocates the next number via max+1. Parallel workflows (batch D dispatch, multiple orchestrator sessions) can claim the same ID simultaneously, producing duplicate tickets that break the ledger contract.

The fix: switch to `DIA-YYMMDD-XXXX` format (6-digit date + 4-char base36 random suffix). This eliminates sequential allocation entirely -- each ticket gets a unique ID derived from timestamp + randomness, with no shared state required.

Additionally, enforce the "DIA-NNN 'slug'" mention format in orchestrator dispatch payloads and review output (per DIA-074/DIA-229 conventions). The current bare-ID references are opaque to the developer.

**Scope:**

- `scripts/tickets` -- ID generation logic (max+1 -> datetime+random)
- `delegation-observer.ts` -- ticket ID parsing/validation if hardcoded to sequential
- `AGENTS.md` -- mention format enforcement in dispatch conventions

**Grandfather policy:** Existing tickets (DIA-001 through DIA-231) keep their sequential IDs. No migration. The new format applies to tickets created after implementation.

## Verification

1. `scripts/tickets new "test ticket" --area scripts --severity Minor` produces `DIA-YYMMDD-XXXX` format
2. Two rapid `scripts/tickets new` calls produce distinct IDs (no collision)
3. `make test-config` passes (ticket validation accepts new format)
4. Existing sequential tickets still parse correctly in README index

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
