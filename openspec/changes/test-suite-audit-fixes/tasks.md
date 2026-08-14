# Tasks: test-suite-audit-fixes

> **Proposal:** `openspec/changes/test-suite-audit-fixes/proposal.md`
> **Design:** `openspec/changes/test-suite-audit-fixes/design.md`
> **Ticket:** `docs/dev-infra-audit/tickets/DIA-179-full-test-suite-audit.md`
> **Source of substance:** `knowledge/ana021-test-suite-audit/ana021-test-suite-audit-report.md`
> **Implementation commits:** none yet (spec phase).
> **Routing:** AGENTS.md section 2.4 (dev-infra). `@coder` implements;
> `make test-config` + `make test-shell` + `pnpm verify:*` + `make
test-python` validate; `@reviewer` reviews dev-infra slices.
> **Parallel-implementation model:** 5 disjoint slices (A, B, C, D, F;
> no E), one coder per slice, each in its OWN git worktree (batch D,
> per `.sdd/dev-infra` ADR 1).
> **ASCII-only protocol (DIA-079):** all changes use ASCII-only text.
> **DIA-094 Docker gate:** implementation work AND commits MUST NOT
> proceed without a running docker dev container.
> **DIA-063 Ticket gate:** no implementation work starts without the
> DIA-179 ticket.
> **Disjoint-ownership contract:** every file in the change has exactly
> one owning slice. See Ownership table in design.md.

## Dependency graph

```
Slice A (F-1 + F-6: pre-push ordering + home-qualt dedup) -- independent
Slice B (F-2: turbo.json default flip) -- independent
Slice C (F-3: Makefile test-infra rebuild) -- independent
Slice D (F-4: bats --quick mode) -- independent
Slice F (F-7: conftest.py consolidation) -- independent
```

**Critical path:** all five slices are independent and run in parallel.
No slice blocks another. The merge phase runs last after all five
slices are complete and verifies the union still passes all gates.

**Rationale for five slices (not fewer, not more):**

- **Not fewer:** each slice is a disjoint file set and a distinct
  finding. Merging slices would conflate different test seams (bats vs
  node .test.mjs vs Python pytest) and make partial rollback harder.
  F-1 and F-6 are already merged into Slice A because they share
  `scripts/verify-pre-push.sh` (see design.md DD1).
- **Not more:** each slice is already the narrowest coherent unit.
  Splitting Slice A (F-1 from F-6) would create a merge conflict on
  `scripts/verify-pre-push.sh`. Splitting Slice C (F-3 Makefile from
  F-3 smoke test) would create a slice that cannot be verified
  independently (the Makefile recipe needs the smoke test's env var
  support to skip the second rebuild).

---

## 1. Slice A (F-1 + F-6): pre-push ordering + home-qualt guard dedup

> **Owner:** Slice A. Files owned:
> `scripts/verify-pre-push.sh`, `scripts/verify-pre-commit.sh`,
> `scripts/guards/home-qualt.sh` (new),
> `scripts/__tests__/verify-pre-push.bats`,
> `scripts/__tests__/verify-pre-commit.bats`.
> No other slice may edit these files.

- [ ] **1.1 Extract the /home/qualt guard into a shared helper + source it from both hooks.**
  - **Blockers:** none
  - **Owner:** Slice A (disjoint; no other slice may edit the files
    listed above).
  - **Vertical slice:** create `scripts/guards/home-qualt.sh` containing
    the `guard_no_home_qualt` function (extracted byte-for-byte from
    `scripts/verify-pre-push.sh:72-83` or `scripts/verify-pre-commit.sh:51-62`;
    they are identical). Add a header comment documenting the helper's
    purpose (regression guard against hardcoded `/home/qualt` paths).
    In `scripts/verify-pre-push.sh`, replace the inline `guard_no_home_qualt`
    function (lines 72-83) with a source statement:
    `source "$(git rev-parse --show-toplevel)/scripts/guards/home-qualt.sh"`.
    Apply the same replacement in `scripts/verify-pre-commit.sh` (lines 51-62).
    The hook scripts still call `guard_no_home_qualt` at the same points;
    only the function definition moves.
  - **Acceptance criteria:**
    - `scripts/guards/home-qualt.sh` exists and defines `guard_no_home_qualt`.
    - `scripts/verify-pre-push.sh` sources the helper and no longer
      contains the inline function definition.
    - `scripts/verify-pre-commit.sh` sources the helper and no longer
      contains the inline function definition.
    - Both hooks still call `guard_no_home_qualt` at the same points
      (the call sites are unchanged).
    - The source path resolves correctly when the hook runs from any
      worktree (uses `git rev-parse --show-toplevel`).
    - `bash -n` passes on all three files (syntax check).
  - **Verification:** `make test-shell` exits 0; existing bats cases
    for both hooks continue to pass (no regression in the guard's
    behavior as seen from the hook level).

- [ ] **1.2 Reorder verify-pre-push.sh step ladder + dedup the bats tests.**
  - **Blockers:** 1.1 (the helper must be sourced before the ordering
    changes, so the guard's call sites are stable)
  - **Owner:** Slice A (disjoint).
  - **Vertical slice:** in `scripts/verify-pre-push.sh`, reorder the
    step ladder (currently around lines 110-115) so the steps run in
    this order: (1) `pnpm verify:format`, (2) `pnpm verify:js`, (3)
    `pnpm verify:js-tests`, (4) `make test-config`, (5) `pnpm
verify:python`, (6) `make test-shell` LAST. Update the header
    comment documenting the step ladder to reflect the new order. In
    `scripts/__tests__/verify-pre-push.bats`, replace the two tests
    that re-implemented the `/home/qualt` grep (around lines 205, 222)
    with a lightweight assertion that the guard is sourced and runs
    (e.g., "the hook sources scripts/guards/home-qualt.sh" and "the
    hook calls guard_no_home_qualt"). Apply the same dedup to
    `scripts/__tests__/verify-pre-commit.bats` (around lines 134, 151).
    Add a new bats test file `scripts/__tests__/guards-home-qualt.bats`
    that sources `scripts/guards/home-qualt.sh` directly and asserts
    the grep behavior (the canonical test for the guard; replaces the
    two duplicated pairs). Optionally, add a grep-based assertion in
    `scripts/__tests__/batch-d-infra.test.mjs` that parses
    `scripts/verify-pre-push.sh` and asserts `make test-shell` appears
    after `pnpm verify:python` (ordering invariant).
  - **Acceptance criteria:**
    - `scripts/verify-pre-push.sh` runs the steps in the new order
      (format, js, js-tests, test-config, python, test-shell LAST).
    - The header comment documents the new step ladder.
    - `scripts/__tests__/verify-pre-push.bats` has no duplicate grep
      tests for `/home/qualt`; only lightweight "guard is sourced"
      assertions remain.
    - `scripts/__tests__/verify-pre-commit.bats` has no duplicate grep
      tests for `/home/qualt`; only lightweight assertions remain.
    - `scripts/__tests__/guards-home-qualt.bats` (new file) asserts
      the grep behavior of the shared helper.
    - All existing bats cases continue to pass (no regression).
    - `make test-shell` exits 0.
  - **Verification:** `make test-shell` exits 0; all bats cases pass;
    new `guards-home-qualt.bats` passes.

---

## 2. Slice B (F-2): turbo.json default test task flip

> **Owner:** Slice B. Files owned: `turbo.json`. No other slice may
> edit this file.

- [ ] **2.1 Flip the turbo `test` default from `dependsOn: ["build"]` to `dependsOn: []`.**
  - **Blockers:** none
  - **Owner:** Slice B (disjoint; no other slice may edit `turbo.json`).
  - **Vertical slice:** in `turbo.json`, locate the base `test` task
    (around lines 21-25 per the audit report). Change `dependsOn:
["build"]` to `dependsOn: []` (or remove the `dependsOn` key
    entirely if the schema allows). Locate the per-package override
    block for the four packages (editor-engine, data-contracts,
    phonetics-core, author-studio) that currently override the default;
    since the new default is `dependsOn: []`, these overrides become
    empty and should be removed. Update any comments documenting the
    override block to reflect the new default. Optionally, add a
    grep-based assertion in `scripts/__tests__/batch-d-infra.test.mjs`
    that parses `turbo.json` and asserts the base `test` task has
    `dependsOn: []` (or no `dependsOn` key), matching the existing
    batch-D pattern from DIA-174 S2.
  - **Acceptance criteria:**
    - The base `test` task in `turbo.json` has `dependsOn: []` (or no
      `dependsOn` key).
    - The per-package override block for the four packages is removed
      (no longer needed).
    - `pnpm test` (turbo) still runs all four vitest suites and exits 0.
    - `turbo.json` is valid JSON (parse check passes).
    - Any comments documenting the override block are updated or
      removed.
  - **Verification:** `pnpm test` exits 0; `turbo.json` parses as
    valid JSON; new batch-d-infra assertion (if added) passes.

---

## 3. Slice C (F-3): eliminate duplicate `up --build` in make test-infra

> **Owner:** Slice C. Files owned: `Makefile`,
> `scripts/test-docker-smoke.sh`. No other slice may edit these files.

- [ ] **3.1 Add `SMOKE_LEAVE_UP` env var to test-docker-smoke.sh.**
  - **Blockers:** none
  - **Owner:** Slice C (disjoint; no other slice may edit
    `scripts/test-docker-smoke.sh`).
  - **Vertical slice:** in `scripts/test-docker-smoke.sh`, add support
    for an environment variable `SMOKE_LEAVE_UP=1`. When set, the
    script leaves the stack running on success instead of tearing it
    down. Add a header comment documenting the env var:
    `# SMOKE_LEAVE_UP=1: leave the stack running on success (for callers
    # that will use the stack immediately after, e.g. make test-infra).`
    The default behavior (no env var) remains: tear down on success.
    Ensure the env var is checked at the teardown step (not at the
    bring-up step) so the smoke test's validation logic is unchanged.
  - **Acceptance criteria:**
    - `scripts/test-docker-smoke.sh` with no env var tears down the
      stack on success (default behavior unchanged).
    - `SMOKE_LEAVE_UP=1 scripts/test-docker-smoke.sh` leaves the stack
      running on success.
    - The header comment documents the env var.
    - `bash -n scripts/test-docker-smoke.sh` passes (syntax check).
  - **Verification:** run the smoke test standalone (no env var) and
    assert the stack is torn down; run with `SMOKE_LEAVE_UP=1` and
    assert the stack is left up (measure via `docker compose ps`).

- [ ] **3.2 Remove the duplicate `up --build` from make test-infra.**
  - **Blockers:** 3.1 (the Makefile recipe needs the smoke test's env
    var support before it can skip the second rebuild)
  - **Owner:** Slice C (disjoint; no other slice may edit `Makefile`).
  - **Vertical slice:** in the `Makefile`, locate the `test-infra`
    recipe (around lines 138-142 per the audit report). Modify it to
    set `SMOKE_LEAVE_UP=1` when invoking `scripts/test-docker-smoke.sh`,
    and remove the subsequent `docker compose up -d --build` line
    (since the smoke test now leaves the stack up). The recipe should
    now be: `gen-jsconfig` -> `test-shell` -> `SMOKE_LEAVE_UP=1
bash scripts/test-docker-smoke.sh` -> `test-python` -> `docker
compose down`. Add a comment above the recipe documenting the
    single-rebuild optimization: `# Single rebuild: smoke test leaves
    # the stack up for test-python (F-3, DIA-179).`
  - **Acceptance criteria:**
    - `make test-infra` runs `docker compose up -d --build` exactly
      once (inside the smoke test), not twice.
    - `test-python` runs against the stack the smoke test left up.
    - `docker compose down` still runs at the end (cleanup).
    - The recipe comment documents the optimization.
    - `make test-infra` exits 0 (requires a running Docker daemon;
      per DIA-094, the dev container must be up).
  - **Verification:** `make test-infra` exits 0; inspect the output to
    confirm only one `up --build` invocation.

---

## 4. Slice D (F-4): bats --quick mode for shell edits

> **Owner:** Slice D. Files owned:
> `scripts/__tests__/bats-wrapper.sh`, `package.json` (lint-staged
> section only). No other slice may edit these files.

- [ ] **4.1 Add --quick mode to bats-wrapper.sh.**
  - **Blockers:** none
  - **Owner:** Slice D (disjoint; no other slice may edit
    `scripts/__tests__/bats-wrapper.sh`).
  - **Vertical slice:** in `scripts/__tests__/bats-wrapper.sh`, add
    support for a `--quick` flag. When invoked with `--quick`, the
    script runs two tiers: (1) syntax tier: `bash -n` on all `*.sh`
    files in `scripts/` (or a curated list), `node --check` on all
    `*.mjs` files in `scripts/__tests__/`; (2) suite tier: run the
    three smallest bats suites: `check-host-jq.bats` (3 tests),
    `check-host-lsp.bats` (9 tests), `validate-skills.bats` (23 tests)
    = 35 tests total. Exit 0 only if both tiers pass. Add a header
    comment documenting the `--quick` mode and its curated suite list.
    The default mode (no `--quick`) remains unchanged (runs all 240
    tests).
  - **Acceptance criteria:**
    - `scripts/__tests__/bats-wrapper.sh --quick` runs syntax checks
      - the three curated suites and exits 0 if both tiers pass.
    - The default mode (no `--quick`) is unchanged (runs all 240 tests).
    - The header comment documents the `--quick` mode.
    - `bash -n scripts/__tests__/bats-wrapper.sh` passes (syntax check).
    - The `--quick` mode completes in under 5 s on a typical developer
      machine (measured during implementation).
  - **Verification:** run `scripts/__tests__/bats-wrapper.sh --quick`
    and assert it exits 0; measure the runtime (should be < 5 s).

- [ ] **4.2 Wire --quick mode into lint-staged for \*.sh files.**
  - **Blockers:** 4.1 (the lint-staged entry needs the `--quick` mode
    to exist before it can invoke it)
  - **Owner:** Slice D (disjoint; no other slice may edit
    `package.json`).
  - **Vertical slice:** in `package.json`, locate the existing
    `lint-staged` block (around line 37). Add a `*.sh` entry that
    invokes `scripts/__tests__/bats-wrapper.sh --quick` on staged
    shell scripts. The entry should be: `"*.sh": "scripts/__tests__/bats-wrapper.sh --quick"`.
    Ensure the entry is placed alphabetically (if the block is sorted)
    or at the end (if unsorted). Verify that `package.json` remains
    valid JSON after the edit.
  - **Acceptance criteria:**
    - `package.json` has a `*.sh` entry in the `lint-staged` block.
    - The entry invokes `scripts/__tests__/bats-wrapper.sh --quick`.
    - `package.json` is valid JSON (parse check passes).
    - Staging a `*.sh` file and running `lint-staged` invokes the
      --quick mode (manual verification during implementation).
  - **Verification:** `node -e "require('./package.json')"` exits 0
    (JSON parse check); manually stage a `*.sh` file and run
    `npx lint-staged` to confirm the --quick mode fires.

---

## 5. Slice F (F-7): consolidate PEP 420 conftest.py bootstrap

> **Owner:** Slice F. Files owned:
> `apps/api-server/pyproject.toml`,
> `packages/analytics-pipeline/pyproject.toml`,
> `apps/api-server/tests/conftest.py` (delete),
> `packages/analytics-pipeline/tests/conftest.py` (delete).
> No other slice may edit these files.

- [ ] **5.1 Set pythonpath in pyproject.toml + delete both conftest.py files.**
  - **Blockers:** none
  - **Owner:** Slice F (disjoint; no other slice may edit the files
    listed above).
  - **Vertical slice:** in `apps/api-server/pyproject.toml`, add (or
    update) the `[tool.pytest.ini_options]` section with `pythonpath =
["."]` (or the appropriate relative path to the package root;
    verify by inspecting the existing conftest.py's `sys.path.insert`
    logic). Apply the same change to
    `packages/analytics-pipeline/pyproject.toml`. Verify the pinned
    pytest version in each package supports `pythonpath` (requires
    pytest 7.0+; if < 7.0, escalate to the developer for a fallback
    strategy). Delete both conftest.py files:
    `apps/api-server/tests/conftest.py` and
    `packages/analytics-pipeline/tests/conftest.py`.
  - **Acceptance criteria:**
    - Both pyproject.toml files have `pythonpath` set under
      `[tool.pytest.ini_options]`.
    - Both conftest.py files are deleted.
    - `make test-python` exits 0 (both import-smoke tests pass; this
      is the verification that the pythonpath config works).
    - The pinned pytest version in each package is >= 7.0 (verified
      during implementation; if < 7.0, escalate).
  - **Verification:** `make test-python` exits 0; both
    `test_auth.py` and `test_smoke.py` pass.

---

## 6. Merge phase (orchestrator-driven, not a coder slice)

- [ ] **6.1 Merge all five slices + verify the union passes all gates.**
  - **Blockers:** 1.2, 2.1, 3.2, 4.2, 5.1 (all five slices complete)
  - **Owner:** orchestrator (not a coder slice; merge phase).
  - **Vertical slice:** merge the five worktree branches into the main
    branch (squash merge per `.sdd/dev-infra` ADR 3). Resolve any
    merge conflicts (none expected; all slices are disjoint). After
    the merge, run the full gate suite to confirm no cross-slice
    regression: `make test-config` + `make test-shell` + `pnpm
verify:*` + `make test-python`. Record the gate outputs as
    verification evidence.
  - **Acceptance criteria:**
    - All five slices merge cleanly (no conflicts, or conflicts
      resolved manually).
    - `make test-config` exits 0.
    - `make test-shell` exits 0.
    - `pnpm verify:*` (format, js, js-tests, python) all exit 0.
    - `make test-python` exits 0.
    - Gate outputs are recorded as verification evidence.
  - **Verification:** all gates exit 0; verification evidence is
    committed to the merge report.
