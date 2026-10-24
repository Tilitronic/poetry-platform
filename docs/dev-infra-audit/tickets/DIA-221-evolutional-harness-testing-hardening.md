---
id: DIA-221
title: 'Evolutional harness infrastructure testing and hardening'
status: COMPLETE
priority: high
created: 2026-08-15
owner: orchestrator
tags: [harness, testing, hardening, orchestrator, meta-infra]
---

# DIA-221: Evolutional harness infrastructure testing and hardening

## Problem

The orchestration harness (delegation system, session management, agent routing,
verification gates, handoff protocol) has grown organically. There is no systematic
testing or hardening of the harness itself -- the system that manages the system.
Failures in the harness are silent (false-delegation incidents, truncated subagent
results, context overestimate leading to premature self-rerun) and only caught
retrospectively.

## Scope

Plan and implement evolutional testing/hardening workflows for the orchestrator
and its supporting infrastructure:

1. **Orchestrator workflow testing** -- formalize testable contracts for:
   - Batch-approval boot gate (DIA-061 checksum verification flow)
   - Handoff protocol (write -> present -> approve -> verify)
   - Delegation registry consistency (A3 retroactive check)
   - Truncated/empty result detection (DIA-099)
   - Self-rerun thresholds and context estimation accuracy (DIA-191)
   - Serialization points (A6 ordering guarantees)

2. **Agent routing hardening** -- test that:
   - Batch-dispatch rules (A1) are enforced
   - Instance separation (DIA-175) is maintained
   - Same-session fixes (DIA-175) resume correctly
   - Ticket-ID gate (DIA-063) blocks invalid dispatches
   - Escalation rules (3-failures, re-plan limit) fire correctly

3. **Verification gate testing** -- ensure:
   - Pre-handoff verification gate catches missing evidence
   - Exit state transitions (clean -> manual-halt -> crisis) are correct
   - Checksum verification detects tampering

4. **Evolutional improvement loop** -- establish a cycle:
   - Incident -> root cause -> hardening rule -> test -> regression prevention
   - Track harness incidents in a dedicated ledger
   - Measure harness reliability over time (false-delegation rate, silent-failure rate)

## Depends on

- DIA-182 (session-analytics.sh) -- provides observability surface
- DIA-191 (context_usage estimator) -- calibration data for self-rerun thresholds

## Acceptance criteria

- [x] Test harness contracts documented in `.sdd/harness-testing/architecture.md`
- [x] At least 5 regression tests for core orchestrator workflows
- [x] Incident ledger established (harness-incidents.md or similar)
- [x] One full evolution cycle demonstrated (incident -> fix -> test -> prevention)

## Notes

This is meta-infrastructure -- testing the system that manages the system.
Priority: HIGH. The harness is the single point of failure for all delegation.
