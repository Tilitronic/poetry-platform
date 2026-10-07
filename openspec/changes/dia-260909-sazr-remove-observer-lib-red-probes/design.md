# Design: Remove RED-era observer-lib test probes

Campaign ticket: DIA-260909-sazr

## Context

See `proposal.md` for motivation. The seven observer-lib suites were authored
while interfaces were still being extracted. Several now discover optional
factories and aliases before testing behavior. The observer shell instead
imports settled named APIs from the seven `lib/` modules.

This change follows the original extraction design at
`openspec/changes/dia-260902-eqgg-delegation-observer-srp/design.md`: D1
defines injected environment dependencies for isolated tests, and "One
canonical interface per module" rejects probe aliases. It makes no
architecture decision and does not alter a module boundary, external
dependency, runtime behavior, or production API.

## Goals / Non-Goals

**Goals:**

- Make every retained test call one explicitly selected API instead of probing
  several possible interfaces.
- Keep fake clocks, filesystems, timers, and subprocess functions on the
  selected DI seam.
- Reduce test LOC without removing independent behavioral coverage.

**Non-Goals:**

- No changes to `.opencode/plugins/lib/`, `delegation-observer.ts`, loader
  guards, checksum logic, or the integration-regressions suite.
- No new helpers, abstractions, test framework, production exports, or loader
  behavior.

## Decisions

### D1: Replace discovery with direct named use

Each suite directly imports and calls its settled interface. It must not test
whether that interface exists, fall back to an alias/default export, or catch a
factory-probe failure before choosing another API.

Rationale: the shell and module exports are already the canonical contract;
adaptive test setup duplicates loader and API-surface coverage.

Alternative: retain flexible discovery. Rejected because it permits stale
compatibility paths and duplicates canonical tests.

### D2: Preserve DI without probe wrappers

The selected test seam keeps the existing deterministic fake mechanism but
uses it directly:

| Suite           | Settled seam and retained fake dependency                                                                |
| --------------- | -------------------------------------------------------------------------------------------------------- |
| capability      | Direct capability DI constructor for UUID/clock tests; direct named token APIs for shell-facing behavior |
| ticket-gate     | Direct ticket-gate DI constructor with filesystem fakes                                                  |
| handoff         | Direct handoff DI constructor with filesystem, clock, and UUID fakes                                     |
| registry        | Direct registry constructor with filesystem, path, clock, and UUID fakes                                 |
| stall-sweep     | Direct stall-sweep constructor with timer, clock, registry-reader, and emitter fakes                     |
| formatter       | Direct formatter function with spawn/filesystem/path fakes                                               |
| circuit-breaker | Direct `ToolCircuitBreaker` constructor with a clock fake                                                |

Rationale: this preserves the extraction design's injected-dependency test
isolation while deleting only the code that decides which interface to test.

Alternative: replace fakes with real clocks/filesystems/subprocesses. Rejected
because it weakens isolation and adds nondeterminism.

## Seams

The developer confirmed these existing public seams before implementation. No
new seam is introduced.

1. Capability mint/verify and its explicit DI entry.
2. Ticket-gate scan/correlation and its explicit filesystem DI entry.
3. Handoff atomic write/checksum and its explicit filesystem DI entry.
4. Registry writer and its explicit filesystem DI entry.
5. Stall-sweep lifecycle and its explicit timer/clock DI entry.
6. Formatter invocation and its direct dependency argument.
7. Circuit-breaker state machine and its explicit clock constructor argument.

Loader-contract tests and independent checksum assertions remain outside the
probe-removal operation even when they use one of these seams.

## Risks / Trade-offs

- [A chosen seam differs from a suite's current real contract] -> Mitigation:
  compare imports to the live module and retain the current passing direct
  interface before deleting alternatives.
- [A probe deletion accidentally removes an independent assertion] ->
  Mitigation: retain assertions on behavior, injected fakes, loader guards,
  and checksum output; run each suite explicitly.
- [Scope expands into production cleanup] -> Mitigation: verify no path under
  `.opencode/plugins/lib/` changed and leave `integration-regressions.test.mjs`
  unmodified.

## Acceptance Evidence: LOC Guardrail

The original 150 to 300 LOC guardrail is superseded. The developer accepted
over-delivery on 2026-09-09; do not add code back merely to fit that range.

- Initial implementation: net -522 across seven files (224 insertions, 746
  deletions).
- Fix-loop 1: a further -92, for net -614 (321 insertions, 935 deletions).
- Fix-loop 2: a further -53, for net -667.
- Minimal-plan step 1: a further -59, for net -726.
- Final sweep of auditor-listed ranges: a further -25, for the measured final
  cumulative net -751 across seven files (322 insertions, 1073 deletions).
- The removals are in-scope RED-alternative docblocks, existence probes, and
  adaptive-acceptance guards.
- Zero behavioral assertions were removed across all cycles. Passing totals
  changed from 269 to 249 solely by deleting existence-only or vacuous tests.
- The developer instruction cited net -667 as the F5 figure, but the two
  subsequent developer-authorized sweeps (-59 and -25) establish net -751 as
  the final measured actual. Net -667 is an intermediate result, not final.

## Migration Plan

1. Simplify each test suite in the declared seam order without changing tests
   outside the seven named files.
2. Run each named Bun suite after its slice, then run all seven and
   `make test-config`.
3. Confirm probe-pattern searches return zero within the seven files, record
   the accepted final measured net -751 LOC result, and do not add code merely
   fit the superseded target range.
4. Roll back by reverting the test-only commit if an independent assertion was
   removed or a verification gate fails.

## Open Questions

None. The developer confirmed scope, exclusions, seams, change name, and
verification commands in the compressed interview.

<!-- ownership: substance: developer; structure: AI; interview_depth: compressed -->
