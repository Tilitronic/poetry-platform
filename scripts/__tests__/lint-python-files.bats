#!/usr/bin/env bats
# Unit tests for the Python lint tooling added by the pre-commit-autofix change:
#   T1 - ruff declared + configured in apps/api-server/pyproject.toml
#   T2 - scripts/lint-python-files.sh (the lint-staged wrapper that bridges
#        repo-root command execution to the api-server venv's ruff binary)
#
# The wrapper is tested in isolation: it is copied into a temp tree so ROOT
# resolves to the temp tree and the real repo venv is never touched. `uv` (on
# PATH) and `.venv/bin/ruff` are recording fakes.

load test-helper

# --- T1: ruff configuration in pyproject.toml --------------------------------

@test "ruff config: pyproject.toml declares ruff in dev deps and matches the design" {
  local pyproject="$REPO_ROOT/apps/api-server/pyproject.toml"
  # declared as a dev dependency so `uv pip install -e ".[dev]"` installs it
  assert_file_contains "$pyproject" "ruff>=0.14.0"
  # [tool.ruff] section with prettier-parity line length (D3)
  assert_file_contains "$pyproject" "[tool.ruff]"
  assert_file_contains "$pyproject" "line-length = 100"
  # lint rules E + F + I (pyflakes + pycodestyle errors + isort) (D4)
  assert_file_contains "$pyproject" 'select = ["E", "F", "I"]'
  # exclude list mirrors .prettierignore for the Python tooling (E4)
  assert_file_contains "$pyproject" '".venv",'
  assert_file_contains "$pyproject" '"secrets",'
}

# --- T2: scripts/lint-python-files.sh (lint-staged -> ruff bridge) -----------
#
# setup_wrapper_tree: copies the wrapper into an isolated temp repo so ROOT
# resolves to the temp tree (never the real repo venv), then plants fakes:
#   - `uv` on PATH records to UV_LOG; when asked to `venv`, it also creates
#     .venv/bin/{python,ruff} so the script's later venv commands resolve.
#   - .venv/bin/ruff records to RUFF_LOG and exits FAKE_RUFF_STATUS (0 default).

setup_wrapper_tree() {
  TREE="$BATS_TEST_TMPDIR/tree"
  # T-PY-001: analytics-pipeline is now in scope — run_ruff cds into its root,
  # so the dir must exist in the isolated tree (it reuses api-server's venv).
  mkdir -p "$TREE/scripts" \
    "$TREE/apps/api-server/.venv/bin" \
    "$TREE/packages/analytics-pipeline" \
    "$BATS_TEST_TMPDIR/bin"
  cp "$SCRIPTS_DIR/lint-python-files.sh" "$TREE/scripts/lint-python-files.sh"

  cat > "$TREE/apps/api-server/.venv/bin/ruff" <<'FAKERUFF'
#!/usr/bin/env bash
printf 'ruff %s\n' "$*" >> "${RUFF_LOG:?RUFF_LOG not set}"
exit "${FAKE_RUFF_STATUS:-0}"
FAKERUFF
  chmod +x "$TREE/apps/api-server/.venv/bin/ruff"

  # a pre-existing venv python marks the "venv already bootstrapped" state;
  # tests that exercise bootstrap remove it (and the fake uv recreates it)
  cat > "$TREE/apps/api-server/.venv/bin/python" <<'FAKEPY'
#!/usr/bin/env bash
exit 0
FAKEPY
  chmod +x "$TREE/apps/api-server/.venv/bin/python"

  cat > "$BATS_TEST_TMPDIR/bin/uv" <<'FAKEUV'
#!/usr/bin/env bash
printf 'uv %s\n' "$*" >> "${UV_LOG:?UV_LOG not set}"
if [ "${1:-}" = "venv" ]; then
  mkdir -p .venv/bin
  cat > .venv/bin/python <<'FAKEPY'
#!/usr/bin/env bash
exit 0
FAKEPY
  cat > .venv/bin/ruff <<'FAKERUFFBOOT'
#!/usr/bin/env bash
printf 'ruff %s\n' "$*" >> "${RUFF_LOG:?RUFF_LOG not set}"
exit 0
FAKERUFFBOOT
  chmod +x .venv/bin/python .venv/bin/ruff
fi
exit 0
FAKEUV
  chmod +x "$BATS_TEST_TMPDIR/bin/uv"

  export UV_LOG="$BATS_TEST_TMPDIR/uv.log"
  export RUFF_LOG="$BATS_TEST_TMPDIR/ruff.log"
  : > "$UV_LOG"
  : > "$RUFF_LOG"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "lint-python-files: runs ruff check --fix then ruff format on the passed files" {
  setup_wrapper_tree

  run bash "$TREE/scripts/lint-python-files.sh" apps/api-server/test.py

  assert_status 0
  assert_file_contains "$RUFF_LOG" "check --fix test.py"
  assert_file_contains "$RUFF_LOG" "format test.py"
  # venv already present -> only the idempotent install runs, no `uv venv`
  run grep -c "venv .venv" "$UV_LOG"
  [ "$output" = "0" ]
}

@test "lint-python-files: bootstraps the venv when .venv/bin/python is missing" {
  setup_wrapper_tree
  rm "$TREE/apps/api-server/.venv/bin/python"
  rm "$TREE/apps/api-server/.venv/bin/ruff"

  run bash "$TREE/scripts/lint-python-files.sh" apps/api-server/test.py

  assert_status 0
  assert_file_contains "$UV_LOG" "venv .venv"
  assert_file_contains "$UV_LOG" "pip install --python .venv/bin/python -q -e .[dev]"
  assert_file_contains "$RUFF_LOG" "check --fix test.py"
}

@test "lint-python-files: rebases repo-root-relative paths from lint-staged" {
  setup_wrapper_tree

  # lint-staged passes paths relative to the repo root (the wrapper cds into
  # apps/api-server, so the prefix must be stripped before ruff sees them)
  run bash "$TREE/scripts/lint-python-files.sh" apps/api-server/app/core/auth.py

  assert_status 0
  assert_file_contains "$RUFF_LOG" "check --fix app/core/auth.py"
  assert_file_contains "$RUFF_LOG" "format app/core/auth.py"
}

@test "lint-python-files: aborts on ruff failure without running ruff format" {
  setup_wrapper_tree
  export FAKE_RUFF_STATUS=1

  run bash "$TREE/scripts/lint-python-files.sh" apps/api-server/test.py

  assert_status 1
  assert_file_contains "$RUFF_LOG" "check --fix test.py"
  run grep -c "format test.py" "$RUFF_LOG"
  [ "$output" = "0" ]
}

@test "lint-python-files: skips out-of-scope paths without invoking ruff" {
  setup_wrapper_tree

  # T-PY-001: analytics-pipeline is now IN scope (it has its own ruff config),
  # so an out-of-scope path is one outside the two Python packages — it must be
  # skipped with a diagnostic, not forwarded to ruff as an unresolvable path
  # (that previously blocked pre-commit)
  run bash "$TREE/scripts/lint-python-files.sh" tools/opencode-docker/bootstrap.py

  assert_status 0
  # the diagnostic goes to stderr; bats 1.x splits stdout/stderr, older bats
  # merges them into $output — check both so the assertion is version-agnostic
  local combined="${output}${stderr:-}"
  [[ "$combined" == *"lint-python-files: skipping out-of-scope path: tools/opencode-docker/bootstrap.py"* ]] || {
    echo "expected skip diagnostic, got:" >&2
    echo "--- stdout ---" >&2
    printf '%s\n' "$output" >&2
    echo "--- stderr ---" >&2
    printf '%s\n' "${stderr:-}" >&2
    return 1
  }
  # ruff must not be invoked at all (not even with no paths, which from the
  # api-server cwd would lint-and-fix the whole package): recording log is empty
  [ ! -s "$RUFF_LOG" ] || {
    echo "expected no ruff invocation, got:" >&2
    cat "$RUFF_LOG" >&2
    return 1
  }
}
