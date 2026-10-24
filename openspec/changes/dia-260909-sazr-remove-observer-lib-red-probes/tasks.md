# Tasks: Remove RED-era observer-lib test probes

Campaign ticket: DIA-260909-sazr

Each task is a test-only mechanical slice sized for one fresh context window.
The slices share no edited file and may start independently. They depend on
the original extraction design at
`openspec/changes/dia-260902-eqgg-delegation-observer-srp/design.md` D1 and
"One canonical interface per module" for retained DI isolation.

## 1. Direct API test slices

- [ ] 1.1 Simplify the capability suite to one settled API path. Blockers: none. Acceptance: token behavior, deterministic UUID/clock fake coverage, and loader-contract assertions remain; factory-existence checks, aliases/default fallbacks, probe wrappers, and their RED-alternative documentation are absent. Run its explicit Bun suite.

- [ ] 1.2 Simplify the ticket-gate suite to one settled API path. Blockers: none. Acceptance: filesystem DI fake coverage, ticket scan/correlation behavior, and loader guards remain; adaptive factory/alias/default probing and associated RED documentation are absent. Run its explicit Bun suite.

- [ ] 1.3 Simplify the handoff suite to one settled API path. Blockers: none. Acceptance: filesystem/clock/UUID fakes, atomic-write behavior, and independent checksum assertions remain; adaptive factory/alias/default probing and associated RED documentation are absent. Run its explicit Bun suite.

- [ ] 1.4 Simplify the registry suite to one settled API path. Blockers: none. Acceptance: filesystem/path/clock/UUID fake coverage and registry writer behavior remain; adaptive factory/alias/default probing and associated RED documentation are absent. Run its explicit Bun suite.

## 2. Lifecycle and formatter test slices

- [ ] 2.1 Simplify the stall-sweep suite to one settled API path. Blockers: none. Acceptance: timer, clock, registry-reader, and emitter fakes plus lifecycle behavior remain; adaptive factory/alias/default probing and associated RED documentation are absent. Run its explicit Bun suite.

- [ ] 2.2 Simplify the formatter suite to one settled API path. Blockers: none. Acceptance: injected spawn/filesystem/path fakes and formatter behavior remain; adaptive factory/alias/default probing and associated RED documentation are absent. Run its explicit Bun suite.

- [ ] 2.3 Simplify the circuit-breaker suite to one settled API path. Blockers: none. Acceptance: clock-injected state-machine coverage remains; adaptive factory/alias/default probing and associated RED documentation are absent. Run its explicit Bun suite.

## 3. Change-level verification

- [ ] 3.1 Verify the completed test-only cleanup. Blockers: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3. Acceptance: all seven explicit Bun suites and `make test-config` pass; probe-pattern search returns zero in the seven suites; no file under `.opencode/plugins/lib/` changed; loader guards, checksum logic, and `integration-regressions.test.mjs` are unchanged; record the developer-accepted final measured net -751 LOC across seven files (322 insertions, 1073 deletions): initial -522, fix-loop 1 -92 to -614, fix-loop 2 -53 to -667, minimal-plan step 1 -59 to -726, and final auditor-listed-range sweep -25 to -751. The 2026-09-09 developer-accepted over-delivery supersedes the former -150 to -300 guardrail and must not cause code to be added back. RED-alternative docblocks, existence probes, and adaptive-acceptance guards are in scope. Zero behavioral assertions are removed; passing totals changed from 269 to 249 solely by deleting existence-only or vacuous tests. Although the developer instruction cited -667 as the F5 figure, the subsequent authorized sweeps establish -751 as final; -667 is intermediate only.

<!-- ownership: substance: developer; structure: AI; interview_depth: compressed -->
