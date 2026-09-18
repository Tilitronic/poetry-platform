# Proposal: Remove RED-era observer-lib test probes

Campaign ticket: DIA-260909-sazr

## Why

Seven observer-lib suites retain TDD RED scaffolding that discovers optional
factories, aliases, and fallback exports instead of calling settled APIs.
The canonical APIs and their DI-backed behavior are now established, so the
scaffolding duplicates coverage and obscures the actual contracts.

## What Changes

- Remove test-side adaptive interface discovery, factory-existence checks,
  alternate alias/default fallbacks, and probe wrappers from the seven
  observer-lib suites.
- Delete comments and docblocks that describe the removed RED alternatives.
- Retain one direct, settled API path in each suite and retain its DI fakes.
- Keep loader-contract tests, independent checksum assertions, and
  `integration-regressions.test.mjs` unchanged.
- Do not modify the seven production `lib/` modules or the observer shell.

## Capabilities

No specification-level behavior changes. This is test-only maintenance, so
`.openspec.yaml` opts out of delta specs with `skip_specs: true`.

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

- Affected tests: capability, ticket-gate, handoff, registry, stall-sweep,
  formatter, and circuit-breaker suites under `.opencode/plugins/__tests__/`.
- Unchanged production modules: the corresponding seven files under
  `.opencode/plugins/lib/`.
- Governing constraint: the original extraction design,
  `openspec/changes/dia-260902-eqgg-delegation-observer-srp/design.md`
  D1 and "One canonical interface per module", defines real dependency
  injection and one canonical interface; the retained tests continue to use
  settled APIs with injected fakes.
- Expected reduction: 150 to 300 test LOC.
- Rollback: restore only the seven test files from the change commit.

## Testing Decisions

A good test exercises one settled public boundary with a deterministic fake
and makes an independent behavioral assertion. Factory/alias existence checks
and wrappers that choose between alternative exports are not independent
coverage and will be removed. Existing loader-contract coverage and handoff
checksum assertions are separate behavior checks and remain intact.

## Alternatives considered

- Retain adaptive probes: rejected. Tier-1:
  `openspec/changes/dia-260902-eqgg-delegation-observer-srp/design.md` requires
  one canonical interface per module and rejects probe aliases.
- Delete tests broadly: rejected. Tier-1:
  `openspec/changes/dia-260902-eqgg-delegation-observer-srp/design.md` D1 and
  "One canonical interface per module" preserve isolated DI testing without
  probe aliases.
- Status-quo / do nothing: rejected. It leaves obsolete RED scaffolding and
  duplicate coverage in seven suites.

Chosen option: remove only adaptive test probes because the settled APIs,
DI fakes, loader contracts, and checksum assertions already cover the
independent behavior.

<!-- ownership: substance: developer; structure: AI; interview_depth: compressed -->
