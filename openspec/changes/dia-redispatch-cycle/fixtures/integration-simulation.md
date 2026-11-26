# Integration End-to-End Simulation (VP-7 + VP-1 final)

> **Fixture:** `openspec/changes/dia-redispatch-cycle/fixtures/integration-simulation.md`
> **Purpose:** complete end-to-end simulation of a 3-cycle change (default budget,
> `max-cycles=3`): clean exit, C1 crisis, exhaustion. Demonstrates that the whole
> protocol hangs together — HANDOFF.md, messages.md, T5 rows, crisis detection,
> budget accounting, and the final schema cross-check (VP-1).
> **Verification:** VP-7 — execute the simulation step by step; VP-1 (final) —
> execute the schema cross-check and verify no contradictions.

> **Fixture scope (F5):** This file's "T3" is a HYPOTHETICAL application task
> (e.g., "auth module / OAuth flow") inside the simulated change — it is distinct
> from THIS change's real T3 (crisis drills). The simulation reuses the T-numbers
> as generic task slots for the 3-cycle change under test.

---

## Overview

| Cycle | Work performed           | Outcome            | Exit state  | Budget |
| ----- | ------------------------ | ------------------ | ----------- | ------ |
| 1     | T1, T2 completed         | All done, verified | `clean`     | 1/3    |
| 2     | T3 attempted ×3, fails   | C1 fires           | `crisis`    | 2/3    |
| 3     | T3 attempted (attempt 4) | Not complete       | `exhausted` | 3/3    |

---

## Cycle 1 — Clean exit

**Work:** T1, T2 completed. HANDOFF.md produced with `exit_state = clean`
(tentative), all 5 subsections populated, `crisis_triggers: []`.

**Fresh-session verification:** A fresh session (new context window) reads
HANDOFF.md, executes each `verification_request` independently (ADR-003 — no
self-certification). All pass. `verification_result` confirms; `exit_state`
confirmed: `clean`.

**Budget:** 1/3 consumed (cycle terminated with a full audit pass).

**T5 rows after cycle 1:**

| task_id | title          | status    | blockers | cycle_id          | cycle_number | attempts | last_exit_state |
| ------- | -------------- | --------- | -------- | ----------------- | ------------ | -------- | --------------- |
| T1      | Scaffold       | completed | []       | c-20260803-093012 | 1            | 1        | clean           |
| T2      | Schema fixture | completed | [T1]     | c-20260803-093012 | 1            | 1        | clean           |
| T3      | Auth module    | pending   | [T2]     | null              | null         | 0        | null            |

**messages.md (cycle 1, 9-column — post-change):**

| timestamp            | sender       | recipient    | channel    | content_ref                  | cycle_id          | evidence | prognosis_ref                       | resolution_status |
| -------------------- | ------------ | ------------ | ---------- | ---------------------------- | ----------------- | -------- | ----------------------------------- | ----------------- |
| 2026-08-03T09:30:12Z | orchestrator | coder        | delegation | "Cycle 1 boot approved"      | c-20260803-093012 | null     | null                                | acknowledged      |
| 2026-08-03T10:12:00Z | coder        | orchestrator | result     | "T1 done, T2 done"           | c-20260803-093012 | null     | null                                | resolved          |
| 2026-08-03T11:00:00Z | coder        | coder-next   | handoff    | "HANDOFF.md cycle 1 written" | c-20260803-093012 | null     | HANDOFF.md#prognosis-for-next-cycle | resolved          |

---

## Cycle 2 — C1 crisis

**Work:** T3 attempted. Fails (attempt 1). Retried, fails (attempt 2). Retried,
fails (attempt 3).

**Crisis detection:** C1 fires at the 3rd failure (≥3 consecutive same-task
failures on T3 — counter per-task, not per-cycle; ADR-002 OR-combined, only C1
fires, no multi-trigger). Cycle halted.

**Crisis HANDOFF.md produced** (all 5 subsections populated, abbreviated in
content per design.md §1 crisis response — Option A):

| Field           | Value                                                         |
| --------------- | ------------------------------------------------------------- |
| cycle_id        | c-20260803-143025                                             |
| exit_state      | crisis                                                        |
| tasks_attempted | ["T3"]                                                        |
| crisis_triggers | ["C1"]                                                        |
| open_tickets    | OT-001 [BLOCKING]: "T3: auth module — 3 consecutive failures" |

**Developer notified** with trigger identity (C1) and evidence (3 test_output
evidence objects). **Developer decides: start a fresh cycle.**

**Budget:** 2/3 consumed — the crisis cycle counts against budget because the
crisis HANDOFF was produced with all 5 subsections (full audit pass per design.md
§7: budget increments on full audit pass; consistent with §1 Option A: crisis
HANDOFF carries all 5 subsections, abbreviated in content).

**T5 rows after cycle 2:**

| task_id | title          | status      | blockers | cycle_id          | cycle_number | attempts | last_exit_state |
| ------- | -------------- | ----------- | -------- | ----------------- | ------------ | -------- | --------------- |
| T1      | Scaffold       | completed   | []       | c-20260803-093012 | 1            | 1        | clean           |
| T2      | Schema fixture | completed   | [T1]     | c-20260803-093012 | 1            | 1        | clean           |
| T3      | Auth module    | in_progress | [T2]     | c-20260803-143025 | 2            | 3        | crisis          |

**messages.md (cycle 2, 9-column):**

| timestamp            | sender       | recipient    | channel      | content_ref                                              | cycle_id          | evidence                                                                                                                     | prognosis_ref | resolution_status |
| -------------------- | ------------ | ------------ | ------------ | -------------------------------------------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------- | ------------- | ----------------- |
| 2026-08-03T14:45:10Z | coder        | orchestrator | crisis       | "C1 fired: T3 failed 3rd consecutive attempt"            | c-20260803-143025 | [{"type":"test_output","value":"tests/auth.spec.ts: 3 failures","produced_at":"2026-08-03T14:44:58Z","produced_by":"coder"}] | null          | open              |
| 2026-08-03T14:50:00Z | orchestrator | developer    | notification | "Crisis: C1 on T3. Decide: extend / fresh cycle / close" | c-20260803-143025 | null                                                                                                                         | null          | acknowledged      |
| 2026-08-03T15:00:00Z | developer    | orchestrator | decision     | "Start a fresh cycle"                                    | c-20260803-143025 | null                                                                                                                         | null          | resolved          |

---

## Cycle 3 — Exhaustion

**Work:** T3 attempted again. Partial progress (attempt 4). Not completed by
cycle end.

**Budget reached:** 3/3. `exit_state = exhausted`.

**Postmortem produced (≤200 chars), in `session_summary.summary_narrative`:**

> "T3 partially complete. Auth module scaffolded but OAuth flow untested.
> Recommend: extend budget to 4 or split T3 into sub-tasks."

**NOT a crisis** (ADR-005 soft exhaustion — exhaustion is a planned boundary).
No C6 trigger exists.

**Developer decides:** extend budget to 4 (`max-cycles` override from 3 to 4 —
permitted because 4 is within the 2..10 clamp range). A new cycle may start.

**T5 rows after cycle 3:**

| task_id | title          | status      | blockers | cycle_id          | cycle_number | attempts | last_exit_state |
| ------- | -------------- | ----------- | -------- | ----------------- | ------------ | -------- | --------------- |
| T1      | Scaffold       | completed   | []       | c-20260803-093012 | 1            | 1        | clean           |
| T2      | Schema fixture | completed   | [T1]     | c-20260803-093012 | 1            | 1        | clean           |
| T3      | Auth module    | in_progress | [T2]     | c-20260803-181500 | 3            | 4        | exhausted       |

**messages.md (cycle 3, 9-column):**

| timestamp            | sender       | recipient    | channel    | content_ref                                    | cycle_id          | evidence | prognosis_ref                       | resolution_status |
| -------------------- | ------------ | ------------ | ---------- | ---------------------------------------------- | ----------------- | -------- | ----------------------------------- | ----------------- |
| 2026-08-03T18:15:00Z | orchestrator | coder        | delegation | "Cycle 3 boot approved (budget extended to 4)" | c-20260803-181500 | null     | null                                | acknowledged      |
| 2026-08-03T19:40:00Z | coder        | orchestrator | result     | "T3 partial: scaffold done, OAuth untested"    | c-20260803-181500 | null     | null                                | open              |
| 2026-08-03T19:55:00Z | coder        | coder-next   | handoff    | "HANDOFF.md cycle 3 written — exhausted"       | c-20260803-181500 | null     | HANDOFF.md#prognosis-for-next-cycle | resolved          |

---

## Schema Cross-Check (VP-1 final)

Cross-references all schemas for consistency. No contradictions found:

| #   | Cross-check                                                                                                         | Result                                                                                                                                       |
| --- | ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | HANDOFF.md template `exit_state` enum ↔ design.md §7 exit states table ↔ integration simulation's exit_state values | PASS — template enum `clean/crisis/exhausted/manual-halt` matches §7; simulation uses `clean` (cyc 1), `crisis` (cyc 2), `exhausted` (cyc 3) |
| 2   | messages.md 9-column schema ↔ integration simulation's messages.md entries                                          | PASS — all simulation rows use 9 columns; nullable columns populated or explicitly `null`                                                    |
| 3   | T5 row schema ↔ integration simulation's T5 rows                                                                    | PASS — all rows carry task_id/title/status/blockers/cycle_id/cycle_number/attempts/last_exit_state per design.md §5                          |
| 4   | Crisis triggers (design.md §1) ↔ crisis drills (T3 fixture) ↔ integration simulation's C1 event                     | PASS — C1 threshold (≥3 same-task failures) consistent in rule text, drill, and cycle 2 event                                                |
| 5   | Budget rules (design.md §7) ↔ budget edge cases (T4 fixture) ↔ integration simulation's budget accounting           | PASS — 1/3 → 2/3 → 3/3; crisis cycle counts (full HANDOFF); exhaustion soft per ADR-005                                                      |
| 6   | ADR-002 (OR-combined) ↔ crisis drills ↔ integration simulation (only C1 fires, no multi-trigger)                    | PASS — cycle 2 fires only C1; drills test each trigger in isolation                                                                          |
| 7   | ADR-005 (soft exhaustion) ↔ integration simulation's cycle 3 exit                                                   | PASS — cycle 3 is `exhausted`, not `crisis`; postmortem ≤200 chars; no C6                                                                    |

---

## VP-7 execution summary

| Step | Verification                                                | Result                                                           |
| ---- | ----------------------------------------------------------- | ---------------------------------------------------------------- |
| 1    | Cycle 1 exits cleanly; fresh session verifies independently | PASS — clean HANDOFF, fresh-session verification, budget 1/3     |
| 2    | Cycle 2's C1 fires correctly (3rd failure on T3)            | PASS — C1 at attempt 3; cycle halted; crisis HANDOFF; budget 2/3 |
| 3    | Cycle 3's exhaustion handled per ADR-005                    | PASS — `exhausted`, postmortem ≤200 chars, NOT crisis            |
| 4    | Budget accounting correct throughout (1/3 → 2/3 → 3/3)      | PASS — matches design.md §7                                      |
| 5    | HANDOFF.md, messages.md, and T5 rows consistent             | PASS — cycle attribution aligns across all three artifacts       |
