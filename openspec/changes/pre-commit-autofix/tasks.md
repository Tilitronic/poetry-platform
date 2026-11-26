# Tasks: pre-commit-autofix

> **Proposal:** `openspec/changes/pre-commit-autofix/proposal.md`
> **Design:** `openspec/changes/pre-commit-autofix/design.md`
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice invoked via the `tdd-craftsman` skill. Write the failing test BEFORE production code. Work one slice at a time.

## Dependency graph

```
T1 (Ruff pyproject.toml + config) ────────┐
                                           ├──▶ T4 (verify-python.sh extension + bats)
T2 (lint-staged + wrapper + config) ───────┤
                                           │
T3 (pre-commit hook + verify-pre-commit.sh + bats) ──┤
                                                      │
                                                      ▼
                                               T5 (end-to-end smoke verification)
```

**Critical path:** T2 → T3 → T5 (pre-commit hook chain)
**Parallel tracks:** T1 and T2 can proceed independently. T4 depends on T1. T5 depends on T3 + T4.
**Final task:** T5 is the integration smoke test — it verifies the full pre-commit → lint-staged → ruff/eslint/prettier chain works end-to-end.

---

## T1 — Ruff in pyproject.toml + configuration

**Blockers:** none
**Vertical slice:** add ruff as a dev dependency and configure it so `ruff check` and `ruff format` work on the Python codebase.
**Traces to:** D3, D4, D5

### What changes

1. `apps/api-server/pyproject.toml`:
   - Add `ruff>=0.14.0` to `[project.optional-dependencies]` `dev` list.
   - Add `[tool.ruff]` section:

     ```toml
      [tool.ruff]
      line-length = 100
      target-version = "py311"
      exclude = [
          ".venv",
          "__pycache__",
          ".pytest_cache",
          ".git",
          "node_modules",
          ".opencode",
          "secrets",
      ]

      [tool.ruff.lint]
      select = ["E", "F", "I"]
     ```

### Acceptance criteria (user perspective)

- `cd apps/api-server && uv pip install -e ".[dev]"` installs ruff into `.venv`.
- `.venv/bin/ruff check .` exits 0 on the current codebase (or reports fixable issues that `ruff check --fix .` resolves).
- `.venv/bin/ruff format --check .` exits 0 or reports files that would be reformatted.
- Running `ruff check --fix . && ruff format .` on the codebase produces a clean result (subsequent `ruff check .` and `ruff format --check .` exit 0).
- `[tool.ruff]` configuration is present and matches the design (line-length 100, select E+F+I, exclude list).

### Testing

- **RED-GREEN:** write a bats test in `scripts/__tests__/lint-python-files.bats` (shared with T2's wrapper) that asserts ruff is installable and runnable. The test fails because ruff is not yet in `[dev]`, then passes after adding it.
- **Smoke test:** manually run `cd apps/api-server && uv pip install -e ".[dev]" && .venv/bin/ruff check . && .venv/bin/ruff format --check .` — both exit 0.
- **Note:** if ruff reports formatting issues on existing code, fix them in this task (run `ruff check --fix . && ruff format .` and commit the result). The codebase should be clean after T1.

---

## T2 — lint-staged config + Python lint wrapper

**Blockers:** none
**Vertical slice:** add lint-staged as a root devDep, configure glob → command mapping, and create the Python lint wrapper script so lint-staged can invoke ruff on staged `apps/api-server/**/*.py` files.
**Traces to:** D2, D7

### Pre-flight checks

Before starting T2, verify:

1. **husky version** — confirm `husky` in root `package.json` `devDependencies` is `^9.1.7` (or compatible v9+). If an older version is present, note it but do NOT upgrade in this task (husky v9 uses the flat config pattern; the `.husky/pre-commit` file approach works with v9).
2. **lint-staged not yet a dep** — confirm that `lint-staged` is NOT already listed in root `package.json` `devDependencies`. If it IS already present, skip step 1 of "What changes" below and proceed to configuring the `"lint-staged"` key.

### What changes

1. `package.json` (root):
   - Add `lint-staged` to `devDependencies`: `"lint-staged": "^15.0.0"` (or latest stable).
   - Add `"lint-staged"` config key:
     ```json
     "lint-staged": {
       "*.{js,ts,mjs,cjs,tsx,vue}": [
         "eslint --fix",
         "prettier --write"
       ],
       "*.{css,scss,html,md,json,yaml,yml}": [
         "prettier --write"
       ],
        "apps/api-server/**/*.py": [
          "scripts/lint-python-files.sh"
        ],
       "*.{sh,bats}": [
         "bash -n"
       ]
     }
     ```

2. `scripts/lint-python-files.sh` (new):
   - Shebang: `#!/usr/bin/env bash`
   - `set -euo pipefail`
   - `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`
   - For each argument in `"$@"`:
     - If the path does NOT start with `apps/api-server/`, print a diagnostic to stderr (`skip out-of-scope: <path>`) and continue to the next argument.
     - Strip the `apps/api-server/` prefix to produce an `apps/api-server`-relative path.
     - Collect the rebased path into a local array (e.g., `REBASED+=("${rel_path}")`).
   - If no in-scope paths remain after filtering, exit 0 (nothing to lint).
   - `cd "$ROOT/apps/api-server"`
   - Ensure venv: `{ test -x .venv/bin/python || uv venv .venv; } >/dev/null`
   - Ensure ruff: `uv pip install --python .venv/bin/python -q -e ".[dev]"`
   - Run ruff on the rebased file list: `.venv/bin/ruff check --fix "${REBASED[@]}"`
   - Run ruff format on the rebased file list: `.venv/bin/ruff format "${REBASED[@]}"`
   - Make executable: `chmod +x scripts/lint-python-files.sh`

3. Run `pnpm install` to add lint-staged to `node_modules`.

### Acceptance criteria (user perspective)

- `pnpm install` succeeds and lint-staged is in `node_modules/.bin/lint-staged`.
- `npx lint-staged --version` prints a version string.
- The lint-staged config in `package.json` uses the scoped glob `"apps/api-server/**/*.py"` (not `*.py`) and lint-staged parses the config without errors.
- `scripts/lint-python-files.sh apps/api-server/app/core/auth.py` rebases the path and runs ruff on `app/core/auth.py` (assuming the file exists).
- `scripts/lint-python-files.sh packages/analytics-pipeline/some/file.py` prints a diagnostic to stderr (`skip out-of-scope: packages/analytics-pipeline/some/file.py`) and exits 0 — does NOT forward the path to ruff, does NOT block the commit.
- `scripts/lint-python-files.sh` is executable and has the correct shebang.

### Testing

- **RED-GREEN:** write a bats test in `scripts/__tests__/lint-python-files.bats` that:
  1. Creates a temp directory with a mock `apps/api-server/` structure.
  2. Mocks `uv` and `ruff` (or uses the real venv if available).
  3. Runs `scripts/lint-python-files.sh apps/api-server/test.py` and asserts ruff is invoked with `test.py` (rebased path) as the argument.
  4. Runs `scripts/lint-python-files.sh packages/other/file.py` and asserts the wrapper prints `skip out-of-scope: packages/other/file.py` to stderr and does NOT invoke ruff.
  5. The test fails because `scripts/lint-python-files.sh` doesn't exist yet, then passes after creating it.
- **Smoke test:** manually run `npx lint-staged --dry-run` (if supported) or stage an `apps/api-server/` `.py` file and run `npx lint-staged` to verify the wrapper is invoked with a rebased path.

---

## T3 — Pre-commit hook + verify-pre-commit.sh + bats tests

**Blockers:** T2 (needs lint-staged to be installed and configured)
**Vertical slice:** create the `.husky/pre-commit` hook and `scripts/verify-pre-commit.sh` that delegates to the dev container and runs lint-staged. Add bats tests for the hook script.
**Traces to:** D1, D6

### What changes

1. `.husky/pre-commit` (new):
   - Shebang: `#!/usr/bin/env bash`
   - Content: `bash scripts/verify-pre-commit.sh`
   - Make executable: `chmod +x .husky/pre-commit`

2. `scripts/verify-pre-commit.sh` (new):
   - Same structure as `scripts/verify-pre-push.sh`:
     - `set -euo pipefail`
     - `ROOT`, `WORKSPACE` variables
     - `is_in_dev_container()`, `container_running()`, `run_workspace()` functions
   - Key difference from pre-push: if `container_running` is false, **exit 1** with error message (fail-by-default, per D1).
   - Run `npx lint-staged --allow-empty` via `run_workspace`.
   - Success message on exit.

3. `scripts/__tests__/verify-pre-commit.bats` (new):
   - Test 1: runs `verify-pre-commit.sh` inside a mock container (hostname = `poetry-dev`) → asserts `npx lint-staged` is invoked.
   - Test 2: runs on host with container running → asserts `docker compose exec -T dev bash -lc "cd /workspace && npx lint-staged --allow-empty"` is invoked.
   - Test 3: runs on host with container NOT running → asserts exit code is 1 and error message contains "dev container not running".
   - Test 4: asserts `--allow-empty` flag is passed (handles empty commits).

4. `scripts/__tests__/bats-wrapper.sh`:
   - Extend the syntax-check loop to include `scripts/verify-pre-commit.sh` and `scripts/lint-python-files.sh` (if not already covered by T2).

### Acceptance criteria (user perspective)

- `git commit` triggers the pre-commit hook (`.husky/pre-commit` is invoked by husky).
- The hook delegates to the dev container if on the host, or runs directly if inside the container.
- If the dev container is not running, the hook fails with a clear error: "dev container not running — start with `make up`, then commit again."
- lint-staged runs on staged files and auto-fixes formatting/linting issues.
- Empty commits (no staged files) pass without error (`--allow-empty` flag).
- All bats tests in `scripts/__tests__/verify-pre-commit.bats` pass.

### Testing

- **RED-GREEN:** write the bats tests first (they fail because `verify-pre-commit.sh` doesn't exist), then create the script until tests pass.
- **Smoke test:** stage a file, run `git commit -m "test"` — hook fires, lint-staged processes the file, commit succeeds (or fails if lint-staged finds unfixable issues).
- **Edge case test:** stage no files, run `git commit --allow-empty -m "empty"` — hook fires, lint-staged exits 0 (no files to process), commit succeeds.

---

## T4 — Extend verify-python.sh with ruff + bats tests

**Blockers:** T1 (needs ruff to be installable via `uv pip install -e ".[dev]"`)
**Vertical slice:** extend `scripts/verify-python.sh` to run ruff before pytest, and add bats tests for the updated script.
**Traces to:** D5

### What changes

1. `scripts/verify-python.sh`:
   - After the venv bootstrap and `uv pip install` step, add:
     - `.venv/bin/ruff check .` → if fails, exit 1 (don't run pytest).
     - `.venv/bin/ruff format --check .` → if fails, exit 1 (don't run pytest).
   - Then run pytest as before: `exec .venv/bin/python -m pytest`.
   - Ordering rationale: ruff is fast (<1s for 51 files), catches formatting issues that would waste pytest time on code that won't pass review.

2. `scripts/__tests__/verify-python.bats` (new):
   - Test 1: runs `verify-python.sh` with mocked `uv` and `python` → asserts `ruff check .` is invoked before `pytest`.
   - Test 2: runs with ruff failing (mock returns non-zero) → asserts pytest is NOT invoked (early exit).
   - Test 3: runs with ruff passing → asserts pytest IS invoked.
   - Test 4: asserts venv bootstrap happens on first run, is skipped on subsequent runs.

3. `scripts/__tests__/bats-wrapper.sh`:
   - Extend the syntax-check loop to include the updated `verify-python.sh` (if not already covered).

### Acceptance criteria (user perspective)

- `pnpm verify:python` (which runs `scripts/verify-python.sh`) executes ruff check, ruff format check, then pytest — in that order.
- If ruff fails, the script exits immediately (pytest is not run).
- If ruff passes, pytest runs as before.
- All bats tests in `scripts/__tests__/verify-python.bats` pass.
- The pre-push hook (`pnpm verify` → `verify:python`) now includes ruff checks.

### Testing

- **RED-GREEN:** write the bats tests first (they fail because `verify-python.sh` doesn't run ruff yet), then extend the script until tests pass.
- **Smoke test:** run `pnpm verify:python` manually — observe ruff check, ruff format, pytest output in sequence.
- **Edge case test:** introduce a ruff violation (e.g., unused import), run `pnpm verify:python` — observe ruff fails, pytest is not run.

---

## T5 — End-to-end smoke verification

**Blockers:** T3, T4
**Vertical slice:** verify the full chain works end-to-end: pre-commit hook → lint-staged → ruff/eslint/prettier/bash, and pre-push hook → full suite including ruff.
**Traces to:** all

### What changes

1. Manual smoke tests (documented here, executed by the developer):
   - **Pre-commit smoke:**
     1. Stage an `apps/api-server/` `.py` file with a formatting issue → `git commit` → observe ruff auto-fixes it.
     2. Stage a `.vue` file with a linting issue → `git commit` → observe eslint --fix + prettier --write run.
     3. Stage a `.md` file → `git commit` → observe prettier --write runs.
     4. Stage a `.sh` file with a syntax error → `git commit` → observe `bash -n` fails, commit blocked.
     5. Stage no files → `git commit --allow-empty -m "empty"` → observe hook passes (no files to process).
   - **Pre-push smoke:**
     1. Run `git push` → observe pre-push hook fires, runs full suite including ruff.
     2. Introduce a ruff violation → `git push` → observe pre-push blocks the push.
   - **Container-down smoke:**
     1. Stop the dev container (`docker compose down`).
     2. Stage a file, run `git commit` → observe pre-commit hook fails with "dev container not running" error.
     3. Start the container (`make up`), run `git commit` again → observe hook succeeds.

2. Optional: add a `scripts/test-pre-commit-smoke.sh` script that automates the smoke tests (creates temp commits, verifies behavior, cleans up). This is a nice-to-have, not required.

### Acceptance criteria (user perspective)

- Pre-commit hook auto-fixes formatting/linting issues for all supported file types (`.py`, `.vue`, `.js`, `.ts`, `.css`, `.scss`, `.html`, `.md`, `.json`, `.yaml`, `.yml`, `.sh`, `.bats`).
- Pre-commit hook blocks commits with unfixable issues (e.g., eslint errors, `bash -n` syntax errors).
- Pre-push hook blocks pushes with ruff violations.
- Pre-commit hook fails clearly when the dev container is down.
- Empty commits pass without error.
- All manual smoke tests pass.

### Testing

- **Manual verification:** the smoke tests ARE the test for this task. They verify the end-to-end behavior.
- **Optional automation:** if `scripts/test-pre-commit-smoke.sh` is created, it can be added to `make test-infra` or run manually.

---

## Summary

| Task | Blockers | Key deliverable                        | Test strategy                                                   |
| ---- | -------- | -------------------------------------- | --------------------------------------------------------------- |
| T1   | none     | Ruff in pyproject.toml + config        | bats (ruff installable), smoke (ruff runs clean)                |
| T2   | none     | lint-staged + wrapper + config         | bats (wrapper invokes ruff), smoke (lint-staged parses config)  |
| T3   | T2       | Pre-commit hook + verify-pre-commit.sh | bats (delegation, container-down), smoke (hook fires on commit) |
| T4   | T1       | verify-python.sh extension             | bats (ruff before pytest), smoke (verify:python runs ruff)      |
| T5   | T3, T4   | End-to-end smoke verification          | Manual smoke tests (full chain)                                 |
