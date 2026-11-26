#!/usr/bin/env bats
# Single-path preset launch (campaign ticket DIA-260918-vsq8).
#
# Exactly one supported way to launch with a preset:
#   make presets                  -> list registry names
#   make opencode PRESET=<name>   -> one-run override, no persistence
# `make preset` is a deprecated stub (exit 2, writes nothing).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
MAKEFILE="$REPO_ROOT/Makefile"

setup() {
  export FAKE_DOCKER_LOG="$BATS_TEST_TMPDIR/docker-$BATS_TEST_NUMBER.log"
  unset OPENCODE_WORKSPACE_PRESET
  unset PRESET
  export COMPOSE_ENGINE=docker
  export COMPOSE_OS=native
  mock_docker
}

run_make() {
  run env XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER" \
    COMPOSE_ENGINE=docker COMPOSE_OS=native make -C "$REPO_ROOT" "$@"
}

@test "make presets lists exactly the current registry (mimo-balanced and openai-first-cost-balanced)" {
  run_make presets
  assert_status 0
  assert_output_contains "mimo-balanced"
  assert_output_contains "openai-first-cost-balanced"
  # Exact inventory (DIA-260929-5c6m removed promo-union-alpha and free):
  # after stripping make's directory chatter, every remaining line must be a
  # registry name and together they are exactly the two current names.
  registry="$(printf '%s\n' "$output" | grep -v '^make' || true)"
  [ "$registry" = "$(printf 'mimo-balanced\nopenai-first-cost-balanced')" ]
  # Strengthened: the removed presets are rejected as unknown, not merely
  # absent from the list - the registry validates names both ways.
  run_make opencode PRESET=free
  assert_status 2
  assert_output_contains 'Unknown preset "free"'
  run_make opencode PRESET=promo-union-alpha
  assert_status 2
  assert_output_contains 'Unknown preset "promo-union-alpha"'
}

@test "make preset stub exits 2, names the single path, writes nothing" {
  run_make preset NAME=mimo-balanced
  assert_status 2
  assert_output_contains "make opencode PRESET="
  assert_output_contains "make presets"
}

@test "Makefile forwards the override via -e OH_MY_OPENCODE_SLIM_PRESET and has no second path" {
  assert_file_contains "$MAKEFILE" '-e OH_MY_OPENCODE_SLIM_PRESET='
  assert_file_contains "$MAKEFILE" 'presets:'
  if grep -qF "OPENCODE_WORKSPACE_PRESET" "$MAKEFILE"; then
    echo "Makefile must not reference the dropped bridge" >&2
    return 1
  fi
}

# PRESET uses a surviving non-active preset and the stale bridge exports the
# other surviving preset, so "output carries the PRESET value but not the
# bridge value" still discriminates the two paths after DIA-260929-5c6m
# removed `free` (the historical PRESET value here).
@test "a stale OPENCODE_WORKSPACE_PRESET export is ignored, PRESET wins by being the only path" {
  run env XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER" \
    COMPOSE_ENGINE=docker COMPOSE_OS=native \
    OPENCODE_WORKSPACE_PRESET=mimo-balanced \
    make -C "$REPO_ROOT" opencode PRESET=openai-first-cost-balanced
  assert_status 0
  assert_output_contains "openai-first-cost-balanced"
  assert_output_contains "PRESET override"
  assert_output_not_contains "mimo-balanced"
  grep -qF "OH_MY_OPENCODE_SLIM_PRESET=openai-first-cost-balanced" "$FAKE_DOCKER_LOG"
}

@test "bare make opencode forwards no override even with a stale bridge exported" {
  run env XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER" \
    COMPOSE_ENGINE=docker COMPOSE_OS=native \
    OPENCODE_WORKSPACE_PRESET=openai-first-cost-balanced \
    make -C "$REPO_ROOT" opencode
  assert_status 0
  assert_output_contains "no override"
  if grep -qF "OH_MY_OPENCODE_SLIM_PRESET=" "$FAKE_DOCKER_LOG"; then
    echo "bare make opencode must forward no OH_MY_OPENCODE_SLIM_PRESET override" >&2
    return 1
  fi
}

@test "unknown PRESET fails loudly with the available list before container setup" {
  run_make opencode PRESET=does-not-exist
  assert_status 2
  assert_output_contains "does-not-exist"
  assert_output_contains "Available presets"
  assert_output_contains "mimo-balanced"
  if grep -qF "compose exec" "$FAKE_DOCKER_LOG"; then
    echo "invalid PRESET must abort before container setup" >&2
    return 1
  fi
}
