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

@test "make presets lists a non-empty registry including free and muse-balanced" {
  run_make presets
  assert_status 0
  assert_output_contains "free"
  assert_output_contains "muse-balanced"
}

@test "make preset stub exits 2, names the single path, writes nothing" {
  run_make preset NAME=muse-balanced
  assert_status 2
  assert_output_contains "make opencode PRESET="
  assert_output_contains "make presets"
}

@test "Makefile forwards the override via -e PRESET and has no second path" {
  assert_file_contains "$MAKEFILE" '-e PRESET='
  assert_file_contains "$MAKEFILE" 'presets:'
  if grep -qF "OPENCODE_WORKSPACE_PRESET" "$MAKEFILE"; then
    echo "Makefile must not reference the dropped bridge" >&2
    return 1
  fi
}

@test "a stale OPENCODE_WORKSPACE_PRESET export is ignored, PRESET wins by being the only path" {
  run env XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER" \
    COMPOSE_ENGINE=docker COMPOSE_OS=native \
    OPENCODE_WORKSPACE_PRESET=openai-first-cost-balanced \
    make -C "$REPO_ROOT" opencode PRESET=free
  assert_status 0
  assert_output_contains "free"
  assert_output_contains "PRESET override"
  assert_output_not_contains "openai-first-cost-balanced"
  grep -qF "PRESET=free" "$FAKE_DOCKER_LOG"
}

@test "bare make opencode forwards no override even with a stale bridge exported" {
  run env XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER" \
    COMPOSE_ENGINE=docker COMPOSE_OS=native \
    OPENCODE_WORKSPACE_PRESET=openai-first-cost-balanced \
    make -C "$REPO_ROOT" opencode
  assert_status 0
  assert_output_contains "no override"
  if grep -qF "PRESET=" "$FAKE_DOCKER_LOG"; then
    echo "bare make opencode must forward no PRESET override" >&2
    return 1
  fi
}

@test "unknown PRESET fails loudly with the available list before container setup" {
  run_make opencode PRESET=does-not-exist
  assert_status 2
  assert_output_contains "does-not-exist"
  assert_output_contains "Available presets"
  assert_output_contains "muse-balanced"
  if grep -qF "compose exec" "$FAKE_DOCKER_LOG"; then
    echo "invalid PRESET must abort before container setup" >&2
    return 1
  fi
}
