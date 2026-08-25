#!/usr/bin/env bats
# RED-phase unit tests for scripts/opencode-dev (DIA-260821-x5nj, Option-A
# engine-specific override design).
#
# Scope of THIS slice (engine-specific override contract, design.md "Unified
# Launch Command" + Seam 1 / Seam 1b / Seam 2b):
#   - engine detection (auto via `docker --version`, or --engine= override)
#   - engine override selection: podman -> docker-compose.podman.yml,
#                                 docker -> docker-compose.rootless-docker.yml
#   - WSL overlay (docker-compose.wsl.yml) applied ON TOP of engine override
#     only when OS is WSL
#   - default action + mode dispatch (--run-opencode / --test) unchanged
#
# Docker/Podman are MOCKED (recording fakes on PATH) so no real container is
# started. Tests run from a scratch CWD seeded with a safe secrets/ fixture:
# the launcher's secrets-ownership preflight (T7.0b, design.md Seam 5) resolves
# ./secrets/ from the CWD like the compose files, so each test controls its own
# fixture instead of depending on the developer's live tree.
#
# Seam under test (design.md "Unified Launch Command"):
#   opencode-dev [--engine=podman|docker] [--os=wsl|native]
#               [--run-opencode|--test] [--ssh-agent]
#   - default:   docker compose -f docker-compose.yml
#                -f docker-compose.<engine>.yml [-f docker-compose.wsl.yml]
#                up -d dev && docker compose ... exec dev bash
#   - --engine=podman  -> docker-compose.podman.yml
#   - --engine=docker  -> docker-compose.rootless-docker.yml
#   - --os=wsl         -> also -f docker-compose.wsl.yml (overlay on top)
#   - auto-detect engine: `docker --version` contains "Podman" -> podman
#   - auto-detect os:     `/proc/version` contains "Microsoft"/"WSL" -> wsl
#
# All assertions inspect the RECORDED docker invocation log (mock_docker in
# $FAKE_DOCKER_LOG). We do NOT assert real container versions here.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/opencode-dev"

# mock_docker_engine: plants a fake `docker` on PATH that records every
# invocation to $FAKE_DOCKER_LOG and answers `docker --version` with a
# controllable string (FAKE_DOCKER_VERSION). Drives engine auto-detect tests
# hermetically. The GREEN script calls `docker --version`; the current
# (obsolete) script never does, so detection falls through to no override.
mock_docker_engine() {
  FAKE_DOCKER_LOG="${FAKE_DOCKER_LOG:-$BATS_TEST_TMPDIR/docker.log}"
  export FAKE_DOCKER_LOG
  : > "$FAKE_DOCKER_LOG"
  local bindir="$BATS_TEST_TMPDIR/engbin"
  mkdir -p "$bindir"
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_DOCKER_LOG:?FAKE_DOCKER_LOG not set}"
case "${1:-}" in
  version)
    printf '%s\n' "${FAKE_DOCKER_VERSION:-Docker version 29.7.2}"
    exit 0
    ;;
  compose)
    exit 0
    ;;
esac
exit 0
FAKEDOCKER
  chmod +x "$bindir/docker"
  PATH="$bindir:$PATH"
  export PATH
}

# mock_grep_os <wsl|native>: plants a fake `grep` on PATH that controls ONLY
# the OS-detection probe (/proc/version) and delegates everything else to the
# real binary. Drives WSL auto-detect tests hermetically.
mock_grep_os() {
  local sim="$1"
  export MOCK_OS="$sim"
  local realgrep
  realgrep="$(command -v grep)"
  local bindir="$BATS_TEST_TMPDIR/osgrepbin"
  mkdir -p "$bindir"
  cat > "$bindir/grep" <<'GREP'
#!/usr/bin/env bash
args="$*"
case "${MOCK_OS:-}" in
  wsl)
    [[ "$args" == *"/proc/version"* ]] && exit 0
    ;;
  *)
    [[ "$args" == *"/proc/version"* ]] && exit 1
    ;;
esac
exec REALGREP "$@"
GREP
  sed -i "s#REALGREP#$realgrep#" "$bindir/grep"
  chmod +x "$bindir/grep"
  PATH="$bindir:$PATH"
  export PATH
}

setup() {
  FAKE_DOCKER_SERVICES=""
  mock_docker
  # Preflight wiring (T7.0b): the launcher runs scripts/check-secrets-ownership.sh
  # against ./secrets/ (CWD-relative, same contract as the compose files) before
  # 'compose up'. Seed a SAFE fixture so flow tests exercise the full launch;
  # the dedicated wiring tests below flip it unsafe.
  cd "$BATS_TEST_TMPDIR"
  mkdir -p secrets
  : > secrets/api.key
  chmod 600 secrets/api.key
}

# --- RED trigger -------------------------------------------------------------

@test "RED trigger: scripts/opencode-dev exists and is executable" {
  assert_file_exists "$SCRIPT"
  [ -x "$SCRIPT" ] || { echo "$SCRIPT is not executable" >&2; return 1; }
}

# --- default action (unchanged contract) -------------------------------------

@test "default action: runs 'up -d dev' then 'exec -it --user dev dev bash'" {
  run bash "$SCRIPT"
  assert_status 0
  assert_file_contains "$FAKE_DOCKER_LOG" "compose up -d dev"
  # Self-healing launch route (DIA-260824-a3mk): non-opencode modes run as dev.
  assert_file_contains "$FAKE_DOCKER_LOG" "compose exec -it --user dev dev bash"
}

# --- engine override selection (NEW contract, RED vs current impl) -----------

@test "engine override --engine=podman selects docker-compose.podman.yml" {
  FAKE_DOCKER_SERVICES=""
  mock_docker_engine
  export FAKE_DOCKER_VERSION="Podman version 5.0.0"
  run bash "$SCRIPT" --engine=podman
  # Current (obsolete) script rejects --engine; GREEN selects podman override.
  assert_file_contains "$FAKE_DOCKER_LOG" "docker-compose.podman.yml"
}

@test "engine override --engine=docker selects docker-compose.rootless-docker.yml" {
  FAKE_DOCKER_SERVICES=""
  mock_docker_engine
  export FAKE_DOCKER_VERSION="Docker version 29.7.2"
  run bash "$SCRIPT" --engine=docker
  assert_file_contains "$FAKE_DOCKER_LOG" "docker-compose.rootless-docker.yml"
}

# --- engine auto-detection via docker --version (NEW contract, RED) ----------

@test "engine auto-detect: Podman version selects docker-compose.podman.yml" {
  FAKE_DOCKER_SERVICES=""
  mock_docker_engine
  export FAKE_DOCKER_VERSION="Podman version 5.0.0"
  run bash "$SCRIPT"
  assert_file_contains "$FAKE_DOCKER_LOG" "docker-compose.podman.yml"
}

@test "engine auto-detect: Docker version selects docker-compose.rootless-docker.yml" {
  FAKE_DOCKER_SERVICES=""
  mock_docker_engine
  export FAKE_DOCKER_VERSION="Docker version 29.7.2"
  run bash "$SCRIPT"
  assert_file_contains "$FAKE_DOCKER_LOG" "docker-compose.rootless-docker.yml"
}

# --- WSL overlay applied on top of engine override (NEW contract, RED) -------

@test "WSL overlay added on top of engine override when OS=wsl (auto-detect)" {
  FAKE_DOCKER_SERVICES=""
  mock_docker_engine
  export FAKE_DOCKER_VERSION="Podman version 5.0.0"
  mock_grep_os wsl
  run bash "$SCRIPT"
  # Both the engine override AND the WSL overlay must be selected.
  assert_file_contains "$FAKE_DOCKER_LOG" "docker-compose.podman.yml"
  assert_file_contains "$FAKE_DOCKER_LOG" "docker-compose.wsl.yml"
}

@test "WSL overlay NOT added when OS is native (auto-detect)" {
  FAKE_DOCKER_SERVICES=""
  mock_docker_engine
  export FAKE_DOCKER_VERSION="Podman version 5.0.0"
  mock_grep_os native
  run bash "$SCRIPT"
  assert_file_contains "$FAKE_DOCKER_LOG" "docker-compose.podman.yml"
  if grep -qF "docker-compose.wsl.yml" "$FAKE_DOCKER_LOG"; then
    echo "WSL overlay must NOT be selected on a native (non-WSL) host" >&2
    return 1
  fi
}

# --- mode dispatch (unchanged contract, regression guards) -------------------

@test "mode --run-opencode routes through entrypoint as root (self-healing launch)" {
  run bash "$SCRIPT" --run-opencode
  assert_status 0
  # Self-healing launch route (DIA-260824-a3mk): opencode runs via the root
  # entrypoint so it can chown the log path, then drops to dev via gosu.
  assert_file_contains "$FAKE_DOCKER_LOG" "compose exec -it --user root dev /usr/local/bin/dev-entrypoint.sh opencode"
}

@test "mode --test dispatches 'exec -T --user dev dev make test-infra'" {
  run bash "$SCRIPT" --test
  assert_status 0
  assert_file_contains "$FAKE_DOCKER_LOG" "compose exec -T --user dev dev make test-infra"
}

# --- secrets ownership preflight wiring (T7.0b, design.md Seam 5) ------------

@test "preflight wiring: missing secrets dir aborts with diagnostic BEFORE 'compose up'" {
  rm -rf "$BATS_TEST_TMPDIR/secrets"
  run bash "$SCRIPT"
  assert_status 1
  assert_output_contains "UNSAFE"
  if grep -qF "compose up" "$FAKE_DOCKER_LOG"; then
    echo "launcher must not start the container when the preflight fails" >&2
    return 1
  fi
}

@test "preflight wiring: group-readable secret file aborts with chmod fix BEFORE 'compose up'" {
  chmod 644 secrets/api.key
  run bash "$SCRIPT"
  assert_status 1
  assert_output_contains "chmod 0600"
  if grep -qF "compose up" "$FAKE_DOCKER_LOG"; then
    echo "launcher must not start the container when the preflight fails" >&2
    return 1
  fi
}
