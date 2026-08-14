# Proposal: test-suite-audit-fixes

> **Status:** drafted
> **Scope:** dev-infra (scripts, Makefile, turbo.json, lint-staged, hook
> scripts, Python conftest.py). Six independent findings from the ana021
> full test-suite audit (DIA-139), plus two clean findings noted as
> out-of-scope context.
> **Ticket:** `docs/dev-infra-audit/tickets/DIA-139-full-test-suite-audit.md`
> **Source of substance:** `knowledge/ana021-test-suite-audit/ana021-test-suite-audit-report.md` (DIA-139 audit report, 451 lines).
> **Governing SDD:** `.sdd/dev-infra/architecture.md` (parallel dev model,
> branch conventions, worktree husky-shim ADR 9, batch-D suite ADR 10).
> **Routing:** AGENTS.md section 2.4 (dev-infra). `@coder` implements;
> `make test-config` + `make test-shell` + `pnpm verify:*` validate;
> `@reviewer` reviews dev-infra slices.
> **Parallel-implementation model:** 5 disjoint slices (A-F, no E; see
> tasks.md), one coder per slice, each in its OWN git worktree (batch D).
> **Interview waiver (practice-protected):** the developer opted into a
> direct spec-authoring from the audit report (verbatim directive:
> "Create the change directly from the completed audit", 2026-08-14).
> The substance (six fix findings + context) already exists in the audit
> report; re-interviewing would re-extract facts already documented.

## Why

The ana021 audit (DIA-139, 2026-08-14) measured the test surface (409
tests, 8 runners) and found six actionable inefficiencies that slow every
developer cycle: the pre-push gate runs its slowest step first (24.6 s
before the first format failure surfaces, instead of 1.2 s), turbo's
default test task silently inherits `dependsOn: ["build"]` for any new
package, `make test-infra` rebuilds the Docker stack twice per run, the
bats suite has no quick tier for shell edits (25 s floor per iteration),
the `/home/qualt` regression guard is byte-identical in two hooks and
re-tested in two bats files, and the PEP 420 conftest.py bootstrap is
duplicated across both Python packages. Together these cost ~1 min of
feedback latency per pre-push cycle and ~1 min per `make test-infra` run,
and leave two DRY surfaces (hooks, conftest) that will drift. This change
fixes all six in one pass, parallelizable across 5 disjoint slices.

## What Changes

- **F-1 [High] Reorder `scripts/verify-pre-push.sh`** -- put the slowest
  step (`make test-shell`, 24.6 s) LAST. New step ladder: verify:format
  (1.2 s), verify:js (2.8 s), verify:js-tests (cached, ~0.05 s),
  test-config (1.6 s), verify:python (1.5 s), test-shell LAST. Cuts the
  fast-to-fail time for a format/typecheck failure from ~32 s to ~1.2 s.

- **F-2 [Medium] Flip the turbo `test` default** -- base `test` task in
  `turbo.json` changes `dependsOn: ["build"]` to `dependsOn: []`. The
  per-package override block for the four known packages
  (editor-engine, data-contracts, phonetics-core, author-studio) becomes
  empty and is removed. New packages get fast tests by default.

- **F-3 [Low] Eliminate the duplicate `up --build` in `make test-infra`**
  -- `scripts/test-docker-smoke.sh` already builds and tears down the
  stack internally; the Makefile recipe then runs `docker compose up -d
--build` again before `test-python`. Fix: make the smoke test leave
  the stack UP on success and remove the second `up --build` from the
  recipe. Saves ~30-60 s per `make test-infra` run.

- **F-4 [Medium] Add a `--quick` tier to the bats runner** -- new mode
  in `scripts/__tests__/bats-wrapper.sh` that runs only syntax checks
  (`bash -n`, `node --check`) plus the three smallest suites
  (check-host-jq.bats:3, check-host-lsp.bats:9, validate-skills.bats:23
  = 35 tests). Wire a `*.sh` entry into `package.json`'s `lint-staged`
  section so shell edits get a sub-3 s feedback loop without running the
  full 240-test monolith.

- **F-6 [Low] Extract the `/home/qualt` guard + dedup bats tests** --
  the `guard_no_home_qualt` function is byte-identical in both
  `scripts/verify-pre-commit.sh` (lines 51-62) and
  `scripts/verify-pre-push.sh` (lines 72-83), and is tested identically
  in both `scripts/__tests__/verify-pre-commit.bats` and
  `scripts/__tests__/verify-pre-push.bats`. Extract the function into a
  new shared helper `scripts/guards/home-qualt.sh`, source it from both
  hooks, keep ONE bats test against the shared helper. The hook-level
  bats tests assert "the guard is sourced and runs" without
  re-implementing the grep.

- **F-7 [Low] Consolidate the PEP 420 conftest.py bootstrap** -- the
  18-line `apps/api-server/tests/conftest.py` and 19-line
  `packages/analytics-pipeline/tests/conftest.py` are near-identical
  `sys.path.insert` bootstrap. Set `pythonpath` in each package's
  `pyproject.toml` `[tool.pytest.ini_options]` and delete both
  conftest.py files (preferred, per the audit's fix suggestion).

## Out of Scope (noted as context)

The audit reported these clean or recommendation findings; they do NOT
become tasks in this change:

- **F-5 [Low] Vitest exec overhead** -- already mitigated by turbo
  caching (45 ms warm). No action unless suite count grows.
- **F-8 [Info] mock_docker_down boilerplate** -- revisit when a third
  caller appears (currently 2).
- **F-9 [Info] author-studio example-store TODO** -- honest scaffold,
  leave as-is until a real store lands.
- **F-10 [Info] Python import-only smoke tests** -- honest seam-markers,
  leave in place until real JWT/analytics logic lands.
- **F-11 [Clean] No tautological tests** -- DIA-124/125 cleanup
  verified.
- **F-12 [Clean] No fake verification** -- grep checks across all test
  files: zero empty asserts, zero always-pass mocks.
- **F-13 [Info] batch-d-infra.test.mjs hand-rolled JSONC parser** --
  revisit later, not urgent.
- **F-14 [Info] validate-skills.bats scope** -- rename / docstring.
- **F-15..F-18** -- informational / already-delivered / recommendations.
- **O-1 [Recommendation] CI pipeline** -- backlog (separate ticket).
- **O-2 [Backlog] 4 uncovered packages** -- backlog (separate ticket).
- **O-3 [Recommendation] Stale worktrees under .worktrees/** -- cleanup.

## Capabilities

### New Capabilities

None. This change is pure dev-infra (tooling/scripts) and does not
introduce any spec-level user-visible behavior. `skip_specs: true` is
set in `.openspec.yaml`.

### Modified Capabilities

None (see above).

## Impact

- **Files touched (dev-infra module only):**
  - `scripts/verify-pre-push.sh` (F-1 step ladder; F-6 guard source)
  - `scripts/verify-pre-commit.sh` (F-6 guard source)
  - `scripts/__tests__/verify-pre-push.bats` (F-6 dedup)
  - `scripts/__tests__/verify-pre-commit.bats` (F-6 dedup)
  - `scripts/guards/home-qualt.sh` (F-6 new shared helper)
  - `scripts/__tests__/bats-wrapper.sh` (F-4 --quick mode)
  - `turbo.json` (F-2 default flip)
  - `Makefile` (F-3 test-infra rebuild)
  - `scripts/test-docker-smoke.sh` (F-3 leave stack UP)
  - `package.json` (F-4 lint-staged \*.sh entry)
  - `apps/api-server/tests/conftest.py` (F-7 delete)
  - `packages/analytics-pipeline/tests/conftest.py` (F-7 delete)
  - `apps/api-server/pyproject.toml` (F-7 pythonpath)
  - `packages/analytics-pipeline/pyproject.toml` (F-7 pythonpath)
- **No new dependencies.** bats, node, make, pytest already installed.
- **No new module boundary.** all changes stay within the existing
  `scripts/`, `apps/`, `packages/` module layout documented in
  `.sdd/dev-infra/architecture.md`.
- **Hooks behavior change (F-1):** developers will now see format/
  typecheck failures in ~1 s instead of ~25 s. The overall gate still
  runs the same steps; only the ordering changes. Documented in the
  verify-pre-push.sh header comment.

## Testing Decisions

**What makes a good test for this change:** every fix is itself test
infrastructure. The validation is that the existing test gates
(`make test-config`, `make test-shell`, `pnpm verify:*`) still pass
after the change, plus targeted assertions on the new behavior:

- **F-1 ordering:** a bats test that sources verify-pre-push.sh's step
  list and asserts test-shell is last. Alternatively, a grep-based
  assertion in batch-d-infra.test.mjs on the ordering in the committed
  file (per the existing batch-D pattern from DIA-134 S2).
- **F-2 turbo default:** a node-native assertion in
  batch-d-infra.test.mjs that parses turbo.json and verifies the base
  `test` task has `dependsOn: []`.
- **F-3 single rebuild:** a bats test on test-docker-smoke.sh (or a
  grep assertion in batch-d-infra.test.mjs) that the `up --build`
  invocation count is one, not two.
- **F-4 --quick mode:** new bats cases in bats-wrapper.bats (or a new
  test file) that invoke `bats-wrapper.sh --quick` and assert exactly
  the three expected suites run (check-host-jq, check-host-lsp,
  validate-skills) and no others.
- **F-6 guard dedup:** a single bats test that sources
  `scripts/guards/home-qualt.sh` directly and asserts the grep
  behavior. The hook-level bats tests assert the guard is sourced
  (lightweight) rather than re-implementing the grep.
- **F-7 pythonpath:** existing pytest import smoke tests in
  `apps/api-server/tests/test_auth.py` and
  `packages/analytics-pipeline/tests/test_smoke.py` become the
  verification -- they pass iff the pythonpath config works. No new
  tests needed; delete conftest.py and run `make test-python`.

**Modules tested:** dev-infra scripts + Makefile + turbo.json + Python
package test bootstrap.

**Prior art in the codebase:**

- `scripts/__tests__/test-helper.bash` (448 lines, DIA-125 consolidated
  helper) -- F-6's new `scripts/guards/home-qualt.sh` follows the same
  small-helper pattern.
- `scripts/__tests__/batch-d-infra.test.mjs` (DIA-134 S2) -- grep-based
  committed-file assertions for dev-infra invariants. F-1/F-2/F-3 can
  add cases here using the existing pattern.
- `apps/api-server/tests/test_auth.py` +
  `packages/analytics-pipeline/tests/test_smoke.py` (DIA-124 import
  smokes) -- F-7 verification piggy-backs on these.

## Rollback Plan

Each slice is independently revertable:

- **F-1:** git revert of `scripts/verify-pre-push.sh` ordering change
  only. No data migration. No hook-reinstall needed (husky reads the
  script at runtime).
- **F-2:** git revert of `turbo.json`. No downstream effect.
- **F-3:** git revert of `Makefile` + `scripts/test-docker-smoke.sh`.
  No state change (Docker stack is ephemeral).
- **F-4:** git revert of `scripts/__tests__/bats-wrapper.sh` +
  `package.json` lint-staged entry. Removes the --quick mode and
  lint-staged wiring; no callers to migrate.
- **F-6:** git revert of the 4 files (two hook scripts, two bats
  files) + delete `scripts/guards/home-qualt.sh`. Returns to the
  byte-identical inline guards. No data migration.
- **F-7:** git revert of pyproject.toml edits + restore both
  conftest.py files. Returns to the duplicate PEP 420 bootstrap.

**Aggregate rollback:** `git revert <merge-commit>` reverts all six
fixes atomically. No state or schema to migrate.

**Risk assessment:** LOW. Every change is either a reorder, a dedup of
byte-identical code, a default flip, or a removal of duplicate rebuild
steps. No new behavior is introduced that was not already tested by the
existing gates. Pre-push still runs the same steps; only the ordering
changes.
