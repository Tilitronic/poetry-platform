## Context

See proposal.md - Why. The ticket ledger has drifted from verifiable state. This design specifies the evidence-gathering methodology and triage-table structure for reconciliation.

## Goals / Non-Goals

**Goals:**

- Produce a grouped markdown triage table (CLOSE / UPDATE / KEEP OPEN / OBSOLETE / reverse-drift / ana026 gaps) with explicit evidence citations and test-status disclosure.
- Verify ana026 P0/P1 findings against current code/config to confirm whether risks remain active.
- Detect reverse-drift: tickets whose CLOSED status contradicts placeholder Fix/Re-verify sections.
- Present the triage table for developer approval before any ticket frontmatter edits.

**Non-Goals:**

- Editing implementation code.
- Modifying OpenSpec task checkboxes or archived change artifacts.
- Creating new tickets for ana026 gaps without explicit developer approval.
- Reconciling tickets created before August 2026 (out of scope per interview decision 1).
- Automated reconciliation (all recommendations require developer approval per practice-protected zone).

## Decisions

### D1: Three-source evidence model

**Decision**: Use git log, OpenSpec change state, and ana026 report verification as the three evidence sources.

**Rationale**: Each source covers a different completion signal:

- Git log: commit references to DIA IDs indicate implementation work was done.
- OpenSpec change state: archived changes with tasks.md checkboxes mapped to ticket Verification sections indicate spec-driven completion.
- ana026 report: external audit findings (P0/P1) may reveal risks not captured by ticket-level evidence.

**Alternatives considered**:

- Single-source (git log only): rejected -- misses spec-driven work and external audit gaps.
- Four-source (add test execution as a separate source): rejected -- test execution is already part of the test-status disclosure requirement, not a separate evidence tier.

### D2: Test-status disclosure as a hard constraint

**Decision**: Every CLOSE recommendation must cite green automated tests or explicitly state "no tests exist" / "tests not run". Never infer test status from file/commit evidence.

**Rationale**: Developer hard preference (interview decision 5). File/commit evidence does not prove tests pass; explicit disclosure prevents false confidence.

**Alternatives considered**:

- Infer test status from commit messages (e.g., "added tests"): rejected -- commit messages are not evidence of green tests.
- Skip test-status disclosure: rejected -- violates developer constraint.

### D3: Reverse-drift detection as a separate category

**Decision**: Tickets whose CLOSED status contradicts placeholder Fix/Re-verify sections are flagged as "reverse-drift" in a separate informational table, not mixed with the main triage categories.

**Rationale**: Reverse-drift is a status/evidence contradiction, not a completion signal. Mixing it with CLOSE/UPDATE/KEEP OPEN would conflate "ticket is done" with "ticket status is wrong".

**Alternatives considered**:

- Merge reverse-drift into UPDATE category: rejected -- reverse-drift requires re-open or evidence audit, not just status refresh.
- Ignore reverse-drift: rejected -- contradicts the reconciliation goal of aligning status with evidence.

### D4: ana026 gap analysis without auto-creation

**Decision**: ana026 P0/P1 findings with no corresponding OPEN ticket are flagged as "recommend new ticket" in a separate table, but no tickets are created until developer approves.

**Rationale**: Practice-protected zone (AGENTS.md section 4) requires developer approval before creating new tickets. Auto-creation would bypass the gate.

**Alternatives considered**:

- Auto-create tickets for ana026 P0 gaps: rejected -- violates practice-protected zone.
- Skip ana026 gap analysis: rejected -- ana026 is the most recent external audit (2026-08-19) and may reveal critical gaps.

### D5: Evidence-gathering sequence

**Decision**: Gather evidence in this order: (1) list all August 2026 tickets, (2) for each ticket, query git log for commit references, (3) check OpenSpec change state, (4) verify ana026 P0/P1 findings against current code/config, (5) run relevant tests (if any), (6) compile triage table.

**Rationale**: Sequential dependency -- ticket list is needed before evidence gathering; ana026 verification is independent of ticket-level evidence but informs gap analysis.

**Alternatives considered**:

- Parallel evidence gathering: rejected -- git log and OpenSpec queries are fast; parallelization adds complexity without meaningful time savings.
- ana026 verification first: rejected -- ticket list is the primary scope; ana026 is a cross-reference.

## Risks / Trade-offs

**Risk**: Git log may not contain commit references for all completed work (e.g., work done in a branch that was squash-merged without DIA ID in the commit message).
→ **Mitigation**: Cross-reference with OpenSpec change state and ana026 findings. If a ticket has an archived OpenSpec change with tasks.md checkboxes mapped to Verification sections, treat that as evidence even without git log references.

**Risk**: ana026 P0/P1 findings may have been fixed after the report date (2026-08-19) without a corresponding ticket update.
→ **Mitigation**: Verify each P0/P1 finding against current code/config during evidence gathering. If the finding no longer exists, mark it as "ana026 finding resolved, no ticket needed" (informational only).

**Risk**: Test execution may fail for reasons unrelated to the ticket (e.g., environment drift, dependency issues).
→ **Mitigation**: If tests fail, disclose "tests not run" or "tests failed" in the triage table. Do not recommend CLOSE based on incomplete test evidence.

**Trade-off**: Bounded scope (August 2026 only) vs. full ledger audit.
→ **Rationale**: Full audit is unbounded and high-cost. August 2026 scope captures the most recent drift while keeping the reconciliation tractable. Pre-August tickets have had multiple reconciliation cycles and are lower priority.

**Trade-off**: Manual developer approval vs. automated reconciliation.
→ **Rationale**: Practice-protected zone requires developer approval before status changes. Automation would bypass the gate and violate AGENTS.md section 4.
