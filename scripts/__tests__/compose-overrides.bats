#!/usr/bin/env bats
# RED-phase unit tests for the ENGINE-SPECIFIC compose override FILES
# (DIA-260821-x5nj, Option-A engine-specific override design, Slice 2 /
# tasks.md T2.1 + T2.2).
#
# Scope of THIS slice (engine-specific UID/GID mapping, design.md "Engine-
# Specific Compose Overrides" + Seam 2 / Seam 2b):
#   - Podman override (docker-compose.podman.yml): userns_mode: keep-id
#     + security_opt: [label=disable] (SELinux compat, res040 §2)
#   - Rootless-Docker override (docker-compose.rootless-docker.yml): user: "0:0"
#     (res040 §1, §4)
#   - WSL overlay (docker-compose.wsl.yml): applied on top, no engine flags,
#     no base duplication
#   - neither engine adapter duplicates base volumes/ports/environment/secrets
#   - opencode-dev --engine references the existing engine override file
#
# These tests are RED by design: the engine-specific override files
# (docker-compose.podman.yml / docker-compose.rootless-docker.yml) do NOT exist
# yet (the current repo ships the OBSOLETE OS-only docker-compose.fedora.yml),
# so every engine-adapter test fails on an assertion (missing file / missing
# key), not on a syntax/compile error. The GREEN coder creates the two files.
#
# Seam under test (design.md "Engine-Specific Compose Overrides"):
#   docker-compose.podman.yml         -> services.dev: userns_mode: keep-id,
#                                        security_opt: [label=disable]
#   docker-compose.rootless-docker.yml -> services.dev: user: "0:0"
#   docker-compose.wsl.yml            -> WSL overlay only (no duplication)
#   base docker-compose.yml           -> single source of truth for volumes/
#                                        ports/environment/secrets
#
# The `docker compose config` tests assert file existence FIRST (clean RED
# when absent) and only then validate the merge against the REAL daemon, so a
# missing file never produces a daemon-dependent false RED. REAL_DOCKER is
# captured in setup() before the docker fake is installed on PATH.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
PODMAN_OVERRIDE="$REPO_ROOT/docker-compose.podman.yml"
ROOTLESS_OVERRIDE="$REPO_ROOT/docker-compose.rootless-docker.yml"
WSL_OVERRIDE="$REPO_ROOT/docker-compose.wsl.yml"
BASE_COMPOSE="$REPO_ROOT/docker-compose.yml"
SCRIPT="$REPO_ROOT/scripts/opencode-dev"

# assert_file_lacks_keys <file> <key>...: fails if <file> declares any of the
# given top-level service keys (anchored to line start + colon so comments and
# substrings like "security_opt" don't false-match "secrets"). Used to enforce
# the "no duplication" constraint and the "WSL has no engine-specific flags"
# constraint without over-constraining GREEN's exact formatting.
assert_file_lacks_keys() {
  local file="$1"; shift
  local key
  for key in "$@"; do
    if grep -Eq "^[[:space:]]*${key}:" "$file"; then
      echo "assert_file_lacks_keys: $file must NOT declare '$key'" >&2
      return 1
    fi
  done
}

setup() {
  # Capture the real docker before the fake is installed on PATH, so the
  # `docker compose config` merge tests talk to the real daemon in GREEN.
  REAL_DOCKER="$(command -v docker)"
  export REAL_DOCKER
  FAKE_DOCKER_SERVICES=""
  mock_docker
}

# --- Behavior 1: Podman override declares keep-id + SELinux (res040 §2) ------

@test "RED trigger: docker-compose.podman.yml exists" {
  assert_file_exists "$PODMAN_OVERRIDE"
}

@test "Podman override declares userns_mode: keep-id" {
  assert_file_exists "$PODMAN_OVERRIDE"
  assert_file_contains "$PODMAN_OVERRIDE" "userns_mode"
  assert_file_contains "$PODMAN_OVERRIDE" "keep-id"
}

@test "Podman override declares security_opt: label=disable" {
  assert_file_exists "$PODMAN_OVERRIDE"
  assert_file_contains "$PODMAN_OVERRIDE" "security_opt"
  assert_file_contains "$PODMAN_OVERRIDE" "label=disable"
}

# --- Behavior 2: Rootless-Docker override declares user: 0:0 (res040 §1) -----

@test "RED trigger: docker-compose.rootless-docker.yml exists" {
  assert_file_exists "$ROOTLESS_OVERRIDE"
}

@test "Rootless-Docker override declares user: 0:0" {
  assert_file_exists "$ROOTLESS_OVERRIDE"
  assert_file_contains "$ROOTLESS_OVERRIDE" "user:"
  assert_file_contains "$ROOTLESS_OVERRIDE" "0:0"
}

# --- Behavior 3: neither engine adapter duplicates base config ---------------

@test "Podman override does not duplicate base volumes/ports/environment/secrets" {
  assert_file_exists "$PODMAN_OVERRIDE"
  assert_file_lacks_keys "$PODMAN_OVERRIDE" volumes ports environment secrets
}

@test "Rootless-Docker override does not duplicate base volumes/ports/environment/secrets" {
  assert_file_exists "$ROOTLESS_OVERRIDE"
  assert_file_lacks_keys "$ROOTLESS_OVERRIDE" volumes ports environment secrets
}

# --- Behavior 4: WSL overlay is engine-agnostic (stable guard) ---------------

@test "WSL overlay contains no engine-specific flags (userns_mode/security_opt)" {
  assert_file_exists "$WSL_OVERRIDE"
  assert_file_lacks_keys "$WSL_OVERRIDE" userns_mode security_opt
}

@test "WSL overlay does not duplicate base volumes/ports/environment/secrets" {
  assert_file_exists "$WSL_OVERRIDE"
  assert_file_lacks_keys "$WSL_OVERRIDE" volumes ports environment secrets
}

# --- Behavior 5: opencode-dev --engine references existing override files ---

@test "opencode-dev --engine=podman references an existing override file" {
  FAKE_DOCKER_SERVICES=""
  mock_docker
  : > "$FAKE_DOCKER_LOG"
  run bash "$SCRIPT" --engine=podman
  override="$(grep -oE 'docker-compose\.(podman|rootless-docker)\.yml' "$FAKE_DOCKER_LOG" | head -1)"
  [ -n "$override" ] || { echo "script did not reference an engine override file" >&2; return 1; }
  assert_file_exists "$REPO_ROOT/$override"
}

@test "opencode-dev --engine=docker references an existing override file" {
  FAKE_DOCKER_SERVICES=""
  mock_docker
  : > "$FAKE_DOCKER_LOG"
  run bash "$SCRIPT" --engine=docker
  override="$(grep -oE 'docker-compose\.(podman|rootless-docker)\.yml' "$FAKE_DOCKER_LOG" | head -1)"
  [ -n "$override" ] || { echo "script did not reference an engine override file" >&2; return 1; }
  assert_file_exists "$REPO_ROOT/$override"
}

# --- Spec "Override Validation": merged config validates (real daemon) ------

@test "podman override merges with base via 'docker compose config'" {
  assert_file_exists "$PODMAN_OVERRIDE"
  run "$REAL_DOCKER" compose -f "$BASE_COMPOSE" -f "$PODMAN_OVERRIDE" config
  assert_status 0
}

@test "rootless-docker override merges with base via 'docker compose config'" {
  assert_file_exists "$ROOTLESS_OVERRIDE"
  run "$REAL_DOCKER" compose -f "$BASE_COMPOSE" -f "$ROOTLESS_OVERRIDE" config
  assert_status 0
}

@test "wsl overlay merges with base + podman engine override via 'docker compose config'" {
  assert_file_exists "$PODMAN_OVERRIDE"
  assert_file_exists "$WSL_OVERRIDE"
  run "$REAL_DOCKER" compose -f "$BASE_COMPOSE" -f "$PODMAN_OVERRIDE" -f "$WSL_OVERRIDE" config
  assert_status 0
}

# Regression (DIA-260824-a3mk / WSL empty-mapping finding): the WSL overlay
# declares `dev: {}` (empty mapping), so the 3-file merge (base + podman
# keep-id + wsl) must still contain the `dev` service. Assert PRESENCE of the
# dev service key in the rendered config, NOT exact YAML shape/ordering
# (daemon-version-fragile). A bare `dev: null` in the overlay would drop the
# key and break this assertion.
@test "wsl overlay merge with base + podman retains the dev service" {
  assert_file_exists "$PODMAN_OVERRIDE"
  assert_file_exists "$WSL_OVERRIDE"
  run "$REAL_DOCKER" compose -f "$BASE_COMPOSE" -f "$PODMAN_OVERRIDE" -f "$WSL_OVERRIDE" config
  assert_status 0
  printf '%s\n' "$output" | grep -Eq '^[[:space:]]*dev:' \
    || { echo "merged config missing 'dev' service:" >&2; echo "$output" >&2; return 1; }
}
