#!/usr/bin/env bats
# Unit tests for scripts/verify-pre-push.sh (the husky pre-push gate).
#
# Three execution contexts are exercised without ever touching a real
# container, a real pnpm run, or a real push:
#   1. host + container running -> delegates each step via `docker compose exec`
#   2. host + container down    -> warns and exits 0 (never blocks a push)
#   3. inside the container     -> runs pnpm directly (fake hostname + fake pnpm)
#
# The verification chain is: the four pnpm verify steps + make test-config in
# fast-to-fail order, with the slow bats suite (make test-shell) LAST (F-1,
# DIA-139: a format/typecheck failure surfaces in ~1.2 s instead of ~25 s;
# DIA-118 originally put the make gates first, F-1 reordered them last).

load test-helper

setup() {
  mock_docker
  # DIA-123: the husky pre-push hook exports VERIFY_PRE_PUSH_RUNNING=1 before
  # running make test-shell, so every bats test would inherit the flag and hit
  # the script's recursion guard (warning + exit 0), breaking the direct
  # invocation tests. Unset it so every test exercises the public entry
  # behavior with a clean environment; the inherited flag is an artifact of the
  # hook environment, not the test subject.
  unset VERIFY_PRE_PUSH_RUNNING
  # Maintainer note: a future test that wants to verify the recursion guard
  # must re-export VERIFY_PRE_PUSH_RUNNING=1 inside its own body AFTER setup()
  # runs (setup() unsets it above).
  # Hermetic host-context (DIA-071, 2026-08-12): fake hostname keeps every
  # non-direct test in the HOST + container-running delegation path even when
  # the suite runs inside poetry-dev; isolated POETRY_COMMANDS_DIR keeps the
  # /home/qualt guard hermetic. See setup_hermetic_host_context in
  # test-helper.bash. The dedicated "runs steps directly" test shadows the
  # fake hostname with its own poetry-dev fake.
  setup_hermetic_host_context
}

@test "verify-pre-push: recursion guard fires when VERIFY_PRE_PUSH_RUNNING is set" {
  # setup() unsets the flag, so re-export it here to exercise the guard path
  # (the hook context exports it before running make test-shell).
  export VERIFY_PRE_PUSH_RUNNING=1

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  assert_output_contains "already running (recursion guard; skipping)"
  # gates must never run when the guard fires (no docker invocation at all)
  [ ! -s "$FAKE_DOCKER_LOG" ]
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

@test "verify-pre-push: delegates every verification step in fast-to-fail order, make test-shell last" {
  export FAKE_DOCKER_SERVICES="dev"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  assert_output_contains "delegating to dev container"
  assert_output_contains "verification passed"
  # F-1 (DIA-139): all six steps are still delegated -- the fast pnpm gates
  # and the config validator first, the slow bats suite (make test-shell)
  # LAST so a format/typecheck failure surfaces in ~1.2 s instead of ~25 s.
  # F-1 ORDER: each step must appear EXACTLY once, in ladder order. The log's
  # first line is the container_running `compose ps` probe, so assert on the
  # per-step match count and the relative index order of the single matches.
  # End-anchored matching: the delegated command is the last arg of the
  # `bash -lc` invocation, so `verify:js$` matches only the js line, never the
  # js-tests line (which ends in `verify:js-tests`). A duplicate step or a
  # swapped pair now fails the count/order check instead of being masked by
  # first-occurrence grep (FALSIFICATION-3, DIA-139).
  local prev=0 step count line
  for step in "verify:format" "verify:js" "verify:js-tests" "make test-config" "verify:python" "make test-shell"; do
    count="$(grep -cE -- "${step}\$" "$FAKE_DOCKER_LOG")"
    [ "$count" -eq 1 ] || {
      echo "count assertion: expected exactly 1 occurrence of '$step', got $count in $FAKE_DOCKER_LOG" >&2
      return 1
    }
    line="$(grep -nE -- "${step}\$" "$FAKE_DOCKER_LOG" | cut -d: -f1)"
    [ "$line" -gt "$prev" ] || {
      echo "order assertion: expected '$step' at a line > $prev in $FAKE_DOCKER_LOG" >&2
      return 1
    }
    prev="$line"
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

@test "verify-pre-push: aborts (exit 1) when make test-shell fails, after all faster gates ran" {
  export FAKE_DOCKER_SERVICES="dev"
  export FAKE_DOCKER_FAIL_STEP="test-shell"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 1
  # the failing gate is named in the output
  assert_output_contains "make test-shell"
  # F-1 (DIA-139): test-shell is the LAST gate, so the four fast pnpm gates
  # and the config validator must have run before it fails (they precede it
  # in the ladder).
  for step in "verify:format" "verify:js" "verify:js-tests" "make test-config" "verify:python"; do
    assert_file_contains "$FAKE_DOCKER_LOG" "$step"
  done
}

@test "verify-pre-push: aborts (exit 1) when make test-config fails, after the fast pnpm gates ran" {
  export FAKE_DOCKER_SERVICES="dev"
  export FAKE_DOCKER_FAIL_STEP="test-config"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 1
  assert_output_contains "make test-config"
  # F-1 (DIA-139): config sits between the fast pnpm gates and the slow bats
  # suite, so format/js/js-tests ran BEFORE the failure ...
  assert_file_contains "$FAKE_DOCKER_LOG" "verify:format"
  assert_file_contains "$FAKE_DOCKER_LOG" "verify:js"
  assert_file_contains "$FAKE_DOCKER_LOG" "verify:js-tests"
  # ... and the slow gate (make test-shell) must NOT have run yet -- it is
  # LAST in the ladder, so the fail-fast abort never reaches it.
  run grep -c "make test-shell" "$FAKE_DOCKER_LOG"
  [ "$output" = "0" ]
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
printf 'pnpm %s\n' "$*" >> "${DELEGATION_LOG:?DELEGATION_LOG not set}"
exit 0
FAKEPNPM
  cat > "$bindir/make" <<'FAKEMAKE'
#!/usr/bin/env bash
printf 'make %s\n' "$*" >> "${DELEGATION_LOG:?DELEGATION_LOG not set}"
exit 0
FAKEMAKE
  chmod +x "$bindir/hostname" "$bindir/pnpm" "$bindir/make"
  export PATH="$bindir:$PATH"
  # Both fakes append to the SAME log (half the entries are make invocations,
  # not pnpm), so the name is DELEGATION_LOG, not PNPM_LOG (S1).
  export DELEGATION_LOG="$BATS_TEST_TMPDIR/delegation.log"
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
  # DIA-118: Debian-style hosts reset PATH unconditionally in /etc/profile for
  # login shells, which would drop the fake bindir above; a temp ~/.bash_profile
  # that re-prepends it keeps the fakes (pnpm AND make) hermetic.
  printf 'export PATH="%s:$PATH"\n' "$bindir" > "$HOME/.bash_profile"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  assert_output_contains "running inside dev container"
  assert_output_contains "verification passed"
  # All six ladder steps run directly (no docker) inside the container too;
  # their F-1 fast-to-fail order is asserted in the delegation-path test.
  for step in "verify:format" "verify:js" "verify:js-tests" "make test-config" "verify:python" "make test-shell"; do
    assert_file_contains "$DELEGATION_LOG" "$step"
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

@test "verify-pre-push: sources the shared home-qualt guard and calls it, with no inline definition" {
  # F-6 (DIA-139): the /home/qualt grep behavior is canonical in
  # guards-home-qualt.bats; the hook only needs to source the helper and
  # call the function. Assert the wiring statically (batch-D grep pattern).
  # The source line must exist, the call site must remain, and the inline
  # function definition must be gone.
  run grep -F 'scripts/guards/home-qualt.sh' "$SCRIPTS_DIR/verify-pre-push.sh"
  assert_status 0
  run grep -xF 'guard_no_home_qualt' "$SCRIPTS_DIR/verify-pre-push.sh"
  assert_status 0
  run grep -F 'guard_no_home_qualt()' "$SCRIPTS_DIR/verify-pre-push.sh"
  assert_status 1
}

@test "verify-pre-push: aborts (exit 1) when the sourced guard finds a literal /home/qualt" {
  export FAKE_DOCKER_SERVICES="dev"
  local commands_dir="$BATS_TEST_TMPDIR/commands-dirty"
  mkdir -p "$commands_dir"
  printf 'bun run "/home/qualt/.cache/opencode/telemetry/report.ts"\n' > "$commands_dir/telemetry-report.md"
  export POETRY_COMMANDS_DIR="$commands_dir"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 1
  assert_output_contains "ERROR: literal '/home/qualt'"
  assert_output_contains "telemetry-report.md"
  # end-to-end wiring check (P-3, DIA-139): the sourced helper must fire
  # BEFORE container detection/delegation -- docker must never be reached
  # while a dirty .opencode/commands file exists
  [ ! -s "$FAKE_DOCKER_LOG" ]
}
