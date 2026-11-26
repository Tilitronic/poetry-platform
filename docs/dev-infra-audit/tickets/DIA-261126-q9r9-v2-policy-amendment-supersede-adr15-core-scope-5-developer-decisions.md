# DIA-261126-q9r9 - V2 policy amendment - supersede ADR15 core scope (5 developer decisions)

---

id: DIA-261126-q9r9
title: "V2 policy amendment - supersede ADR15 core scope (5 developer decisions)"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-11-26
source: inventory
date: 2026-11-26
created: 2026-11-26
updated: 2026-11-26

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

## DEVELOPER DECISIONS (binding, 2026-11-26)

1. HANDOFF: cancel the automatic plugin handoff contract (DIA-085 resolution chain, DIA-124 hard rule, DIA-061 checksum, DIA-093 lane-0 dispatch). Replace with two slash commands, make-handoff and read-handoff, writing and reading .opencode/session/handoffs/HANDOFF-<date>-<branch>.md. Per-session file naming replaces the single-file design so parallel worktrees do not clobber. Consequence: the Batch-Approval Boot Gate section is removed together with lib/handoff.ts and its tests in one commit.
2. WATCHDOG: keep a ~35-line permission-ask timeout watchdog. OpenCode v2 has no ask timeout, so unattended runs would hang forever without it. All other needs-input mechanisms (ticker, WinRT toast, session renaming, fast-resolve) are deleted.
3. ROSTER: delete council (agent block, 6 councillor-\* permissions, seat block, and the COUNCIL DELEGATION section of analyzer_append.md). Keep 13 operational lanes. Seat-model staleness to be confirmed by a separate verification lane before the prompt edit lands.
4. FETCH-SOURCE: keep fetch-source.ts and the 4-tier capture chain as is. Minimum source-archival requirement for the research pipeline is unchanged.
5. SECOND PRESET: keep both presets. Hoist the shared orchestrator prompt out of the two inline copies into one file so the drift gate stays satisfied at zero maintenance cost.
6. BASELINE GATE (open, developer-owned): make test-config must exit 0 and the four-step policies smoke test must run in poetry-dev-v2 on OpenCode 2.3.2 before any deletion. Claims of 78 pass currently conflict with a recorded exit 2 at the OMO version-sync step and must be resolved first.

## Re-verify

> To be filled at re-verify time.
