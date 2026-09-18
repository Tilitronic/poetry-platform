# DIA-260822-m035 - Investigate OpenCode restart crash-storm alerts

---

id: DIA-260822-m035
title: "Investigate OpenCode restart crash-storm alerts"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-22
source: inventory
date: 2026-08-22
created: 2026-08-22
updated: 2026-09-10

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

STALE / CLOSED without code change. Read-only triage (cod-4) found all four root causes already mitigated by CLOSED fix tickets; F3 probe/oracle confirmed false-alarm terminology (restart crash-storm alerts were stale-boot emissions, not real crashes).

Evidence refs:

- DIA-260822-oldn 'Plugin reload boot/sweep dedup' CLOSED - timer dedup, lib/stall-sweep.ts:225-231 (30s persisted dedup, disposal-safe single ticker).
- DIA-260822-fksf 'Stale stall-sweep startup protection' CLOSED - boot cutoff, lib/stall-sweep.ts:196, stale-boot-sweep tests 5/5.
- DIA-260822-unsn 'Ticker expiry' CLOSED - TTL purge, needs-input-observer.ts:613-618 (purge invalid/stale waiting/error entries during seed/persist).
- DIA-260902-eqgg 'Refactor delegation-observer plugin' CLOSED - lib extraction (7 seam modules, SRP).

Triage session: cod-4 / ses_f7535e21effeFa3RMX4u0TEbop. No remaining action; close as STALE.

## Re-verify

> To be filled at re-verify time.
