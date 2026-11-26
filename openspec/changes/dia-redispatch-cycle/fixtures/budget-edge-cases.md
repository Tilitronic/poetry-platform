# Budget Accounting — Edge Cases (VP-4)

> **Fixture:** `openspec/changes/dia-redispatch-cycle/fixtures/budget-edge-cases.md`
> **Purpose:** edge-case scenarios for cycle-budget accounting (design.md §7,
> ADR-004 default max-cycles=3, ADR-005 soft exhaustion). Each edge case has a
> setup, expected behavior, and reasoning.
> **Verification:** VP-4 — execute each edge case mentally and confirm the
> expected behavior matches the budget rules.
> **Recording location (locked decision Q12 R12.2):** budget state (cycle
> current/max, clean-re-audit, budget-exhausted) is recorded in the cycle
> HANDOFF.md + the campaign trigger manifest — NOT in NEXT-RUN.md.

---

## Edge case 1 — max-cycles=2, clean exit on cycle 2

**Setup:** Change with `max-cycles=2`. Cycle 1 completes T1, T2. Cycle 2
completes T3, T4 (all tasks done).

**Expected:** `exit_state = clean`. Change ready to archive. Budget counter =
2/2 (two cycles consumed, both clean).

**Reasoning:** Clean exit requires all tasks completed or cancelled, no open
blocking tickets, all verification requests passed (NEXT-RUN §5 clean-cycle
definition, referenced by design.md §9). Both cycles terminated with complete
HANDOFF.md documents and fresh-session verification confirmed `clean`.

---

## Edge case 2 — max-cycles=3 (default), exhaustion on cycle 3

**Setup:** Change with `max-cycles=3` (default). Cycle 1: clean. Cycle 2: C1
crisis. Cycle 3: not clean, no more budget.

**Expected:** `exit_state = exhausted`. Postmortem ≤200 chars. **NOT a crisis**
(ADR-005: soft exhaustion — exhaustion is a planned boundary, not a failure).

**Reasoning:** Budget reached (3/3) without clean completion. Per design.md §7
exhaustion semantics: postmortem of ≤200 characters in
`session_summary.summary_narrative`; exit state is `exhausted`, NOT `crisis`; no
C6 trigger exists. The developer decides whether to extend the budget (if <10)
or split the change (if at 10).

---

## Edge case 3 — override clamping: max-cycles=15

**Setup:** Developer sets `max-cycles=15`.

**Expected:** Clamped to 10. Warning logged: "max-cycles=15 clamped to 10.
Consider splitting the change."

**Reasoning:** Override range is 2..10 (clamped) per ADR-004 and design.md §7.
Values above 10 are clamped, not rejected — clamping prevents accidents. The
warning directs the developer to the change-split path for work that genuinely
needs more than 10 cycles.

---

## Edge case 4 — max-cycles=1

**Setup:** Developer sets `max-cycles=1`.

**Expected:** Rejected. Error message: "max-cycles=1 disallowed. If you need only
1 cycle, the redispatch protocol is unnecessary. Use normal flow."

**Reasoning:** Per ADR-004 and design.md §7, `max-cycles = 1` is **disallowed**:
the redispatch protocol has overhead (HANDOFF.md, batch approval, verification)
that is not justified for single-cycle work. Unlike clamping, this is a hard
rejection with an explicit error message.

---

## Edge case 5 — ≥50% context rerun, cycle still terminates cleanly

**Setup:** Cycle 1 reruns 60% of its context but completes all tasks cleanly.

**Expected (final, per tasks.md correction):** Budget **IS incremented** (1/3).
The ≥50% rerun is tracked in messages.md evidence but does not itself alter
budget counting. The cycle DID terminate with a full audit pass, so the budget
increments.

**Reasoning:** Design.md §7 budget accounting: "The budget increments **only on
full audit pass** — a cycle that ends due to ≥50% context rerun does NOT
increment the budget counter unless a full audit pass was completed." A "full
audit pass" means the cycle produced a complete HANDOFF.md with all five
subsections and the successor acknowledged receipt via batch approval. Here the
cycle terminated cleanly (complete HANDOFF, all tasks done), so the full audit
pass occurred and the cycle consumed budget. The ≥50% rerun is a soft C4 signal —
flagged and tracked, but not itself a budget event.

**Contrast:** A mid-cycle SELF-RERUN that does NOT produce a complete HANDOFF.md
(no full audit pass) does NOT consume budget — the cycle did not terminate.

---

## Edge case 6 — max-cycles=2, permitted

**Setup:** Developer sets `max-cycles=2`.

**Expected:** Accepted. `max-cycles=2` is explicitly permitted (edge case
acknowledged in ADR-004).

**Reasoning:** The override range is 2..10; 2 is the lower clamp bound and is a
valid setting. Some changes are small enough for 2 cycles but still need the
protocol (design.md §7 budget rules: "max-cycles = 2: Permitted. Edge case
acknowledged — some changes are small enough for 2 cycles but need the
protocol."). No clamping, no warning, no rejection.

---

## Edge case 7 — Crisis cycle: does the budget increment?

**Setup:** Cycle 2 hits a C1 crisis (T3 fails ≥3 consecutive times). The cycle is
halted, a crisis HANDOFF.md is produced, and the developer decides to start a
fresh cycle.

**Expected:** Budget **IS incremented** (2/3 after cycle 2). The crisis cycle
consumes budget exactly like any other terminated cycle.

**Reasoning:** The crisis HANDOFF.md is produced with **all 5 subsections
populated, abbreviated in content** (design.md §1 crisis response — Option A:
session_summary includes crisis_triggers; fixes_applied may be empty; open_tickets
populated; verification_request and resume_instructions describe crisis-handling
only). Per design.md §7, "full audit pass" means the cycle produced a complete
HANDOFF.md with all five subsections populated and the successor acknowledged
receipt via batch approval — which holds for the crisis HANDOFF. The ≥50% context
rerun carve-out in §7 does not apply (that is a mid-cycle non-termination event);
a crisis is a termination with a full HANDOFF, so it counts.

---

## Edge case summary table

| #   | Scenario                            | Expected behavior                                                        | Design reference    |
| --- | ----------------------------------- | ------------------------------------------------------------------------ | ------------------- |
| 1   | max-cycles=2, clean on cycle 2      | `clean`, archive-ready, budget 2/2                                       | §7, §9, NEXT-RUN §5 |
| 2   | max-cycles=3, exhaustion on cycle 3 | `exhausted`, postmortem ≤200 chars, NOT crisis                           | §7, ADR-005         |
| 3   | max-cycles=15                       | Clamped to 10, warning logged                                            | §7, ADR-004         |
| 4   | max-cycles=1                        | Rejected, error message, normal flow                                     | §7, ADR-004         |
| 5   | ≥50% rerun, clean termination       | Budget incremented (full audit pass); rerun tracked, not a budget event  | §7                  |
| 6   | max-cycles=2                        | Accepted (permitted edge case)                                           | §7, ADR-004         |
| 7   | Crisis cycle (C1 fires)             | Budget incremented (crisis HANDOFF = full audit pass, all 5 subsections) | §1 (Option A), §7   |
