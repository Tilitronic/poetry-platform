#!/usr/bin/env bats
# Unit tests for scripts/dev-stack.sh.
#
# `docker` is replaced by a recording fake (mock_docker in test-helper.bash) —
# no containers are started. The script is copied into an isolated temp tree
# so the real repo .env is never created or overwritten.

load test-helper

setup() {
  mock_docker
  # Hermetic engine selection (DIA-260909-9api precedent): an inherited
  # COMPOSE_ENGINE=podman would route the script at a podman fake the old
  # assertions do not expect. Unset it; engine-specific tests export it.
  unset COMPOSE_ENGINE
  DEV_STACK_TREE="$(setup_dev_stack_tree)"
}

@test "dev-stack: creates .env from .env.example when missing" {
  run bash "$DEV_STACK_TREE/scripts/dev-stack.sh"

  assert_status 0
  assert_output_contains "created .env from .env.example"
  assert_file_exists "$DEV_STACK_TREE/.env"
  # the compose stack is actually started
  assert_file_contains "$FAKE_DOCKER_LOG" "compose up -d --build"
}

@test "dev-stack: skips .env creation when .env already present" {
  printf 'SENTINEL=1\n' > "$DEV_STACK_TREE/.env"

  run bash "$DEV_STACK_TREE/scripts/dev-stack.sh"

  assert_status 0
  assert_output_contains ".env already present"
  # existing file must be left untouched (never re-copied from template)
  assert_file_contains "$DEV_STACK_TREE/.env" "SENTINEL=1"
}

@test "dev-stack: exits with a clear error when the container engine is unreachable" {
  export FAKE_DOCKER_DAEMON_UP=no

  run bash "$DEV_STACK_TREE/scripts/dev-stack.sh"

  assert_status 1
  assert_output_contains "is not reachable"
  # the stack must not be started when the engine is unreachable
  assert_file_contains "$FAKE_DOCKER_LOG" "info"
  assert_output_not_contains "compose up"
}

@test "dev-stack: skips pnpm install when turbo binary already present" {
  export FAKE_DOCKER_TURBO_INSTALLED=yes

  run bash "$DEV_STACK_TREE/scripts/dev-stack.sh"

  assert_status 0
  assert_output_contains "dependencies already installed"
  assert_output_not_contains "pnpm install"
  assert_file_contains "$FAKE_DOCKER_LOG" "test -x node_modules/.bin/turbo"
}

@test "dev-stack: runs pnpm install when turbo binary is missing" {
  export FAKE_DOCKER_TURBO_INSTALLED=no

  run bash "$DEV_STACK_TREE/scripts/dev-stack.sh"

  assert_status 0
  assert_output_contains "installing dependencies"
  assert_file_contains "$FAKE_DOCKER_LOG" "pnpm install"
}
