# Interview: dia-redispatch-cycle

> **Change:** dia-redispatch-cycle
> **Session:** ope-13
> **Interview depth:** full (12 questions)
> **Phase 3 structured interview summary:** CONFIRMED by developer
> **Practice-protected §6 conditions:** both met — summary confirmed + explicit delegation of artifact drafting to AI

---

## Decision table — Q1–Q12 (authoritative reconciliation)

| ID  | Topic                                                          | Decision                                                                                                                                                                                                                                                                | Status           |
| --- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| Q1  | Orchestrator prompt edits (`boss_append`, system instructions) | **DEFERRED** — belongs to a separate §10 AI Devtools Modernization Workflow change. Not in scope for dia-redispatch-cycle.                                                                                                                                              | Locked           |
| Q2  | HANDOFF.md "Prognosis for next cycle" schema                   | **CONFIRMED** — five folded subsections: `session_summary`, `fixes_applied`, `open_tickets`, `verification_request`, `resume_instructions`.                                                                                                                             | Locked           |
| Q3  | Batch Interview Protocol location                              | **AGENTS.md §11** — general-scope workflow policy, lives OUTSIDE dia-redispatch-cycle scope. Note the location decision in design.md context but do NOT include in deliverables.                                                                                        | Locked (amended) |
| Q4  | messages.md backward compatibility                             | **NO MIGRATION** — leave existing 5-column rows as-is; new columns nullable; readers default missing `cycle_id` to null.                                                                                                                                                | Locked (amended) |
| Q5  | .sdd ADR seed                                                  | **ALL 5 ADRs CONFIRMED**: ADR-001 (prognosis in HANDOFF vs PROGNOSIS.md), ADR-002 (C1–C5 OR-combined), ADR-003 (fresh-session independence), ADR-004 (cycles budget default 3), ADR-005 (soft exhaustion).                                                              | Locked (amended) |
| Q6  | CRISIS-DETECTION rule text                                     | **CONFIRMED** — C1–C5 triggers, binary OR combined. See design.md for full rule text.                                                                                                                                                                                   | Locked           |
| Q7  | PROGNOSIS-DISCIPLINE rule text                                 | **CONFIRMED** — governs HANDOFF.md authoring discipline and cycle transition. See design.md for full rule text.                                                                                                                                                         | Locked           |
| Q8  | Cycle ID format                                                | **CONFIRMED** — `c-YYYYMMDD-HHMMss` UTC (e.g., `c-20260803-143025`). Generated at cycle start, immutable for duration of cycle.                                                                                                                                         | Locked           |
| Q9  | Cycles budget                                                  | **CONFIRMED** — default `max-cycles=3`; override range 2..10 (clamped); 1 disallowed (if you need only 1 cycle, you don't need a redispatch protocol); >10 requires splitting into multiple changes.                                                                    | Locked           |
| Q10 | Exit states                                                    | **CONFIRMED** — four states: `clean` / `crisis` / `exhausted` / `manual-halt`. `exhausted` = soft non-crisis (≤200 char postmortem, no C6 trigger). Budget independent of ≥50% context reruns (increments only on full audit pass). `max-cycles=2` edge case permitted. | Locked           |
| Q11 | Ticket system change                                           | **SEPARATE CHANGE** — dia-redispatch-cycle does NOT include ticket-system implementation. Mention as out-of-scope reference only.                                                                                                                                       | Locked           |
| Q12 | Fresh-session independence verification                        | **CONFIRMED** — structurally-enforced via FRESH session; NEXT-RUN §5 clean-cycle as positive exit; no self-certification; untrusted markers block SELF-RERUN.                                                                                                           | Locked           |

---

## Owner amendment decisions (post-summary)

After the Phase 3 structured interview summary was confirmed, the developer provided three amendment decisions:

### Q3 — Batch Interview Protocol location

**Decision:** The Batch Interview Protocol is a general-scope workflow policy that belongs in `AGENTS.md §11` (Research & Knowledge Workflow). It is NOT part of the dia-redispatch-cycle change's deliverables.

**Rationale:** The batch interview protocol governs how ALL interviews are conducted across the project, not just dia-redispatch-cycle. Placing it in a change-specific artifact would create a precedent for general policies living in scoped changes. AGENTS.md §11 is the correct home.

**Action:** Note the location decision in design.md's context section as a traceability reference. Do NOT include the batch interview protocol implementation in this change's deliverables, tasks, or acceptance criteria.

### Q4 — messages.md backward compatibility

**Decision:** No migration. Leave existing 5-column rows as-is. New columns (`cycle_id`, `evidence[]`, `prognosis_ref`, `resolution_status`) are nullable. Readers default missing `cycle_id` to null.

**Rationale:** A migration would require rewriting existing messages.md rows, which is a destructive operation on historical data with no functional benefit — old rows predate the cycle concept and carry no cycle information by definition. Nullable columns with a null-default convention are the standard backward-compatible schema evolution pattern.

**Action:** design.md specifies the 8-column schema with explicit nullable semantics. tasks.md includes a verification procedure that asserts old 5-column rows still parse correctly after the schema change.

### Q5 — .sdd ADR seed

**Decision:** All 5 ADRs confirmed as the seed for `.sdd/dia-redispatch-cycle/architecture.md`:

| ADR     | Title                               | Decision                                                                                                                                                                              |
| ------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ADR-001 | Prognosis location: HANDOFF.md only | Prognosis lives in HANDOFF.md's "Prognosis for next cycle" section, NOT in a separate PROGNOSIS.md file. One source of truth per cycle transition.                                    |
| ADR-002 | C1–C5 OR-combined triggers          | Crisis is detected when ANY of C1–C5 fires (binary OR). No weighted scoring, no multi-trigger thresholds. Simple, debuggable, no hidden coupling between trigger conditions.          |
| ADR-003 | Fresh-session independence          | Verification of cycle completion is structurally enforced via a FRESH session (separate context window). The session that produced the work cannot certify its own completion.        |
| ADR-004 | Cycles budget default: max-cycles=3 | Default budget is 3 cycles. Override range is 2..10 (clamped). 1 is disallowed (if you need only 1 cycle, the redispatch protocol is unnecessary). >10 requires splitting the change. |
| ADR-005 | Soft exhaustion                     | Budget exhaustion is a non-crisis exit state. Produces a ≤200-char postmortem. Does NOT trigger a C6 crisis. The developer decides whether to extend the budget or close the change.  |

---

## Phase 3 confirmation

The developer confirmed the Phase 3 structured interview summary and explicitly delegated artifact drafting to the AI (practice-protected §6):

- **Condition 1 (summary confirmed):** The decision table above reflects the locked Q1–Q12 decisions as reconciled in the orchestrator's prior brief. Developer confirmed accuracy.
- **Condition 2 (explicit delegation):** Developer message: "DELEGATED drafting of the openspec artifacts to you (practice-protected §6: substance: AI — both conditions met: summary confirmed + explicit delegation)."

**Ownership classification:** `substance: AI | structure: AI | interview_depth: full`

---

## Scope boundaries (confirmed)

This change is scoped to **dev-infra campaign protocol** — documentation, rule texts, schemas, and process definitions. It does NOT include:

| Out-of-scope item                               | Reason                                                                                                  |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Orchestrator prompt edits (Q1)                  | Deferred to §10 AI Devtools Modernization Workflow change                                               |
| Batch Interview Protocol implementation (Q3)    | Belongs in AGENTS.md §11 (general-scope workflow policy)                                                |
| Ticket system (Q11)                             | Separate change                                                                                         |
| Application code changes                        | This is a process/documentation change, not an application feature                                      |
| `.sdd/` module docs beyond the 5 confirmed ADRs | No architecture escalation needed (Q9); greenfield `.sdd/dia-redispatch-cycle/` is seeded, not expanded |

---

## Precedent reference

- **DIA-036** — session-continuity precedent from a prior project or methodology. Referenced in design.md for HANDOFF.md protocol design rationale.

---

<!--
ownership:
  substance: AI
  structure: AI
  interview_depth: full
-->
