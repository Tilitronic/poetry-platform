# Architecture: dia-redispatch-cycle

> **Created:** 2026-08-03
> **Status:** seeded
> **Parent:** `architecture.md` (root system architecture authority)
> **Module:** dia-redispatch-cycle (dev-infra campaign protocol)
> **Decision source:** `openspec/changes/dia-redispatch-cycle/interview.md` — Q5 (locked, amended: "ALL 5 ADRs CONFIRMED")
> **Governing design:** `openspec/changes/dia-redispatch-cycle/design.md` §12 (SDD traceability)

## Purpose

This document is the **design-authority seed** for the cycle-management protocol
(CRISIS-DETECTION, PROGNOSIS-DISCIPLINE, cycle-budget management). It records the
five architecture decisions (ADR-001 through ADR-005) that the rule texts in
`openspec/changes/dia-redispatch-cycle/design.md` must not contradict.

This is a **seed, not an expansion**: per interview Q9, no architecture escalation
was required for this change. The five ADRs below are the complete decision set
for this module. They are transcribed verbatim from design.md §12.

## Decision source — interview Q5

Every ADR below traces to the locked decision **Q5** in the change interview
(`openspec/changes/dia-redispatch-cycle/interview.md`, decision table, status:
Locked, amended): _"ALL 5 ADRs CONFIRMED: ADR-001 (prognosis in HANDOFF vs
PROGNOSIS.md), ADR-002 (C1–C5 OR-combined), ADR-003 (fresh-session independence),
ADR-004 (cycles budget default 3), ADR-005 (soft exhaustion)."_

| ADR     | Title                               | Q5 decision source               |
| ------- | ----------------------------------- | -------------------------------- |
| ADR-001 | Prognosis location: HANDOFF.md only | Q5 — confirmed (Locked, amended) |
| ADR-002 | C1–C5 OR-combined triggers          | Q5 — confirmed (Locked, amended) |
| ADR-003 | Fresh-session independence          | Q5 — confirmed (Locked, amended) |
| ADR-004 | Cycles budget default: max-cycles=3 | Q5 — confirmed (Locked, amended) |
| ADR-005 | Soft exhaustion                     | Q5 — confirmed (Locked, amended) |

---

## ADR-001: Prognosis location — HANDOFF.md only

**Decision:** The prognosis for the next cycle lives in HANDOFF.md's "Prognosis for next cycle" section, NOT in a separate PROGNOSIS.md file.

**Rationale:** One source of truth per cycle transition. Splitting prognosis into a separate file creates a synchronization problem (which file is authoritative?) and a discoverability problem (where do I look for the prognosis?). HANDOFF.md is already the cycle-transition document; the prognosis is a section of it, not a sibling.

**Consequence:** The HANDOFF.md schema (§3) includes the prognosis as folded subsections. No PROGNOSIS.md file is created or referenced.

---

## ADR-002: C1–C5 OR-combined triggers

**Decision:** Crisis is detected when ANY of C1–C5 fires (binary OR). No weighted scoring, no multi-trigger thresholds.

**Rationale:** Simple, debuggable, no hidden coupling between trigger conditions. If C1 and C3 both fire, the crisis is not "more severe" than if only C1 fires — it's just two triggers instead of one. The developer sees both and decides. Weighted scoring would introduce a hidden calibration problem (why is C1 worth 3 points but C3 worth 1?) that adds complexity without improving detection.

**Consequence:** The CRISIS-DETECTION rule text (§1) uses binary OR. Each trigger is independently evaluable.

---

## ADR-003: Fresh-session independence

**Decision:** Verification of cycle completion is structurally enforced via a FRESH session (separate context window). The session that produced the work cannot certify its own completion.

**Rationale:** Self-certification is a classic trust failure. A session that spent 4 hours on a task has cognitive incentive to declare it done. A fresh session has no such incentive — it evaluates the work on its merits (do tests pass? are files consistent? does the HANDOFF.md match reality?). Structural enforcement means the protocol makes self-certification impossible, not just discouraged.

**Consequence:** The clean-termination protocol (§9) requires a fresh session. No exceptions.

---

## ADR-004: Cycles budget default — max-cycles=3

**Decision:** Default budget is 3 cycles. Override range is 2..10 (clamped). 1 is disallowed. >10 requires change split.

**Rationale:** 3 is the empirical sweet spot — enough cycles for most complex features, not so many that the change becomes unbounded. 1 is disallowed because the redispatch protocol has overhead (HANDOFF.md, batch approval, verification) that's not justified for single-cycle work. >10 is a signal the change is too large and should be split. Clamping (rather than rejecting) overrides prevents accidents (setting max-cycles=1 by mistake gets clamped to 2 with a warning, not silently accepted).

**Consequence:** The budget rules (§7) enforce these constraints.

---

## ADR-005: Soft exhaustion

**Decision:** Budget exhaustion is a non-crisis exit state. Produces a ≤200-char postmortem. Does NOT trigger a C6 crisis trigger.

**Rationale:** Exhaustion is a planned boundary, not a failure. The developer set the budget; reaching it is expected behavior, not a crisis. Treating it as a crisis would create false alarms and incentivize budget inflation (set max-cycles=10 "just in case"). A concise postmortem (≤200 chars) forces honest summarization without bloating the HANDOFF.md.

**Consequence:** The exit states table (§7) lists `exhausted` separately from `crisis`. No C6 trigger exists.

---

## Traceability summary

| ADR     | Design.md section it governs               | Tasks that consume it                          |
| ------- | ------------------------------------------ | ---------------------------------------------- |
| ADR-001 | §2 PROGNOSIS-DISCIPLINE, §3 HANDOFF schema | T1 (HANDOFF.md template)                       |
| ADR-002 | §1 CRISIS-DETECTION rule text              | T3 (crisis drills), T6 (integration C1 event)  |
| ADR-003 | §9 Clean-termination protocol              | T5 (independence verification), T6 (cycle 1)   |
| ADR-004 | §7 Cycles budget                           | T4 (budget edge cases), T6 (budget accounting) |
| ADR-005 | §7 Exit states / exhaustion                | T4 (exhaustion edge case), T6 (cycle 3 exit)   |
