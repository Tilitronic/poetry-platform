#!/usr/bin/env bats
# RED-phase seam tests for campaign ticket DIA-260916-gv9i.
#
# The selection store is isolated with XDG_CONFIG_HOME. Compose is mocked so
# startup assertions prove validation happens before container setup.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
MAKEFILE="$REPO_ROOT/Makefile"

setup() {
  export FAKE_DOCKER_LOG="$BATS_TEST_TMPDIR/docker-$BATS_TEST_NUMBER.log"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config-home-$BATS_TEST_NUMBER"
  unset OPENCODE_CONFIG_DIR
  # DIA-260916-gv9i followup: the dev shell exports OPENCODE_WORKSPACE_PRESET
  # (host launcher bridge) and PRESET may leak from the caller env. Either
  # would shadow the isolated file store, so drop both for hermetic tests.
  unset OPENCODE_WORKSPACE_PRESET
  unset PRESET
  export COMPOSE_ENGINE=docker
  export COMPOSE_OS=native
  mock_docker
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
  run_make preset NAME=promo

  assert_status 0
  assert_output_contains "promo"
  assert_output_contains "$REPO_ROOT"
  assert_output_contains "next launch"
}

@test "startup uses PRESET override before the stored workspace selection" {
  run_make preset NAME=promo
  assert_status 0

  run_make opencode PRESET=openai-first-cost-balanced
  assert_status 0
  assert_output_contains "openai-first-cost-balanced"
  assert_output_contains "PRESET"
  assert_output_contains "override"

  run_make opencode
  assert_status 0
  assert_output_contains "promo"
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
  assert_output_contains "promo"
  assert_output_contains "$REPO_ROOT"
  if grep -qF "compose up" "$FAKE_DOCKER_LOG" || grep -qF "compose exec" "$FAKE_DOCKER_LOG"; then
    echo "invalid PRESET must abort before container setup" >&2
    return 1
  fi
}

@test "stale stored preset fails closed before agent setup" {
  mkdir -p "$XDG_CONFIG_HOME/opencode"
  printf '{"version":1,"workspaces":{"%s":"removed"}}\n' "$REPO_ROOT" \
    > "$XDG_CONFIG_HOME/opencode/workspace-presets.json"

  run_make opencode

  assert_status 2
  assert_output_contains "removed"
  assert_output_contains "$REPO_ROOT"
  assert_output_contains "promo"
  [ ! -s "$FAKE_DOCKER_LOG" ]
}

@test "malformed stored data fails closed before agent setup" {
  mkdir -p "$XDG_CONFIG_HOME/opencode"
  printf '{malformed\n' > "$XDG_CONFIG_HOME/opencode/workspace-presets.json"

  run_make opencode

  assert_status 2
  assert_output_contains "invalid store data"
  assert_output_contains "$REPO_ROOT"
  assert_output_contains "promo"
  [ ! -s "$FAKE_DOCKER_LOG" ]
}

@test "store lock failure does not acknowledge a preset write" {
  mkdir -p "$XDG_CONFIG_HOME/opencode"
  : > "$XDG_CONFIG_HOME/opencode/workspace-presets.json.lock"

  run_make preset NAME=promo

  assert_status 2
  assert_output_contains "lock"
  assert_output_not_contains "Saved"
}

@test "project config parse failure fails closed before agent setup" {
  workspace="$BATS_TEST_TMPDIR/parse-workspace-$BATS_TEST_NUMBER"
  mkdir -p "$workspace/.opencode"
  printf '{malformed\n' > "$workspace/.opencode/oh-my-opencode-slim.json"

  run env XDG_CONFIG_HOME="$XDG_CONFIG_HOME" bun run \
    "$REPO_ROOT/.opencode/oh-my-opencode-slim/src/config/workspace-preset-cli.ts" \
    resolve "$workspace"

  assert_status 1
  assert_output_contains "invalid preset configuration"
  [ ! -s "$FAKE_DOCKER_LOG" ]
}
