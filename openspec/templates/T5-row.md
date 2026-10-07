# T5 Row — Extended Task-Tracking Schema

> **Template:** `openspec/templates/T5-row.md` — reference for the T5 row format
> defined in design.md §5. T5 rows add cycle attribution to the standard task row
> in tasks.md. The `attempts` column is the data source for C1 (same-task failure
> loop) tracking: C1 fires when the same task reaches 3 consecutive failures
> (design.md §1, ADR-002).

## Column definitions (design.md §5)

| Column name     | Type     | Required | Description                                                                                                                              |
| --------------- | -------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| task_id         | string   | yes      | Task identifier (e.g., `T1`, `T2`)                                                                                                       |
| title           | string   | yes      | Short title                                                                                                                              |
| status          | enum     | yes      | One of: `pending`, `in_progress`, `completed`, `blocked`, `cancelled`                                                                    |
| blockers        | string[] | no       | List of task_ids that must complete before this task can start                                                                           |
| cycle_id        | string   | **yes**  | Cycle ID this task was worked on (`c-YYYYMMDD-HHMMss` UTC)                                                                               |
| cycle_number    | integer  | **yes**  | Sequential cycle number within this change (1-indexed)                                                                                   |
| attempts        | integer  | **yes**  | Number of attempts made on this task (for C1 tracking)                                                                                   |
| last_exit_state | enum     | no       | Exit state of the cycle that last touched this task. One of: `clean`, `crisis`, `exhausted`, `manual-halt` (mirrors design.md §3.1 / §7) |

## Example row (hypothetical task)

| task_id | title      | status      | blockers | cycle_id          | cycle_number | attempts | last_exit_state |
| ------- | ---------- | ----------- | -------- | ----------------- | ------------ | -------- | --------------- |
| T3      | OAuth flow | in_progress | [T2]     | c-20260803-143025 | 2            | 3        | crisis          |

<!-- This row reads: T3 (OAuth flow) is in progress, blocked on T2, worked on in
     cycle 2 (c-20260803-143025), 3 attempts so far. Per design.md §1, attempts=3
     on the same task means C1 fired (≥3 consecutive failures) and the cycle
     exited in `crisis` — consistent with `last_exit_state: crisis`. -->

## Usage notes

- One T5 row exists per task in tasks.md; the row is **updated** (not replaced)
  at the end of each cycle that touches the task.
- `cycle_id` / `cycle_number` / `attempts` are required once a task is worked on
  (post-change rows); `last_exit_state` is optional and records the exit state of
  the most recent cycle that touched the task.
- Example multi-row files (completed / in-progress / blocked) live in
  `openspec/changes/dia-redispatch-cycle/fixtures/t5-row-examples.md`.
