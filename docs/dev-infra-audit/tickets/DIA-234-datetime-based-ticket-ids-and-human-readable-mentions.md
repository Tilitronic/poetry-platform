# DIA-234 — Datetime-based ticket IDs (DIA-YYMMDD-XXXX) and human-readable mentions

---

id: DIA-234
title: "Datetime-based ticket IDs (DIA-YYMMDD-XXXX) and human-readable mentions"
area: scripts
severity: Major
status: DONE
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
updated: 2026-09-21

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

Implemented before close-out (verified present in working tree 2026-09-21):

- `scripts/allocate-id` (new): unified datetime ID generator, emits
  `DIA-YYMMDD-XXXX` (6-digit date + 4-char lowercase base36 suffix from
  /dev/urandom with PID/nanosecond mixing, loops until 4 chars accumulate).
- `scripts/tickets next_dia()`: delegates to `scripts/allocate-id`
  (no more max+1 scan); `num_of_file`, `cmd_frontier`, `blockers_of`,
  `find_ticket_file` all datetime-aware; dual-mode sort keeps the
  sequential block (numeric) before the datetime block (lexical).
- `cmd_new` validates `blocked-by` / `parent-epic` in both formats and
  keeps the 5-attempt file/README collision guard as a second net.
- Gate (`.opencode/plugins/lib/ticket-gate.ts` lines 103-105):
  `TICKET_ID_RE` / `_FIND` / `_FILENAME` accept both formats, case-folded.
- `scripts/__tests__/tickets.bats`: datetime-format, README-landing,
  blocked-by, parent-epic, frontier-sort, and rollup coverage.
- `AGENTS.md` documents the `DIA-NNN 'slug'` / `DIA-YYMMDD-XXXX 'slug'`
  mention format (prose convention, no mechanical check).

## Re-verify

2026-09-21 close-out run, all 4 ticket criteria PASS:

1. `scripts/tickets new "DIA-234 verify alpha" --area scripts --severity Minor`
   produced `DIA-260921-25nq-dia-234-verify-alpha.md` (DIA-YYMMDD-XXXX). PASS.
2. Second rapid create produced `DIA-260921-d0js-dia-234-verify-beta.md`;
   suffixes `25nq` vs `d0js` distinct, no collision. PASS.
   (Both probe tickets moved to `.scratch/dia-234-verify-probes/` and their
   README rows removed; `scripts/tickets rollup` recomputed counts.)
3. `make test-config` exit 0. PASS.
4. README index holds 150 sequential + 173 datetime rows; `tickets show DIA-045`
   and `tickets list` parse sequential tickets correctly. PASS.

Residuals (unchanged, accepted as-is): R1 stale max+1 comment
(`scripts/tickets` ~852-859, Low); R2 `[[ ]]` vs bash-3 header claim
(~717, Low); R3 gate suffix `[a-z0-9]+` lenient vs exactly-4 (~103-105, Low);
R4 mention rule prose-only (Info). No Critical/Major residuals.
