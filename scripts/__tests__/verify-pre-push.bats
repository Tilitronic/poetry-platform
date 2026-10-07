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
  # PHASE 5 / ADR 11: make test-shell now runs on the host (not delegated),
  # so check-host-lsp's container probes hit the fake docker via
  # container-engine.sh. Overwrite the fake docker with a version that
  # responds to LSP version probes so the prerequisite checks pass in the
  # hermetic test environment. Other exec commands still exit 0 with no
  # output (original behavior for delegation assertions).
  local docker_bin="$BATS_TEST_TMPDIR/bin/docker"
  cat > "$docker_bin" <<'FAKEDOCKER'
#!/usr/bin/env bash
# Fake docker CLI for unit tests. Records every call; canned answers only.
# Extended with LSP container probe responses (PHASE 5 / ADR 11).
printf '%s\n' "$*" >> "${FAKE_DOCKER_LOG:?FAKE_DOCKER_LOG not set}"

case "${1:-}" in
  info)
    [ "${FAKE_DOCKER_DAEMON_UP:-yes}" = "yes" ] && exit 0 || exit 1
    ;;
  compose)
    shift
    # consume global compose flags (-f <file>)
    if [ "${1:-}" = "-f" ]; then shift 2; fi
    case "${1:-}" in
      exec)
        shift
        # consume flags (-T/-it/--/--user <user>) until the container name
        while [ $# -gt 0 ]; do
          case "$1" in
            --user) shift 2 ;;
            -T|-it|--|--) shift ;;
            *) break ;;
          esac
        done
        shift # container name
        if [ -n "${FAKE_DOCKER_FAIL_STEP:-}" ] && [[ "$*" == *"$FAKE_DOCKER_FAIL_STEP"* ]]; then
          exit 1
        fi
        case "$*" in
          "test -x node_modules/.bin/turbo")
            [ "${FAKE_DOCKER_TURBO_INSTALLED:-yes}" = "yes" ] && exit 0 || exit 1
            ;;
          *rust-analyzer*--version*)
            printf '%s\n' "rust-analyzer 1.97.1 (hash)"
            exit 0
            ;;
          *pyright*--version*)
            printf '%s\n' "pyright 1.1.411"
            exit 0
            ;;
          *yaml-language-server*--version*)
            printf '%s\n' "yaml-language-server 1.24.0"
            exit 0
            ;;
          *typescript-language-server*--version*)
            printf '%s\n' "typescript-language-server 5.3.0"
            exit 0
            ;;
        esac
        exit 0
        ;;
      ps)
        printf '%s\n' "${FAKE_DOCKER_SERVICES:-}"
        exit 0
        ;;
    esac
    exit 0
    ;;
esac
exit 0
FAKEDOCKER
  chmod +x "$docker_bin"
  # PHASE 5 / ADR 11: make test-shell runs on the host via (cd "$ROOT" &&
  # make test-shell). In the test environment, a fake make on PATH exits
  # immediately so unit tests don't run the full 711-test bats suite. The
  # test verifies the host-local path via the script's stdout marker.
  cat > "$BATS_TEST_TMPDIR/bin/make" <<'FAKEMAKE'
#!/usr/bin/env bash
exit 0
FAKEMAKE
  chmod +x "$BATS_TEST_TMPDIR/bin/make"
  # Hermetic engine selection (DIA-260909-9api precedent): an inherited
  # COMPOSE_ENGINE would reroute the adapter past the docker fake these tests
  # assert on. Unset it; engine-specific coverage lives in container-engine.bats.
  unset COMPOSE_ENGINE
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

@test "verify-pre-push: delegates every verification step in fast-to-fail order, make test-shell host-local last" {
  export FAKE_DOCKER_SERVICES="dev"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  assert_output_contains "delegating to dev container"
  assert_output_contains "verification passed"
  # PHASE 5 / ADR 11: test-shell must have run on the host (visible host-local
  # marker in output). Check this BEFORE any subsequent `run` overwrites $output.
  assert_output_contains "make test-shell (host-local, PHASE 5 / ADR 11)"
  # F-1 (DIA-139): five steps are delegated via run_workspace -- the fast pnpm
  # gates and the config validator first, then verify:python. The slow bats
  # suite (make test-shell) runs HOST-LOCAL last (PHASE 5 / ADR 11: the dev
  # image no longer ships the Docker CLI, so compose-overrides needs the real
  # docker on the host). End-anchored matching: each step must appear EXACTLY
  # once, in ladder order. A duplicate step or a swapped pair now fails the
  # count/order check instead of being masked by first-occurrence grep.
  local prev=0 step count line
  for step in "verify:format" "verify:js" "verify:js-tests" "make test-config" "verify:python"; do
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
  # PHASE 5 / ADR 11: test-shell must NOT be delegated (no docker exec).
  run grep -c "make test-shell" "$FAKE_DOCKER_LOG"
  [ "$output" = "0" ]
}

@test "verify-pre-push: wires host-local dia189 toast leg between make test-omo and pnpm verify:python, no test-harness line (DIA-260827-36ht)" {
  # Static pin: the bun leg line must exist exactly once, AFTER the test-omo
  # line and BEFORE the verify:python line; the removed run_workspace
  # "make test-harness" line (nested-Docker root cause) must be gone.
  # run_workspace/bun-anchored matching (not bare step names) so ladder
  # comments never affect the pin; relative order, not absolute line numbers,
  # so other ladder edits stay green.
  local omo_line toast_line python_line
  omo_line="$(grep -nF 'run_workspace "make test-omo"' "$SCRIPTS_DIR/verify-pre-push.sh" | head -n 1 | cut -d: -f1)"
  toast_line="$(grep -nF 'bun test needs-input-observer.dia189.test.mjs' "$SCRIPTS_DIR/verify-pre-push.sh" | head -n 1 | cut -d: -f1)"
  python_line="$(grep -nF 'run_workspace "pnpm verify:python"' "$SCRIPTS_DIR/verify-pre-push.sh" | head -n 1 | cut -d: -f1)"
  [ -n "$omo_line" ] && [ -n "$toast_line" ] && [ -n "$python_line" ]
  [ "$omo_line" -lt "$toast_line" ]
  [ "$toast_line" -lt "$python_line" ]
  [ "$(grep -cF 'bun test needs-input-observer.dia189.test.mjs' "$SCRIPTS_DIR/verify-pre-push.sh")" -eq 1 ]
  run grep -F 'make test-harness' "$SCRIPTS_DIR/verify-pre-push.sh"
  [ "$status" -ne 0 ]
}

@test "verify-pre-push: executes the dia189 toast leg on the host between test-omo and verify:python (green path)" {
  export FAKE_DOCKER_SERVICES="dev"
  # Same-worker WSL-restore pin (cheap): the leg runs in a child bun process,
  # so the parent shell env must be untouched afterwards.
  export WSL_DISTRO_NAME="bats-sentinel"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  assert_output_contains "bun test dia189 desktop-toast"
  # the real bun run executed (6 toast tests), not just an echo
  assert_output_contains "6 pass"
  # snapshot: later `run` invocations clobber $output
  local script_output="$output"
  # host-local leg: never delegated, so docker log carries no dia189 entry
  run grep -c "dia189" "$FAKE_DOCKER_LOG"
  [ "$output" = "0" ]
  # placement: the leg echo falls between the test-omo and verify:python
  # delegation echoes on stdout
  local omo toast python
  omo="$(printf '%s\n' "$script_output" | grep -n "make test-omo" | head -n 1 | cut -d: -f1)"
  toast="$(printf '%s\n' "$script_output" | grep -n "bun test dia189 desktop-toast" | head -n 1 | cut -d: -f1)"
  python="$(printf '%s\n' "$script_output" | grep -n "verify:python" | head -n 1 | cut -d: -f1)"
  [ "$omo" -lt "$toast" ]
  [ "$toast" -lt "$python" ]
  # parent env untouched by the child bun run
  [ "$WSL_DISTRO_NAME" = "bats-sentinel" ]
}

@test "verify-pre-push: aborts (exit 1) when the dia189 toast leg fails (red path blocks push)" {
  export FAKE_DOCKER_SERVICES="dev"
  # Failing fake bun first on PATH proves the leg ACTUALLY EXECUTES bun (not
  # just records it): a recorded-but-never-run leg would still exit 0 here.
  local bindir="$BATS_TEST_TMPDIR/fakebun"
  mkdir -p "$bindir"
  printf '#!/usr/bin/env bash\necho "0 pass, 1 fail (fake bun)"\nexit 1\n' > "$bindir/bun"
  chmod +x "$bindir/bun"
  export PATH="$bindir:$PATH"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 1
  assert_output_contains "bun test dia189 desktop-toast"
  # fail-fast: the python gate after the leg never runs
  run grep -c "verify:python" "$FAKE_DOCKER_LOG"
  [ "$output" = "0" ]
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
  # PHASE 5 / ADR 11: test-shell runs host-local (not delegated), so make it
  # fail by shadowing `make` with a fake that rejects the test-shell target.
  local bindir="$BATS_TEST_TMPDIR/fakemakebin"
  mkdir -p "$bindir"
  cat > "$bindir/make" <<'FAKEMAKE'
#!/usr/bin/env bash
echo "make: *** [test-shell] Error 1 (simulated failure)" >&2
exit 1
FAKEMAKE
  chmod +x "$bindir/make"
  export PATH="$bindir:$PATH"

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
  # DIA-260827-36ht: the dia189 toast leg calls bun directly (host-local, no
  # run_workspace), so a logging fake keeps the in-container path hermetic
  # (no real bun run) while still proving the leg executes there.
  cat > "$bindir/bun" <<'FAKEBUN'
#!/usr/bin/env bash
printf 'bun %s\n' "$*" >> "${DELEGATION_LOG:?DELEGATION_LOG not set}"
exit 0
FAKEBUN
  chmod +x "$bindir/hostname" "$bindir/pnpm" "$bindir/make" "$bindir/bun"
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
  # All ladder steps run directly (no docker) inside the container too;
  # their F-1 fast-to-fail order is asserted in the delegation-path test.
  # DIA-260827-36ht: the host-local dia189 toast leg also executes
  # in-container (direct bun call, no delegation), recorded by the fake bun.
  for step in "verify:format" "verify:js" "verify:js-tests" "make test-config" "make test-omo" "verify:python" "make test-shell"; do
    assert_file_contains "$DELEGATION_LOG" "$step"
  done
  assert_file_contains "$DELEGATION_LOG" "needs-input-observer.dia189.test.mjs"
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

@test "verify-pre-push: delegation uses --user dev (not root) on host" {
  export FAKE_DOCKER_SERVICES="dev"

  run bash "$SCRIPTS_DIR/verify-pre-push.sh"

  assert_status 0
  # host delegation must run every step as dev, not root (DIA-260901-m4xq)
  assert_file_contains "$FAKE_DOCKER_LOG" "--user dev"
  # static guard: the exec line in the script itself must contain --user dev
  run grep -F 'exec -T --user dev dev' "$SCRIPTS_DIR/verify-pre-push.sh"
  assert_status 0
  # no bare `exec -T dev` without --user remains for host delegation
  run grep -Eq 'exec -T dev( |$)' "$SCRIPTS_DIR/verify-pre-push.sh"
  # grep exits 1 when no bare pattern found -> desired
  [ "$status" -ne 0 ]
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

@test "verify-pre-push: budget range block precedes the container-down early exit (C1 static ordering pin)" {
  # C1: the range backstop must execute even when the dev stack is offline.
  # Pin the order statically (batch-D grep pattern, mirror of the home-qualt
  # wiring test above): the range-gate invocation line must precede the
  # container-down skip exit. Moving the block back below the exit fails
  # this pin (and the behavioral pin below).
  local range_line skip_line
  range_line="$(grep -n 'check-budget-gate.sh' "$SCRIPTS_DIR/verify-pre-push.sh" | head -n 1 | cut -d: -f1)"
  skip_line="$(grep -n "pre-push verification skipped" "$SCRIPTS_DIR/verify-pre-push.sh" | head -n 1 | cut -d: -f1)"
  [ -n "$range_line" ] && [ -n "$skip_line" ]
  [ "$range_line" -lt "$skip_line" ]
}

@test "verify-pre-push: container-down push carrying pushed refs still hits the budget range check (C1 behavioral pin)" {
  export FAKE_DOCKER_SERVICES="postgres"
  # Copy-based hermetic fixture (no PATH shims: shadowing `bash` deadlocks
  # bats' inherited fds inside the script's $( ) substitutions). The copied
  # hook derives $ROOT from its own location, so the REAL budget gate
  # evaluates a REAL violating fixture history in default layout while the
  # container is down. If the range block moved back below the container-down
  # exit, this exits 0 (skip) instead of 1 (blocked).
  local tree="$BATS_TEST_TMPDIR/c1range"
  mkdir -p "$tree/scripts/guards" "$tree/.opencode/plugins/lib" "$tree/docs/dev-infra-audit/tickets"
  cp "$SCRIPTS_DIR/verify-pre-push.sh" "$tree/scripts/verify-pre-push.sh"
  cp "$SCRIPTS_DIR/check-budget-gate.sh" "$tree/scripts/check-budget-gate.sh"
  cp "$SCRIPTS_DIR/guards/home-qualt.sh" "$tree/scripts/guards/home-qualt.sh"
  cp "$SCRIPTS_DIR/in-container.sh" "$tree/scripts/in-container.sh"
  seq 1 10 > "$tree/.opencode/plugins/delegation-observer.ts"
  seq 1 10 > "$tree/.opencode/plugins/lib/util.ts"
  cat > "$tree/scripts/budget-baselines.json" <<'EOF'
{
  "prod_ceiling": 20,
  "shell_ceiling": 10,
  "patterns": [],
  "campaigns": [
    { "ticket": "DIA-260903-o7n0", "scope": "refactor", "status": "approved" }
  ],
  "mode": "blocking"
}
EOF
  cat > "$tree/docs/dev-infra-audit/tickets/DIA-260903-o7n0-zz-campaign.md" <<'EOF'
---
status: OPEN
---
# DIA-260903-o7n0 campaign fixture (C1 pin suite)
EOF
  if ! git -C "$tree" init -q -b main 2>/dev/null; then
    git -C "$tree" init -q
    git -C "$tree" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$tree" config user.email "bats@example.com"
  git -C "$tree" config user.name "bats test"
  git -C "$tree" add -A
  git -C "$tree" commit -q -m init
  local init_sha viol_sha zero_sha ref_line
  init_sha="$(git -C "$tree" rev-parse HEAD)"
  # Violating commit: prod 25 vs ceiling 20, refactor-backed (real backing
  # on disk), so the range check must refuse it.
  seq 1 15 > "$tree/.opencode/plugins/lib/util.ts"
  git -C "$tree" add .opencode/plugins/lib/util.ts
  git -C "$tree" commit -q -m "violating refactor

Budget-Scope: refactor"
  viol_sha="$(git -C "$tree" rev-parse HEAD)"
  zero_sha="0000000000000000000000000000000000000000"
  ref_line="refs/heads/feature/c1-pin $viol_sha refs/heads/feature/c1-pin $init_sha"
  # The copied hook resolves git state from its CWD, so run it from the
  # fixture repo (last test-position effects are harmless: each bats file
  # runs in its own process). Herestring, not a pipe: piping into `run`
  # subshells it and loses $status/$output.
  cd "$tree"
  run bash "$tree/scripts/verify-pre-push.sh" <<< "$ref_line"

  assert_status 1
  assert_output_contains "pre-push blocked: budget gate range check failed"
  # the violation was refused while the stack was offline: docker is never
  # reached (P-3 pattern from the home-qualt test above; -s is missing-safe
  # because a pre-container block leaves the log file uncreated)
  [ ! -s "$FAKE_DOCKER_LOG" ]
}

@test "verify-pre-push: compose-config host check precedes the container-down early exit (P6, T12.3 ordering pin)" {
  # P6: the host-side compose-config validation (check-compose-config.sh)
  # must run BEFORE the container-down skip, matching the home-qualt and
  # budget-range ordering pins. Moving it below the exit breaks this pin.
  local compose_config_line skip_line
  compose_config_line="$(grep -n 'check-compose-config.sh' "$SCRIPTS_DIR/verify-pre-push.sh" | head -n 1 | cut -d: -f1)"
  skip_line="$(grep -n "pre-push verification skipped" "$SCRIPTS_DIR/verify-pre-push.sh" | head -n 1 | cut -d: -f1)"
  [ -n "$compose_config_line" ] && [ -n "$skip_line" ]
  [ "$compose_config_line" -lt "$skip_line" ]
}
