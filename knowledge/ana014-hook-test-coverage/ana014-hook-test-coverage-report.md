# Pre-commit / Pre-push Hook Test Coverage Audit

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: /workspace/.husky/pre-commit, /workspace/.husky/pre-push,
  /workspace/scripts/verify-pre-commit.sh, /workspace/scripts/verify-pre-push.sh,
  /workspace/turbo.json, /workspace/Makefile, /workspace/package.json,
  /workspace/scripts/__tests__/*.bats
confidence: High
shelf-registration: .opencode/memory-shelf.yaml (shelf.analyses)
-->

## Scope

Trace the full chain from husky entrypoints through gate scripts, turbo pipeline,
Makefile targets, and the bats unit suite. For each zone (pre-commit, pre-push,
turbo tasks, Makefile gates, Python gates, lint-staged config), evaluate:

1. Edge cases not covered.
2. Failure-mode loudness (correct non-zero exit, silent-pass paths).
3. Behavior variants (caching, parallelism, timeout, non-interactive shell).
4. Cross-zone coverage vs. AGENTS.md gate table (shell/config/python/docker/infra).
5. Concrete fixes ranked by impact/effort.

Files read: `.husky/pre-commit`, `.husky/pre-push`, `.husky/_/*` (husky v9 shim),
`scripts/verify-pre-commit.sh` (81L), `scripts/verify-pre-push.sh` (83L),
`scripts/verify-python.sh` (38L), `scripts/lint-python-files.sh` (55L),
`scripts/test-docker-smoke.sh` (320L), `scripts/test-ticket-gate.sh` (107L),
`scripts/__tests__/{bats-wrapper,test-helper,verify-pre-commit,verify-pre-push,verify-python,lint-python-files}.bats`,
`turbo.json` (36L), `package.json` (70L), `Makefile` (232L).

## Gate map (what runs where)

```
                       git commit                    git push
                          |                              |
                   .husky/pre-commit              .husky/pre-push
                          |                              |
              scripts/verify-pre-commit.sh   scripts/verify-pre-push.sh
                   |              |               |              |
           guard_no_home_qualt  container?   guard_no_home_qualt  container?
                   |              |               |              |
                   v              v               |              v
             lint-staged --allow-empty           |   pnpm verify:format
           (eslint --fix + prettier + ruff +     |   pnpm verify:js
            bash -n via package.json config)     |     = pnpm lint && pnpm typecheck
                                                 |     = turbo run lint && turbo run typecheck
                                                 |   pnpm verify:js-tests
                                                 |     = pnpm test
                                                 |     = turbo test
                                                 |   pnpm verify:python
                                                 |     = scripts/verify-python.sh
                                                 |       = ruff check + ruff format + pytest
                                                 |         in apps/api-server
                                                 |         in packages/analytics-pipeline
                                                 |
                                                 v
                                   (container down -> exit 0, WARN)

Makefile targets (on-demand, NOT in hooks):
  test-shell    = check-pin-sync + check-host-jq + check-host-lsp
                  + test-opencode-docker + batswrapper.sh (24 bats files)
  test-config   = test-interview + test-skills + validate-opencode-config
                  + validate-agent-names + validate-output-contracts
                  + validate-reviewer-sections + validate-handoff
                  + test-ticket-gate + 2x audit-agent-tool-coverage
  test-python   = pytest in 2 packages (in-container)
  test-infra    = gen-jsconfig + test-shell + test-docker-smoke + test-python
  eval-lite     = standalone (locked decision: deliberately not in hooks)
```

## Bats coverage summary (per hook script)

| Script under test           | bats file               | Tests |
| --------------------------- | ----------------------- | ----- |
| verify-pre-commit.sh        | verify-pre-commit.bats  | 7     |
| verify-pre-push.sh          | verify-pre-push.bats    | 7     |
| verify-python.sh            | verify-python.bats      | 4     |
| lint-python-files.sh        | lint-python-files.bats  | 6     |
| **TOTAL pre-commit/push**   |                         | **24**|

For comparison, the entire test-shell suite (bats) has 100+ tests across 24 bats
files covering dev-stack, dev-entrypoint, check-tools, check-pin-sync,
check-host-lsp, check-host-jq, opencode-docker, validate-agent-names,
validate-handoff, validate-skills, jsonl-cross-check, session-log, eval-lite,
context7-docs, audit-agent-tool-coverage, author-studio-probe-guard, gen-jsconfig,
lint-python-files, verify-pre-commit, verify-pre-push, verify-python.

## Findings (by severity)

### CRITICAL

**C1. Turbo `test` task inputs cache masks source changes.**
- `turbo.json` lines 21-25 declare `test` with `inputs: ["src/**/*.test.ts", "src/**/*.spec.ts", "src/**/*.test.py"]`.
- Turbo uses content-based caching over the declared inputs. If only source
  files change (no test files touched), turbo returns the cached test result.
- **Impact:** a regression introduced in source code is invisible to
  `pnpm verify:js-tests` / `turbo test`. The pre-push hook prints
  "verification passed" while tests against the new source have not actually
  run.
- **Fix:** remove the `inputs` restriction from the `test` task so turbo uses
  its default (all package files), or add `src/**` to inputs.
  `inputs: ["src/**", "src/**/*.test.ts", "src/**/*.spec.ts", "src/**/*.test.py"]`
  (or simply drop `inputs` for `test`).
- **Effort:** 1 line. Impact: high.

**C2. `make test-shell` (the entire 100+ test bats suite) is NOT wired into any hook.**
- The bats suite is the primary safety net for all shell dev-infra artifacts
  (verify-pre-commit.sh, verify-pre-push.sh, verify-python.sh, lint-python-files.sh,
  validate-agent-names.sh, validate-handoff.sh, dev-stack.sh, dev-entrypoint.sh,
  check-pin-sync.sh, etc.). A developer can break any of these, commit, and push
  without the suite running once.
- `make test-shell` requires no Docker daemon (host-runnable), so it COULD run
  in the pre-push hook alongside the verify steps.
- **Impact:** silent regression of any shell gate (including the hooks themselves).
  The only signal comes from manual `make test-shell` / `make test-infra` runs.
- **Fix:** add `make test-shell` as a pre-push step (host-runnable, no container
  needed) — e.g. `run_workspace "make test-shell"` before the pnpm steps, but
  executed on the HOST directly since bats is vendored and runs without the
  container. Alternatively, wire a subset (the 4 hook/verify bats files) into
  verify-pre-push.sh itself.
- **Effort:** 1-2h. Impact: very high.

**C3. `make test-config` (all OpenCode config validators) is NOT wired into any hook.**
- test-config runs 8 validators: validate-opencode-config.sh,
  validate-agent-names.sh, validate-output-contracts.sh,
  validate-reviewer-sections.sh, validate-handoff.sh, test-ticket-gate.sh,
  2x audit-agent-tool-coverage.sh + test-interview + test-skills.
- A developer can commit broken .opencode config (e.g., malformed JSONC,
  agent-name drift, broken HANDOFF schema) and it goes undetected until manual
  `make test-config`.
- **Impact:** silent drift of the opencode configuration surface (the exact thing
  that triggered ana013's 50-file audit).
- **Fix:** add `make test-config` to pre-push (host-runnable, no container).
- **Effort:** 1-2h. Impact: high.

### HIGH

**H1. No timeout on turbo invocations; hook can hang indefinitely.**
- `verify-pre-push.sh` runs `run_workspace "pnpm verify:..."` with no timeout.
  A hung turbo task (dependency download stall, deadlock, network hang) blocks
  the push forever.
- Pre-commit has the same issue with `npx lint-staged`.
- **Fix:** wrap each `run_workspace` with `timeout 600` (10 min) or
  configurable `$HOOK_TIMEOUT`.
- **Effort:** 30 min. Impact: medium-high.

**H2. No test for the `pnpm verify:js` multi-step failure chain.**
- `pnpm verify:js` = `pnpm lint && pnpm typecheck`. Bats tests verify-pre-push
  only test that "one step fails, exit 1". There is no test that:
  (a) lint failure skips typecheck (current behavior: yes, because `&&`);
  (b) typecheck failure surfaces the typecheck error, not the lint error;
  (c) if `turbo` itself exits non-zero, which sub-step failed is identifiable.
- **Fix:** add 2-3 bats tests with FAKE_DOCKER_FAIL_STEP="lint" vs
  FAKE_DOCKER_FAIL_STEP="typecheck" and assert the right step name is surfaced.
- **Effort:** 30 min. Impact: medium.

**H3. `turbo lint` has empty config `{}` — no `inputs`, no `dependsOn`.**
- Empty config means turbo uses default inputs (all files). Fine for cache
  invalidation, but: if a package has NO `lint` script, turbo silently skips it
  with no warning. No test asserts that all workspaces that should be linted
  actually have a `lint` script.
- Publishing-platform, data-contracts, stress-lang-core, visualizer-2d,
  visualizer-3d: no visible lint script. They may silently skip.
- **Fix:** either add `"lint"` scripts (even no-ops) or use turbo's
  `--filter` to assert coverage. Add a CI-only check that enumerates workspace
  packages and reports those without `lint`.
- **Effort:** 2h. Impact: medium.

**H4. Docker daemon down path in verify-pre-commit is tested, but daemon-down
path in verify-pre-push is NOT explicitly tested.**
- verify-pre-commit.bats tests "container down -> exit 1" (correct, DIA-094).
- verify-pre-push.bats tests "container down -> exit 0 WARN" (correct).
- But neither tests `FAKE_DOCKER_DAEMON_UP=no` (docker info fails entirely).
  The `container_running()` function runs `docker compose ps 2>/dev/null | grep -qx dev`.
  If the daemon is down, stderr is swallowed, grep fails, container_running
  returns 1. Behavior is correct (pre-commit exits 1, pre-push exits 0 WARN),
  but this failure mode is not in the bats matrix.
- **Fix:** add one test per hook: `FAKE_DOCKER_DAEMON_UP=no` and assert the
  correct exit code and message.
- **Effort:** 30 min. Impact: medium.

**H5. Python gate failure modes not all tested.**
- verify-python.bats covers: ruff order, ruff-fail aborts pytest, venv reuse,
  venv bootstrap.
- Missing: (a) pytest failure exit code propagation; (b) second package
  (analytics-pipeline) failure when first succeeds; (c) `uv` missing from PATH
  (currently fails with ugly "command not found" instead of a clean error);
  (d) ruff format --check failure path (only ruff check failure tested).
- **Fix:** add 4 bats tests covering these branches.
- **Effort:** 1h. Impact: medium.

**H6. No test for lint-staged configuration validity.**
- package.json `lint-staged` block maps globs to commands. If a glob is
  malformed (e.g., invalid brace expansion), lint-staged may silently skip
  files. If a command is removed (e.g., `bash -n` for *.sh), shell scripts
  bypass syntax check on commit.
- **Fix:** add a test (bats or Makefile target) that parses package.json and
  asserts the canonical lint-staged keys exist: `*.{js,ts,...}`, `*.{css,...}`,
  `apps/api-server/**/*.py`, `packages/analytics-pipeline/**/*.py`, `*.sh`.
- **Effort:** 1h. Impact: medium.

### MEDIUM

**M1. No test for non-interactive shell (no TTY) behavior.**
- Hooks run under git, not an interactive shell. No TTY, no `$TERM`.
  `run_workspace` uses `bash -lc "$cmd"` — a login shell that sources ~/.profile.
  In the container, ~/.profile may do unexpected things (e.g., the VOLTA_HOME
  path prepend the verify-pre-commit.bats comment mentions at line 79-82).
- The existing bats workaround (temp HOME) is good but only in 2 tests.
  Production runs depend on the dev user's ~/.profile being benign.
- **Fix:** document this dependency in AGENTS.md §6 or add a probe.

**M2. No test for CI environment (hostname != poetry-dev, no dev container).**
- In GitHub Actions / CI, hostname is the runner, not poetry-dev.
  `is_in_dev_container` returns false. `container_running` returns false (no
  docker or no dev container). Pre-commit hard-fails with "dev container not
  running". Pre-push warns and exits 0.
- This means: in CI, pre-commit is a hard blocker unless `--no-verify` is used.
  This is probably intentional but not documented or tested.
- **Fix:** add a `POETRY_SKIP_CONTAINER_CHECK=1` escape hatch or document
  that CI uses `git commit --no-verify` + relies on CI's own gates.

**M3. No test for COMMANDS_DIR missing.**
- `guard_no_home_qualt` runs `grep -lF '/home/qualt' "$COMMANDS_DIR"/*.md 2>/dev/null || true`.
  If `$COMMANDS_DIR` does not exist, the glob expands literally, grep fails,
  `|| true` swallows. Guard silently passes.
- Not a real-world problem (the dir always exists in the repo), but the silent
  pass when the guard's target is missing is a defensive-programming gap.
- **Fix:** add an explicit `[ -d "$COMMANDS_DIR" ] || exit 2` (INFRA).

**M4. No test for file renames / binary files / submodule changes in lint-staged.**
- lint-staged skips binary files and non-matched patterns. Submodule changes
  don't match any glob. Renames are treated as add+delete.
- Not actually broken, but no test proves the behavior.
- **Fix:** add a bats test for lint-python-files.sh with a binary file path —
  assert it is skipped with the out-of-scope diagnostic.

**M5. No test for `turbo typecheck` and `turbo lint` actually having workspaces
that define the scripts.**
- If a workspace lacks a `lint` script, turbo silently skips it. This could mask
  a workspace that should be linted but has no script.
- **Fix:** add a script that enumerates all workspace packages and asserts they
  have lint+typecheck scripts (or explicitly opt out).

**M6. `turbo.json` itself is NOT validated by `make test-config`.**
- validate-opencode-config.sh validates OpenCode JSONC. Nobody validates
  turbo.json, package.json, pnpm-workspace.yaml, or the husky scripts.
- A malformed turbo.json (e.g., missing `$schema`, invalid task config) would
  silently break `turbo run lint/typecheck/test` without a gate catching it.
- **Fix:** add `turbo --dry-run lint typecheck test >/dev/null` as a pre-push
  sanity check (verifies turbo.json parses and all tasks are resolvable).
- **Effort:** 30 min.

**M7. `test-docker-smoke.sh` has no bats/unit test.**
- The 320-line smoke test is a hand-written bash script with ad-hoc assertions.
  It is tested only by running it. No fixture-driven bats tests.
- This is acceptable given it requires a real Docker daemon, but the helper
  functions (`wait_healthy`, probe logic) are untested.
- **Fix:** extract the helpers and add bats tests with a fake docker.

### LOW

**L1. No test for `--no-verify` bypass detection.**
- Developers can bypass with `git commit --no-verify`. Not detectable by design.
  The hooks cannot police this.

**L2. No test for parallel turbo task interference.**
- turbo runs workspace tasks in parallel by default. If two workspaces share
  state (e.g., a common dist/ directory), parallel writes could race.
- Not a current problem (workspaces are isolated), but no test asserts isolation.

**L3. Hook scripts are not in `bash -n` allowlist for the husky files.**
- bats-wrapper.sh runs `bash -n` on 23 shell artifacts. The husky files
  themselves (`.husky/pre-commit`, `.husky/pre-push`) are NOT validated.
- They're simple (`bash scripts/verify-pre-commit.sh`) but still, adding them
  costs nothing.

**L4. `scripts/lint-python-files.sh` has a subtle edge case.**
- If `api_files` is empty but `pipeline_files` is not, the
  `run_ruff apps/api-server "${api_files[@]}"` invocation with an empty array
  would expand to `run_ruff apps/api-server` (no paths), which cds into the
  package and runs `ruff check --fix .` — linting the WHOLE package.
- The script guards against this in `run_ruff()` with `if [ "$#" -gt 0 ]`,
  but the array expansion `run_ruff apps/api-server "${api_files[@]}"` would
  pass `api_files` as separate args after `$pkg`. Let me re-read...
- Actually: `run_ruff() { local pkg="$1"; shift; if [ "$#" -gt 0 ]; then ...`
  The shift removes `pkg`, then the remaining args are the files. If `api_files`
  is empty, then after shift, `$#` is 0. Guard works. No bug.

**L5. verify-pre-commit.sh and verify-pre-push.sh duplicate ~50 lines of
boilerplate** (container_running, run_workspace, guard_no_home_qualt).
- Not a coverage gap, but the duplication invites drift.
- **Fix:** extract to scripts/lib/hook-common.sh.

## Behavior-variant coverage

| Variant                       | Covered? | Notes                                      |
| ----------------------------- | -------- | ------------------------------------------ |
| Container up, host            | YES      | 7 tests in each bats file                  |
| Container down, host          | YES      | pre-commit: exit 1, pre-push: exit 0 WARN  |
| Inside container              | YES      | direct invocation tested                   |
| Path with spaces              | YES      | D2 regression test                         |
| /home/qualt guard dirty       | YES      | exit 1 before container detection          |
| /home/qualt guard clean       | YES      | passes through                             |
| Delegated step failure        | YES      | pre-push: exit 1 on any step               |
| Empty commit (--allow-empty)  | YES      | pre-commit only (correct)                  |
| Docker daemon entirely down   | NO       | H4 gap                                     |
| Multi-step chain ordering     | PARTIAL  | lint -> typecheck skip not tested          |
| Timeout / hang                | NO       | H1 gap                                     |
| Non-interactive shell (no TTY)| NO       | M1 gap                                     |
| CI environment                | NO       | M2 gap                                     |
| COMMANDS_DIR missing          | NO       | M3 gap                                     |
| Merge conflict state          | NO       | not tested, but lint-staged handles        |
| Initial commit (no HEAD)      | NO       | not tested, but not a realistic issue      |
| Large diff (1000+ files)      | NO       | not tested, lint-staged scales             |
| Binary files                  | NO       | M4 gap                                     |
| File renames                  | NO       | M4 gap                                     |
| Submodule changes             | NO       | M4 gap                                     |
| Locale issues                 | NO       | not tested; grep -F is locale-agnostic     |
| Turbo cache masking           | NO       | C1 critical gap                            |
| Parallel task interference    | NO       | L2                                         |

## Cross-zone coverage vs AGENTS.md gate table

AGENTS.md §6 declares these gates:

| Gate              | Hook-wired? | Makefile target    | Bats tests |
| ----------------- | ----------- | ------------------ | ---------- |
| Pre-commit hook   | YES         | n/a                | 7 tests    |
| Pre-push hook     | YES         | n/a                | 7 tests    |
| test-shell        | NO          | test-shell         | 24 files   |
| test-config       | NO          | test-config        | (via bats) |
| test-python       | PARTIAL     | test-python (in-container) | (via verify-python) |
| test-infra        | NO          | test-infra         | (via bats) |

The pre-commit/push hooks cover: JS/TS linting (via turbo), JS tests (via turbo),
Python lint+format+pytest (via verify-python.sh), and prettier formatting.

NOT covered by hooks:
- Shell dev-infra tests (`make test-shell`, 100+ tests)
- OpenCode config validation (`make test-config`, 8 validators)
- Docker smoke test (`make test-infra`, requires daemon)
- Agent-name cross-reference validation
- Output-contract validation
- HANDOFF schema validation
- Ticket-gate regression probe
- Tool-coverage audit
- Pin-sync check (only runs as part of test-shell)

## Recommendations (ranked by impact/effort)

| Rank | Fix                                          | Severity | Effort | Impact     |
| ---- | -------------------------------------------- | -------- | ------ | ---------- |
| 1    | C1: fix turbo.json `test` inputs             | CRITICAL | 5 min  | Very high  |
| 2    | C2: wire `make test-shell` into pre-push     | CRITICAL | 2h     | Very high  |
| 3    | C3: wire `make test-config` into pre-push    | CRITICAL | 2h     | High       |
| 4    | H1: add `timeout` to run_workspace           | HIGH     | 30 min | Medium     |
| 5    | H2: test lint vs typecheck failure chain     | HIGH     | 30 min | Medium     |
| 6    | H4: test docker-daemon-down path             | HIGH     | 30 min | Medium     |
| 7    | H5: expand verify-python.bats                | HIGH     | 1h     | Medium     |
| 8    | H6: test lint-staged config validity         | HIGH     | 1h     | Medium     |
| 9    | M6: validate turbo.json in test-config       | MEDIUM   | 30 min | Medium     |
| 10   | H3: assert all workspaces have lint scripts  | HIGH     | 2h     | Medium     |

## Justification for top 3

**C1 (turbo test inputs):** the `inputs` field on the `test` task is a single
line but has the highest potential impact of any finding. It silently masks
source-code regressions from the pre-push gate. This is not a theoretical risk;
it is a misconfiguration that is active today. Every `git push` where only
source files changed has been returning a cached test result.

**C2 (test-shell in hooks):** the 100+ bats tests are the only automated safety
net for the shell dev-infra artifacts, including the hook scripts themselves.
Breaking verify-pre-commit.sh and pushing it would go undetected until someone
runs `make test-shell` manually. Since `make test-shell` is host-runnable and
fast (seconds, no Docker), there is no reason not to run it on pre-push.

**C3 (test-config in hooks):** the OpenCode config surface is the most change-
prone part of the repo (see ana013's 50-file audit). Every agent config, skill,
handoff template, and output contract is validated by test-config, which never
runs automatically. Adding it to pre-push catches config drift at the same
boundary as the other verification steps.

## Conclusion

The hook test coverage is strong for the narrow scope of the verify-pre-commit.sh
and verify-pre-push.sh scripts themselves (24 bats tests, good edge case
coverage for the delegation/degradation paths). However, the hooks' SCOPE is too
narrow: they exercise only the JS/TS/Python lint+test chain via turbo and
verify-python, while leaving the 100+ shell dev-infra tests and the 8 config
validators entirely out of the automatic commit/push boundary. Combined with the
turbo `test` inputs misconfiguration (C1), the pre-push gate is providing a
false sense of coverage for source-code regressions and shell/config drift.

The three critical fixes (C1, C2, C3) close the two largest holes with roughly
4h of work and bring the hook coverage in line with the AGENTS.md §6 gate table
intent.
