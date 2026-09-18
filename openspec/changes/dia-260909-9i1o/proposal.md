# Proposal: Consolidate budget-gate Bats fixture setup

Campaign ticket: DIA-260909-9i1o

## Why

The two budget-gate Bats suites duplicate fixture setup, including manifest
writing, campaign-ticket seeding, Git initialization, and inline environment
invocation. The duplication is about 60 to 70 LOC and has already drifted by
one manifest parameter, making equivalent fixtures harder to keep aligned.

## What Changes

- Move only reusable budget-fixture primitives into `scripts/__tests__/test-helper.bash`.
- Give the shared manifest writer an explicit baseline-count argument so both
  suites retain their current manifest data.
- Share campaign-ticket seeding, Git repository initialization, and hook/range
  invocation wrappers.
- Replace equivalent suite-local setup with those primitives while retaining
  suite-local tree shapes, commits, test names, assertions, environment
  behavior, and fixture semantics.
- Do not alter production scripts, budget-gate behavior, Bats test behavior,
  or any ticket, OpenCode configuration, changelog, or memory artifact.

## Capabilities

No specification-level behavior changes. This is a test-fixture refactor, so
`.openspec.yaml` sets `skip_specs: true`.

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

- Affected test artifacts: `scripts/__tests__/budget-gate.bats`,
  `scripts/__tests__/budget-gate-range-exemption.bats`, and
  `scripts/__tests__/test-helper.bash`.
- Existing public test seams remain the two Bats suite entrypoints and their
  `run`-captured gate invocations.
- No `.sdd/` document governs this test-helper-only change; it introduces no
  module boundary, runtime API, dependency, or architecture decision.
- Rollback: revert the single refactor commit if either affected suite changes
  observable behavior or verification fails.

## Testing Decisions

A good test for this refactor preserves the existing suite contract rather
than adding duplicate behavior tests. The affected modules are the two Bats
suites and their shared helper. Prior art is the existing hermetic fixture
pattern: each suite builds an isolated Git repository under
`$BATS_TEST_TMPDIR`, invokes the gate through Bats `run`, and asserts current
status and output. Run both affected suites before and after the extraction;
their unchanged names, assertions, exit codes, environment behavior, and
fixture semantics are the parity evidence.

## Alternatives considered

- Keep duplicate suite-local fixtures: rejected. Tier-1: developer Q1-Q3
  interview decisions on 2026-09-10 identify observable-parity preservation,
  a narrow shared-helper boundary, and two-suite verification as the accepted
  approach.
- Extract whole fixture scenarios into a generic framework: rejected. Tier-1:
  developer Q2 keeps tree shape, commits, and assertions suite-local; a
  broader framework would exceed the agreed boundary.
- Status-quo / do nothing: rejected. It retains the identified manifest
  parameter drift and 60 to 70 LOC of repeated setup.

Chosen option: share only the agreed primitives because the developer-approved
boundary removes drift while preserving the existing Bats contracts.

<!-- ownership: substance: developer; structure: AI; interview_depth: compressed -->
