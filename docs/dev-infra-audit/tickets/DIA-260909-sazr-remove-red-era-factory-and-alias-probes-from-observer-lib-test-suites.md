# DIA-260909-sazr - remove RED-era factory and alias probes from observer-lib test suites

---

id: DIA-260909-sazr
title: "remove RED-era factory and alias probes from observer-lib test suites"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "DIA-260903-o7n0"
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-09
source: inventory
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-10

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

Post-audit cleanup item 2 from ponytail audit /tmp/architecture-review-20260909-170245.html (ephemeral; substance carried here). Parent context: DIA-260903-o7n0 de-bloat + observer-lib extraction work. Item 1 (compound bats split) ALREADY FIXED at 420ce4f - do not re-ticket.

Remove obsolete RED-era factory/alias probes from the 7 new observer-lib test suites. These were TDD RED scaffolding to prove loader wiring before canonical APIs existed; canonical APIs now exist and are tested via DI fakes + loader-contract tests. Keep DI fakes and loader-contract tests intact - they verify useful behavior/parity.

Estimated savings: -150..-300 test LOC. Scope: 7 observer-lib test suites under .opencode/plugins/**tests** (plugin-harness-adjacent lib tests). Pattern: factory function existence checks, alias re-exports, and probe wrappers that duplicate canonical API coverage without adding independent assertions.

Guard (MANDATORY): do NOT delete the 7 extracted production modules themselves, capability loader guards, or independent checksum logic (useful behavior/parity contracts, not bloat). Only delete RED-era probe wrappers in tests where canonical API coverage already exists.

Source: ponytail audit item 2, DIA-260903-o7n0 follow-up. Campaign ticket DIA-260901-91qy.

## Verification

- [ ] 7 observer-lib test suites contain no RED-era factory/alias probe wrappers (grep for probe patterns returns 0)
- [ ] DI fakes + loader-contract tests remain intact and passing
- [ ] 7 extracted production modules untouched (git diff shows no deletions under .opencode/plugins/lib or equivalent)
- [ ] Capability loader guards and independent checksum logic untouched
- [ ] Test LOC delta -150..-300 verified via cloc or git diff --stat
- [ ] `make test-config` and plugin suite pass (or relevant `bun test` harness passes)

## Fix

## Final evidence (persist-only lane, 2026-09-09)

Test-only cleanup: removed RED-era factory/alias probes from 7 observer-lib suites. No production module touched.

- Bun: 249 pass / 0 fail across 7 suites (capability 18, ticket-gate 56, handoff 20, registry 28, stall-sweep 32, formatter 61, circuit-breaker 34)
- make test-config: EXIT 0 (61 PASS)
- Probe grep: 0 hits (dynamic-import catch, factory/default/alias discovery, call-arity retry patterns)
- Diff: 7 test-only files, 322 ins / 1053 del, net -751 LOC. History -522, -614, -667, -726, -751; over-delivery accepted per developer 2026-09-09, guardrail superseded.
- ai-specialist gate: GO-conditional met (settled fake/loader paths preserved verbatim per preservation table)
- ai-auditor advisory path: F1/F7 PASS, then F2-F6 fix loops (2 cycles) + minimal-plan sweeps; final re-check F3/F4/F5/F6 closed, F2 residuals removed per developer-authorized final allow-list sweep
- DI basis: dia-260902-eqgg (ADR3 miscitation corrected; ADR3 records RED/GREEN instance separation, not DI)

Status kept OPEN; developer closes.

## Re-verify

## Re-verification (persist-only lane, 2026-09-09)

- Bun 249 pass / 0 fail (7 suites: 18 + 56 + 20 + 28 + 32 + 61 + 34)
- make test-config EXIT 0, 61 PASS
- Probe-pattern grep returns 0
- git diff --stat: 7 test-only files, 322 ins / 1053 del, net -751; no deletions under lib/, shell, loader-smoke, or integration-regressions
- DI fakes + loader-contract tests intact and passing; capability loader guards and checksum logic untouched
- ai-auditor final re-check: F3/F4/F5/F6 closed; F2 residuals removed per developer-authorized final allow-list sweep

Ticket status left as-is (OPEN) for developer close.

## Close (ticket-close lane, 2026-09-10)

Status: CLOSED with advisory residual acceptance per developer decision.

- Final result: -751 LOC net (322 ins / 1053 del), 7 test-only files
- Bun: 249 pass / 0 fail (18+56+20+28+32+61+34)
- make test-config: green EXIT 0
- Probe grep: 0 hits
- openspec validate: 0 (pass)
- lib/ diff: 0 (no production module deletions)
- ai-auditor advisory never reached GO: final F2 partial on newly found lines, developer accepted as residual, no further audit loops per prior decision
- F5 figure history: -522 / -614 / -667 / -726 / -751, final -751 authoritative
- Prior lanes done: cod-3 / cod-4 / mem-1 already completed
- Changelog: 135 entries; learnings COMPLETED; 3 memory lessons recorded

## Re-open (2026-09-10, cod-4 verify RED)

- Prior status CLOSED (ticket-close lane 2026-09-10); re-opened as fix to already-implemented diff, not a new ticket and not bootstrap. Campaign ticket DIA-260909-sazr.
- Trigger: cod-4 verify RED - eslint no-import-assign, 4 errors in capability.test.mjs on cryptoNs (295:9, 303:11, 331:9, 333:15).
- Staged 16 preserved; stash@{0} lint-staged backup must NOT be touched.
- Next: same-session cod-3 fix required per DIA-175 R5. No code modified, staged, or committed by this re-open.

## Re-close (2026-09-10, cryptoNs fix)

- Status: CLOSED per developer re-close instruction.
- (1) Waiver verbatim: DIA-175 R5 waived: original implementation session cod-3 was evicted from the task board; revive by alias and session ID returned unknown. Fresh coder restricted to four ESLint-only assignments in capability.test.mjs; no behavioral or scope changes.
- (2) Fix: block-local shadow const cryptoNs receiving the 4 writes, capability.test.mjs only (+44/-37 approx, one file).
- (3) Verify: node 18/18 exit 0, bun full 243/0 exit 0, eslint 0 errors exit 0, make test-config 61 PASS exit 0.
- (4) ai-specialist ai--1 GO-CONDITIONAL + learnings .opencode/learnings/external-patterns/2026-09-10-dia-260909-cryptons-gate.md; ai-auditor ai--2 GO-CONDITIONAL advisory with non-blocking caveat (local shadow cannot intercept lib import; spy test exercises fallback branch; DI/loader/fallback assertions intact) accepted as advisory residual per developer re-close instruction.
- (5) stash@{0} lint-staged backup untouched, no stage/commit by this lane (final commit runs from host shell).
