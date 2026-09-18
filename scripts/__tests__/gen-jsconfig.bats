#!/usr/bin/env bats
# Behavioral tests for scripts/gen-jsconfig.sh (the jsconfig.json generator).
#
# Unlike dev-entrypoint.bats, these tests run against the REAL repo layout —
# the generator's input IS the workspace (pnpm-workspace.yaml + packages/*).
# No namespace isolation or fixtures: fixtures would duplicate the exact
# layout the generator exists to reflect, and drift when the workspace grows.

load test-helper

# Uses `run --separate-stderr` so the generator's stdout-only JSON is cleanly
# separated from its stderr diagnostics (skip notes/warnings).
bats_require_minimum_version 1.5.0

GEN_SCRIPT="$SCRIPTS_DIR/gen-jsconfig.sh"

@test "gen-jsconfig: emits valid JSON that jq can parse" {
  run --separate-stderr bash "$GEN_SCRIPT"
  assert_status 0
  echo "$output" | jq -e . >/dev/null
}

@test "gen-jsconfig: compilerOptions.baseUrl is '.'" {
  run --separate-stderr bash "$GEN_SCRIPT"
  assert_status 0
  assert_output_contains '"baseUrl": "."'
}

@test "gen-jsconfig: maps every current @poetry package" {
  run --separate-stderr bash "$GEN_SCRIPT"
  assert_status 0
  # Workspace inventory (verified 2026-08-25): these five @poetry-scoped
  # packages declare an entry point that exists on disk. If a new package is
  # added without an entry point, this test fails — catching the drift the
  # generator was designed to prevent. (@poetry/stress-lang-core removed
  # DIA-260825-aapj; re-scaffold deliberate when W1 lands.)
  assert_output_contains '"@poetry/data-contracts"'
  assert_output_contains '"@poetry/editor-engine"'
  assert_output_contains '"@poetry/phonetics-core"'
  assert_output_contains '"@poetry/visualizer-2d"'
  assert_output_contains '"@poetry/visualizer-3d"'
}

@test "gen-jsconfig: every mapped path points to an existing file" {
  run --separate-stderr bash "$GEN_SCRIPT"
  assert_status 0
  # Extract the first element of each paths[] value and verify it resolves
  # (relative to repo root, per baseUrl: ".") to a real file on disk.
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    assert_file_exists "$REPO_ROOT/$p"
  done < <(printf '%s\n' "$output" | jq -r '.compilerOptions.paths[] | .[0]')
}

@test "gen-jsconfig: output is deterministic across runs" {
  run --separate-stderr bash "$GEN_SCRIPT"
  assert_status 0
  local first="$output"
  run --separate-stderr bash "$GEN_SCRIPT"
  assert_status 0
  if [ "$first" != "$output" ]; then
    echo "gen-jsconfig: output differs between two runs of the same workspace" >&2
    diff <(printf '%s\n' "$first") <(printf '%s\n' "$output") >&2 || true
    return 1
  fi
}
