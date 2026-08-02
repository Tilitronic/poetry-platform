#!/usr/bin/env bats
# Unit tests for scripts/verify-pre-push.sh (the husky pre-push gate).
#
# Three execution contexts are exercised without ever touching a real
# container, a real pnpm run, or a real push:
#   1. host + container running -> delegates each step via `docker compose exec`
#   2. host + container down    -> warns and exits 0 (never blocks a push)
#   3. inside the container     -> runs pnpm directly (fake hostname + fake pnpm)

load test-helper

setup() {
  mock_docker
}

@test "verify-pre-push: skips with a warning when the dev container is not running" {
  export FAKE_DOCKER_SERVICES="postgres"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  assert_output_contains "pre-push verification skipped: dev container not running"
  # no verification step is delegated when the stack is down
  run grep -c "compose exec" "$FAKE_DOCKER_LOG"
  [ "$output" = "0" ]
}

@test "verify-pre-push: delegates every verification step to the dev container" {
  export FAKE_DOCKER_SERVICES="dev"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  assert_output_contains "delegating to dev container"
  assert_output_contains "verification passed"
  for step in "verify:format" "verify:js" "verify:js-tests" "verify:python"; do
    assert_file_contains "$FAKE_DOCKER_LOG" "$step"
  done
}

@test "verify-pre-push: aborts (exit 1) when a delegated step fails" {
  export FAKE_DOCKER_SERVICES="dev"
  export FAKE_DOCKER_FAIL_STEP="verify:js"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 1
  # the failing step is surfaced in the output
  assert_output_contains "verify:js"
}

@test "verify-pre-push: runs steps directly when already inside the dev container" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat > "$bindir/hostname" <<'FAKEHOSTNAME'
#!/usr/bin/env bash
echo "poetry-dev"
FAKEHOSTNAME
  cat > "$bindir/pnpm" <<'FAKEPNPM'
#!/usr/bin/env bash
printf 'pnpm %s\n' "$*" >> "${PNPM_LOG:?PNPM_LOG not set}"
exit 0
FAKEPNPM
  chmod +x "$bindir/hostname" "$bindir/pnpm"
  export PATH="$bindir:$PATH"
  export PNPM_LOG="$BATS_TEST_TMPDIR/pnpm.log"
  export POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$POETRY_WORKSPACE"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  assert_output_contains "running inside dev container"
  assert_output_contains "verification passed"
  for step in "verify:format" "verify:js" "verify:js-tests" "verify:python"; do
    assert_file_contains "$PNPM_LOG" "$step"
  done
  # docker must never be invoked from inside the container
  [ ! -s "$FAKE_DOCKER_LOG" ]
}
