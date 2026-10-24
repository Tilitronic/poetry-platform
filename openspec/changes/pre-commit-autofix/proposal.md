# Proposal: pre-commit-autofix

> **Status:** proposed · **Scope:** dev-infra (husky, lint-staged, ruff, verify scripts)
> **Escalation:** none — change is within existing module boundaries (per AGENTS.md §2.4, dev-infra changes do not require @architector)
> **Requirement:** maximum automatic linting/formatting across all supported languages; pre-commit auto-fix + expanded tooling coverage

## Motivation

The current verification strategy is **reactive and blocking**: husky runs a `pre-push` hook that executes `pnpm verify` (prettier --check, eslint, typecheck, tests, pytest) and blocks the push if any check fails. This means:

1. **No auto-fix at commit time** — formatting and linting errors are caught only after `git commit`, forcing developers to fix, re-stage, and re-commit. The feedback loop is slow.
2. **Incomplete language coverage** — Python has no linter or formatter configured (only pytest). Shell scripts are syntax-checked via `bash -n` in bats-wrapper but not linted. YAML/JSON are not validated.
3. **No incremental feedback** — `pre-push` runs the full suite on the entire codebase, not just staged files. A developer who stages a single `.vue` file triggers a full `turbo lint` + `turbo test` + `pytest` run.
4. **Python tooling gap** — `apps/api-server/pyproject.toml` has no `[tool.ruff]`, `[tool.black]`, `[tool.isort]`, or `[tool.mypy]` sections. Python code is unformatted and unlinted.

The goal is to shift verification **left**: auto-fix at commit time (pre-commit), full gate at push time (pre-push), with expanded tooling coverage (ruff for Python, shell syntax checks, YAML/JSON validation via prettier).

## Scope

### In scope

1. **Pre-commit hook** — new `.husky/pre-commit` → `scripts/verify-pre-commit.sh` that delegates to the dev container (same host/container pattern as `verify-pre-push.sh`) and runs `lint-staged` inside the container.

2. **lint-staged configuration** — root `package.json` `lint-staged` key mapping by glob:
   - `*.{js,ts,mjs,cjs,tsx,vue}` → `eslint --fix` + `prettier --write`
   - `*.{css,scss,html,md,json,yaml,yml}` → `prettier --write`
   - `apps/api-server/**/*.py` → `scripts/lint-python-files.sh` (scoped — ruff is only configured for `apps/api-server`; a repo-wide `*.py` glob would trap out-of-scope Python from `packages/analytics-pipeline`, `packages/phonetics-core`, and `tools/opencode-docker`, and block commits with "file not found")
   - `*.sh` + `*.bats` → `bash -n` (syntax gate; cheap, no new dep)

3. **Ruff integration** — add `ruff` to `apps/api-server/pyproject.toml` `[project.optional-dependencies]` `dev` group + `[tool.ruff]` configuration (line-length, lint rules, format settings). Ruff is installed into the `.venv` via `uv` (same pattern as `verify-python.sh`), so it runs inside the container WITHOUT requiring host python/ruff.

4. **Pre-push extension** — extend `scripts/verify-python.sh` to also run `ruff check .` and `ruff format --check .` (in addition to pytest). This keeps the Python verification in a single script rather than splitting into `verify:python` + `verify:python-lint`.

5. **Tooling additions** — add `lint-staged` as a root `devDependency` in `package.json`. Husky is already a root `devDependency`.

6. **Edge case handling**:
   - Empty commit (no staged files) → `lint-staged --allow-empty` (no-op, passes).
   - `.prettierignore` already excludes `node_modules/`, `.venv/`, `secrets/`, `dist/`, `generated/`, `.opencode/`, `knowledge/`, `tools/` — lint-staged respects these for prettier runs.
   - lint-staged's own glob patterns should NOT match `secrets/` or `.venv/` (verify and document).
   - After `git add`, prettier/ruff modify staged files → lint-staged auto re-stages fixes (built-in behavior).

### Out of scope

- **Dev container down behavior** — OPEN QUESTION (see below). Recommendation: fail-by-default with clear error message ("dev container not running — start with `make up`"), but user may prefer warn+skip.
- **Mypy type checking** — Python type checking is not in scope. Ruff handles linting and formatting; mypy can be added in a future change if needed.
- **Shell linting (shellcheck)** — `bash -n` syntax check is in scope; full shellcheck integration is not. Can be added later if needed.
- **YAML/JSON schema validation** — prettier formats YAML/JSON; schema validation (e.g., against JSON Schema) is not in scope.
- **Rust tooling** — the Rust/WASM code under `.opencode/oh-my-opencode-slim/companion/` is plugin infrastructure, out of scope for the poetry-platform monorepo's linting strategy.
- **Changes to application code** — this change adds tooling and configuration only; no application code is modified.

## Design authority (.sdd/) reference

**No `.sdd/` document governs dev-infra.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer tooling. Per AGENTS.md §2.4, dev-infra changes within existing boundaries use the spec chain directly without architectural escalation.

## Testing decisions

**What makes a good test for this change?**

1. **Hook delegation** — the pre-commit hook must correctly delegate to the dev container (or run directly if already inside the container). Test: bats unit tests for `verify-pre-commit.sh` that mock `is_in_dev_container` and `container_running`, assert the correct `docker compose exec` command is invoked.

2. **lint-staged behavior** — lint-staged must run the correct commands for each file type, re-stage fixes, and handle edge cases (empty commit, ignored files). Test: smoke tests that stage files of each type, run `lint-staged`, and verify the expected commands were invoked (via mock scripts or log inspection).

3. **Ruff integration** — ruff must be installable via `uv pip install -e ".[dev]"` in `apps/api-server`, and `ruff check` / `ruff format` must work on the Python codebase. Test: `verify-python.sh` runs ruff as part of the pre-push gate; smoke test asserts ruff is on PATH and exits 0 on a clean codebase.

4. **Pre-push extension** — `verify-python.sh` must run pytest AND ruff. Test: bats unit tests for `verify-python.sh` that mock `uv` and `python`, assert the correct commands are invoked in the correct order.

**Which modules will be tested?**

- `scripts/verify-pre-commit.sh` (new) — bats unit tests
- `scripts/verify-python.sh` (modified) — bats unit tests
- `apps/api-server/pyproject.toml` (modified) — smoke test (ruff install + run)
- Root `package.json` (modified) — smoke test (lint-staged install + run)
- `.husky/pre-commit` (new) — manual verification (hook fires on `git commit`)

**Prior art in the codebase:**

- `scripts/verify-pre-push.sh` — established pattern for host/container delegation via `is_in_dev_container` + `container_running` + `run_workspace`.
- `scripts/verify-python.sh` — established pattern for uv-based venv bootstrap + pytest invocation.
- `scripts/__tests__/dev-entrypoint.bats` — established bats test structure with namespace-isolated harness.
- `scripts/__tests__/bats-wrapper.sh` — syntax-checks all shell scripts.

## Rollback plan

**If the change causes problems, how do we roll back?**

1. **Remove the pre-commit hook** — `rm .husky/pre-commit scripts/verify-pre-commit.sh`. This is a local-only change (husky hooks are not committed to git history, only the hook scripts are).

2. **Remove lint-staged** — `pnpm remove lint-staged` from root `package.json`. Revert the `lint-staged` config block.

3. **Remove ruff** — revert `apps/api-server/pyproject.toml` to remove `ruff` from `[project.optional-dependencies]` `dev` and remove `[tool.ruff]` section. Run `uv pip uninstall ruff` in `apps/api-server/.venv`.

4. **Revert pre-push extension** — revert `scripts/verify-python.sh` to remove the ruff check/format steps.

5. **Git history** — all changes are in a single commit (or a small PR). Revert the commit or merge a revert PR.

**Risk assessment:** LOW. This change adds tooling and configuration; it does not modify application code. The worst-case scenario is a broken pre-commit hook that blocks commits — easily fixed by removing `.husky/pre-commit`. The pre-push hook is unchanged (only extended), so if the pre-commit hook fails, developers can still push (and the pre-push hook will catch any issues).

## Open questions

All four open questions are now **RESOLVED**:

1. **RESOLVED — Dev container down behavior (pre-commit hook):** **(A) FAIL-by-default.** When the dev container is not running, the pre-commit hook fails with a clear error: "dev container not running — start with `make up`, then commit again." Rationale: commit-time auto-fix is a quality gate; silently passing defeats the purpose of "maximum automatic linting." The developer can always `git commit --no-verify` to bypass explicitly.

2. **RESOLVED — lint-staged config location:** **(A) Root `package.json` `lint-staged` key.** The config lives alongside husky, prettier, and eslint config in the same file. Rationale: simpler (no new file), consistent with existing tooling config pattern, and the config is small (~10 lines).

3. **RESOLVED — Ruff line-length:** **100** (prettier printWidth parity). Rationale: the project already uses prettier with `printWidth: 100` for JS/TS/Vue/CSS/HTML/MD/YAML/JSON. Setting ruff to 100 ensures Python line-length matches the rest of the codebase — a single, consistent line-length across all languages. The previous default of 88 (black standard) would create a jarring visual mismatch between Python and JS/TS in the same monorepo.

4. **RESOLVED — Ruff lint rules:** **`E` + `F` + `I`** (pyflakes + pycodestyle errors + isort). Rationale: isort auto-sorts imports safely (deterministic reordering, no semantic change). **UP (pyupgrade) is deliberately excluded** — it modernizes syntax (e.g., `str.format()` → f-strings, `typing.List` → `list`), which churns existing code and creates diff noise without adding safety value. UP can be added later as a deliberate, one-shot migration if desired.
