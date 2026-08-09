# T5 Row Examples — Task Attribution Across Cycles

> **Fixture:** `openspec/changes/dia-redispatch-cycle/fixtures/t5-row-examples.md`
> **Purpose:** concrete example T5 rows (design.md §5) showing three states:
> completed, in-progress, and blocked — with cycle attribution, attempt counts
> (C1 tracking), and last exit state.
> **Schema reference:** `openspec/templates/T5-row.md`.

## Example rows

| task_id | title                      | status      | blockers | cycle_id          | cycle_number | attempts | last_exit_state |
| ------- | -------------------------- | ----------- | -------- | ----------------- | ------------ | -------- | --------------- |
| T1      | Spec-infra scaffold        | completed   | []       | c-20260803-093012 | 1            | 1        | clean           |
| T2      | messages.md schema fixture | in_progress | [T1]     | c-20260803-093012 | 1            | 1        | clean           |
| T3      | OAuth flow integration     | blocked     | [T2]     | c-20260803-143025 | 2            | 3        | crisis          |

Row-by-row reading:

1. **T1 — completed with cycle attribution.** Finished in cycle 1
   (`c-20260803-093012`, cycle_number 1) on the first attempt (`attempts: 1`).
   The cycle that last touched it exited `clean`. No blockers (`[]`).
2. **T2 — in-progress mid-cycle.** Started in cycle 1 after T1 completed
   (`blockers: [T1]`). Not yet done; `attempts: 1`; last touched by a `clean`
   cycle. Will continue in the next cycle.
3. **T3 — blocked with blocker references.** Depends on T2 (`blockers: [T2]`).
   Worked on in cycle 2 (`c-20260803-143025`, cycle_number 2) with 3 attempts —
   per design.md §1 this means **C1 fired** (≥3 consecutive same-task failures),
   and the cycle exited `crisis` (`last_exit_state: crisis`). The task remains
   `blocked` until T2 completes and the crisis is resolved.

## Consistency notes

- `cycle_id` / `cycle_number` / `attempts` are required on every post-change row
  (design.md §5).
- `attempts` is the C1 data source: it counts consecutive failures per task and
  resets only on success, not on cycle change (design.md §1 trigger semantics).
- `last_exit_state` is optional and mirrors the exit state of the most recent
  cycle that touched the task (`clean` / `crisis` / `exhausted` / `manual-halt`).
