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
  # Point the /home/qualt guard (POETRY_COMMANDS_DIR seam — mirror of the
  # POETRY_WORKSPACE override) at an isolated empty dir so every test is
  # hermetic regardless of the real repo's .opencode/commands state.
  export POETRY_COMMANDS_DIR="$BATS_TEST_TMPDIR/commands"
  mkdir -p "$POETRY_COMMANDS_DIR"
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
  # run_workspace uses `bash -lc`, a login shell that sources ~/.profile, which
  # prepends $VOLTA_HOME/bin and would shadow our fake pnpm with the real one
  # (the real pnpm then errors: no package.json in the temp workspace). A temp
  # HOME keeps the login shell clean so the fake pnpm is exercised.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$POETRY_WORKSPACE" "$HOME"
  # DIA-119: the temp-HOME guard is the single defense against a host login
  # profile (~/.profile prepends $VOLTA_HOME/bin) shadowing the fake pnpm with
  # the real one, which then errors ERR_PNPM_NO_IMPORTER_MANIFEST_FOUND in this
  # empty sandbox. Seed an importer manifest + the four verify scripts (logging
  # to PNPM_LOG exactly like the fake) so the outcome no longer depends on
  # which pnpm resolves.
  # NOTE: \\n in the unquoted heredoc becomes \n in the file, JSON-decode turns it into a literal newline, printf emits it (3-stage chain - do NOT quote the heredoc or normalize \\n).
  cat > "$POETRY_WORKSPACE/package.json" <<EOF
{"name":"verify-pre-push-sandbox","private":true,"scripts":{
  "verify:format":"printf '%s\\n' 'pnpm verify:format' >> \"\$PNPM_LOG\"",
  "verify:js":"printf '%s\\n' 'pnpm verify:js' >> \"\$PNPM_LOG\"",
  "verify:js-tests":"printf '%s\\n' 'pnpm verify:js-tests' >> \"\$PNPM_LOG\"",
  "verify:python":"printf '%s\\n' 'pnpm verify:python' >> \"\$PNPM_LOG\""
}}
EOF

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

@test "verify-pre-push: delegates a workspace path with spaces as one cd argument" {
  export FAKE_DOCKER_SERVICES="dev"
  export POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws with spaces"
  mkdir -p "$POETRY_WORKSPACE"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  # the delegated log must preserve the space-containing path as ONE quoted cd
  # argument — an unquoted $WORKSPACE would split it at the first space (D2)
  assert_file_contains "$FAKE_DOCKER_LOG" "cd \"$POETRY_WORKSPACE\" &&"
}

@test "verify-pre-push: blocks the push when a .opencode/commands file contains literal /home/qualt" {
  export FAKE_DOCKER_SERVICES="dev"
  local commands_dir="$BATS_TEST_TMPDIR/commands-dirty"
  mkdir -p "$commands_dir"
  printf 'bun run "/home/qualt/.cache/opencode/telemetry/report.ts"\n' > "$commands_dir/telemetry-report.md"
  export POETRY_COMMANDS_DIR="$commands_dir"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 1
  assert_output_contains "ERROR: literal '/home/qualt'"
  assert_output_contains "telemetry-report.md"
  # the guard fires BEFORE container detection/delegation — docker must never
  # be reached while a dirty .opencode/commands file exists
  [ ! -s "$FAKE_DOCKER_LOG" ]
}

@test "verify-pre-push: passes when no .opencode/commands file contains literal /home/qualt" {
  export FAKE_DOCKER_SERVICES="dev"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  assert_output_contains "verification passed"
}
