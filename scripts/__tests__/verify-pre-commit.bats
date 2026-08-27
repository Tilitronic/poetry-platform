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
  # Hermetic host-context (DIA-071, 2026-08-12): fake hostname keeps every
  # non-direct test in the HOST + container-running delegation path even when
  # the suite runs inside poetry-dev; isolated POETRY_COMMANDS_DIR keeps the
  # /home/qualt guard hermetic. See setup_hermetic_host_context in
  # test-helper.bash. The dedicated "runs lint-staged directly" test shadows
  # the fake hostname with its own poetry-dev fake.
  setup_hermetic_host_context
}

@test "verify-pre-commit: delegates lint-staged to the dev container when on the host" {
  export FAKE_DOCKER_SERVICES="dev"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  assert_output_contains "delegating to dev container"
  assert_output_contains "autofix passed"
  # the full delegated command, including the --allow-empty flag; the inner cd
  # target is escaped-quoted so a space-containing WORKSPACE stays one argument
  assert_file_contains "$FAKE_DOCKER_LOG" "cd \"/workspace\" && npx lint-staged --allow-empty"
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
  # DIA-119 (symmetric fix): the temp-HOME guard is the single defense against
  # a host login profile (~/.profile prepends $VOLTA_HOME/bin) shadowing the
  # fake npx with the real one, which then runs real lint-staged and errors in
  # this empty sandbox (npx ENOENT / lint-staged fetch, or "not a git
  # directory"). Seed an importer manifest + a local lint-staged stub (logging
  # to NPX_LOG exactly like the fake) so real npx resolves the stub from
  # node_modules/.bin and the outcome no longer depends on which npx resolves.
  cat > "$POETRY_WORKSPACE/package.json" <<EOF
{"name":"verify-pre-commit-sandbox","private":true}
EOF
  mkdir -p "$POETRY_WORKSPACE/node_modules/.bin"
  cat > "$POETRY_WORKSPACE/node_modules/.bin/lint-staged" <<'FAKELS'
#!/usr/bin/env bash
# F2: adaptive stub - log via "$*" (real npx invokes us with only the args
# after the binary name, so rebuild the full command from $0; the fake npx
# receives the whole command and logs the same line). Arg drift is detected.
printf 'npx %s\n' "$(basename "$0") $*" >> "${NPX_LOG:?NPX_LOG not set}"
exit 0
FAKELS
  chmod +x "$POETRY_WORKSPACE/node_modules/.bin/lint-staged"
  # DIA-071: Debian-style hosts reset PATH unconditionally in /etc/profile for
  # login shells, which would drop the fake bindir above; a temp ~/.bash_profile
  # that re-prepends it keeps the fake npx hermetic (mirror of the
  # verify-pre-push "runs steps directly" test).
  printf 'export PATH="%s:$PATH"\n' "$bindir" > "$HOME/.bash_profile"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  assert_output_contains "running inside dev container"
  assert_output_contains "autofix passed"
  assert_file_contains "$NPX_LOG" "lint-staged --allow-empty"
  # docker must never be invoked from inside the container
  [ ! -s "$FAKE_DOCKER_LOG" ]
}

@test "verify-pre-commit: delegates a workspace path with spaces as one cd argument" {
  export FAKE_DOCKER_SERVICES="dev"
  export POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws with spaces"
  mkdir -p "$POETRY_WORKSPACE"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  # the delegated log must preserve the space-containing path as ONE quoted cd
  # argument — an unquoted $WORKSPACE would split it at the first space (D2)
  assert_file_contains "$FAKE_DOCKER_LOG" "cd \"$POETRY_WORKSPACE\" &&"
}

@test "verify-pre-commit: sources the shared home-qualt guard and calls it, with no inline definition" {
  # F-6 (DIA-139): the /home/qualt grep behavior is canonical in
  # guards-home-qualt.bats; the hook only needs to source the helper and
  # call the function. Assert the wiring statically (batch-D grep pattern).
  # The source line must exist, the call site must remain, and the inline
  # function definition must be gone.
  run grep -F 'scripts/guards/home-qualt.sh' "$SCRIPTS_DIR/verify-pre-commit.sh"
  assert_status 0
  run grep -xF 'guard_no_home_qualt' "$SCRIPTS_DIR/verify-pre-commit.sh"
  assert_status 0
  run grep -F 'guard_no_home_qualt()' "$SCRIPTS_DIR/verify-pre-commit.sh"
  assert_status 1
}

# ---------------------------------------------------------------------------
# DIA-260821-aoag: when the engine socket is absent INSIDE opencode-docker the
# hook must fail with --with-engine guidance (not the misleading "make up"
# message). The OPENCODE_DOCKER=1 sentinel (exported by the launcher) is the
# signal; the host-down path (no sentinel) keeps the original message.
# ---------------------------------------------------------------------------

@test "verify-pre-commit: inside opencode-docker without engine socket fails with --with-engine guidance" {
  export OPENCODE_DOCKER=1
  # FAKE_DOCKER_DAEMON_UP=no -> `docker info` fails (engine socket unreachable),
  # so engine_socket_reachable is false -> --with-engine remediation.
  export FAKE_DOCKER_DAEMON_UP=no

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 1
  assert_output_contains "--with-engine"
}

@test "verify-pre-commit: host-down path unchanged (no sentinel -> make up guidance, no --with-engine)" {
  # no OPENCODE_DOCKER sentinel; container down -> original message only
  export FAKE_DOCKER_SERVICES="postgres"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 1
  assert_output_contains "dev container not running"
  assert_output_not_contains "--with-engine"
}

@test "verify-pre-commit: inside opencode-docker with engine socket but dev service down -> make up guidance" {
  export OPENCODE_DOCKER=1
  # FAKE_DOCKER_DAEMON_UP default yes -> `docker info` succeeds (socket
  # reachable); FAKE_DOCKER_SERVICES=postgres -> dev service not running. The
  # socket IS available, so the remedy is `make up`, NOT --with-engine.
  export FAKE_DOCKER_SERVICES="postgres"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 1
  assert_output_contains "dev container not running"
  assert_output_not_contains "--with-engine"
}
