#!/usr/bin/env bats
# Unit tests for scripts/container-engine.sh (DIA-260912-y2uo, Podman support
# for the DIA-094 container-engine adapter).
#
# Three seams, all hermetic (no daemon, no real engine):
#   1. Engine-selection seam: COMPOSE_ENGINE override precedence, autodetection
#      when unset, invalid-value rejection, no daemon call during selection.
#   2. Host-operation seam: command-recording fakes prove every host-side
#      compose/info/status/exec operation uses the ONE selected native engine
#      with no direct bypass or cross-engine invocation.
#   3. DIA-094 readiness seam: the gate succeeds only when reachability AND dev
#      running status AND `exec -T dev true` all pass; each failure is distinct
#      and never falls back to the other engine.
#
# Mock strategy: mock_docker (test-helper.bash) plants recording docker+podman
# fakes sharing canned answers (FAKE_DOCKER_DAEMON_UP / FAKE_DOCKER_SERVICES /
# FAKE_DOCKER_FAIL_STEP). Autodetection tests steer the docker-free probe
# (`command -v docker` + `readlink -f`) via PATH only — never via daemon.

load test-helper

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ADAPTER="$REPO_ROOT/scripts/container-engine.sh"
COMPOSE_ENV="$REPO_ROOT/scripts/compose-env.sh"
MAKEFILE="$REPO_ROOT/Makefile"

setup() {
  # Hermetic engine selection (DIA-260909-9api precedent): ignore any inherited
  # COMPOSE_ENGINE; tests that need an override export it explicitly.
  unset COMPOSE_ENGINE
  mock_docker
  : > "$FAKE_DOCKER_LOG"
}

# assert_log_only_engine <docker|podman>: every recorded invocation used the
# one selected engine. For podman every line starts with "podman "; for docker
# no line may start with "podman " (the docker fake logs bare args).
assert_log_only_engine() {
  local eng="$1" line
  [ -s "$FAKE_DOCKER_LOG" ] || {
    echo "assert_log_only_engine: expected [$eng] invocations, log is empty" >&2
    return 1
  }
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$eng" in
      podman)
        case "$line" in
          "podman "*) ;;
          *) echo "assert_log_only_engine: non-podman invocation under COMPOSE_ENGINE=podman: [$line]" >&2; return 1 ;;
        esac
        ;;
      docker)
        case "$line" in
          "podman "*) echo "assert_log_only_engine: cross-engine fallback to podman under COMPOSE_ENGINE=docker: [$line]" >&2; return 1 ;;
          *) ;;
        esac
        ;;
    esac
  done < "$FAKE_DOCKER_LOG"
}

assert_no_engine_invoked() {
  [ ! -s "$FAKE_DOCKER_LOG" ] || {
    echo "assert_no_engine_invoked: engine was invoked:" >&2
    cat "$FAKE_DOCKER_LOG" >&2
    return 1
  }
}

# setup_podman_shim: prepend a dir whose `docker` client resolves (readlink -f)
# to a path containing "podman" — the Podman-shim autodetection signal. Only
# the path matters (the selection probe never executes the client), so the
# shim is a trivial script.
setup_podman_shim() {
  local shimdir="$BATS_TEST_TMPDIR/podman-shim"
  mkdir -p "$shimdir"
  printf '#!/bin/sh\nexit 0\n' > "$shimdir/docker"
  chmod +x "$shimdir/docker"
  PATH="$shimdir:$PATH"
  export PATH
}

# setup_no_docker_client: make `command -v docker` fail while delegating every
# other builtin call, so the adapter sees no docker client but keeps a working
# PATH (same exported-`command` pattern as compose-env.bats). Selection must
# fall back to the default.
setup_no_docker_client() {
  command() {
    case "${1:-}" in
      -v)
        if [ "${2:-}" = "docker" ]; then
          return 1
        fi
        ;;
    esac
    builtin command "$@"
  }
  export -f command
}

# --- Seam 1: engine selection ------------------------------------------------

@test "selection: COMPOSE_ENGINE=docker selects docker with native compose" {
  export COMPOSE_ENGINE="docker"
  run bash "$ADAPTER" select
  assert_status 0
  [ "$output" = "docker" ]
  run bash "$ADAPTER" compose-bin
  assert_status 0
  [ "$output" = "docker" ]
}

@test "selection: COMPOSE_ENGINE=podman selects podman with native compose" {
  export COMPOSE_ENGINE="podman"
  run bash "$ADAPTER" select
  assert_status 0
  [ "$output" = "podman" ]
  run bash "$ADAPTER" compose-bin
  assert_status 0
  [ "$output" = "podman" ]
}

@test "selection: unsupported COMPOSE_ENGINE is rejected with accepted values, no engine reported" {
  export COMPOSE_ENGINE="weird"
  run --separate-stderr bash "$ADAPTER" select
  [ "$status" -ne 0 ]
  [ -z "$output" ] || { echo "selection must report no engine, got [$output]" >&2; return 1; }
  [[ "$stderr" == *"unsupported COMPOSE_ENGINE"* ]] || { echo "stderr: [$stderr]" >&2; return 1; }
  [[ "$stderr" == *"docker"* ]] || { echo "stderr: [$stderr]" >&2; return 1; }
  [[ "$stderr" == *"podman"* ]] || { echo "stderr: [$stderr]" >&2; return 1; }
  assert_no_engine_invoked
}

@test "selection: invalid override fails compose and gate before any engine call" {
  export COMPOSE_ENGINE="bogus"
  run bash "$ADAPTER" compose ps
  [ "$status" -ne 0 ]
  run bash "$ADAPTER" gate
  [ "$status" -ne 0 ]
  assert_no_engine_invoked
}

@test "selection: unset override with a plain docker client autodetects docker" {
  run bash "$ADAPTER" select
  assert_status 0
  [ "$output" = "docker" ]
}

@test "selection: unset override with a podman shim autodetects podman" {
  setup_podman_shim
  run bash "$ADAPTER" select
  assert_status 0
  [ "$output" = "podman" ]
}

@test "selection: unset override with no docker client defaults to docker" {
  setup_no_docker_client
  run bash "$ADAPTER" select
  assert_status 0
  [ "$output" = "docker" ]
}

@test "selection: resolving the engine makes no daemon call" {
  run bash "$ADAPTER" select
  assert_status 0
  run bash "$COMPOSE_ENV"
  assert_status 0
  assert_no_engine_invoked
}

# --- Seam 2: unified host-side operations ------------------------------------

@test "operations: docker override routes config/up/down/exec through docker compose only" {
  export COMPOSE_ENGINE="docker"
  export FAKE_DOCKER_SERVICES="dev"
  run bash "$ADAPTER" compose config --quiet
  assert_status 0
  run bash "$ADAPTER" compose up -d --build
  assert_status 0
  run bash "$ADAPTER" compose down
  assert_status 0
  run bash "$ADAPTER" compose exec -T dev true
  assert_status 0
  assert_file_contains "$FAKE_DOCKER_LOG" "compose config --quiet"
  assert_file_contains "$FAKE_DOCKER_LOG" "compose up -d --build"
  assert_file_contains "$FAKE_DOCKER_LOG" "compose down"
  assert_file_contains "$FAKE_DOCKER_LOG" "compose exec -T dev true"
  assert_log_only_engine docker
}

@test "operations: podman override routes config/up/down/exec through podman compose only" {
  export COMPOSE_ENGINE="podman"
  export FAKE_DOCKER_SERVICES="dev"
  run bash "$ADAPTER" compose config --quiet
  assert_status 0
  run bash "$ADAPTER" compose up -d --build
  assert_status 0
  run bash "$ADAPTER" compose down
  assert_status 0
  run bash "$ADAPTER" compose exec -T dev true
  assert_status 0
  assert_file_contains "$FAKE_DOCKER_LOG" "podman compose config --quiet"
  assert_file_contains "$FAKE_DOCKER_LOG" "podman compose up -d --build"
  assert_file_contains "$FAKE_DOCKER_LOG" "podman compose down"
  assert_file_contains "$FAKE_DOCKER_LOG" "podman compose exec -T dev true"
  assert_log_only_engine podman
}

@test "operations: direct Podman CLI resolves the Podman compose overlay" {
  export COMPOSE_ENGINE="podman"
  unset COMPOSE_FILE
  local bindir="$BATS_TEST_TMPDIR/compose-file-probe"
  mkdir -p "$bindir"
  cat > "$bindir/podman" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${COMPOSE_FILE:-<unset>}"
EOF
  chmod +x "$bindir/podman"
  PATH="$bindir:$PATH"

  run bash "$ADAPTER" compose config --quiet
  assert_status 0
  assert_output_contains "docker-compose.yml:docker-compose.podman.yml"
}

@test "operations: reachability/status/exec probes use the selected engine" {
  export COMPOSE_ENGINE="podman"
  export FAKE_DOCKER_SERVICES="dev"
  run bash "$ADAPTER" reachable
  assert_status 0
  run bash "$ADAPTER" dev-running
  assert_status 0
  run bash "$ADAPTER" dev-exec
  assert_status 0
  assert_file_contains "$FAKE_DOCKER_LOG" "podman info"
  assert_file_contains "$FAKE_DOCKER_LOG" "podman compose ps"
  assert_file_contains "$FAKE_DOCKER_LOG" "podman compose exec -T dev true"
  assert_log_only_engine podman
}

# --- Seam 3: strict DIA-094 gate ----------------------------------------------

@test "gate: running and executable dev service passes, naming the selected engine" {
  export FAKE_DOCKER_SERVICES="dev"
  run bash "$ADAPTER" gate
  assert_status 0
  assert_output_contains "'docker'"
  assert_file_contains "$FAKE_DOCKER_LOG" "info"
  assert_file_contains "$FAKE_DOCKER_LOG" "compose ps"
  assert_file_contains "$FAKE_DOCKER_LOG" "compose exec -T dev true"
  assert_log_only_engine docker
}

@test "gate: unreachable engine hard-fails with an engine-reachability diagnostic, no fallback" {
  export FAKE_DOCKER_DAEMON_UP="no"
  run bash "$ADAPTER" gate
  [ "$status" -ne 0 ]
  assert_output_contains "engine-reachability"
  assert_output_contains "'docker'"
  assert_output_not_contains "dev-service-status"
  assert_output_not_contains "dev-service-exec"
  # the failed engine stays selected: podman is never attempted
  if grep -q "^podman " "$FAKE_DOCKER_LOG" 2>/dev/null; then
    echo "gate fell back to podman after a docker failure" >&2
    return 1
  fi
}

@test "gate: dev service not running hard-fails with a status diagnostic, exec never attempted" {
  export FAKE_DOCKER_SERVICES="postgres"
  run bash "$ADAPTER" gate
  [ "$status" -ne 0 ]
  assert_output_contains "dev-service-status"
  assert_output_contains "dev container not running"
  assert_output_not_contains "engine-reachability"
  assert_output_not_contains "dev-service-exec"
  # status alone is not proof: the exec proof must not run after status fails
  if grep -q "compose exec" "$FAKE_DOCKER_LOG" 2>/dev/null; then
    echo "gate attempted exec after a status failure" >&2
    return 1
  fi
}

@test "gate: running-but-not-executable dev service hard-fails with an exec diagnostic" {
  export FAKE_DOCKER_SERVICES="dev"
  export FAKE_DOCKER_FAIL_STEP="true"
  run bash "$ADAPTER" gate
  [ "$status" -ne 0 ]
  assert_output_contains "dev-service-exec"
  assert_output_not_contains "engine-reachability"
  assert_output_not_contains "dev-service-status"
  assert_log_only_engine docker
}

@test "gate: podman selection reports podman in every diagnostic, never touches docker" {
  export COMPOSE_ENGINE="podman"
  export FAKE_DOCKER_SERVICES="dev"
  run bash "$ADAPTER" gate
  assert_status 0
  assert_output_contains "'podman'"
  assert_log_only_engine podman

  export FAKE_DOCKER_DAEMON_UP="no"
  run bash "$ADAPTER" gate
  [ "$status" -ne 0 ]
  assert_output_contains "engine-reachability"
  assert_output_contains "'podman'"
  assert_log_only_engine podman
}

# --- compose-env trust boundary -------------------------------------------------

@test "compose-env: unsupported COMPOSE_ENGINE is rejected with accepted values" {
  export COMPOSE_ENGINE="bogus"
  run --separate-stderr bash "$COMPOSE_ENV"
  [ "$status" -ne 0 ]
  [ -z "$output" ] || { echo "compose-env must print no COMPOSE_FILE, got [$output]" >&2; return 1; }
  [[ "$stderr" == *"unsupported COMPOSE_ENGINE"* ]] || { echo "stderr: [$stderr]" >&2; return 1; }
  [[ "$stderr" == *"docker"* ]] || { echo "stderr: [$stderr]" >&2; return 1; }
  [[ "$stderr" == *"podman"* ]] || { echo "stderr: [$stderr]" >&2; return 1; }
  assert_no_engine_invoked
}

# --- Migration: no direct bypass, in-container behavior preserved ----------------

@test "migration: Makefile routes host compose through the adapter, no bare engine recipe" {
  assert_file_contains "$MAKEFILE" 'COMPOSE := bash scripts/container-engine.sh compose'
  # tab-indented recipe lines must not invoke an engine binary directly
  recipe_direct="$(grep -E $"^\tdocker (compose|info|inspect|ps)([[:space:]]|$)" "$MAKEFILE" || true)"
  [ -z "$recipe_direct" ] || { echo "bare docker recipe: [$recipe_direct]" >&2; return 1; }
  recipe_direct="$(grep -E $"^\tpodman (compose|info|inspect|ps)([[:space:]]|$)" "$MAKEFILE" || true)"
  [ -z "$recipe_direct" ] || { echo "bare podman recipe: [$recipe_direct]" >&2; return 1; }
}

@test "migration: migrated host scripts use the adapter with no direct engine call" {
  local f direct
  for f in dev-stack.sh verify-pre-commit.sh verify-pre-push.sh test-docker-smoke.sh; do
    assert_file_contains "$REPO_ROOT/scripts/$f" "scripts/container-engine.sh"
    # strip full-line comments, then fail on any command-position direct call
    direct="$(grep -v '^[[:space:]]*#' "$REPO_ROOT/scripts/$f" | grep -E '(^|[;&|(` ])(docker|podman) (compose|info|inspect|ps)([[:space:]]|$)' || true)"
    [ -z "$direct" ] || { echo "$f has a direct engine call: [$direct]" >&2; return 1; }
  done
}

@test "migration: in-container commands keep their existing behavior" {
  assert_file_contains "$REPO_ROOT/scripts/verify-pre-commit.sh" "npx lint-staged --allow-empty"
  assert_file_contains "$REPO_ROOT/scripts/dev-stack.sh" "pnpm install"
  assert_file_contains "$REPO_ROOT/scripts/dev-stack.sh" "pnpm dev"
  assert_file_contains "$REPO_ROOT/scripts/test-docker-smoke.sh" "openspec --version"
  assert_file_contains "$MAKEFILE" "exec -T --user dev dev bash -c"
}

@test "migration: adapter stays bash-3 compatible (no bash-4-only constructs)" {
  # skip comment lines: the header documents the banned constructs by name
  run bash -c "grep -v '^[[:space:]]*#' '$ADAPTER' | grep -E 'declare -A|mapfile|readarray'"
  [ "$status" -ne 0 ] || { echo "bash-4-only construct in adapter:" >&2; echo "$output" >&2; return 1; }
  run bash -n "$ADAPTER"
  assert_status 0
}
