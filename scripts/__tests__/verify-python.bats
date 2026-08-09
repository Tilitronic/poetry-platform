#!/usr/bin/env bats
# Unit tests for scripts/verify-python.sh — the pre-push Python gate. Covers
# the ruff extension (D5): ruff check + ruff format --check run BEFORE pytest,
# a ruff failure aborts without running pytest, and the venv bootstrap is
# skipped when the venv already exists.
#
# Isolation: the script is copied into a temp tree so ROOT resolves to the
# temp tree (never the real repo venv). `uv` (on PATH), .venv/bin/ruff and
# .venv/bin/python are recording fakes.

load test-helper

# setup_python_tree: copies verify-python.sh into an isolated temp repo and
# plants fakes for uv, .venv/bin/ruff and .venv/bin/python. The fake uv
# recreates the venv binaries when asked to bootstrap (so the bootstrap test
# still reaches the ruff/pytest steps).

setup_python_tree() {
  TREE="$BATS_TEST_TMPDIR/tree"
  # Mirror verify-python.sh's package list (DIA-013: apps/api-server +
  # packages/analytics-pipeline) so the second package's `cd` does not fail.
  # Fakes are planted in BOTH venvs; tests delete a venv's binaries to drive
  # the bootstrap path for that package.
  mkdir -p "$TREE/scripts" "$BATS_TEST_TMPDIR/bin"
  for pkg in apps/api-server packages/analytics-pipeline; do
    mkdir -p "$TREE/$pkg/.venv/bin"
    cat > "$TREE/$pkg/.venv/bin/ruff" <<'FAKERUFF'
#!/usr/bin/env bash
printf 'ruff %s\n' "$*" >> "${RUFF_LOG:?RUFF_LOG not set}"
exit "${FAKE_RUFF_STATUS:-0}"
FAKERUFF
    chmod +x "$TREE/$pkg/.venv/bin/ruff"

    cat > "$TREE/$pkg/.venv/bin/python" <<'FAKEPY'
#!/usr/bin/env bash
printf 'python %s\n' "$*" >> "${PYTHON_LOG:?PYTHON_LOG not set}"
exit 0
FAKEPY
    chmod +x "$TREE/$pkg/.venv/bin/python"
  done
  cp "$SCRIPTS_DIR/verify-python.sh" "$TREE/scripts/verify-python.sh"

  cat > "$BATS_TEST_TMPDIR/bin/uv" <<'FAKEUV'
#!/usr/bin/env bash
printf 'uv %s\n' "$*" >> "${UV_LOG:?UV_LOG not set}"
if [ "${1:-}" = "venv" ]; then
  mkdir -p .venv/bin
  cat > .venv/bin/python <<'FAKEPYBOOT'
#!/usr/bin/env bash
printf 'python %s\n' "$*" >> "${PYTHON_LOG:?PYTHON_LOG not set}"
exit 0
FAKEPYBOOT
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
  export PYTHON_LOG="$BATS_TEST_TMPDIR/python.log"
  : > "$UV_LOG"
  : > "$RUFF_LOG"
  : > "$PYTHON_LOG"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "verify-python: runs ruff check, ruff format --check, then pytest in order" {
  setup_python_tree

  run bash "$TREE/scripts/verify-python.sh"

  assert_status 0
  assert_file_contains "$PYTHON_LOG" "python -m pytest"
  # ruff runs first (fast, blocks pytest on code that would not pass review)
  [[ "$(sed -n '1p' "$RUFF_LOG")" == *"check ."* ]]
  [[ "$(sed -n '2p' "$RUFF_LOG")" == *"format --check ."* ]]
}

@test "verify-python: aborts on ruff failure without running pytest" {
  setup_python_tree
  export FAKE_RUFF_STATUS=1

  run bash "$TREE/scripts/verify-python.sh"

  assert_status 1
  assert_file_contains "$RUFF_LOG" "check ."
  # ruff format is not reached, and pytest must never run on unlinted code
  run grep -c "format --check ." "$RUFF_LOG"
  [ "$output" = "0" ]
  run grep -c "pytest" "$PYTHON_LOG"
  [ "$output" = "0" ]
}

@test "verify-python: reuses the existing venv on subsequent runs" {
  setup_python_tree

  run bash "$TREE/scripts/verify-python.sh"

  assert_status 0
  # the idempotent install still runs, but no fresh `uv venv` bootstrap
  assert_file_contains "$UV_LOG" "pip install --python .venv/bin/python -q -e .[dev]"
  run grep -c "venv .venv" "$UV_LOG"
  [ "$output" = "0" ]
}

@test "verify-python: bootstraps the venv when it is missing" {
  setup_python_tree
  rm "$TREE/apps/api-server/.venv/bin/python"
  rm "$TREE/apps/api-server/.venv/bin/ruff"

  run bash "$TREE/scripts/verify-python.sh"

  assert_status 0
  assert_file_contains "$UV_LOG" "venv .venv"
  assert_file_contains "$UV_LOG" "pip install --python .venv/bin/python -q -e .[dev]"
  assert_file_contains "$PYTHON_LOG" "python -m pytest"
}
