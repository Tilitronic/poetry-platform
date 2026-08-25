# DIA-260825-lro1 — Gate Research Findings (ai-specialist, §2.5 step 1)

- **Date:** 2026-08-25
- **Ticket:** DIA-260825-lro1 (release task idempotency reservation after failed dispatch)
- **Gate verdict:** VERIFICATION_RESULT YES — implementation matches ticket claims, test coverage adequate, no blocking risks.
- **Classification:** OpenCode config/plugin work (AGENTS.md §2.5). Lane = step 4 (implement/commit) after the gate.

## Pattern: transactional idempotency reservation

`adaptiveDispatch()` reserves the task idempotency hash in `idempotencyCache`
(keyed by `computeDispatchHash`) and records the call in
`pendingAdaptiveDispatches` (now carrying `idempotencyHash`). The reservation
must be **transactional**: retained after an accepted preflight, released when a
later local preflight gate rejects the call.

### Rollback-on-failure

`rollbackAdaptiveDispatch(callId)` releases BOTH the hash
(`idempotencyCache.delete(pending.idempotencyHash)`) and the pending-call
record (`pendingAdaptiveDispatches.delete(callId)`). It is invoked on every
rejection path after `adaptiveDispatch` succeeds:

1. Invalid capability token (§10 TICKET GATE)
2. Missing `ticket_id` field (DIA-217 gate)
3. Invalid `ticket_id` format (DIA-217 gate)
4. Config routing-order violation (ROUTING GATE, §2.5)
5. No correlating DIA ticket for §10 work (§10 TICKET GATE)

A **critical-health gate failure** also releases its reservation
(`idempotencyCache.delete(hash)`) before propagating the error — `hash` is in
scope at that point (computed earlier in the same dispatch function).

### Single-registration guard

Local observer plugins (`.opencode/plugins/delegation-observer.ts`,
`needs-input-observer.ts`) are auto-discovered by OpenCode. Explicitly listing
them in the project `plugin` array initialized a second copy of every hook and
duplicated lifecycle side effects. The fix removes the explicit entries from
`.opencode/opencode.jsonc`; `scripts/__tests__/batch-d-infra.test.mjs` (S7)
asserts they are NOT in the configured plugin array.

## Coverage notes

- Focused regression (`dia217-ticket-gate.test.mjs`): missing-`ticket_id`
  dispatch rejected; corrected retry with valid `ticket_id` succeeds; a
  subsequent identical accepted dispatch is still blocked as a duplicate.
- Full observer suite: 100 pass / 311 assertions. Config suite: 57 pass.
  `make test-config` exit 0. Prettier + `git diff --check` clean.
- `opencode debug config` resolves each auto-discovered local observer exactly
  once in the effective plugin array.
- **Coverage gap (noted, non-blocking):** the critical-health-gate release path
  has no dedicated unit test; it is exercised only indirectly. Recommend a
  focused test if the gate logic is later extended.

## Outcome

- **Status:** implemented + committed (03a25e8) + smoke test passed.
- **ai-auditor verdict:** PASS WITH RESIDUAL RISK.
- **Residual risks (accepted 2026-08-25):** (1) scope discipline - a3mk
  ticket-ledger nits folded into lro1 commit per developer approval; (2)
  test coverage - 4 of 5 rollback paths lack dedicated behavioral regressions
  (shared rollback function, suite-wide 100 pass).
- **Phase 5:** runtime coder-dispatch smoke test PASSED; ticket checkbox 5
  closed.
