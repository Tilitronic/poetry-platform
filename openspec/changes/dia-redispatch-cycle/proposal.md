# Proposal: dia-redispatch-cycle

> **Status:** proposed · **Scope:** dev-infra (campaign protocol — rule texts, schemas, handoff documents)
> **Escalation:** none — change is within existing module boundaries (per AGENTS.md §2.4, dev-infra changes do not require @architector). Greenfield `.sdd/dia-redispatch-cycle/` seeded with 5 ADRs per interview Q5.

## Motivation

AI-assisted development on this project uses long-running multi-session "cycles" to tackle complex features. Today, session transitions are ad hoc: the developer verbally summarizes what happened, the next session reads the code to reconstruct context, and there is no structured mechanism to detect when a cycle is stuck or failing. Three concrete problems result:

1. **Context loss on redispatch.** When a cycle transitions between sessions (context window exhaustion, model switch, developer-initiated restart), the successor session has no structured contract for what the predecessor accomplished, what remains, and what went wrong. The developer becomes the bridge — re-explaining, re-orienting, re-deciding — which is exactly the overhead the AI-assisted workflow should eliminate.

2. **Undetected crises.** Cycles can enter pathological states (repeated failures on the same task, architecture re-plans without convergence, tool-call loops that produce no state change, context overflow, unresolved prognosis blocks) without any structural signal. The developer notices only after burning significant time. A formal crisis-detection rule set would surface these states early and trigger intervention.

3. **No independence guarantee on completion claims.** When a session declares "I'm done," there is no structural enforcement that the claim is trustworthy. The same session that produced the work evaluates its own completion — a classic self-certification problem. Fresh-session independent verification would close this gap.

This change introduces three interlocking protocols — **CRISIS-DETECTION**, **PROGNOSIS-DISCIPLINE**, and **cycle-budget management** — to address all three problems as a coherent system. Together they define:

- **When** a cycle is in crisis (C1–C5 triggers, binary OR)
- **What** the outgoing session must produce for the next session (HANDOFF.md with "Prognosis for next cycle")
- **How** the incoming session boots (batch-approval protocol)
- **How** cycles terminate cleanly (fresh-session independent verification)
- **How many** cycles a change is allowed (budget with soft exhaustion)

## Scope

### In scope

1. **CRISIS-DETECTION rule text** — formal definition of five crisis triggers (C1: ≥3 same-task failures, C2: ≥2 architector re-plans, C3: ≥5 tool calls with no state change, C4: context overflow/truncation, C5: prognosis block unresolved for 1 cycle). Binary OR combination. See design.md for full rule text.
2. **PROGNOSIS-DISCIPLINE rule text** — formal definition of what the outgoing session must produce at cycle end: a HANDOFF.md containing the "Prognosis for next cycle" section with five folded subsections (session_summary, fixes_applied, open_tickets, verification_request, resume_instructions).
3. **HANDOFF.md schema** — the structural contract for the prognosis document, including the five subsections and their field requirements.
4. **messages.md schema extension** — 8-column row format (adding cycle_id, evidence[], prognosis_ref, resolution_status to existing 5 columns). Backward-compatible: existing rows unchanged, new columns nullable, no migration (interview Q4).
5. **T5 row schema** — extended task-tracking row with cycle attribution.
6. **Cycle ID format** — `c-YYYYMMDD-HHMMss` UTC, generated at cycle start, immutable for cycle duration.
7. **Cycles budget** — default `max-cycles=3`, override 2..10 (clamped), 1 disallowed, >10 requires change split. Four exit states: clean/crisis/exhausted/manual-halt. Soft exhaustion (≤200 char postmortem, no C6 trigger).
8. **Batch-approval boot protocol** — incoming session reads HANDOFF first, presents Prognosis as batch approval BEFORE delegation, developer approves per item.
9. **Clean-termination protocol** — structurally-enforced independent verification via FRESH session; NEXT-RUN §5 clean-cycle as positive exit; no self-certification; untrusted markers block SELF-RERUN.
10. **.sdd seed** — `.sdd/dia-redispatch-cycle/architecture.md` with 5 ADRs (ADR-001 through ADR-005 per interview Q5).

### Out of scope

- **Orchestrator prompt edits** (Q1) — deferred to a separate §10 AI Devtools Modernization Workflow change.
- **Batch Interview Protocol implementation** (Q3) — belongs in `AGENTS.md §11` (general-scope workflow policy). Noted in design.md context as a location decision.
- **Ticket system** (Q11) — separate change, referenced only as a consumer of T5 rows.
- **Application code changes** — this is a process/documentation change.
- **`.sdd/` module docs beyond the 5 confirmed ADRs** — no architecture escalation needed; the `.sdd/dia-redispatch-cycle/` directory is seeded, not expanded.

## Design authority (.sdd/) reference

**No existing `.sdd/` module docs govern this change.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer workflow protocols. Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation.

**However, this change seeds a new `.sdd/` directory** — `.sdd/dia-redispatch-cycle/architecture.md` — with 5 ADRs per interview Q5. This is the greenfield design authority for the cycle-management protocol. The 5 ADRs are:

- ADR-001: Prognosis in HANDOFF vs PROGNOSIS.md
- ADR-002: C1–C5 OR-combined triggers
- ADR-003: Fresh-session independence
- ADR-004: Cycles budget default 3
- ADR-005: Soft exhaustion

**Precedent reference:** DIA-036 session-continuity (referenced in design.md for HANDOFF.md protocol design rationale).

## Success criteria

1. A cycle in crisis is detected within one cycle transition (not after multiple wasted sessions).
2. The incoming session can reconstruct full context from HANDOFF.md alone, without developer re-explanation.
3. Completion claims are verified by a structurally independent session (no self-certification possible).
4. Budget exhaustion produces a graceful, non-crisis exit with a concise postmortem.
5. Existing messages.md rows (5-column format) remain valid and parseable after the schema extension.
6. The protocol is self-documenting: a developer reading the rule texts + schemas can operate the system without external guidance.

## Non-goals (what this change does NOT solve)

- Automated crisis recovery (the protocol detects; the developer decides response).
- Integration with any specific ticket/issue tracker (Q11 — separate change).
- Changes to the orchestrator's own prompt or system instructions (Q1 — separate §10 change).
- A general batch-interview protocol (Q3 — belongs in AGENTS.md §11).
- Cross-project cycle management (this protocol is scoped to poetry-platform).

## Stakeholders

| Stakeholder     | Interest                                                                                   |
| --------------- | ------------------------------------------------------------------------------------------ |
| Developer       | Reduced context-loss overhead; early crisis detection; trustworthy completion verification |
| @openspec-plan  | Produces HANDOFF.md at cycle end; consumes HANDOFF.md at cycle start                       |
| @coder          | Operates within the cycle budget; writes T5 rows with cycle attribution                    |
| @reviewer       | Evaluates against CRISIS-DETECTION + PROGNOSIS-DISCIPLINE compliance                       |
| @memory-manager | Persists ADRs and lessons from exhausted/cried cycles                                      |
| @architector    | Consulted if a crisis triggers re-plan (C2); not escalated for this change (Q9)            |

## Rollback plan

Every artifact added by this change is independently revertable:

| Artifact                                           | Revert                               |
| -------------------------------------------------- | ------------------------------------ |
| `.sdd/dia-redispatch-cycle/architecture.md`        | Delete file (and directory if empty) |
| HANDOFF.md schema documentation (in design.md)     | Revert design.md                     |
| messages.md schema extension (in design.md)        | Revert design.md                     |
| CRISIS-DETECTION + PROGNOSIS-DISCIPLINE rule texts | Revert design.md                     |
| Interview transcript                               | Delete interview.md                  |

No existing production code is modified. No data migrations (messages.md is backward-compatible per Q4). Rollback is file deletion / git checkout, with no side effects on running services.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is a **process/documentation change** — there is no application code to unit test. "Testing" here means **verification procedures**: structural checks that the schemas are valid, the rule texts are internally consistent, and the protocol can be executed end-to-end in a simulated scenario. A good verification procedure is one that would catch a schema typo, a contradictory rule, or a missing field before the protocol is used in a real cycle.

### Verification procedures (not automated tests)

1. **Schema validation** — HANDOFF.md schema and messages.md 8-column schema are validated for internal consistency (required fields present, nullable columns correctly marked, no contradictions between field definitions).
2. **Simulated crisis drills** — for each crisis trigger (C1, C3, C4+context), construct a synthetic scenario and verify the rule text correctly identifies it as a crisis. For C2 and C5, verify the threshold semantics.
3. **Redispatch flow simulation** — construct a HANDOFF.md for a hypothetical cycle end, then verify a "fresh session" (new context) can reconstruct context from it alone.
4. **Budget accounting** — verify that cycle counting, exhaustion detection, and the soft-exit postmortem work correctly for edge cases (max-cycles=2, max-cycles=10, override clamping).
5. **Independence guarantee** — verify that the clean-termination protocol structurally prevents self-certification (the session that produced the work cannot be the verifier).
6. **Backward compatibility** — verify that existing 5-column messages.md rows still parse correctly with the 8-column schema (new columns default to null).
7. **Integration** — end-to-end: a simulated 3-cycle change (default budget) that hits crisis on cycle 2, exhausts on cycle 3, and verifies the exhaustion postmortem is ≤200 chars and non-crisis.

### What we explicitly do NOT test

- Automated test suite (no application code to test).
- Orchestrator prompt behavior (Q1 — separate change).
- Ticket system integration (Q11 — separate change).
- Real cycle execution (the protocol is validated by simulation, not by running it on a real feature before the artifacts exist).

### Prior art in the codebase

- OpenSpec change artifacts: `openspec/changes/context7-docs-pipeline/` (established pattern for proposal/design/tasks).
- `.sdd/README.md` (design authority layer model — this change seeds the first module-level `.sdd/` doc).
- `AGENTS.md §2.4` (dev-infra change workflow — this change follows that pattern).
- `AGENTS.md §11` (Research & Knowledge Workflow — location decision for Batch Interview Protocol per Q3).

### Test risk and mitigation

**Risk:** The verification procedures are manual/simulated, not automated. A future developer could skip them. **Mitigation:** The verification procedures are embedded in the design.md and tasks.md as explicit acceptance criteria. The @reviewer pass checks that they were executed.

**Risk:** The protocol's rule texts could contain contradictions that simulation doesn't catch. **Mitigation:** The 5 ADRs in `.sdd/` provide a design-authority checkpoint — if a rule text contradicts an ADR, the contradiction is visible in the design authority layer.

---

<!--
ownership:
  substance: AI
  structure: AI
  interview_depth: full
-->
