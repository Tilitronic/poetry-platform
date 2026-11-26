# Design: pre-commit-autofix

> **Proposal:** `openspec/changes/pre-commit-autofix/proposal.md`
> **Scope:** dev-infra only — no system architecture decisions, no `.sdd/` escalation required.

## Approach

This change stays within the existing dev-infra module boundary. No new module is introduced, no cross-cutting technology decision is made, and `architecture.md` is not affected. The design follows established patterns in the codebase:

- **Host/container delegation pattern:** reuse the exact `is_in_dev_container` / `container_running` / `run_workspace` pattern from `scripts/verify-pre-push.sh`. The pre-commit hook runs the same way — detect context, delegate if on host.
- **uv venv bootstrap pattern:** reuse the exact `uv venv .venv` + `uv pip install -e ".[dev]"` pattern from `scripts/verify-python.sh` for ruff installation. Ruff is a Python tool distributed as a pip package — no separate binary install needed.
- **bats unit test pattern:** reuse the namespace-isolated harness pattern from `scripts/__tests__/dev-entrypoint.bats` for testing the new verify scripts.
- **package.json tooling config pattern:** lint-staged config lives in root `package.json` alongside husky, prettier, and eslint config — single file for tooling.
- **Single-verification-script pattern:** extend `verify-python.sh` (not a new script) for ruff — pytest + ruff share the same venv, same context, same failure mode.

## Seams

Public boundaries where tests will live:

| Seam                                               | Test location                                            | What it covers                                         |
| -------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------ |
| `scripts/verify-pre-commit.sh` CLI contract        | `scripts/__tests__/verify-pre-commit.bats`               | Exit codes, delegation logic, container-down behavior  |
| `scripts/verify-python.sh` CLI contract            | `scripts/__tests__/verify-python.bats`                   | pytest + ruff invocation order, venv bootstrap         |
| `scripts/verify-pre-commit.sh` + husky integration | Manual smoke test (documented in T2 acceptance criteria) | Hook fires on `git commit`, delegates to container     |
| `scripts/lint-python-files.sh` CLI contract        | `scripts/__tests__/lint-python-files.bats`               | Venv bootstrap, ruff invocation, file list passthrough |
| lint-staged glob → command mapping                 | Manual smoke test (documented in T3 acceptance criteria) | Correct commands run for each file type                |
| `scripts/__tests__/bats-wrapper.sh`                | Self-check                                               | Syntax-checks all shell scripts including new ones     |

## Files changed

| File                                       | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Traced to                |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `.husky/pre-commit`                        | New file: shell script that delegates to `scripts/verify-pre-commit.sh` (same pattern as existing `.husky/pre-push`).                                                                                                                                                                                                                                                                                                                                            | Pre-commit hook          |
| `scripts/verify-pre-commit.sh`             | New file: lint-staged runner. Same host/container delegation pattern as `verify-pre-push.sh`. Calls `npx lint-staged` via `run_workspace`. Key difference from pre-push: if container is not running, **fail by default** (open question — see proposal §Open questions Q1). Uses `lint-staged --allow-empty` to handle empty commits gracefully.                                                                                                                | Pre-commit hook          |
| `package.json` (root)                      | (1) Add `lint-staged` to `devDependencies`; (2) add `"lint-staged"` config key with glob → command mapping.                                                                                                                                                                                                                                                                                                                                                      | lint-staged config       |
| `scripts/lint-python-files.sh`             | New file: wrapper script invoked by lint-staged for `apps/api-server/**/*.py` files (scoped glob — see D8). Ensures `apps/api-server/.venv` exists and ruff is installed, rebases paths from repo-root-relative to `apps/api-server`-relative, skips out-of-scope paths with a diagnostic, then runs `ruff check --fix` + `ruff format`. lint-staged cannot invoke ruff directly because ruff lives in the venv (`apps/api-server/.venv/bin/ruff`), not on PATH. | Python lint wrapper      |
| `apps/api-server/pyproject.toml`           | (1) Add `ruff>=0.14.0` to `[project.optional-dependencies]` `dev`; (2) add `[tool.ruff]` section with line-length, lint select, format config.                                                                                                                                                                                                                                                                                                                   | Ruff integration         |
| `scripts/verify-python.sh`                 | Extend to run `ruff check .` and `ruff format --check .` BEFORE pytest. If ruff fails, exit immediately (don't run pytest on unlinted code).                                                                                                                                                                                                                                                                                                                     | Pre-push extension       |
| `scripts/__tests__/verify-pre-commit.bats` | New bats test file: covers container delegation, empty-commit handling, container-down behavior.                                                                                                                                                                                                                                                                                                                                                                 | Test: pre-commit hook    |
| `scripts/__tests__/verify-python.bats`     | New bats test file: covers ruff invocation, venv bootstrap, pytest-after-ruff ordering.                                                                                                                                                                                                                                                                                                                                                                          | Test: pre-push extension |
| `scripts/__tests__/bats-wrapper.sh`        | Extend syntax-check loop to cover the two new scripts (`verify-pre-commit.sh` and the updated `verify-python.sh`).                                                                                                                                                                                                                                                                                                                                               | Test infra               |

## Decision rationale

### D1: Fail-by-default when container is down (pre-commit)

**Decision:** If the dev container is not running when `git commit` is invoked, the pre-commit hook **fails** with a clear message: "dev container not running — start with `make up`, then commit again."

**Traced to:** User requirement: "maximum automatic linting and formatting." A non-blocking hook is not maximum.

**Alternatives considered:**

- **Warn+skip** (matches pre-push behavior): rejected because pre-push is a gate (blocks pushes), while pre-commit is an auto-fix hook. Silently skipping auto-fix means unformatted code enters the staging area. The developer can always `git commit --no-verify` to bypass if they explicitly want to skip.
- **Auto-start the container**: rejected because `make up` involves building images, which can take 30+ seconds. A commit hook should be fast (seconds, not minutes).

### D2: lint-staged config in root package.json

**Decision:** lint-staged config lives in root `package.json` under the `"lint-staged"` key.

**Traced to:** Consistency with existing tooling config location (husky, prettier, eslint are all configured in root `package.json` or root-level config files).

**Alternatives considered:**

- **`.lintstagedrc.json`**: rejected because it adds a new file for a small config (~15 lines). `package.json` is already the central place.

### D3: Ruff line-length = 100

**Decision:** `[tool.ruff]` uses `line-length = 100`.

**Traced to:** Prettier printWidth parity. The project's prettier configuration uses `printWidth: 100` for JS/TS/Vue/CSS/HTML/MD/YAML/JSON. Setting ruff to the same value ensures a single, consistent line-length across all languages in the monorepo. Using 88 (black default) would create a visual mismatch — Python files would wrap earlier than adjacent JS/TS files in the same codebase.

**Alternatives considered:** 88 (black/ruff default) — rejected because it diverges from prettier's 100, creating inconsistency. 120 (wide) — rejected as too permissive; 100 is the established project standard via prettier.

### D4: Ruff lint rules = E + F + I

**Decision:** `[tool.ruff.lint]` uses `select = ["E", "F", "I"]` (pyflakes + pycodestyle errors + isort).

**Traced to:** Safe automation principle. isort auto-sorts imports deterministically — it reorders `import` and `from ... import` statements alphabetically/by-source without changing any semantics. This is a safe, high-value automation that eliminates a category of manual housekeeping. The Python codebase is small, so the initial sort is cheap and the ongoing maintenance burden is zero.

**UP (pyupgrade) deliberately excluded.** pyupgrade modernizes syntax (e.g., `str.format()` → f-strings, `typing.List` → `list`, `Optional[X]` → `X | None`). While these changes are semantically equivalent, they churn existing code and create diff noise without adding safety value. Each UP fix is a line change that obscures the real intent in `git blame`. UP can be added later as a deliberate, one-shot migration if the team decides the modernization is worth the churn.

### D5: Extend verify-python.sh (not a new script)

**Decision:** `scripts/verify-python.sh` runs both ruff AND pytest, in that order.

**Traced to:** Single responsibility for Python verification. Both tools share the same venv, the same working directory (`apps/api-server`), and the same failure context. Splitting into `verify-python.sh` + `verify-python-lint.sh` would duplicate the venv bootstrap logic.

**Ordering rationale:** ruff runs first because it's fast (<1s for 51 files) and catches formatting issues that would waste pytest time on code that won't pass review.

### D6: Shell syntax check via `bash -n` (no shellcheck)

**Decision:** Shell scripts are syntax-checked via `bash -n` in lint-staged, not linted with shellcheck.

**Traced to:** No-new-dependency principle. `bash -n` is available everywhere bash is. shellcheck would require installation in the dev container (apt-get) and adds a new tool to maintain. Shell scripts are few (`scripts/*.sh`, `dev-entrypoint.sh`) and the existing `bats-wrapper.sh` already syntax-checks them.

### D7: Container tooling — lint-staged as root devDep, ruff via uv venv + wrapper script

**Decision:** `lint-staged` is a root `devDependency` (runs from `node_modules` in the container, already present via pnpm workspace). `ruff` is installed into `apps/api-server/.venv` via `uv pip install -e ".[dev]"` (same pattern as pytest). A small wrapper script `scripts/lint-python-files.sh` bridges lint-staged → ruff: it ensures the venv exists, installs ruff if needed, then invokes `ruff check --fix` + `ruff format` on the file list passed by lint-staged.

**Traced to:** Existing patterns. The dev container already has `node_modules` (pnpm workspace root) and `uv` (for Python venv management). Adding ruff to the Dockerfile would be a new pattern; adding it to `pyproject.toml` dev deps follows the existing pattern.

**Why a wrapper script?** lint-staged runs commands from the repo root, where `ruff` is not on PATH (it lives in `apps/api-server/.venv/bin/ruff`). The wrapper:

1. Ensures the venv exists (`{ test -x .venv/bin/python || uv venv .venv; }`)
2. Ensures ruff is installed (`uv pip install --python .venv/bin/python -q -e ".[dev]"`)
3. Runs ruff on the files passed as arguments (`"$@"`)

This is the same venv-bootstrap pattern as `verify-python.sh`, extracted into a reusable script so lint-staged can invoke it without duplicating the bootstrap logic in the lint-staged config.

**Verification:** `verify-python.sh` already runs `uv pip install --python .venv/bin/python -q -e ".[dev]"` before pytest. Adding ruff to `[dev]` means it's installed automatically. The wrapper script reuses this install step (idempotent — `uv pip install` is a no-op if ruff is already present).

### D8: Python lint wrapper — scoped glob + path rebasing

**Decision:** lint-staged's glob for Python is `apps/api-server/**/*.py` (not `*.py`). `scripts/lint-python-files.sh` receives repo-root-relative paths from lint-staged (e.g., `apps/api-server/app/core/auth.py`), `cd`s into `apps/api-server`, strips the `apps/api-server/` prefix to produce a package-relative path, and invokes ruff on the rebased list. Out-of-scope paths (anything not starting with `apps/api-server/`) are skipped with a stderr diagnostic — they are never forwarded to ruff.

**Traced to:** Reviewer finding (Critical) — ruff is configured only in `apps/api-server/pyproject.toml`. A repo-wide `*.py` glob would match Python files in `packages/analytics-pipeline/`, `packages/phonetics-core/`, and `tools/opencode-docker/`, where ruff has no configuration and no project context. lint-staged runs from the repo root and passes repo-root-relative paths; without rebasing, ruff (invoked from inside `apps/api-server`) would fail with "file not found" and block the commit.

**Why a rebasing wrapper (not direct invocation)?** lint-staged passes paths like `apps/api-server/app/core/auth.py`. The wrapper must:

1. Validate scope — reject paths outside `apps/api-server/` (defensive guard against future glob widening).
2. Strip the `apps/api-server/` prefix — ruff resolves paths relative to its own cwd, which is `apps/api-server`.
3. Bootstrap the venv — same pattern as `verify-python.sh` (idempotent).
4. Forward the rebased paths to `ruff check --fix` + `ruff format`.

**Out-of-scope skip behavior:** The wrapper iterates over `"$@"`, filters paths that start with `apps/api-server/`, strips the prefix, collects rebased paths into a local array. If a path does NOT start with `apps/api-server/`, it prints `skip out-of-scope: <path>` to stderr and continues. If no in-scope paths remain after filtering, the wrapper exits 0 (nothing to lint). This ensures that even if a future glob widening accidentally routes an out-of-scope path to the wrapper, the commit is not blocked.

**Alternatives considered:**

- **Configure ruff at repo root**: rejected — `packages/analytics-pipeline` and `packages/phonetics-core` have different Python version requirements and may not share ruff config. A single root-level ruff config would impose one style on projects that may want different rules.
- **Multiple scoped globs per Python package**: rejected as premature — if a second Python package needs ruff in the future, add its glob and wrapper entry then. YAGNI.
- **Let the wrapper fail on out-of-scope paths**: rejected — the wrapper should never receive out-of-scope paths given the scoped glob, but if it does (due to a future misconfiguration), failing silently with a diagnostic is better than blocking the commit with an opaque ruff error.

## Edge cases

### E1: Empty commit (no staged files)

lint-staged with no staged files exits 0 by default in recent versions, but we add `--allow-empty` explicitly for clarity and forward compatibility.

### E2: .prettierignore coverage

Existing `.prettierignore` already excludes: `node_modules/`, `.pnpm-store/`, `dist/`, `.output/`, `.next/`, `.astro/`, `.nuxt/`, `.quasar/`, `.turbo/`, `coverage/`, `.venv/`, `**/.venv/`, `__pycache__/`, `*.pyc`, `.pytest_cache/`, `*.egg-info/`, `**/generated/`, `.opencode/`, `tools/`, `secrets/`, `knowledge/`, `scripts/__tests__/vendor/`, `jsconfig.json`.

lint-staged respects `.prettierignore` when running prettier (prettier reads it natively). For ruff, we add a matching `.ruffignore` or use `[tool.ruff] exclude` to skip the same directories. For lint-staged's own glob matching (which determines which files are passed to commands), we rely on git's staged file list — git already respects `.gitignore` (which covers `.venv/`, `node_modules/`, `secrets/`, etc.).

### E3: lint-staged auto re-stages fixes

lint-staged's default behavior: after running a command that modifies a file, it runs `git add <file>` to re-stage the fix. This is built-in and requires no configuration.

### E4: Ruff exclude list

Add to `[tool.ruff]`:

```toml
exclude = [
    ".venv",
    "__pycache__",
    ".pytest_cache",
    ".git",
    "node_modules",
    ".opencode",
    "secrets",
]
```

This mirrors `.prettierignore` for the Python tooling.

### E5: Scoped Python glob — ruff scope boundary

The lint-staged glob `apps/api-server/**/*.py` reflects ruff's actual configuration scope. Only `apps/api-server/pyproject.toml` contains `[tool.ruff]` settings. Python files elsewhere in the monorepo (`packages/analytics-pipeline/`, `packages/phonetics-core/`, `tools/opencode-docker/`) are intentionally excluded from pre-commit lint-staged processing.

If Python linting is needed for another package in the future, the change must:

1. Add `[tool.ruff]` to that package's `pyproject.toml` (or a shared root config if appropriate).
2. Add a separate lint-staged glob entry for that package (e.g., `packages/analytics-pipeline/**/*.py`).
3. Extend or duplicate the wrapper script to handle the new package root (or generalize the wrapper to accept a package-root argument).

The scoped glob is a deliberate boundary — not a gap to be filled. Each Python package in this monorepo is independent, and ruff configuration is per-package.

## Test strategy

### Unit tests (bats)

| Script                 | Test file                                  | What it covers                                                                                                                                                                                                                                                  |
| ---------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `verify-pre-commit.sh` | `scripts/__tests__/verify-pre-commit.bats` | (1) Runs `npx lint-staged` inside container when on host; (2) runs `npx lint-staged` directly when inside container; (3) fails with clear message when container is down (fail-by-default); (4) passes `--allow-empty` flag; (5) `container_running` detection. |
| `verify-python.sh`     | `scripts/__tests__/verify-python.bats`     | (1) Runs `ruff check .` then `ruff format --check .` then `pytest`; (2) exits immediately if ruff fails (doesn't run pytest); (3) venv bootstrap on first run; (4) venv reuse on subsequent runs.                                                               |
| `bats-wrapper.sh`      | (existing test)                            | Syntax-checks all `.sh` files including new `verify-pre-commit.sh`.                                                                                                                                                                                             |

### Smoke tests (manual, documented in task acceptance criteria)

| Scenario                                        | How to verify                                                                                                                                                |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Pre-commit hook fires on `git commit`           | Stage a file, run `git commit -m "test"` — hook runs, lint-staged processes the file                                                                         |
| lint-staged runs correct commands per file type | Stage an `apps/api-server/` `.py` file → verify `ruff check --fix` + `ruff format` run; stage a `.vue` file → verify `eslint --fix` + `prettier --write` run |
| Ruff is installed and works                     | `cd apps/api-server && .venv/bin/ruff check .` exits 0 on a clean codebase                                                                                   |
| Pre-push gate still passes                      | `git push` triggers pre-push, which runs the full suite including ruff                                                                                       |

## Rollback plan

See proposal §Rollback plan. Summary: all changes are reversible via git revert. The worst case is a broken pre-commit hook, which is fixed by `rm .husky/pre-commit`.
