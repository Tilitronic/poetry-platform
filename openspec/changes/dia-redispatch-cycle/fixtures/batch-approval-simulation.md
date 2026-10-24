# Batch-Approval Boot Protocol — Simulation (VP-3)

> **Fixture:** `openspec/changes/dia-redispatch-cycle/fixtures/batch-approval-simulation.md`
> **Purpose:** simulated end-to-end execution of the batch-approval boot protocol
> (design.md §8): a fresh session boots from the predecessor cycle's HANDOFF.md,
> presents the prognosis as a batch for per-item developer approval, and only
> then begins work. Includes the C5 check.
> **Verification:** VP-3 — execute the simulation step by step and confirm each
> step matches the boot sequence in design.md §8.

---

## 1. Predecessor HANDOFF.md (cycle 1, exit_state: manual-halt)

Constructed with all 5 subsections populated (design.md §3). The predecessor is
a `manual-halt` exit — the developer deliberately stopped cycle 1 to review —
which keeps all 5 subsections populated while allowing an open `[BLOCKING]`
ticket without violating the NEXT-RUN §5 clean-cycle definition (a `clean` exit
must have no open blocking tickets).

### Session summary (abridged)

| Field             | Value                                                                                           |
| ----------------- | ----------------------------------------------------------------------------------------------- |
| cycle_id          | c-20260803-093012                                                                               |
| started_at        | 2026-08-03T09:30:12Z                                                                            |
| ended_at          | 2026-08-03T11:47:29Z                                                                            |
| exit_state        | manual-halt                                                                                     |
| tasks_completed   | ["T1"]                                                                                          |
| tasks_attempted   | ["T2"]                                                                                          |
| crisis_triggers   | []                                                                                              |
| summary_narrative | "T1 scaffold complete. T2 partially built; halted for developer review of the schema approach." |

### Fixes applied (abridged)

| file_path                                         | change_type | task_ref | test_status         |
| ------------------------------------------------- | ----------- | -------- | ------------------- |
| openspec/templates/HANDOFF.md                     | created     | T1       | no_tests_applicable |
| openspec/changes/.../fixtures/messages-example.md | created     | T2       | no_tests_applicable |

### Open tickets (abridged)

| ticket_id         | task_ref | title                      | blocking | next_step                                            |
| ----------------- | -------- | -------------------------- | -------- | ---------------------------------------------------- |
| OT-001 [BLOCKING] | T2       | New-format rows incomplete | true     | Add the 5 new-format rows to the messages.md fixture |
| OT-002            | T3       | Crisis drills drafted      | false    | Review drill C4 soft case wording                    |
| OT-003            | T4       | Budget edge cases          | false    | Write budget-edge-cases.md                           |

### Verification request (abridged)

| verification_id | what_to_verify                    | success_criteria                      | blocking |
| --------------- | --------------------------------- | ------------------------------------- | -------- |
| VR-001          | messages.md fixture column counts | legacy rows = 5 columns, new rows = 9 | true     |

### Resume instructions (abridged)

| step_number | instruction                                      | estimated_scope |
| ----------- | ------------------------------------------------ | --------------- |
| 1           | Approve this HANDOFF.md batch with the developer | trivial         |
| 2           | Complete OT-001 (new-format rows)                | small           |

---

## 2. Boot sequence transcript (cycle 2)

**Actor:** Fresh session (new context window; no access to cycle 1's conversation
history). Input: the predecessor HANDOFF.md above + the working tree.

1. **Read HANDOFF.md.** The fresh session reads `HANDOFF.md — Cycle
c-20260803-093012` and parses the "Prognosis for next cycle" section.
2. **Present session_summary.** Session: "Here's what the last cycle did:
   T1 scaffold complete, T2 partially built; cycle halted manually for review.
   Acknowledge?" Developer: **Approve.**
3. **Present fixes_applied.** Session: "Here's what was changed: HANDOFF.md
   template and the messages.md fixture were created. Review?" Developer:
   **Approve.**
4. **Present open_tickets.** Session: "Here's what's unfinished: OT-001
   [BLOCKING] (new-format rows), OT-002 (crisis drills wording), OT-003 (budget
   edge cases). Approve each ticket's next_step?" Developer: **approve OT-001,
   approve OT-002, defer OT-003.**
5. **Present verification_request.** Session: "Here's what needs verification:
   VR-001 — column-count check on the messages.md fixture. Approve the
   verification plan?" Developer: **Approve.**
6. **Present resume_instructions.** Session: "Here's the plan for this cycle:
   step 1 approve batch, step 2 complete OT-001. Approve?" Developer:
   **Approve.**
7. **Deferred ticket carries forward.** OT-003 (deferred) becomes a new
   open_ticket in cycle 2's working set: `OT-003 → cycle-2 working set`.

**Result:** All items approved (with OT-003 deferred per-item). Only now does
the session begin work — **no work before approval** (design.md §8 boot protocol
constraints).

---

## 3. C5 check (demonstrated)

**Check performed during step 3c (open_tickets review):** the session checks
whether any `[BLOCKING]` ticket from the predecessor's HANDOFF.md was already
supposed to be resolved (design.md §8: "If a blocking ticket was supposed to be
resolved in this cycle but wasn't, C5 fires (per §1)").

- The predecessor (cycle 1) HANDOFF.md contains `OT-001 [BLOCKING]`.
- During THIS cycle's (cycle 2's) batch-approval review, the developer approves
  OT-001's `next_step` — the blocking ticket **is addressed** in the predecessor
  review.
- **C5 does NOT fire.** Because the blocking ticket from cycle 1 was addressed in
  cycle 2's batch approval, there is no unresolved-for-1-full-cycle prognosis
  block. Per design.md §1, C5 fires only at the start of cycle N+2 when cycle
  N+1 failed to address the `[BLOCKING]` ticket.
- **Contrast:** had the cycle 2 review neither resolved nor deferred OT-001 with
  rationale, C5 would fire at the start of cycle 3.

---

## 4. Audit trail (messages.md entries)

Per design.md §8, the batch-approval interaction is recorded in messages.md — one
message per item, with `channel: "delegation"` and `resolution_status:
"acknowledged"` or `"deferred"` (9-column format).

| timestamp            | sender | recipient | channel    | content_ref                         | cycle_id          | evidence | prognosis_ref                   | resolution_status |
| -------------------- | ------ | --------- | ---------- | ----------------------------------- | ----------------- | -------- | ------------------------------- | ----------------- |
| 2026-08-03T12:00:01Z | coder  | developer | delegation | "session_summary acknowledged"      | c-20260803-113000 | null     | HANDOFF.md#session-summary      | acknowledged      |
| 2026-08-03T12:00:02Z | coder  | developer | delegation | "fixes_applied reviewed"            | c-20260803-113000 | null     | HANDOFF.md#fixes-applied        | acknowledged      |
| 2026-08-03T12:00:03Z | coder  | developer | delegation | "OT-001 next_step approved"         | c-20260803-113000 | null     | HANDOFF.md#open-tickets         | acknowledged      |
| 2026-08-03T12:00:04Z | coder  | developer | delegation | "OT-002 next_step approved"         | c-20260803-113000 | null     | HANDOFF.md#open-tickets         | acknowledged      |
| 2026-08-03T12:00:05Z | coder  | developer | delegation | "OT-003 deferred"                   | c-20260803-113000 | null     | HANDOFF.md#open-tickets         | deferred          |
| 2026-08-03T12:00:06Z | coder  | developer | delegation | "VR-001 verification plan approved" | c-20260803-113000 | null     | HANDOFF.md#verification-request | acknowledged      |
| 2026-08-03T12:00:07Z | coder  | developer | delegation | "resume_instructions approved"      | c-20260803-113000 | null     | HANDOFF.md#resume-instructions  | acknowledged      |
