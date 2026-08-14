# ana021 -- Full test-suite audit (DIA-139)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: session ses_fff77a14effezT82MKtHSrdJre; live timing runs 2026-08-14
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

Auditor: @analyzer (DIA-139)
Date: 2026-08-14
Scope: every test artifact on the main working tree (excludes the 13 stale
worktrees under .worktrees/, which are not part of any gate). Prior test work
(DIA-115, DIA-124, DIA-125, DIA-126, DIA-127) was read and built upon -- no
finding here contradicts those tickets; several re-surface as "still open" or
"partial" where prior fixes introduced new asymmetries.

---

## 0. Test inventory (main tree)

```
Test surface                  Count   Runner     Typical time   Wired into
------------------------------ ----- ---------- -------------- -----------------------
scripts/__tests__/*.bats        240   bats        24.6 s        make test-shell
scripts/__tests__/batch-d-infra  43   node:test    0.3 s        make test-config
apps/author-studio                2   vitest       0.2 s        turbo test (cached 45ms)
packages/data-contracts           2   vitest       0.2 s        turbo test
packages/editor-engine           96   vitest       0.2 s        turbo test
packages/phonetics-core          24   vitest       0.3 s        turbo test
apps/api-server (pytest)          1   pytest       0.0 s        make test-python
packages/analytics-pipeline       1   pytest       0.0 s        make test-python
------------------------------ -----
TOTAL                           409

Tests per file (top 10):
  81  packages/editor-engine/src/view/opusFormattingFilter.test.ts
  43  scripts/__tests__/batch-d-infra.test.mjs
  24  packages/phonetics-core/src/atlas/load-atlas.test.ts
  23  scripts/__tests__/validate-skills.bats
  19  scripts/__tests__/worktrees.bats
  17  scripts/__tests__/audit-agent-tool-coverage.bats
  16  scripts/__tests__/context7-docs.bats
  14  scripts/__tests__/check-pin-sync.bats
  12  scripts/__tests__/dev-entrypoint.bats
  12  scripts/__tests__/jsonl-cross-check.bats
```

Packages with NO test script and NO tests:
  apps/publishing-platform, packages/stress-lang-core,
  packages/visualizer-2d, packages/visualizer-3d.

Hooks:
  .husky/pre-commit -> scripts/verify-pre-commit.sh (lint-staged autofix)
  .husky/pre-push   -> scripts/verify-pre-push.sh  (full suite)

No CI config is present (.github/, .gitlab-ci.yml, .circleci/ all absent).
pre-push is the only "CI-equivalent" -- if pre-push does not run it, it does
not run anywhere automatically.

---

## 1. EXECUTION-ORDER findings

Current pre-push order (verify-pre-push.sh, lines 110-115):

```
Step  Gate                        Measured time   Cumulative
----  --------------------------  -------------   ----------
  1   make test-shell               24.6 s          24.6 s   <-- HEAVIEST
  2   make test-config               1.6 s          26.2 s
  3   pnpm verify:format             1.2 s          27.4 s
  4   pnpm verify:js (lint+tsc)      2.8 s          30.2 s
  5   pnpm verify:js-tests (turbo)   0.05 s (cache) 30.3 s
  6   pnpm verify:python             1.5 s          31.8 s
                                          TOTAL ~ 32 s

Makefile dependency order (make test-infra, Makefile lines 138-142):
  test-infra -> gen-jsconfig, test-shell, test-docker-smoke.sh,
                docker compose up -d --build, test-python, docker compose down.
  test-config -> test-interview, test-skills, docker compose config --quiet,
                 validate-opencode-config, validate-agent-names,
                 validate-output-contracts, validate-reviewer-sections,
                 validate-handoff, test-ticket-gate, audit-agent-tool-coverage
                 (x2), batch-d-infra.test.mjs.
  test-shell  -> check-pin-sync, check-host-jq, check-host-lsp,
                 test-opencode-docker, bats-wrapper.
```

### F-1  pre-push runs the slowest gate FIRST [severity: High]

- File: scripts/verify-pre-push.sh:110
- Problem: `make test-shell` (24.6 s, 240 bats tests) runs before every other
  gate. A formatting typo or a typecheck regression waits 25 seconds before
  being reported.
- Why it matters: violates the fast-to-fail principle -- the cheapest signals
  (format, typecheck) should surface first; a developer iterating on a
  formatting fix burns 25 s per cycle waiting for bats before the formatter
  rejects their commit.
- Fix: reorder verify-pre-push.sh so the step ladder is
  (a) verify:format, (b) verify:js, (c) verify:js-tests (turbo cache),
  (d) test-config, (e) verify:python, (f) test-shell LAST.
  Estimated new TTF for a format-only failure: 32 s -> 1.2 s.

### F-2  turbo `test` has `dependsOn: ["build"]` for unknown packages [severity: Medium]

- File: turbo.json:21-25
- Problem: the BASE `test` task inherits `dependsOn: ["build"]`. DIA-125 added
  per-package overrides for the four packages that do not need build output
  (editor-engine, data-contracts, phonetics-core, author-studio). Any NEW
  package with a `test` script will silently inherit `dependsOn: ["build"]`
  and force an unnecessary build before tests.
- Why it matters: new packages get slow tests by default; the override list
  is a hidden maintenance surface.
- Fix: flip the default. Base `test` should be `dependsOn: []`; packages that
  genuinely need build output (none currently do) should opt IN. The current
  per-package override block becomes empty and can be removed.

### F-3  test-infra rebuilds the stack unnecessarily after the smoke test [severity: Low]

- File: Makefile:138-142
- Problem: `bash scripts/test-docker-smoke.sh` already builds and tears down
  the stack internally; the recipe then runs `docker compose up -d --build`
  AGAIN just so test-python has a stack to run against. Two full image
  rebuilds per `make test-infra`.
- Why it matters: ~30-60 s wasted per test-infra run.
- Fix: either (a) have the smoke test leave the stack UP on success (and
  skip the second `up --build`), or (b) have test-python use the stack the
  smoke test just brought up.

---

## 2. FAST-TO-FAIL findings

### F-4  test-shell contains a 24.6 s monolithic run with no early-exit tiers [severity: Medium]

- File: scripts/__tests__/bats-wrapper.sh
- Problem: all 240 bats tests run in one pass; there is no tier-1 / tier-2
  split. A regression in a slow suite (e.g. worktrees.bats with its 19
  subprocess-spawning tests) blocks feedback on the rest.
- Why it matters: when iterating on a shell script, 25 s per cycle is slow
  enough to break the red-green loop.
- Fix: add a `--quick` mode that runs only the syntax-check (bash -n, node
  --check) + the three smallest suites (check-host-jq.bats:3,
  check-host-lsp.bats:9, validate-skills.bats:23 = 35 tests). Wire it into
  lint-staged for *.sh changes so shell edits get a sub-3 s feedback loop.

### F-5  vitest runs are serialized by container exec overhead [severity: Low]

- File: root package.json `test` script
- Problem: turbo test runs four vitest suites in parallel, but each incurs
  ~900 ms of `docker compose exec` overhead. Wall-clock for all four (cold
  cache) is ~4 x 1 s = 4 s instead of ~1 s.
- Why it matters: minor, but visible on every pre-push.
- Fix: already mitigated by turbo caching (45 ms when warm). No further
  action needed unless the suite count grows.

---

## 3. DUPLICATE findings

### F-6  /home/qualt regression guard tested in BOTH hook bats files [severity: Low]

- Files:
    scripts/__tests__/verify-pre-commit.bats:134, :151  (2 tests)
    scripts/__tests__/verify-pre-push.bats:205, :222    (2 tests)
- Problem: the four tests assert the same `grep -lF '/home/qualt'` behavior
  that is implemented identically in both hook scripts. The hook scripts
  themselves contain byte-identical `guard_no_home_qualt` functions (compare
  verify-pre-commit.sh:51-62 to verify-pre-push.sh:72-83).
- Why it matters: two tests for one behavior is the textbook dup; if the
  guard logic changes, both bats files must change in lockstep.
- Fix: extract `guard_no_home_qualt` into a shared shell helper
  (scripts/guards/home-qualt.sh) sourced by both hooks; keep ONE bats test
  against the shared helper. The hook-level tests can then assert "the guard
  is sourced and runs" without re-implementing the grep.

### F-7  conftest.py is duplicated verbatim across both Python packages [severity: Low]

- Files:
    apps/api-server/tests/conftest.py (18 lines)
    packages/analytics-pipeline/tests/conftest.py (19 lines)
- Problem: both files add their parent directory to sys.path in identical
  fashion (PEP 420 namespace-package bootstrap).
- Why it matters: if the sys.path bootstrap logic needs to change (e.g.
  switch to pytest's rootdir or pyproject.toml `tool.pytest.ini_options`),
  two files must change.
- Fix: move the bootstrap into a single shared conftest at the repo root, or
  set `pythonpath` in each package's pyproject.toml `tool.pytest.ini_options`
  and delete both conftest.py files.

### F-8  mock_docker_down callers still use their own boilerplate around it [severity: Informational]

- Files: scripts/__tests__/eval-lite.bats:6 uses, check-host-lsp.bats:3 uses
- Problem: DIA-125 consolidated `mock_docker_down` itself, but the callers
  still build their own PATH isolation around it. Not a true dup (the
  surrounding context differs), but the pattern repeats enough to be a DRY
  candidate for Phase 2.
- Fix: no immediate action; revisit when a third caller appears.

---

## 4. STALE findings

### F-9  author-studio example-store test is documented scaffold [severity: Informational]

- File: apps/author-studio/src/stores/example-store.test.ts:1-3
- Problem: the TODO comment at the top admits this is template boilerplate
  for `useCounterStore` (a scaffold, not domain logic). 2 tests, no real
  coverage.
- Why it matters: a reader skimming test counts may mistake "2 tests passing"
  for meaningful coverage of author-studio.
- Fix: leave as-is until a real store exists (per author-studio AGENTS.md
  known-gaps); the TODO comment is already honest about the state.

### F-10  Python import-only smoke tests pin nothing behavioral [severity: Informational]

- Files:
    apps/api-server/tests/test_auth.py:21-24 (1 test, 24 lines)
    packages/analytics-pipeline/tests/test_smoke.py:23-27 (1 test, 27 lines)
- Problem: each test asserts only that the module imports cleanly via the
  namespace-package path. No behavioral contract. DIA-124 removed the
  docstring-pin tests (flake-on-doc-edit) but kept the import tests.
- Why it matters: the docstrings of both test files explicitly document the
  intent: "pins the import path so a regression fails loudly". They are
  honest scaffolds, not hidden stale tests.
- Fix: leave in place as seam-markers until real JWT/OAuth or analytics
  logic lands.

---

## 5. UNNECESSARY findings

### F-11  No tests are truly tautological [severity: N/A (clean)]

- I grepped for empty asserts, always-pass mocks, and `expect(x).toBeDefined()`
  across all .test.ts / .test.mjs / .bats files: zero hits.
- Every vitest test asserts specific values; every bats test uses the
  assert_status / assert_output_contains / assert_file_contains helpers from
  test-helper.bash; batch-d-infra asserts committed-file contents; pytest
  tests assert import identity.
- Conclusion: the prior DIA-124 / DIA-125 cleanup did its job. No tests need
  deletion on tautology grounds.

---

## 6. VERIFICATION-HONESTY findings

### F-12  No fake verification detected [severity: N/A (clean)]

Checks performed:
  - `expect(x).toBeDefined()` across all .test.ts: 0 hits
  - `assert()` with no arguments: 0 hits
  - `expect(true).toBe(true)` or similar tautologies: 0 hits
  - Tests with only mocked paths (no real call-through): the Orchestrator
    test (DIA-127) is explicitly zero-mock; the load-atlas test reads the
    real atlas file; opusFormattingFilter creates real CM6 state; no
    always-pass mocks observed.
  - Tests that never run in any gate: every .test.ts / .bats is reachable
    from either `make test-shell`, `make test-config`, `pnpm test` (turbo),
    or `make test-python`. No orphaned test files.

### F-13  batch-d-infra.test.mjs re-implements a JSONC parser [severity: Informational]

- File: scripts/__tests__/batch-d-infra.test.mjs:49-89
- Problem: `stripJsonc` is a hand-rolled JSONC comment stripper. The OMO
  slim config is JSONC; opencode ships a JSONC parser in node_modules.
- Why it matters: a bug in the hand-rolled parser (e.g. failure on line
  continuations inside strings, multi-line /* */ edge cases) would silently
  mis-parse the config under test, masking real regressions.
- Fix: replace `stripJsonc` with a dependency-free but proven parser (e.g.
  `jsonc-parser` if available in node_modules; otherwise keep and add a
  negative test asserting known-bad JSONC fails to parse). Not urgent --
  the current implementation handles the two comment forms opencode uses.

### F-14  validate-skills.bats has 23 tests but validates only YAML frontmatter [severity: Informational]

- File: scripts/__tests__/validate-skills.bats (23 tests)
- Problem: the name "validate-skills" is broad; the actual validation is
  "SKILL.md frontmatter: valid YAML, name/description present,
  name==dirname". Body content is not checked.
- Why it matters: a reader could mistake the suite for covering SKILL.md
  behavioral correctness; it covers only the structural contract.
- Fix: rename the suite or add a docstring explaining the scope (the bats
  file already has a header comment, but the `@test` titles do not make the
  scope obvious).

---

## 7. FIXES-NEEDED summary

Prioritized by impact (time-saved per developer-cycle):

```
Priority  Ticket  Severity  What to fix                              Est. time
--------  ------  --------  ---------------------------------------  ---------
 P0       F-1     High      Reorder verify-pre-push.sh: slowest LAST  15 min
 P1       F-2     Medium    Flip turbo.json test default to []        15 min
 P1       F-4     Medium    Add bats --quick tier for shell edits     45 min
 P2       F-3     Low       Skip duplicate `up --build` in test-infra 30 min
 P2       F-6     Low       Extract home-qualt guard + dedup bats     30 min
 P3       F-7     Low       Consolidate conftest.py bootstrap         20 min
 P3       F-13    Info      Replace stripJsonc with proven parser     30 min
 --       F-9     Info      Leave example-store TODO as-is             -
 --       F-10    Info      Leave Python import smokes as seam-markers -
```

Recommended single commit for P0: reorder verify-pre-push.sh (F-1). This
alone cuts the TTF for a format/typecheck failure from ~32 s to ~1.2 s.

---

## 8. DRY-HELPER / OPTIMIZATION findings

### F-15  bats already has a strong shared helper (DIA-125 delivered) [severity: N/A]

- File: scripts/__tests__/test-helper.bash (448 lines)
- Already provides: assert_status, assert_output_contains,
  assert_output_not_contains, assert_file_exists, assert_file_not_exists,
  assert_file_contains, mock_docker, mock_docker_down,
  setup_hermetic_host_context, setup_dev_stack_tree,
  install_check_tools_fakes, setup_check_tools_tree, setup_pin_sync_tree,
  require_unshare, run_entrypoint_ns, run_entrypoint_xvfb_ns.
- Used by 23 of 25 bats files. Good DRY surface.

### F-16  vitest setup boilerplate could be shared across 4 packages [severity: Low]

- Files: apps/author-studio/vitest.config.ts, packages/data-contracts/
  vitest.config.ts, packages/editor-engine/vitest.config.ts,
  packages/phonetics-core/vitest.config.ts.
- Problem: four near-identical vitest configs (node env, src/**/*.test.ts
  include).
- Fix: lift into a root `vitest.workspace.ts` or a shared
  `@poetry/vitest-config` package. Not urgent -- the current duplication is
  4 x 6 lines = 24 lines total.

### F-17  turbo test is already cached; no further parallelization win [severity: N/A]

- Cold-cache: ~4 x 1 s = 4 s wall-clock.
- Warm-cache: 45 ms (FULL TURBO).
- The 4 packages' test scripts run in parallel inside turbo. No further
  parallelization is possible without moving away from per-package vitest
  (which would lose the cache boundary).

### F-18  Consider a `make test-fast` tier [severity: Recommendation]

- Add a new Makefile target that runs ONLY the sub-5 s gates:
  `test-config` (1.6 s) + turbo test (45 ms cached) + verify:format (1.2 s)
  + verify:js (2.8 s). Total ~5.7 s cold.
- Wire `make test-fast` into lint-staged as a follow-up to autofix for
  developers who want an explicit "pre-push dry-run" without running bats.

---

## 9. Cross-cutting observations

### O-1  No CI pipeline exists

- There is no .github/workflows/, .gitlab-ci.yml, .circleci/, or Jenkinsfile.
- pre-push is the ONLY automated verification gate. If a developer pushes
  with `--no-verify` (or from a client without husky installed), nothing
  runs.
- Recommendation: add a minimal CI workflow (GitHub Actions) that runs
  `make test-config` + `make test-shell` + `pnpm test` + `pnpm verify:python`
  on every PR. pre-push is a developer convenience; CI is the safety net.

### O-2  Four packages have no tests at all

- apps/publishing-platform, packages/stress-lang-core, packages/visualizer-2d,
  packages/visualizer-3d: no `test` script in package.json, no test files.
- These are out of scope for DIA-139 (this audit reports on what exists, not
  on what should exist). Noted here for the backlog.

### O-3  .worktrees/ holds 386 MB of stale test copies

- 13 old worktrees under /workspace/.worktrees/ contain identical copies of
  every test file. These are gitignored and NOT picked up by any gate (bats
  discovery is scoped to scripts/__tests__; vitest is scoped per-package;
  pytest is scoped per-package).
- Recommendation: delete stale worktrees to reclaim disk. Not a test
  correctness issue.

---

## 10. Sections where evidence is incomplete

- E-1  `make test-python` and `make test-infra` were NOT run end-to-end by
  the analyzer: they require a running Docker daemon with the dev container
  (the container IS running in this session, but test-infra's smoke test
  rebuilds images, which is a ~2 min operation out of scope for a read-only
  audit). test-python's 2 pytest runs were executed manually in-container
  and confirmed green (1 passed each).
- E-2  CI pipeline: cannot be audited because none exists (O-1).
- E-3  Author-studio component tests: documented as not-yet-written
  (author-studio AGENTS.md known-gaps). Nothing to audit.

---

## Appendix A -- gate wiring diagram

```
                    .husky/pre-commit
                           |
                           v
                scripts/verify-pre-commit.sh
                           |
                           v
               lint-staged --allow-empty
         (eslint --fix, prettier --write,
          ruff fix+format, bash -n)
                           |
                           v
                  [commit accepted]


                    .husky/pre-push
                           |
                           v
                scripts/verify-pre-push.sh
                           |
       +---------+---------+---------+---------+---------+
       |         |         |         |         |         |
       v         v         v         v         v         v
  test-shell  test-cfg  verify:  verify:  verify:  verify:
   (24.6 s)   (1.6 s)   format    js      js-tests python
                         (1.2 s)  (2.8 s)  (0.05 s) (1.5 s)
                                                   (cached)

  make test-infra (on-demand, heavy):
      gen-jsconfig -> test-shell -> test-docker-smoke.sh
        -> docker compose up --build -> test-python
        -> docker compose down
```

---

## Appendix B -- prior-ticket reconciliation

| Prior ticket | Status | Relation to this audit |
|--------------|--------|------------------------|
| DIA-115 (hook test coverage) | OPEN | Its edge-case recommendations were largely delivered by DIA-124/125/126. This audit finds one remaining asymmetry (F-6, the /home/qualt dup). |
| DIA-124 (Phase 0 safety wins) | OPEN (applied) | Docstring-pin tests removed; author-studio now fails loudly and is wired back in via DIA-126. Import-only Python smokes kept deliberately (F-10). |
| DIA-125 (Phase 1 dedup) | OPEN (applied) | bats helpers consolidated, it.each applied, bash -n auto-discovered. Remaining DRY surface (F-7 conftest.py, F-16 vitest configs) is small. |
| DIA-126 (Phase 2 critical gaps) | OPEN (applied) | author-studio + data-contracts now have real tests. publishing-platform / stress-lang-core / visualizer-2d / visualizer-3d remain uncovered (O-2). |
| DIA-127 (Phase 3 orchestrator contract) | DONE | Orchestrator.test.ts is the strongest test in the suite (zero mocks, real behavior). No findings against it. |

---

End of report.
