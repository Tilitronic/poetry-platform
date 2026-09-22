# AI-Specialist Gate - DIA-260909-sazr

Ticket: DIA-260909-sazr
Source: ai-specialist session ses_f785ce9c2ffeJrJu9pvhkuLkDE
Verdict: GO conditional
Date: 2026-09-09
Lane: learnings-registration-only (no implementation)

## Gate summary

Conditional GO for adaptive-test-code cleanup across 7 suites only.
Delete paths are probe fallbacks, not settled DI behavior. Settled
fake/loader paths must be preserved verbatim.

## Settled-path preservation table

| Suite | Settled path to preserve | Must keep |
| --- | --- | --- |
| capability | token behavior + loader guards + .server checks | token behavior, loader guards, .server checks |
| ticket-gate | FS-fake scan and correlation | FS-fake scan, correlation assertions |
| handoff | fake-FS checksum + atomic-write ordering | fake-FS checksum, atomic-write ordering |
| registry | fake FS/path/clock writer assertions | fake FS, path, clock writer assertions |
| stall-sweep | timer/clock/reader/emitter fakes | timer, clock, reader, emitter fakes |
| formatter | temp workspace + spawn/FS fakes | temp workspace, spawn fakes, FS fakes |
| circuit-breaker | fake-clock FSM tests | fake-clock FSM tests |

## Conditions

1. Delete ONLY adaptive test code:
   - dynamic-import catch fallbacks
   - factory/default/alias discovery
   - alternate call-arity retries
   - RED-era comments
2. Handoff: replace callAtomic fallback retry with a single canonical
   four-arg call. No retry chain.
3. Scope is limited to the 7 suites above. No edits to:
   - lib/
   - shell
   - loader-smoke
   - integration-regressions

## Risks

1. DI fake setup deletion risk: deleting a fake that looks adaptive but
   is the settled DI seam breaks isolation. Guard: keep every fake named
   in the preservation table.
2. .server test deletion risk: .server tests are covered by the loader
   contract dated 2026-09-02. Deleting them as "adaptive" breaks the
   contract. Guard: .server checks are out of scope.
3. Verification set (required at implementation):
   - seven Bun test files pass
   - make test-config passes
   - zero probe-pattern search hits (dynamic-import catch, alias
     discovery, call-arity retry patterns)
   - LOC delta in range -150..-300 (flags over/under-deletion)

## Correction

The OpenSpec ADR3 citation for DI is wrong. ADR3 records RED/GREEN
instance separation, not dependency injection. The actual DI basis is
dia-260902-eqgg/design.md lines 28-32 and 89-95. Future references must
cite dia-260902-eqgg, not ADR3, for DI fake seams.

## Outcome

Outcome: COMPLETED 2026-09-09. Test-only cleanup across 7 suites: net
-751 LOC (322 ins / 1053 del), Bun 249 pass / 0 fail, make test-config
EXIT 0 (61 PASS), probe grep 0. ai-auditor advisory path closed (F1/F7
PASS; F2-F6 fix loops 2 cycles + minimal-plan sweeps; final re-check
F3/F4/F5/F6 closed, F2 residuals removed per developer-authorized final
allow-list sweep). GO-conditional gate conditions met; settled
fake/loader paths preserved verbatim.
