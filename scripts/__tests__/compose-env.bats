#!/usr/bin/env bats
# RED-phase unit tests for scripts/compose-env.sh (DIA-260826-766f, Makefile
# uses the engine-aware compose stack).
#
# SCOPE OF THIS SLICE (design.md D1-D4, tasks.md T1.2): the shared helper
# scripts/compose-env.sh is the SINGLE SOURCE OF TRUTH for engine/OS detection.
# It must print the merged COMPOSE_FILE that scripts/opencode-dev already
# computes (scripts/opencode-dev lines 45-60, replicated byte-for-byte in
# design.md D3):
#   docker engine -> docker-compose.rootless-docker.yml   (user: '0:0')
#   podman engine -> docker-compose.podman.yml            (userns_mode keep-id
#                                                         + security_opt label=disable)
#   wsl OS       -> append docker-compose.wsl.yml         (overlay on top)
#   joined by ':' -> e.g. docker-compose.yml:docker-compose.rootless-docker.yml
#
# The helper MUST be docker-free at compute time (design.md D2): it uses only
# command -v / readlink / grep — never invokes docker or podman. This lets
# `make test-shell` stay host-runnable (no daemon) and the Makefile's
# `$(shell scripts/compose-env.sh)` stay docker-free on every `make` parse.
#
# These tests are RED by design: scripts/compose-env.sh does NOT exist yet and
# the Makefile still carries the dead UID/GID lines (Makefile 36-39) and lacks
# the COMPOSE_FILE export. So every behavior test fails on a missing/empty
# COMPOSE_FILE and every static Makefile assertion fails on the unchanged
# Makefile. The GREEN coder creates the helper + edits the Makefile.
#
# Mocking strategy (no docker daemon, no docker invocation):
#   - `command` is overridden by an exported shell function that intercepts ONLY
#     `command -v docker` (present/absent + the resolved path), delegating every
#     other `command` builtin call to `builtin command`. This drives engine
#     detection hermetically without a real docker client on PATH.
#   - fake `readlink` on PATH returns the controlled podman/docker path for -f
#     probes (the helper greps that path for "podman"); delegates otherwise.
#   - fake `grep` on PATH controls ONLY the /proc/version OS probe (wsl|native);
#     delegates otherwise.
#   - recording fakes `docker`/`podman` on PATH log any real execution to
#     $MOCK_DOCKER_INVOKE_LOG; assert_docker_free fails the test if the helper
#     ever invokes them (docker-free contract).

load test-helper

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HELPER="$REPO_ROOT/scripts/compose-env.sh"
MAKEFILE="$REPO_ROOT/Makefile"

# Exact expected COMPOSE_FILE strings (replicated from scripts/opencode-dev
# lines 45-60 / design.md D3).
DEFAULT_EXPECTED="docker-compose.yml:docker-compose.rootless-docker.yml"
PODMAN_EXPECTED="docker-compose.yml:docker-compose.podman.yml"
WSL_EXPECTED="docker-compose.yml:docker-compose.rootless-docker.yml:docker-compose.wsl.yml"

# assert_file_not_contains <file> <substring>: fails if <file> contains the
# fixed substring (grep -F). Used for the "dead lines GONE" Makefile assertions.
assert_file_not_contains() {
  if grep -qF -- "$2" "$1"; then
    echo "assert_file_not_contains: $1 unexpectedly contains substring: $2" >&2
    return 1
  fi
  return 0
}

# assert_docker_free: fails if the helper executed docker/podman at compute time
# (the recording fakes log any invocation to MOCK_DOCKER_INVOKE_LOG).
assert_docker_free() {
  local log="${MOCK_DOCKER_INVOKE_LOG:-$BATS_TEST_TMPDIR/docker-invoke.log}"
  if [ -s "$log" ]; then
    echo "assert_docker_free: helper invoked docker/podman (must be docker-free at compute time):" >&2
    cat "$log" >&2
    return 1
  fi
  return 0
}

# setup_engine_mocks <present 0|1> <readlink_output> <os wsl|native>: installs
# the hermetic engine/OS detection environment. <present> controls whether
# `command -v docker` reports a client; <readlink_output> is the path the
# helper's `readlink -f` sees (must contain "podman" for the podman engine);
# <os> drives the /proc/version grep probe.
setup_engine_mocks() {
  local present="${1:-1}"
  local readlink_out="${2:-/usr/bin/docker}"
  local os="${3:-native}"
  export MOCK_DOCKER_PRESENT="$present"
  export MOCK_READLINK_OUTPUT="$readlink_out"
  export MOCK_OS="$os"
  export MOCK_DOCKER_INVOKE_LOG="$BATS_TEST_TMPDIR/docker-invoke.log"
  : > "$MOCK_DOCKER_INVOKE_LOG"

  local real_readlink real_grep
  real_readlink="$(command -v readlink)"
  real_grep="$(command -v grep)"
  local bindir="$BATS_TEST_TMPDIR/engbin"
  mkdir -p "$bindir"

  # fake readlink: returns the controlled podman/docker path for -f probes.
  cat > "$bindir/readlink" <<'FAKEREADLINK'
#!/usr/bin/env bash
if [ "${1:-}" = "-f" ]; then
  printf '%s\n' "${MOCK_READLINK_OUTPUT:-/usr/bin/docker}"
  exit 0
fi
exec REALREADLINK "$@"
FAKEREADLINK
  sed -i "s#REALREADLINK#$real_readlink#" "$bindir/readlink"
  chmod +x "$bindir/readlink"

  # fake grep: controls ONLY the /proc/version OS probe; delegates otherwise.
  cat > "$bindir/grep" <<'FAKEGREP'
#!/usr/bin/env bash
args="$*"
case "${MOCK_OS:-native}" in
  wsl) [[ "$args" == *"/proc/version"* ]] && exit 0 ;;
  *)   [[ "$args" == *"/proc/version"* ]] && exit 1 ;;
esac
exec REALGREP "$@"
FAKEGREP
  sed -i "s#REALGREP#$real_grep#" "$bindir/grep"
  chmod +x "$bindir/grep"

  # recording fakes: any real docker/podman execution is logged (must stay empty).
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
printf '%s\n' "DOCKER_INVOKED: $*" >> "${MOCK_DOCKER_INVOKE_LOG:?}"
exit 1
FAKEDOCKER
  cat > "$bindir/podman" <<'FAKEPODMAN'
#!/usr/bin/env bash
printf '%s\n' "PODMAN_INVOKED: $*" >> "${MOCK_DOCKER_INVOKE_LOG:?}"
exit 1
FAKEPODMAN
  chmod +x "$bindir/docker" "$bindir/podman"

  PATH="$bindir:$PATH"
  export PATH

  # exported `command` function: intercept `command -v docker` only; delegate
  # every other builtin `command` call (so real readlink/grep/bash resolve).
  command() {
    case "$1" in
      -v)
        if [ "$2" = "docker" ]; then
          if [ "${MOCK_DOCKER_PRESENT:-1}" = "1" ]; then
            printf '%s\n' "${MOCK_READLINK_OUTPUT:-/usr/bin/docker}"
            return 0
          fi
          return 1
        fi
        ;;
    esac
    builtin command "$@"
  }
  export -f command
}

# --- RED trigger -------------------------------------------------------------

@test "RED trigger: scripts/compose-env.sh exists" {
  assert_file_exists "$HELPER"
}

# --- Behavior 1: default docker client + native OS ---------------------------

@test "default docker client native OS emits docker-compose.yml:docker-compose.rootless-docker.yml" {
  setup_engine_mocks 1 "/usr/bin/docker" native
  run --separate-stderr bash "$HELPER"
  [ "$output" = "$DEFAULT_EXPECTED" ] || {
    echo "expected COMPOSE_FILE=[$DEFAULT_EXPECTED]" >&2
    echo "got=[$output]" >&2
    return 1
  }
  assert_docker_free
}

# --- Behavior 2: podman engine (docker resolves to podman shim) ---------------

@test "podman shim emits docker-compose.yml:docker-compose.podman.yml" {
  setup_engine_mocks 1 "/usr/bin/podman" native
  run bash "$HELPER"
  [ "$output" = "$PODMAN_EXPECTED" ] || {
    echo "expected COMPOSE_FILE=[$PODMAN_EXPECTED]" >&2
    echo "got=[$output]" >&2
    return 1
  }
  assert_docker_free
}

# --- Behavior 3: WSL overlay appended on top of docker engine -----------------

@test "wsl overlay emits docker-compose.yml:docker-compose.rootless-docker.yml:docker-compose.wsl.yml" {
  setup_engine_mocks 1 "/usr/bin/docker" wsl
  run --separate-stderr bash "$HELPER"
  [ "$output" = "$WSL_EXPECTED" ] || {
    echo "expected COMPOSE_FILE=[$WSL_EXPECTED]" >&2
    echo "got=[$output]" >&2
    return 1
  }
  assert_docker_free
}

# --- Behavior 4: COMPOSE_ENGINE=podman override ------------------------------

@test "COMPOSE_ENGINE podman override emits docker-compose.yml:docker-compose.podman.yml" {
  export COMPOSE_ENGINE="podman"
  setup_engine_mocks 1 "/usr/bin/docker" native
  run bash "$HELPER"
  [ "$output" = "$PODMAN_EXPECTED" ] || {
    echo "expected COMPOSE_FILE=[$PODMAN_EXPECTED]" >&2
    echo "got=[$output]" >&2
    return 1
  }
  assert_docker_free
}

# --- Behavior 5: no docker client present at all -> default docker ------------

@test "no docker client defaults to docker-compose.yml:docker-compose.rootless-docker.yml" {
  setup_engine_mocks 0 "/usr/bin/docker" native
  run bash "$HELPER"
  [ "$output" = "$DEFAULT_EXPECTED" ] || {
    echo "expected COMPOSE_FILE=[$DEFAULT_EXPECTED]" >&2
    echo "got=[$output]" >&2
    return 1
  }
  assert_docker_free
}

# --- Behavior 6: docker-free at compute time (cross-cutting) ------------------

@test "helper is docker-free at compute time" {
  assert_file_exists "$HELPER"
  setup_engine_mocks 1 "/usr/bin/docker" native
  run bash "$HELPER"
  assert_status 0
  [ -n "$output" ] || { echo "helper produced no COMPOSE_FILE" >&2; return 1; }
  assert_docker_free
}

# --- Fedora engine-detection blocker (DIA-260826-766f, test-author slice) ----
# These 3 tests pin the Fedora regression: on a Fedora host where
# /usr/bin/docker is a SEPARATE docker-cli (NOT a podman shim) connected to the
# Podman API, the helper must NOT silently pick docker when COMPOSE_ENGINE is
# set, and on ambiguous autodetection it MUST warn (to stderr, mentioning
# COMPOSE_ENGINE) and default to docker. The helper stays docker-free
# (readlink only); Fedora sets COMPOSE_ENGINE=podman explicitly.

@test "FEDORA REGRESSION: separate docker CLI (not podman shim) + COMPOSE_ENGINE=podman -> podman override" {
  export COMPOSE_ENGINE="podman"
  setup_engine_mocks 1 "/usr/bin/docker" native
  run bash "$HELPER"
  [ "$output" = "$PODMAN_EXPECTED" ] || {
    echo "expected COMPOSE_FILE=[$PODMAN_EXPECTED]" >&2
    echo "got=[$output]" >&2
    return 1
  }
  assert_docker_free
}

@test "AMBIGUOUS autodetection warns to stderr mentioning COMPOSE_ENGINE and defaults to docker" {
  unset COMPOSE_ENGINE
  setup_engine_mocks 1 "/usr/bin/docker" native
  run --separate-stderr bash "$HELPER"
  [ "$output" = "$DEFAULT_EXPECTED" ] || {
    echo "expected COMPOSE_FILE=[$DEFAULT_EXPECTED]" >&2
    echo "got=[$output]" >&2
    return 1
  }
  [ -n "$stderr" ] || { echo "expected a warning on stderr, got none" >&2; return 1; }
  if ! printf '%s' "$stderr" | grep -q "COMPOSE_ENGINE"; then
    echo "stderr did not mention COMPOSE_ENGINE: [$stderr]" >&2
    return 1
  fi
  assert_docker_free
}

@test "PARITY: ambiguous docker (podman-backed) diverges without COMPOSE_ENGINE, agrees with it" {
  setup_engine_mocks 1 "/usr/bin/docker" native
  # Fedora env: a real docker-cli fronting the Podman API. `docker version`
  # reports a Podman server, but the helper is docker-free and cannot see it.
  local bindir="$BATS_TEST_TMPDIR/engbin"
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
if [ "$1" = "version" ]; then
  printf 'Server: Podman Engine\n'
  exit 0
fi
printf '%s\n' "DOCKER_INVOKED: $*" >> "${MOCK_DOCKER_INVOKE_LOG:?}"
exit 1
FAKEDOCKER
  chmod +x "$bindir/docker"

  # (a) ambiguous autodetection, no override -> warns + defaults to docker.
  unset COMPOSE_ENGINE
  run --separate-stderr bash "$HELPER"
  [ "$output" = "$DEFAULT_EXPECTED" ] || {
    echo "expected COMPOSE_FILE=[$DEFAULT_EXPECTED]" >&2
    echo "got=[$output]" >&2
    return 1
  }
  [ -n "$stderr" ] || { echo "expected a warning on stderr, got none" >&2; return 1; }
  if ! printf '%s' "$stderr" | grep -q "COMPOSE_ENGINE"; then
    echo "stderr did not mention COMPOSE_ENGINE: [$stderr]" >&2
    return 1
  fi

  # (b) explicit override -> podman, same as opencode-dev would resolve.
  export COMPOSE_ENGINE="podman"
  run bash "$HELPER"
  [ "$output" = "$PODMAN_EXPECTED" ] || {
    echo "expected COMPOSE_FILE=[$PODMAN_EXPECTED]" >&2
    echo "got=[$output]" >&2
    return 1
  }
}

# --- Static Makefile parity assertions (design.md D4, tasks.md T2.1) ----------

@test "Makefile exports COMPOSE_FILE via scripts/compose-env.sh" {
  assert_file_contains "$MAKEFILE" 'export COMPOSE_FILE := $(shell scripts/compose-env.sh)'
}

@test "Makefile dead UID line is gone" {
  assert_file_not_contains "$MAKEFILE" 'UID := $(shell id -u)'
}

@test "Makefile dead GID line is gone" {
  assert_file_not_contains "$MAKEFILE" 'GID := $(shell id -g)'
}

@test "Makefile dead export UID line is gone" {
  assert_file_not_contains "$MAKEFILE" 'export UID'
}

@test "Makefile dead export GID line is gone" {
  assert_file_not_contains "$MAKEFILE" 'export GID'
}
