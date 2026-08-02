#!/usr/bin/env bats
# Unit tests for scripts/verify-pre-commit.sh (the husky pre-commit autofix
# gate). Mirrors the verify-pre-push.bats contexts, with one deliberate
# difference (D1): when the dev container is down the pre-commit hook FAILS —
# a commit-time autofix gate that silently passes would not be "maximum
# automatic linting" — so the developer must start the stack or use
# `git commit --no-verify` to bypass explicitly.
#
# Three execution contexts are exercised without ever touching a real
# container, a real npx, or a real commit:
#   1. host + container running -> delegates lint-staged via `docker compose exec`
#   2. host + container down    -> exit 1 with a clear "dev container not running"
#   3. inside the container     -> runs `npx lint-staged --allow-empty` directly

load test-helper

setup() {
  mock_docker
}

@test "verify-pre-commit: delegates lint-staged to the dev container when on the host" {
  export FAKE_DOCKER_SERVICES="dev"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  assert_output_contains "delegating to dev container"
  assert_output_contains "autofix passed"
  # the full delegated command, including the --allow-empty flag
  assert_file_contains "$FAKE_DOCKER_LOG" "cd /workspace && npx lint-staged --allow-empty"
}

@test "verify-pre-commit: passes --allow-empty so empty commits are not blocked" {
  export FAKE_DOCKER_SERVICES="dev"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  # --allow-empty is part of every lint-staged invocation (E1: a commit with
  # no staged files must not fail the hook)
  assert_file_contains "$FAKE_DOCKER_LOG" "lint-staged --allow-empty"
}

@test "verify-pre-commit: blocks the commit when the dev container is down" {
  export FAKE_DOCKER_SERVICES="postgres"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 1
  assert_output_contains "dev container not running"
  # fail-by-default: lint-staged must never be delegated when the stack is down
  run grep -c "compose exec" "$FAKE_DOCKER_LOG"
  [ "$output" = "0" ]
}

@test "verify-pre-commit: runs lint-staged directly when already inside the dev container" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat > "$bindir/hostname" <<'FAKEHOSTNAME'
#!/usr/bin/env bash
echo "poetry-dev"
FAKEHOSTNAME
  cat > "$bindir/npx" <<'FAKENPX'
#!/usr/bin/env bash
printf 'npx %s\n' "$*" >> "${NPX_LOG:?NPX_LOG not set}"
exit 0
FAKENPX
  chmod +x "$bindir/hostname" "$bindir/npx"
  export PATH="$bindir:$PATH"
  export NPX_LOG="$BATS_TEST_TMPDIR/npx.log"
  export POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws"
  # run_workspace uses `bash -lc`, a login shell that sources ~/.profile, which
  # prepends $VOLTA_HOME/bin and would shadow our fake npx with the real one.
  # A temp HOME keeps the login shell clean so the fake npx is exercised.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$POETRY_WORKSPACE" "$HOME"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  assert_output_contains "running inside dev container"
  assert_output_contains "autofix passed"
  assert_file_contains "$NPX_LOG" "lint-staged --allow-empty"
  # docker must never be invoked from inside the container
  [ ! -s "$FAKE_DOCKER_LOG" ]
}
