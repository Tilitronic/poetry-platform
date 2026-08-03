# Tasks: dia-redispatch-cycle

> **Proposal:** `openspec/changes/dia-redispatch-cycle/proposal.md`
> **Design:** `openspec/changes/dia-redispatch-cycle/design.md`
> **Interview:** `openspec/changes/dia-redispatch-cycle/interview.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice. This is a docs/process change — tasks produce documentation artifacts and verification fixtures, not application code.

## Dependency graph

```
T1 (spec-infra scaffold: .sdd seed + HANDOFF template)
 ├──▶ T2 (messages.md schema fixture + T5 row examples + VP-6)
 ├──▶ T3 (crisis drill scenarios: VP-2 — all 5 triggers)
 │     │
 │     └──▶ T4 (budget accounting edge cases + batch-approval sim: VP-4 + VP-3)
 │           │
 │           └──▶ T5 (clean-termination independence verification: VP-5)
 │                 │
 └─────────────────┴──▶ T6 (integration end-to-end: VP-7 + VP-1 + final validation)
```

**Critical path:** T1 → T3 → T4 → T5 → T6
**Parallel track:** T2 can run in parallel with T3 (both depend only on T1), but T6 requires both T2 and T5.

**Rationale for ordering:** T1 produces the foundational artifacts (.sdd ADRs + HANDOFF template) that all other tasks reference. T3 produces crisis trigger definitions that T4's budget scenarios depend on. T5 requires both crisis triggers (T3) and exit states (T4). T6 is the integration slice that requires all prior tasks. T2 is schema-focused and can proceed independently, but the final integration (T6) needs it.

---

## T1 — Spec-infra scaffold: .sdd seed + HANDOFF template

**Blockers:** none
**Vertical slice:** create the design-authority foundation (.sdd ADRs) and the HANDOFF.md template that all subsequent cycles will fill in. Produces the two core structural artifacts.

### What changes

1. **`.sdd/dia-redispatch-cycle/architecture.md`** (new file):
   - Contains the 5 ADRs from design.md §12 (ADR-001 through ADR-005).
   - Each ADR has: title, decision, rationale, consequence (as defined in design.md).
   - Header: `# Architecture: dia-redispatch-cycle` with metadata (created date, status: seeded, parent: architecture.md).
   - Reference to interview.md Q5 as the decision source.

2. **`openspec/templates/HANDOFF.md`** (new file):
   - A template file matching the schema in design.md §3.
   - Contains placeholder sections for each subsection: `## Session summary`, `## Fixes applied`, `## Open tickets`, `## Verification request`, `## Resume instructions`.
   - Each section has field tables with type/required/description columns (matching §3.1–§3.5).
   - Example values in comments to guide the session author.
   - This is the template that the outgoing session fills in at cycle end.

3. **`openspec/templates/T5-row.md`** (new file):
   - Reference document showing the T5 row schema from design.md §5.
   - Includes an example filled-in row for a hypothetical task.

### Acceptance criteria (user perspective)

- `.sdd/dia-redispatch-cycle/architecture.md` exists and contains all 5 ADRs with titles, decisions, rationales, and consequences.
- Each ADR's decision matches the locked decision from interview.md Q5.
- `openspec/templates/HANDOFF.md` exists and contains all 5 subsections with field tables.
- The HANDOFF.md template's `exit_state` enum matches the exit states table in design.md §7.
- `openspec/templates/T5-row.md` exists and contains the column definitions from design.md §5.

### Verification procedure

- **VP-1 (partial):** Manual review — read `.sdd/dia-redispatch-cycle/architecture.md` and verify each ADR's decision matches interview.md Q5. Verify HANDOFF.md template has all required sections and field types.
- **Schema cross-check:** Verify that `exit_state` values in HANDOFF.md template (`clean`, `crisis`, `exhausted`, `manual-halt`) match the exit states table in design.md §7.

### Testing

- No automated tests (documentation artifact). Verification is manual review per VP-1.
- Traceability: every ADR references interview.md Q5.

---

## T2 — messages.md schema fixture + T5 row examples + VP-6 backward compatibility

**Blockers:** T1
**Vertical slice:** produce a concrete messages.md fixture showing both old-format (5-column) and new-format (9-column) rows, with a backward-compatibility verification scenario. This makes the schema extension tangible and testable.

### What changes

1. **`openspec/changes/dia-redispatch-cycle/fixtures/messages-example.md`** (new file):
   - A concrete example messages.md file demonstrating both formats.
   - **Section 1: Legacy rows (5-column).** At least 3 rows showing the pre-cycle format: `timestamp | sender | recipient | channel | content_ref`. These rows have no cycle_id, no evidence, no prognosis_ref, no resolution_status.
   - **Section 2: New-format rows (9-column).** At least 5 rows showing the extended format with all columns:
     - One row with `cycle_id` set and `evidence` populated (e.g., a crisis trigger message).
     - One row with `cycle_id` set and `prognosis_ref` set (e.g., a handoff message).
     - One row with `resolution_status: "resolved"`.
     - One row with `resolution_status: "deferred"`.
     - One row with nullable columns explicitly set to `null` (showing the explicit-null convention).
   - Each row is a Markdown table row (pipe-delimited).

2. **`openspec/changes/dia-redispatch-cycle/fixtures/t5-row-examples.md`** (new file):
   - At least 3 example T5 rows showing different states:
     - A completed task with cycle attribution.
     - An in-progress task mid-cycle.
     - A blocked task with blocker references.
   - Each row uses the column format from design.md §5.

3. **VP-6 backward-compatibility scenario document:**
   - Embedded in `fixtures/messages-example.md` as a "Verification" section at the end.
   - States the test: "Parse the legacy rows above using the 9-column schema. Verify that columns 6–9 default to null for each legacy row."
   - States the expected result: "All legacy rows parse successfully. `cycle_id` = null, `evidence` = null, `prognosis_ref` = null, `resolution_status` = null."

### Acceptance criteria (user perspective)

- `fixtures/messages-example.md` contains both legacy and new-format rows.
- Legacy rows have exactly 5 columns; new-format rows have exactly 9 columns.
- Nullable columns in new-format rows are either populated or explicitly set to `null`.
- `fixtures/t5-row-examples.md` contains example rows in the T5 schema format.
- VP-6 scenario is documented with expected results.
- A developer reading the fixtures can immediately understand the schema evolution.

### Verification procedure

- **VP-6:** Parse each legacy row with the 9-column schema. Confirm columns 6–9 default to null. Parse each new-format row and confirm all 9 columns are present.

### Testing

- No automated tests. Verification is the VP-6 manual parse exercise.
- The fixture file itself serves as living documentation of the schema format.

---

## T3 — Crisis drill scenarios (VP-2: all 5 triggers)

**Blockers:** T1
**Vertical slice:** produce concrete crisis-drill scenarios for each of the 5 triggers (C1–C5), with synthetic data that exercises the rule text from design.md §1. Each scenario has a setup, the expected trigger behavior, and the expected outcome.

### What changes

1. **`openspec/changes/dia-redispatch-cycle/fixtures/crisis-drills.md`** (new file):
   - Contains 5 drill scenarios, one per trigger:

   **Drill C1 — Same-task failure loop:**
   - Setup: T2 attempted in cycle 1, fails. T2 attempted in cycle 2, fails. T2 attempted in cycle 2 again, fails (3rd consecutive failure on T2).
   - Expected: C1 fires after the 3rd failure. Counter is per-task, not per-cycle.
   - Evidence: T5 row shows `attempts: 3` for T2.

   **Drill C2 — Re-plan churn:**
   - Setup: Cycle 1 starts with design.md v1. After initial implementation attempt, design.md rewritten to v2 (re-plan 1). After further issues, design.md rewritten to v3 (re-plan 2).
   - Expected: C2 fires after the 2nd rewrite. Cycle halted.
   - Evidence: messages.md contains 2 entries with `channel: "re-plan"`.

   **Drill C3 — Tool-call stagnation:**
   - Setup: 5 consecutive tool calls (read, grep, glob, read, ast_grep_search) with no file writes, no test status changes, no git diff.
   - Expected: C3 fires after the 5th call. The reads-only sequence produces no state change.
   - Counter-example: 4 reads followed by 1 write → C3 does NOT fire (state changed).

   **Drill C4 — Context overflow:**
   - Setup (hard): Model reports token limit hit, output truncated mid-sentence.
   - Expected (hard): C4 fires immediately.
   - Setup (soft): Context rerun at ≥50% but no truncation.
   - Expected (soft): C4 flagged but does NOT fire. Only hard overflow triggers C4.

   **Drill C5 — Prognosis debt:**
   - Setup: Cycle 1 HANDOFF.md contains `OT-001` with `blocking: true`. Cycle 2's batch-approval review does not address OT-001 (neither resolves nor defers with rationale).
   - Expected: C5 fires at the start of cycle 3 (not cycle 2 — cycle 2 had the opportunity to address it).
   - Counter-example: Cycle 2 explicitly defers OT-001 with rationale → C5 does NOT fire.

2. **Each drill includes:**
   - Setup (synthetic scenario data)
   - Expected trigger behavior (fires / does not fire, with reasoning)
   - Evidence (what messages.md / T5 rows / HANDOFF.md entries would look like)
   - Cross-reference to ADR-002 in `.sdd/dia-redispatch-cycle/architecture.md`

### Acceptance criteria (user perspective)

- All 5 drills are present in `fixtures/crisis-drills.md`.
- Each drill has setup, expected behavior, and evidence.
- Counter-examples are included where the trigger should NOT fire (C3 with a write, C4 soft case, C5 with explicit deferral).
- A developer reading the drills can verify the rule text is correct by mentally executing each scenario.

### Verification procedure

- **VP-2:** Execute each drill mentally. Verify the expected trigger behavior matches the rule text in design.md §1. Verify counter-examples do NOT fire.

### Testing

- No automated tests. Verification is the VP-2 mental execution exercise.
- The drills document serves as both verification and training material.

---

## T4 — Budget accounting edge cases + batch-approval simulation (VP-4 + VP-3)

**Blockers:** T1, T3
**Vertical slice:** produce budget accounting edge-case scenarios and a batch-approval boot protocol simulation. These test the protocol's operational mechanics.

### What changes

1. **`openspec/changes/dia-redispatch-cycle/fixtures/budget-edge-cases.md`** (new file):
   - Contains edge-case scenarios for budget accounting (design.md §7):

   **Edge case: max-cycles=2, clean exit on cycle 2**
   - Setup: Change with max-cycles=2. Cycle 1 completes T1, T2. Cycle 2 completes T3, T4 (all tasks done).
   - Expected: exit_state = `clean`. Change ready to archive. Budget counter = 2/2.

   **Edge case: max-cycles=3 (default), exhaustion on cycle 3**
   - Setup: Change with max-cycles=3 (default). Cycle 1: clean. Cycle 2: C1 crisis. Cycle 3: not clean, no more budget.
   - Expected: exit_state = `exhausted`. Postmortem ≤200 chars. NOT a crisis.

   **Edge case: override clamping — max-cycles=15**
   - Setup: Developer sets max-cycles=15.
   - Expected: Clamped to 10. Warning logged: "max-cycles=15 clamped to 10. Consider splitting the change."

   **Edge case: max-cycles=1**
   - Setup: Developer sets max-cycles=1.
   - Expected: Rejected. Error message: "max-cycles=1 disallowed. If you need only 1 cycle, the redispatch protocol is unnecessary. Use normal flow."

   **Edge case: ≥50% context rerun without termination**
   - Setup: Cycle 1 reruns 60% of its context but completes all tasks cleanly.
   - Expected: Budget NOT incremented (no full audit pass → no cycle consumed). Actually: budget IS incremented because the cycle terminated cleanly. The ≥50% rerun is tracked in messages.md evidence but does not affect budget counting separately. Correction: the cycle DID terminate (cleanly), so the budget increments. The ≥50% rerun is noted but is not itself a budget event.

   **Edge case: max-cycles=2, permitted**
   - Setup: Developer sets max-cycles=2.
   - Expected: Accepted. max-cycles=2 is explicitly permitted (edge case acknowledged in ADR-004).

2. **`openspec/changes/dia-redispatch-cycle/fixtures/batch-approval-simulation.md`** (new file):
   - A simulated batch-approval boot sequence (design.md §8):
   - **Predecessor HANDOFF.md:** Constructed with all 5 subsections populated for a hypothetical cycle end. Includes one `[BLOCKING]` open ticket.
   - **Boot sequence transcript:** Simulated interaction showing:
     1. Fresh session reads HANDOFF.md
     2. Presents session_summary for developer acknowledgment
     3. Presents fixes_applied for developer review
     4. Presents open_tickets — developer approves 2 of 3, defers 1
     5. Presents verification_request — developer approves
     6. Presents resume_instructions — developer approves
     7. Deferred ticket becomes a new open_ticket in the cycle's working set
   - **C5 check:** The simulation includes a check for whether the `[BLOCKING]` ticket from a PREVIOUS cycle was addressed. Since this is cycle 2 and the blocking ticket is from cycle 1, the simulation shows C5 does NOT fire (the ticket was addressed in this cycle's predecessor review).

### Acceptance criteria (user perspective)

- All 6 budget edge cases are present in `fixtures/budget-edge-cases.md`.
- Each edge case has setup, expected behavior, and reasoning.
- The batch-approval simulation in `fixtures/batch-approval-simulation.md` shows a complete boot sequence.
- The simulation demonstrates per-item approval (approve/defer/reject).
- The C5 check is demonstrated in the simulation.

### Verification procedure

- **VP-4:** Execute each budget edge case mentally. Verify the expected behavior matches the budget rules in design.md §7.
- **VP-3:** Execute the batch-approval simulation step by step. Verify each step matches the boot sequence in design.md §8.

### Testing

- No automated tests. Verification is VP-4 and VP-3 mental execution.

---

## T5 — Clean-termination independence verification (VP-5)

**Blockers:** T3, T4
**Vertical slice:** produce the independence guarantee verification scenario that demonstrates the clean-termination protocol structurally prevents self-certification.

### What changes

1. **`openspec/changes/dia-redispatch-cycle/fixtures/independence-verification.md`** (new file):
   - Contains the VP-5 verification scenario:

   **Scenario: Self-certification attempt**
   - Setup: Producer session completes all tasks and writes HANDOFF.md with exit_state = `clean` (tentative). In the `session_summary.summary_narrative`, the producer writes: "I verified all tests pass and the implementation is complete."
   - The verification_request section lists: "Run `make test` — expect all tests passing."
   - **Fresh session starts** (new context window, no access to producer's conversation history).
   - Fresh session reads HANDOFF.md.
   - Fresh session encounters the statement "I verified all tests pass."
   - **Expected behavior:** Fresh session treats "I verified" as an untrusted marker. It does NOT accept the producer's self-assessment. Instead, it independently runs `make test` and observes the actual output.
   - **Two sub-scenarios:**
     - Sub-scenario A: `make test` actually passes → fresh session writes `verification_result` confirming clean exit. exit_state confirmed as `clean`.
     - Sub-scenario B: `make test` fails (e.g., 2 tests failing) → fresh session writes `verification_result` with failure details. exit_state downgraded to `crisis`. Producer's self-certification is overridden.

   **Scenario: Untrusted marker detection**
   - Setup: Producer session writes in HANDOFF.md: "All verification complete. No further checks needed."
   - **Expected behavior:** Fresh session identifies "No further checks needed" as an untrusted marker (attempting to bypass verification). Fresh session proceeds with independent verification regardless.
   - The clean-termination protocol's rule "no self-certification" means the fresh session ALWAYS runs the verification_requests, regardless of what the producer session claims.

   **Structural enforcement analysis:**
   - Documents why the protocol makes self-certification structurally impossible:
     1. Fresh session has no access to producer's conversation history.
     2. Fresh session cannot see what the producer "knows" — only what's in HANDOFF.md and the working tree.
     3. The verification_requests are executed by the fresh session, not trusted from the producer's claims.
     4. If verification fails, the exit_state is downgraded regardless of producer's assertion.

2. **Clean-termination checklist** (embedded in the same file):
   - A checklist for the fresh session to follow:
     1. [ ] Read HANDOFF.md — verify all 5 subsections present
     2. [ ] Check exit_state — if `clean` (tentative), proceed to verification
     3. [ ] Identify untrusted markers — any claims of self-verification
     4. [ ] Execute each verification_request independently
     5. [ ] Record results in verification_result section
     6. [ ] If all pass → confirm exit_state = `clean`
     7. [ ] If any fail → downgrade exit_state to `crisis`, record failure details

### Acceptance criteria (user perspective)

- The independence verification scenario clearly demonstrates that self-certification is structurally prevented.
- The untrusted marker detection scenario shows that "no further checks needed" does not bypass verification.
- The clean-termination checklist is actionable — a fresh session can follow it step-by-step.
- Sub-scenarios A and B show both success and failure paths.

### Verification procedure

- **VP-5:** Execute the self-certification attempt scenario. Verify that:
  - The fresh session does not accept "I verified" as evidence.
  - The fresh session runs `make test` independently.
  - In sub-scenario B, the exit_state is downgraded despite the producer's claim.
  - Untrusted markers are identified and bypassed.

### Testing

- No automated tests. Verification is VP-5 mental execution.

---

## T6 — Integration end-to-end + final schema cross-check (VP-7 + VP-1)

**Blockers:** T2, T3, T4, T5
**Vertical slice:** end-to-end integration simulation of a 3-cycle change, plus final schema cross-check across all artifacts. This is the "does the whole protocol hang together?" task.

### What changes

1. **`openspec/changes/dia-redispatch-cycle/fixtures/integration-simulation.md`** (new file):
   - A complete end-to-end simulation of a 3-cycle change (default budget, max-cycles=3):

   **Cycle 1: Clean exit**
   - T1, T2 completed. HANDOFF.md produced with exit_state = `clean`.
   - Fresh session verifies: all tests pass, HANDOFF.md complete.
   - exit_state confirmed: `clean`.
   - Budget: 1/3 consumed.

   **Cycle 2: C1 crisis**
   - T3 attempted. Fails (attempt 1). Retried, fails (attempt 2). Retried, fails (attempt 3).
   - C1 fires (≥3 same-task failures on T3).
   - Cycle halted. Crisis HANDOFF.md produced with all 5 subsections, abbreviated in content (design.md §1 Option A): session_summary includes crisis_triggers; fixes_applied may be empty; open_tickets populated; verification_request/resume_instructions describe crisis-handling only.
   - Developer notified. Developer decides: start fresh cycle.
   - Budget: 2/3 consumed (crisis cycle counts against budget because a full HANDOFF.md was produced).

   **Cycle 3: Exhaustion**
   - T3 attempted again. Partial progress (attempt 4). Not completed by cycle end.
   - Budget reached (3/3). exit_state = `exhausted`.
   - Postmortem produced: ≤200 chars. Example: "T3 partially complete. Auth module scaffolded but OAuth flow untested. Recommend: extend budget to 4 or split T3 into sub-tasks."
   - NOT a crisis (ADR-005: soft exhaustion).
   - Developer decides: extend budget to 4 (max-cycles override from 3 to 4).

   - The simulation includes messages.md entries at each cycle transition (showing the 9-column format for cycle 2 and 3, 5-column format for cycle 1 if it predates the change — but since all cycles are post-change, all use 9-column format).
   - The simulation includes T5 rows updated at each cycle with cycle_id, cycle_number, attempts.

2. **VP-1 final schema cross-check:**
   - Embedded in the same file as a "Schema Cross-Check" section.
   - Cross-references all schemas for consistency:
     - HANDOFF.md template's `exit_state` enum ↔ design.md §7 exit states table ↔ integration simulation's exit_state values.
     - messages.md 9-column schema ↔ integration simulation's messages.md entries.
     - T5 row schema ↔ integration simulation's T5 rows.
     - Crisis triggers (design.md §1) ↔ crisis drills (T3) ↔ integration simulation's C1 event.
     - Budget rules (design.md §7) ↔ budget edge cases (T4) ↔ integration simulation's budget accounting.
     - ADR-002 (OR-combined) ↔ crisis drills ↔ integration simulation (only C1 fires, no multi-trigger).
     - ADR-005 (soft exhaustion) ↔ integration simulation's cycle 3 exit.

### Acceptance criteria (user perspective)

- The integration simulation runs a complete 3-cycle change from start to finish.
- Each cycle produces a HANDOFF.md, messages.md entries, and T5 row updates.
- The crisis is detected correctly (C1 on cycle 2).
- The exhaustion is handled correctly (cycle 3, soft exit, ≤200 char postmortem).
- The schema cross-check finds no contradictions between artifacts.
- A developer reading the simulation can understand the full protocol flow.

### Verification procedure

- **VP-7:** Execute the integration simulation step by step. Verify:
  - Cycle 1 exits cleanly, fresh session verifies.
  - Cycle 2's C1 trigger fires correctly (3rd failure on T3).
  - Cycle 3's exhaustion is handled per ADR-005.
  - Budget accounting is correct throughout (1/3 → 2/3 → 3/3).
  - HANDOFF.md, messages.md, and T5 rows are consistent.
- **VP-1 (final):** Execute the schema cross-check. Verify no contradictions.

### Testing

- No automated tests. Verification is VP-7 and VP-1 final.
- This is the last task — it's the "does it all hang together?" check.

---

## Implementation order (suggested)

1. **Start with T1** (spec-infra scaffold) — no blockers, produces the foundational artifacts. Create `.sdd/dia-redispatch-cycle/architecture.md` and HANDOFF.md template.
2. **Then T2 and T3 in parallel** (if two context windows available) — T2 produces the messages.md fixture, T3 produces the crisis drills. Both depend only on T1.
3. **Then T4** (budget + batch-approval) — depends on T3 (crisis triggers) and T1 (ADR refs).
4. **Then T5** (independence verification) — depends on T3 and T4.
5. **Finally T6** (integration + final cross-check) — depends on all prior tasks.

## Out of scope for these tasks

- Orchestrator prompt edits (Q1 — separate §10 change).
- Batch Interview Protocol implementation (Q3 — belongs in AGENTS.md §11).
- Ticket system (Q11 — separate change).
- Application code changes.
- Automated test suites (this is a documentation/process change; verification procedures are manual/simulated).
- Real cycle execution (the protocol is validated by simulation, not by running it on a real feature).

---

<!--
ownership:
  substance: AI
  structure: AI
  interview_depth: full
-->
