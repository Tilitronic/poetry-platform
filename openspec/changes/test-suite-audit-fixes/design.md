# Design: test-suite-audit-fixes

> **Proposal:** `openspec/changes/test-suite-audit-fixes/proposal.md`
> **Ticket:** `docs/dev-infra-audit/tickets/DIA-139-full-test-suite-audit.md`
> **Source of substance:** `knowledge/ana021-test-suite-audit/ana021-test-suite-audit-report.md`
> **Scope:** dev-infra. Six fix findings (F-1, F-2, F-3, F-4, F-6, F-7)
> from the ana021 audit, grouped into 5 disjoint slices (A, B, C, D, F;
> no E) parallelizable across 5 coders under batch D (each coder in its
> OWN git worktree).
> **Governing SDD:** `.sdd/dev-infra/architecture.md` (parallel dev
> model, branch conventions, worktree husky-shim ADR 9, batch-D suite
> persistence ADR 10). None of the six fixes crosses a module boundary
> or introduces a new technology choice; no @architector escalation is
> required.
> **Disjoint-ownership contract:** every file in the change has exactly
> one owning slice. No other slice may edit it. See Ownership table at
> the end of this document.

## Context

See proposal.md for motivation. Summary: the ana021 audit measured a
409-test surface and found six actionable inefficiencies in the
dev-infra layer. Each is self-contained; none requires architectural
escalation. The design below is file-by-file and slice-by-slice.

The 5 slices map to 5 disjoint file sets (see Ownership table). Each
slice is independently demoable, independently revertable, and
independently testable. Slices run in parallel during implementation
(batch D); the merge phase verifies the union still passes all gates.

## Goals / Non-Goals

**Goals:**

- Cut the fast-to-fail time for a format/typecheck failure from ~32 s
  to ~1.2 s (F-1).
- Make new packages get fast tests by default (F-2).
- Eliminate one redundant `docker compose up --build` per `make
test-infra` run (F-3).
- Provide a sub-3 s quick tier for shell edits (F-4).
- Consolidate the byte-identical `/home/qualt` guard into one helper
  with one canonical test (F-6).
- Consolidate the duplicated PEP 420 conftest.py bootstrap (F-7).
- Keep every slice independently revertable.

**Non-Goals:**

- Do NOT touch `.sdd/` documents (no ADR-worthy decisions; all changes
  stay within existing module boundaries per `.sdd/dev-infra`).
- Do NOT address O-1 (CI pipeline) or O-2 (uncovered packages) --
  those are backlog items, not fixes.
- Do NOT add end-to-end CI workflow files (`.github/` etc).
- Do NOT alter the actual set of steps verify-pre-push.sh runs (F-1
  only reorders; no step is added or removed).
- Do NOT merge the four vitest configs (F-16, low priority, 24 lines
  total) -- out of scope.
- Do NOT replace the hand-rolled `stripJsonc` in batch-d-infra.test.mjs
  (F-13) -- out of scope.

## Decisions

### DD1: Merging F-1 and F-6 into a single slice (A)

**Decision:** F-1 (reorder verify-pre-push.sh steps) and F-6 (extract
/home/qualt guard + dedup bats tests) are MERGED into one slice
because both modify `scripts/verify-pre-push.sh`. Parallel worktrees
cannot safely edit the same file in different regions without merge
conflict risk; merging eliminates the collision.

**Rationale:** the alternative (two slices with line-range ownership)
relies on git's ability to merge non-overlapping regions of the same
file, which is not guaranteed and has failed in prior batch-D changes
(revert commit af6e019, DIA-132). Merging is the safer choice and the
combined slice is still one-context-window sized (estimated 45-60 min).

**Alternatives considered:** keep F-1 and F-6 in separate slices with
explicit line-range ownership -- rejected (merge risk); keep F-6 only
and defer F-1 -- rejected (F-1 is the highest-severity fix, P0).

### DD2: F-6 helper location (`scripts/guards/home-qualt.sh`)

**Decision:** the extracted guard lives at `scripts/guards/home-qualt.sh`
(new directory `scripts/guards/`). Both hook scripts source it via a
relative path from the repo root.

**Rationale:** `scripts/guards/` is a natural namespace for small
reusable shell helpers that are sourced (not executed standalone). It
keeps the helper close to the hooks that consume it and discoverable
via glob.

**Alternatives considered:** put the helper in `scripts/__tests__/` --
rejected (it is production code sourced by hooks, not a test fixture);
put it in `scripts/lib/` -- rejected (no such directory exists; new
top-level directory for one helper is over-scoped).

### DD3: F-3 fix strategy (smoke test leaves stack UP)

**Decision:** modify `scripts/test-docker-smoke.sh` to accept an
environment variable `SMOKE_LEAVE_UP=1` that, on success, leaves the
stack running instead of tearing down. The `make test-infra` recipe
sets `SMOKE_LEAVE_UP=1` and removes the subsequent `docker compose up
-d --build` call.

**Rationale:** the smoke test already builds and validates the stack;
tearing it down only to rebuild it is pure waste. An env-var switch
keeps the smoke test's default behavior (tear down) intact for
developers who run it standalone, while allowing the Makefile recipe to
opt into "leave up" mode.

**Alternatives considered:** have test-python use the stack the smoke
test just brought up without modifying the smoke test -- rejected
(requires the smoke test to NOT tear down; same effect as the chosen
approach but without the explicit opt-in); delete the smoke test
entirely and rely on test-infra's own up/build -- rejected (the smoke
test validates a different contract: fresh-stack bring-up, independent
of test-python).

### DD4: F-4 --quick mode invocation

**Decision:** `scripts/__tests__/bats-wrapper.sh --quick` accepts a
literal list of suite basenames (or defaults to the curated list:
check-host-jq, check-host-lsp, validate-skills). It runs `bash -n` and
`node --check` on all scripts first (syntax tier), then runs the three
suites via bats. Exit 0 only if both tiers pass.

**Rationale:** a curated default list keeps the common case (no args)
fast; the literal-list option allows future callers to name their own
subset without forking the script.

**Alternatives considered:** auto-discover "small" suites by test count
-- rejected (fragile; requires parsing every .bats file's @test count
at runtime); add a new Makefile target (`test-shell-quick`) -- rejected
(Makefile is owned by Slice C; Slice D owns only bats-wrapper.sh and
package.json).

### DD5: F-4 lint-staged wiring

**Decision:** add a `*.sh` entry to `package.json`'s existing
`lint-staged` block that runs `scripts/__tests__/bats-wrapper.sh
--quick` on staged `*.sh` files. No new config file (`.lintstagedrc`
etc).

**Rationale:** the existing lint-staged config lives in `package.json`
(no separate `.lintstagedrc`); adding to it is one line. The `*.sh`
glob covers every shell script in the repo (hooks, runners, helpers);
bats-wrapper.sh discovers only the relevant tests for each script.

**Alternatives considered:** create `.lintstagedrc.mjs` -- rejected
(two configs for one tool); wire `--quick` into the existing pre-commit
hook -- rejected (pre-commit already runs lint-staged; the new entry
piggy-backs on it).

### DD6: F-7 pythonpath strategy

**Decision:** set `pythonpath = ["."]` (or the appropriate relative
path to the package root) in each package's `pyproject.toml` under
`[tool.pytest.ini_options]`, then delete both conftest.py files.

**Rationale:** pytest's native `pythonpath` setting (added in pytest
7.0) replaces the manual sys.path bootstrap without any Python code.
Deleting both conftest.py files removes the duplication entirely
instead of consolidating into a single shared conftest (which would
introduce a new file at the repo root with cross-package scope).

**Alternatives considered:** single shared conftest.py at the repo root
-- rejected (cross-package scope, fragile if either package is moved);
keep both conftest.py files and import from a shared helper -- rejected
(does not remove the duplication, just moves it).

## Risks / Trade-offs

- **[F-3 smoke test env var]** The `SMOKE_LEAVE_UP=1` contract must be
  documented in `scripts/test-docker-smoke.sh`'s header comment so
  future maintainers understand why the stack stays up when invoked
  from the Makefile. Mitigation: header comment in the script.
- **[F-4 lint-staged *.sh glob]** Running bats-wrapper.sh on every
  staged `*.sh` file could slow pre-commit if a commit touches many
  shell scripts. Mitigation: the --quick mode is sub-3 s even for the
  full curated list; if the glob ever proves too wide, narrow it to
  specific paths.
- **[F-6 helper source path]** Sourcing `scripts/guards/home-qualt.sh`
  requires the hook scripts to resolve the path relative to the repo
  root (not the hook's own directory). Mitigation: use
  `$(git rev-parse --show-toplevel)/scripts/guards/home-qualt.sh` to
  locate the repo root, matching the existing pattern in the hook
  scripts.
- **[F-7 pytest pythonpath]** The `pythonpath` setting requires pytest
  7.0+. Mitigation: verify the pinned pytest version in each package's
  pyproject.toml before applying; if < 7.0, fall back to a shared
  conftest.py at the repo root.
- **[Aggregate] Slice merge order** -- slices are independent and can
  merge in any order. The merge phase runs the full gate suite
  (`make test-config` + `make test-shell` + `pnpm verify:*` + `make
test-python`) to confirm no cross-slice regression.

## Seams

The tests for this change live at the following pre-agreed seams (all
existing; no new seams introduced):

- **scripts/**tests**/\*.bats** -- the bats test seam. F-4 adds cases
  for --quick mode; F-6 replaces the inline guard tests with a single
  test that sources the shared helper.
- **scripts/**tests**/batch-d-infra.test.mjs** -- the node-native
  grep-based committed-file assertion seam (DIA-134 S2 pattern). F-1,
  F-2, F-3 can add cases here for ordering / turbo default / rebuild
  count invariants.
- **apps/api-server/tests/test_auth.py + packages/analytics-pipeline/tests/test_smoke.py** --
  the Python import-smoke seam (DIA-124). F-7 verification piggy-backs
  on these: if `make test-python` passes after conftest.py deletion,
  the pythonpath config works.

## Test Strategy

**Per finding:**

- **F-1:** add a case to `batch-d-infra.test.mjs` that parses
  `scripts/verify-pre-push.sh` and asserts `test-shell` appears after
  `verify:python` (or after all other steps). Grep-based, matching the
  existing batch-D pattern.
- **F-2:** add a case to `batch-d-infra.test.mjs` that parses
  `turbo.json` and asserts the base `test` task has `dependsOn: []`
  (or no `dependsOn` key). JSON-parsed assertion.
- **F-3:** add a case to `batch-d-infra.test.mjs` that parses
  `Makefile` and asserts `docker compose up -d --build` appears exactly
  once in the `test-infra` recipe (or zero times if the smoke test is
  the sole bring-up). Alternatively, a bats test that runs `make
test-infra` and asserts the stack is brought up once (measured via
  docker events or log grep).
- **F-4:** add new bats cases (in a new file `scripts/__tests__/bats-wrapper.bats`
  or alongside existing bats-wrapper tests if any) that invoke
  `bats-wrapper.sh --quick` and assert: (a) syntax tier runs, (b) the
  three expected suites run, (c) no other suites run.
- **F-6:** add a single bats test in
  `scripts/__tests__/guards-home-qualt.bats` (new file) that sources
  `scripts/guards/home-qualt.sh` and asserts the grep behavior. The
  existing `verify-pre-commit.bats` and `verify-pre-push.bats` tests
  that re-implemented the grep are replaced with lightweight assertions
  that the guard is sourced and runs.
- **F-7:** no new tests. Run `make test-python`; if both import-smoke
  tests pass after conftest.py deletion, the pythonpath config works.

**Aggregate verification:** `make test-config` + `make test-shell` +
`pnpm verify:*` + `make test-python` all exit 0 after all five slices
are merged.

## Rollback Plan

Each slice is independently revertable via `git revert <slice-commit>`:

- **Slice A (F-1 + F-6):** revert the ordering change and the guard
  extraction. Returns to inline guards and old step ladder.
- **Slice B (F-2):** revert turbo.json. Returns to `dependsOn: ["build"]`
  default.
- **Slice C (F-3):** revert Makefile + test-docker-smoke.sh. Returns to
  double rebuild.
- **Slice D (F-4):** revert bats-wrapper.sh + package.json. Removes
  --quick mode and lint-staged entry.
- **Slice F (F-7):** revert pyproject.toml edits + restore both
  conftest.py files. Returns to duplicated PEP 420 bootstrap.

**Aggregate rollback:** `git revert <merge-commit>` reverts all six
fixes atomically. No state or schema to migrate.

## Ownership Table (disjoint file sets per slice)

| Slice | Findings | Files owned (exactly one slice per file)                                                                                                                                                 |
| ----- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A** | F-1, F-6 | `scripts/verify-pre-push.sh`, `scripts/verify-pre-commit.sh`, `scripts/guards/home-qualt.sh` (new), `scripts/__tests__/verify-pre-push.bats`, `scripts/__tests__/verify-pre-commit.bats` |
| **B** | F-2      | `turbo.json`                                                                                                                                                                             |
| **C** | F-3      | `Makefile`, `scripts/test-docker-smoke.sh`                                                                                                                                               |
| **D** | F-4      | `scripts/__tests__/bats-wrapper.sh`, `package.json` (lint-staged section only)                                                                                                           |
| **F** | F-7      | `apps/api-server/pyproject.toml`, `packages/analytics-pipeline/pyproject.toml`, `apps/api-server/tests/conftest.py` (delete), `packages/analytics-pipeline/tests/conftest.py` (delete)   |

**Disjointness check:** no file appears in more than one slice.
Slice D's ownership of `package.json` is scoped to the `lint-staged`
section only; no other slice edits `package.json`.

## Migration Plan

No migration needed. All changes are reorderings, dedups, or default
flips with no persistent state. Developers pull the merge commit; the
next pre-push run uses the new ordering automatically (husky reads the
script at runtime).
