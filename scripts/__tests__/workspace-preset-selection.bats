#!/usr/bin/env bats
# RED-phase seam tests for campaign ticket DIA-260916-gv9i.
#
# The selection store is isolated with XDG_CONFIG_HOME. Compose is mocked so
# startup assertions prove validation happens before container setup.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
MAKEFILE="$REPO_ROOT/Makefile"

setup() {
  mock_docker
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config-home"
  export COMPOSE_ENGINE=docker
  export COMPOSE_OS=native
}

run_make() {
  run env XDG_CONFIG_HOME="$XDG_CONFIG_HOME" COMPOSE_ENGINE=docker \
    COMPOSE_OS=native make -C "$REPO_ROOT" "$@"
}

@test "make exposes the workspace selector and forwards PRESET to opencode" {
  assert_file_contains "$MAKEFILE" "preset:"
  assert_file_contains "$MAKEFILE" "PRESET"
}

@test "make preset saves an exact name for the next launch" {
  run_make preset NAME=opencode-go

  assert_status 0
  assert_output_contains "opencode-go"
  assert_output_contains "$REPO_ROOT"
  assert_output_contains "next launch"
}

@test "startup uses PRESET override before the stored workspace selection" {
  run_make preset NAME=opencode-go
  assert_status 0

  run_make opencode PRESET=cebula
  assert_status 0
  assert_output_contains "cebula"
  assert_output_contains "PRESET"
  assert_output_contains "override"

  run_make opencode
  assert_status 0
  assert_output_contains "opencode-go"
  assert_output_contains "stored"
}

@test "startup reports the no-preset default when no selection exists" {
  run_make opencode

  assert_status 0
  assert_output_contains "no preset"
  assert_output_contains "source"
}

@test "unknown PRESET fails closed before agent setup" {
  run_make opencode PRESET=does-not-exist

  # GNU make reports a failed recipe as exit 2; the nonzero status still proves
  # the invalid preset fails closed before any container setup.
  assert_status 2
  assert_output_contains "does-not-exist"
  assert_output_contains "opencode-go"
  assert_output_contains "$REPO_ROOT"
  if grep -qF "compose up" "$FAKE_DOCKER_LOG" || grep -qF "compose exec" "$FAKE_DOCKER_LOG"; then
    echo "invalid PRESET must abort before container setup" >&2
    return 1
  fi
}
