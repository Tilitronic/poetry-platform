# Crisis Drills — C1–C5 Trigger Verification (VP-2)

> **Fixture:** `openspec/changes/dia-redispatch-cycle/fixtures/crisis-drills.md`
> **Purpose:** concrete synthetic scenarios that exercise each crisis trigger
> (design.md §1). Each drill has a setup, the expected trigger behavior (fires /
> does not fire), the evidence the protocol would record, and a cross-reference to
> ADR-002 (C1–C5 OR-combined triggers, `.sdd/dia-redispatch-cycle/architecture.md`).
> **Verification:** VP-2 — execute each drill mentally and confirm the expected
> trigger behavior matches the rule text.

> **Combination rule (ADR-002):** Triggers combine via binary OR — a single
> trigger is sufficient; there is no weighted scoring or multi-trigger threshold.
> Each drill below tests ONE trigger in isolation.
>
> **Crisis HANDOFF (design.md §1 crisis response, Option A):** when a trigger
> fires, the crisis HANDOFF.md is produced with **all 5 subsections populated,
> abbreviated in content** — `session_summary` includes the `crisis_triggers`
> (which is why the evidence below reads them out of `session_summary`, §3.1);
> `fixes_applied` may be empty; `open_tickets` is populated;
> `verification_request` and `resume_instructions` describe crisis-handling only.

---

## Drill C1 — Same-task failure loop

**Setup (synthetic):**

- Cycle 1: task T2 attempted, fails (attempt 1).
- Cycle 2: task T2 attempted, fails (attempt 2).
- Cycle 2 (continued): task T2 attempted again, fails (attempt 3) — 3rd
  consecutive failure on T2.

**Expected trigger behavior:** C1 **fires** after the 3rd failure. The counter is
per-task, not per-cycle — failures across cycles 1 and 2 accumulate on T2; the
counter resets only on success, not on cycle change (design.md §1 trigger
semantics). The cycle is halted; a crisis HANDOFF.md is produced; the developer
is notified with trigger identity (C1) and evidence.

**Evidence:**

- T5 row for T2 shows `attempts: 3` (design.md §5).
- Crisis HANDOFF.md lists `crisis_triggers: ["C1"]` in `session_summary`
  (design.md §3.1).
- messages.md contains the crisis message with `channel: "crisis"` and the
  evidence array (trigger data), 9-column format (design.md §4).

**Cross-reference:** ADR-002 — C1–C5 OR-combined triggers
(`.sdd/dia-redispatch-cycle/architecture.md`).

---

## Drill C2 — Re-plan churn

**Setup (synthetic):**

- Cycle 1 starts with `design.md` v1.
- After the initial implementation attempt, `design.md` is rewritten to v2
  (re-plan 1, via `openspec update-change`).
- After further issues, `design.md` is rewritten to v3 (re-plan 2).

**Expected trigger behavior:** C2 **fires** after the 2nd rewrite (re-plan 2).
The threshold is 2 substantive design.md rewrites within the same cycle — one
re-plan is a course correction, two is a signal the approach is unstable
(design.md §1). The cycle is halted. Minor edits (typo fixes) do not count as
re-plans.

**Evidence:**

- messages.md contains 2 entries with `channel: "re-plan"` (one per rewrite).
- Crisis HANDOFF.md lists `crisis_triggers: ["C2"]`.
- T5 row for the affected task records the crisis exit state.

**Cross-reference:** ADR-002 — C1–C5 OR-combined triggers
(`.sdd/dia-redispatch-cycle/architecture.md`).

---

## Drill C3 — Tool-call stagnation

**Setup (synthetic):**

- 5 consecutive tool calls: `read`, `grep`, `glob`, `read`, `ast_grep_search`.
- No file writes, no test status changes, no git diff across all 5 calls.

**Expected trigger behavior:** C3 **fires** after the 5th call. The reads-only
sequence produces no observable state change (git working tree unchanged AND no
test pass/fail change AND no new file created) — 5 consecutive state-less calls
meet the threshold (design.md §1).

**Counter-example:** 4 reads followed by 1 write → C3 does **NOT** fire — the
write is an observable state change that resets the stagnation sequence
(design.md §1: "Tool calls that only read do not count unless 5 consecutive reads
produce no subsequent write").

**Evidence:**

- messages.md records the stagnation window with `channel: "crisis"` (or the
  state-diff evidence attached to the trigger).
- Crisis HANDOFF.md lists `crisis_triggers: ["C3"]`.

**Cross-reference:** ADR-002 — C1–C5 OR-combined triggers
(`.sdd/dia-redispatch-cycle/architecture.md`).

---

## Drill C4 — Context overflow

**Setup (hard):**

- Model reports token limit hit; output is truncated mid-sentence.

**Expected (hard):** C4 **fires immediately**. Hard overflow is an actual
truncation / refusal-to-continue signal (design.md §1: "C4 fires on actual
truncation or hard overflow"). Cycle halted; crisis HANDOFF.md produced.

**Setup (soft):**

- Context rerun triggered at ≥50% (e.g., 60% rerun) but NO truncation occurs.

**Expected (soft):** C4 is **flagged but does NOT fire**. The ≥50% context rerun
is the soft signal — it is tracked in messages.md evidence, and budget counting
is unaffected unless the cycle terminates (design.md §7); only actual truncation
or hard overflow triggers C4. A soft rerun that still completes cleanly is not a
crisis.

**Evidence (hard):** messages.md `channel: "crisis"` with `log_excerpt` evidence
of truncation; crisis HANDOFF.md `crisis_triggers: ["C4"]`.
**Evidence (soft):** messages.md `channel: "log"` entry noting the ≥50% rerun
with `resolution_status: null`; no crisis HANDOFF produced.

**Cross-reference:** ADR-002 — C1–C5 OR-combined triggers
(`.sdd/dia-redispatch-cycle/architecture.md`).

---

## Drill C5 — Prognosis debt

**Setup (synthetic):**

- Cycle 1 HANDOFF.md contains `OT-001` with `blocking: true` (a `[BLOCKING]`
  open ticket).
- Cycle 2's batch-approval review does NOT address OT-001 — it neither resolves
  it nor defers it with rationale.

**Expected trigger behavior:** C5 **fires at the start of cycle 3** — not cycle 2.
Cycle 2 had the opportunity to address OT-001 during its batch approval; because
it did not, the prognosis block is "unresolved for 1 full cycle" and C5 fires at
the start of cycle N+2 (design.md §1 trigger semantics, design.md §8 C5 check).

**Counter-example:** Cycle 2 explicitly defers OT-001 with rationale → C5 does
**NOT** fire. Explicit deferral with rationale counts as "addressed" (design.md
§1: "either resolves or explicitly defers with rationale").

**Evidence:**

- Cycle 1 HANDOFF.md `open_tickets` row for `OT-001 [BLOCKING]` (design.md §3.3).
- Cycle 3 boot: messages.md records the C5 check result (`channel:
"delegation"`, `resolution_status: "blocked"`), and the cycle is halted at
  boot with `crisis_triggers: ["C5"]`.

**Cross-reference:** ADR-002 — C1–C5 OR-combined triggers
(`.sdd/dia-redispatch-cycle/architecture.md`).

---

## Drill summary table

| Drill | Trigger | Fires?            | Threshold                                                | Counter-example present |
| ----- | ------- | ----------------- | -------------------------------------------------------- | ----------------------- |
| C1    | C1      | Yes (3rd failure) | ≥3 consecutive failures on same task                     | —                       |
| C2    | C2      | Yes (2nd rewrite) | ≥2 substantive design.md rewrites/cycle                  | —                       |
| C3    | C3      | Yes (5th call)    | ≥5 tool calls, no state change                           | 4 reads + 1 write → no  |
| C4    | C4      | Yes (hard only)   | truncation / hard overflow; soft ≥50% rerun flagged only | soft rerun → no         |
| C5    | C5      | Yes (cycle N+2)   | `[BLOCKING]` ticket unresolved 1 full cycle              | explicit deferral → no  |
