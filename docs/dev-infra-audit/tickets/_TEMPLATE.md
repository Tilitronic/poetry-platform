# DIA-XXX — <Title>

<!-- Copy this template to a new file `DIA-<NNN>.md` and replace placeholders.
     Keep the YAML frontmatter block intact. Statuses VALIDATE and E2E (added
     2026-08-04, ticket-vocabulary drift fix) are audit-phase statuses — used
     while the gate-matrix validation / Docker+browser end-to-end runs are
     pending or in progress; they transition to fix-lane states via Fix →
     Re-verify. -->
<!-- GRANDFATHERED: DIA-001 through DIA-049 use v1 schema (no session fields).
     Session-attribution fields are OPTIONAL for all tickets. New tickets SHOULD
     populate them; existing tickets are not retroactively updated. -->

---

id: DIA-XXX
title: "<short title>"
area: <docker | opencode-config | js-tooling | git-hooks | python-tooling | scripts | docs | secrets | env | tests-infra | ci | deps>
severity: <Blocker | Critical | Major | Medium | Minor | Info>
status: <OPEN | VALIDATE | E2E | DEFERRED | MONITOR | FIXED | IMPLEMENTED | VERIFIED | CLOSED | BLOCKED | DISPATCHED | RUNNING | COMPLETE> # VALIDATE/E2E added 2026-08-04 (audit-phase statuses; ticket-vocabulary drift fix); DISPATCHED/RUNNING/COMPLETE added 2026-08-04 (v2 delegation lifecycle, set by delegation-observer plugin at delegation time)
blocked_by: [] # DIA-NNN refs, or empty
discovered:
source: <inventory | baseline | test-lane | fix-lane>
date: YYYY-MM-DD
created: YYYY-MM-DD
updated: YYYY-MM-DD

# --- Session Attribution (v2 schema, optional — GRANDFATHERED for DIA-001..049) ---

session_id: "" # OpenCode session ID that owned this ticket
lane_id: "" # e.g. cod-1, ai--3
agent: "" # agent name (coder, reviewer, etc.)
model: "" # model ID used
parent_session_id: "" # orchestrator's session ID (populated via get-my-session-id tool)
attempts: 0 # how many delegations attempted
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: [] # list of file paths modified
artifacts: [] # list of artifact references (commits, test outputs)
evidence: [] # list of evidence URIs (messages.md#row, registry.jsonl#seq)

---

## Description

<What is wrong. Reference exact files and line refs where known. Why it matters
(impact on gates, clean-cycle, or daily dev loop).>

## Verification

<How to test the defect exists / how to prove the fix. Concrete commands, gates
to run, files to inspect.>

## Fix

<What changed — fill at fix time. Leave blank with this note until then.>

> To be filled at fix time.

## Re-verify

<Result of re-running Verification after the fix — fill at re-verify time.
Must include the actual gate output/exit code that proves VERIFIED.>

> To be filled at re-verify time.
