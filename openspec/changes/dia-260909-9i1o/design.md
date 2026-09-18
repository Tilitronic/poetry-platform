# Design: Consolidate budget-gate Bats fixture setup

Campaign ticket: DIA-260909-9i1o

## Context

See `proposal.md` for motivation. The two Bats suites construct hermetic Git
fixtures beneath `$BATS_TEST_TMPDIR` and use the same budget-gate CLI in hook
and range modes. Their equivalent setup has diverged in the manifest writer's
baseline-count parameter. `test-helper.bash` is the existing shared location
for Bats helpers and currently contains no budget-gate helpers.

No `.sdd/` document applies to this test-helper-only refactor. It preserves
the existing test boundary and makes no architecture decision.

## Goals / Non-Goals

**Goals:**

- Centralize only the developer-confirmed reusable fixture primitives.
- Make all manifest fixture inputs explicit, including the pattern baseline
  count that differs between suites.
- Keep the suites' current observable contracts unchanged.

**Non-Goals:**

- No production budget-gate, manifest, hook, or runtime behavior changes.
- No generic fixture framework, new dependency, new Bats assertion library, or
  new behavior test.
- No extraction of suite-specific repository topology, historical commits,
  scenario data, or assertions.

## Decisions

### D1: Share small fixture primitives in the existing helper

`test-helper.bash` receives only four classes of reusable primitive: manifest
writing with an explicit baseline count, campaign-ticket seeding, Git
repository initialization, and gate invocation wrappers for hook and range
modes. Each primitive accepts the current caller-controlled paths and values;
it must not infer scenario-specific fixture data.

Rationale: this removes the known parameter drift while retaining the existing
shared-helper location and the suites' hermetic fixture model.

Alternative: add a new helper file or framework. Rejected because
`test-helper.bash` is already loaded by both suites and no additional
abstraction is needed.

### D2: Preserve suite-owned scenario setup

Each suite continues to create its own repository tree, write its own
scenario-specific files and ticket status history, create commits, and make
its existing assertions. The range-exemption suite continues to model its
prehistory and ticket-history cases locally; the primary suite continues to
model its baseline and regression cases locally.

Rationale: these data shapes are behavior-specific, not byte-equivalent
infrastructure. Keeping them local prevents a helper from obscuring the
scenario under test.

Alternative: move complete repository setup functions into the shared helper.
Rejected because it exceeds the developer-confirmed boundary.

### D3: Preserve CLI invocation semantics through narrow wrappers

The helper wrappers construct the same environment assignments and gate
arguments currently passed to Bats `run`, including manifest, ticket directory,
plugin-root, optional caller environment, working-directory behavior, and the
`--range` argument where applicable. Call sites retain their current
assertions on Bats status and output.

Rationale: command construction is repeated infrastructure, but the asserted
verdict is the public behavior of each individual test.

Alternative: standardize all callers on one wrapper or one working directory.
Rejected because the current suites deliberately exercise both direct and
repository-relative invocation behavior.

## Seams

The developer confirmed the existing test seams before implementation. No new
seam is introduced.

1. `budget-gate.bats` hook-mode gate invocation through Bats `run`.
2. `budget-gate.bats` range-mode gate invocation through Bats `run`.
3. `budget-gate-range-exemption.bats` range-mode invocation from its fixture
   repository through Bats `run`.
4. `test-helper.bash` primitive inputs and outputs, exercised only through the
   two existing suites.

## Test Strategy

1. Capture a baseline by running both affected Bats suites before editing.
2. After each narrow extraction slice, run both affected suites and compare
   their pass/fail result with the baseline.
3. Confirm test names, assertions, exit codes, output expectations,
   environment assignments, and fixture semantics are unchanged.
4. Run `make test-shell` as the project shell-suite gate after both targeted
   suites pass. Its wrapper syntax-checks `test-helper.bash` and executes the
   Bats suite.

No new behavior tests are added: the existing Bats assertions are the agreed
parity contract.

## Risks / Trade-offs

- [A wrapper loses an environment variable or changes the working directory]
  -> Mitigation: preserve each existing invocation form and use the affected
  suites' current status and output assertions as parity checks.
- [A shared manifest writer silently changes the range suite's baseline count]
  -> Mitigation: require baseline count as an explicit primitive input and run
  both suites after extraction.
- [The helper grows into a scenario framework] -> Mitigation: keep tree shape,
  commit history, scenario files, and assertions in their owning suite.

## Migration Plan

1. Record the pre-change result for both affected Bats suites.
2. Add the four agreed primitives to `test-helper.bash` and switch only
   byte-equivalent setup call sites in the two suites.
3. Run the two suites, then `make test-shell`; record their exit codes and
   summary lines.
4. Revert the single refactor commit if either suite changes observable
   behavior or any parity verification fails.

## Open Questions

None. The developer confirmed scope, seams, verification, and rollback in the
compressed interview.

<!-- ownership: substance: developer; structure: AI; interview_depth: compressed -->
