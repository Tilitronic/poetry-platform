# DIA-260825-lro1 - Release task idempotency reservation after failed dispatch

---

id: DIA-260825-lro1
title: "Release task idempotency reservation after failed dispatch"
area: opencode-config
severity: Blocker
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-211
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-25
source: fix-lane
date: 2026-08-25
created: 2026-08-25
updated: 2026-08-25

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

`adaptiveDispatch()` reserves the task idempotency hash before the universal
ticket and config-routing preflight gates run. When one of those gates rejects
the call, the reservation survives even though no child task was started. A
corrected retry with the same agent, description, prompt, and git HEAD is then
incorrectly blocked as an idempotent duplicate.

Make the reservation transactional: retain it after an accepted preflight, but
release it whenever a later local preflight gate rejects the dispatch. Cover the
missing-`ticket_id` path with a regression test that also proves real duplicates
remain blocked after an accepted retry.

## Verification

- [x] A missing-`ticket_id` dispatch is rejected by the DIA-217 gate.
- [x] The same dispatch succeeds after adding a valid `ticket_id`.
- [x] A subsequent identical accepted dispatch is still blocked as a duplicate.
- [x] The complete delegation-observer Bun test suite passes.
- [x] Restart OpenCode and complete a fresh runtime coder dispatch smoke test. (DONE 2026-08-25: plugin auto-reloaded post-commit 03a25e8; single registration confirmed via `opencode debug config`; live coder dispatch processed with no errors/reservation leaks; `make test-config` exit 0; observer suite 100 pass / 311 assertions. Phase 5 closed.)

## Fix

`pendingAdaptiveDispatches` now retains the reserved hash and
`rollbackAdaptiveDispatch()` releases both the hash and pending-call record when
a later local preflight gate rejects the call. Rollback covers invalid
capability tokens, missing or malformed ticket IDs, config routing-order
violations, and unmatched explicit config-work tickets. A critical-health gate
failure also releases its reservation before propagating the error.

## Re-verify

- RED: focused DIA-217 test failed because the corrected retry received
  `Idempotent duplicate dispatch blocked` (5 pass, 1 fail).
- GREEN: focused DIA-217 tests pass (6 pass, 0 fail, 26 assertions).
- Regression: all delegation-observer Bun tests pass (100 pass, 0 fail, 311
  assertions).
- Config gate: `make test-config` passes (exit 0).
- Formatting: Prettier check passes for all four changed source/config files.
- Runtime config load: `opencode debug config` in the active OpenCodeDocker
  container exits 0 and resolves each auto-discovered local observer exactly
  once in the effective plugin array.

## Closure (2026-08-25)

- Scope discipline: a3mk ticket-ledger nits (Outstanding annotation + updated
  field) folded into lro1 commit 03a25e8 per developer approval 2026-08-25;
  ai-auditor scope-discipline finding accepted, risk recorded.
- Test-coverage residual risk: 4 of 5 rollback paths lack dedicated behavioral
  regressions; accepted per developer approval 2026-08-25 (shared rollback
  function, suite-wide coverage 100 pass).
- ai-auditor verdict: PASS WITH RESIDUAL RISK. Developer dispositions: scope
  finding ACCEPT + RECORD; Phase 5 smoke test PASSED; test-coverage residual
  risk ACCEPTED.
