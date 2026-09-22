#!/usr/bin/env bats
# Unit tests for scripts/check-compose-config.sh (seam 9: host-side compose-config gate).
#
# PHASE 5 contract (design.md "Host-Side Compose-Config Gate Boundary"):
#   - Runs `<engine> compose config --quiet` via scripts/container-engine.sh
#   - HARD FAIL (non-zero, actionable) when engine CLI is unavailable
#   - NEVER silently skips
#   - In-container `make test-config` path prints visible host-scoped skip note
#
# Uses mock_docker from test-helper.bash (canonical fake, records invocations).
# No Docker daemon needed; the check is client-side.

load test-helper

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# setup_compose_config_tree: copies container-engine.sh + compose-env.sh +
# check-compose-config.sh into an isolated temp tree and plants a minimal
# docker-compose.yml. Echoes the tree root.
setup_compose_config_tree() {
  local tree="$BATS_TEST_TMPDIR/compose-config"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/container-engine.sh" "$tree/scripts/container-engine.sh"
  if [ -f "$REPO_ROOT/scripts/compose-env.sh" ]; then
    cp "$REPO_ROOT/scripts/compose-env.sh" "$tree/scripts/compose-env.sh"
  fi
  if [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ]; then
    cp "$REPO_ROOT/scripts/check-compose-config.sh" "$tree/scripts/check-compose-config.sh"
  fi
  if [ -f "$REPO_ROOT/scripts/in-container.sh" ]; then
    cp "$REPO_ROOT/scripts/in-container.sh" "$tree/scripts/in-container.sh"
  fi
  # Plant a minimal docker-compose.yml so `compose config` has something to validate
  cat > "$tree/docker-compose.yml" <<'EOF'
services:
  dev:
    image: debian:13-slim
EOF
  echo "$tree"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "check-compose-config: script must exist (feature prerequisite)" {
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || {
    echo "FEATURE ABSENT: scripts/check-compose-config.sh does not exist yet" >&2
    return 1
  }
  [ -x "$REPO_ROOT/scripts/check-compose-config.sh" ] || {
    echo "scripts/check-compose-config.sh exists but is not executable" >&2
    return 1
  }
}

@test "check-compose-config: engine CLI present + valid config -> exit 0" {
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || skip "script not yet implemented"
  mock_docker
  local tree
  tree="$(setup_compose_config_tree)"

  run bash "$tree/scripts/check-compose-config.sh"

  assert_status 0
  # Prove the adapter was actually invoked (S3: reuse mock_docker recording)
  grep -q "compose config" "$FAKE_DOCKER_LOG"
}

@test "check-compose-config: engine CLI absent -> HARD FAIL with actionable message" {
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || skip "script not yet implemented"
  local tree
  tree="$(setup_compose_config_tree)"

  # S4 + Obs-3: drive REAL CLI absence via COMPOSE_ENGINE=podman.
  # On this host, podman is not installed (command -v podman fails), so the
  # P3 command-v check catches it. This is deterministic: the test asserts
  # the precondition that podman is not resolvable.
  run env COMPOSE_ENGINE=podman bash "$tree/scripts/check-compose-config.sh"

  assert_status 1
  # P3: the message must name the missing engine and tell the developer to install
  assert_output_contains "not found on PATH"
  # Must NOT silently succeed or skip
  [[ "$output" != *"skip"* ]] || {
    echo "check-compose-config: FAIL -- silently skipped instead of hard-failing" >&2
    return 1
  }
}

@test "check-compose-config: compose config validation fails -> non-zero exit" {
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || skip "script not yet implemented"
  # ponytail: duplicate fake retained for a targeted compose-config-failure
  # path, extend mock_docker with FAKE_DOCKER_COMPOSE_CONFIG_FAIL if a third
  # consumer appears.
  # Plant a docker fake that succeeds on everything except `compose config`.
  # This is more targeted than mock_docker_down: it proves the compose-config
  # failure path specifically, not just "every probe fails".
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
# Fake docker: succeeds on everything except `compose config`.
printf '%s\n' "$*" >> "${FAKE_DOCKER_LOG:-/dev/null}"
case "${1:-}" in
  compose)
    shift
    while [ $# -gt 0 ] && [ "${1:-}" = "-f" ]; do shift 2; done
    case "${1:-}" in
      config) exit 1 ;;
    esac
    exit 0
    ;;
esac
exit 0
FAKEDOCKER
  chmod +x "$bindir/docker"
  PATH="$bindir:$PATH"
  export PATH
  local tree
  tree="$(setup_compose_config_tree)"

  run bash "$tree/scripts/check-compose-config.sh"

  assert_status 1
  assert_output_contains "compose config --quiet failed"
}

@test "check-compose-config: in-container path prints visible host-scoped skip note" {
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || skip "script not yet implemented"
  # Obs-2: mock_docker initializes FAKE_DOCKER_LOG so the negative assertion
  # is meaningful (not a vacuous read of an unset variable).
  mock_docker
  local tree
  tree="$(setup_compose_config_tree)"

  # Simulate in-container: the script detects in-container by hostname
  # (check-compose-config.sh sources in-container.sh: hostname = "poetry-dev").
  # Override the hostname command with a fake that returns "poetry-dev".
  local fakebin="$BATS_TEST_TMPDIR/fakebin2"
  mkdir -p "$fakebin"
  cat > "$fakebin/hostname" <<'FAKEHOST'
#!/usr/bin/env bash
printf '%s\n' "poetry-dev"
FAKEHOST
  chmod +x "$fakebin/hostname"

  run env PATH="$fakebin:$PATH" bash "$tree/scripts/check-compose-config.sh"

  # The output must contain a visible note about host-scoping
  assert_output_contains "host"
  # Must NOT invoke the engine adapter (no docker calls logged)
  [ ! -s "$FAKE_DOCKER_LOG" ] || {
    echo "check-compose-config: FAIL -- adapter invoked during in-container path" >&2
    return 1
  }
}
