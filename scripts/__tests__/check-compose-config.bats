#!/usr/bin/env bats
# Unit tests for scripts/check-compose-config.sh (seam 9: host-side compose-config gate).
#
# PHASE 5 contract (design.md "Host-Side Compose-Config Gate Boundary"):
#   - Runs `<engine> compose config --quiet` via scripts/container-engine.sh
#   - HARD FAIL (non-zero, actionable) when engine CLI is unavailable
#   - NEVER silently skips
#   - In-container `make test-config` path prints visible host-scoped skip note
#
# PATH-stubbing: engine CLI fakes are planted on PATH to control availability.
# No Docker daemon needed; the check is client-side (design.md: "offline dev
# stack never blocks").

load test-helper

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# install_engine_fakes <dir>: plants fake docker + podman on PATH that
# simulate `compose config --quiet` succeeding. Controlled by env:
#   FAKE_ENGINE_COMPOSE_CONFIG_FAIL=1   compose config exits 1
install_engine_fakes() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
# Fake docker CLI for compose-config tests.
case "${1:-}" in
  compose)
    shift
    # Consume -f flags
    while [ $# -gt 0 ] && [ "${1:-}" = "-f" ]; do shift 2; done
    case "${1:-}" in
      config)
        [ "${FAKE_ENGINE_COMPOSE_CONFIG_FAIL:-}" = "1" ] && exit 1
        exit 0
        ;;
    esac
    exit 0
    ;;
  version)
    # container-engine.sh autodetect uses `command -v docker` + readlink;
    # the fake exists on PATH so command -v succeeds.
    printf 'Docker version 24.0.0\n'
    exit 0
    ;;
esac
exit 0
FAKEDOCKER
  cat > "$dir/podman" <<'FAKEPODMAN'
#!/usr/bin/env bash
# Fake podman CLI for compose-config tests.
case "${1:-}" in
  compose)
    shift
    while [ $# -gt 0 ] && [ "${1:-}" = "-f" ]; do shift 2; done
    case "${1:-}" in
      config)
        [ "${FAKE_ENGINE_COMPOSE_CONFIG_FAIL:-}" = "1" ] && exit 1
        exit 0
        ;;
    esac
    exit 0
    ;;
  version)
    printf 'podman version 5.0.0\n'
    exit 0
    ;;
esac
exit 0
FAKEPODMAN
  chmod +x "$dir/docker" "$dir/podman"
  PATH="$dir:$PATH"
  export PATH
}

# setup_compose_config_tree: copies container-engine.sh + compose-env.sh +
# check-compose-config.sh into an isolated temp tree and plants a minimal
# docker-compose.yml. Echoes the tree root.
# The test runner is responsible for invoking the script under test.
setup_compose_config_tree() {
  local tree="$BATS_TEST_TMPDIR/compose-config"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/container-engine.sh" "$tree/scripts/container-engine.sh"
  # Also copy compose-env.sh (container-engine.sh sources it)
  if [ -f "$REPO_ROOT/scripts/compose-env.sh" ]; then
    cp "$REPO_ROOT/scripts/compose-env.sh" "$tree/scripts/compose-env.sh"
  fi
  # Copy check-compose-config.sh (implementation now exists, T12.1)
  if [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ]; then
    cp "$REPO_ROOT/scripts/check-compose-config.sh" "$tree/scripts/check-compose-config.sh"
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
  # PHASE 5 RED gate: the implementation must exist before behavioral tests
  # can run. This assertion makes the "feature absent" failure explicit rather
  # than letting it surface as a cryptic cp error in downstream tests.
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || {
    echo "FEATURE ABSENT: scripts/check-compose-config.sh does not exist yet" >&2
    echo "Expected by PHASE 5 (T12.1). Implementation must create this script." >&2
    return 1
  }
  [ -x "$REPO_ROOT/scripts/check-compose-config.sh" ] || {
    echo "scripts/check-compose-config.sh exists but is not executable" >&2
    return 1
  }
}

@test "check-compose-config: engine CLI present + valid config -> exit 0" {
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || skip "script not yet implemented"
  install_engine_fakes "$BATS_TEST_TMPDIR/fakes"
  local tree
  tree="$(setup_compose_config_tree)"

  run bash "$tree/scripts/check-compose-config.sh"

  assert_status 0
}

@test "check-compose-config: engine CLI absent -> HARD FAIL (non-zero) with actionable message" {
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || skip "script not yet implemented"
  local tree
  tree="$(setup_compose_config_tree)"

  # Replace the temp tree's container-engine.sh with a stub that always fails
  # select. This is more reliable than PATH manipulation (Docker Desktop WSL
  # puts docker at /usr/bin AND /bin, so PATH=/usr/bin:/bin still finds it).
  cat > "$tree/scripts/container-engine.sh" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
  chmod +x "$tree/scripts/container-engine.sh"

  run bash "$tree/scripts/check-compose-config.sh"

  assert_status 1
  # Must contain an actionable message telling the developer what to do
  assert_output_contains "container engine"
  # Must NOT silently succeed or skip
  [[ "$output" != *"skip"* ]] || {
    echo "check-compose-config: FAIL -- silently skipped instead of hard-failing" >&2
    return 1
  }
}

@test "check-compose-config: compose config validation fails -> non-zero exit" {
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || skip "script not yet implemented"
  install_engine_fakes "$BATS_TEST_TMPDIR/fakes"
  local tree
  tree="$(setup_compose_config_tree)"
  export FAKE_ENGINE_COMPOSE_CONFIG_FAIL=1

  run bash "$tree/scripts/check-compose-config.sh"

  assert_status 1
}

@test "check-compose-config: in-container test-config path prints visible host-scoped skip note" {
  [ -f "$REPO_ROOT/scripts/check-compose-config.sh" ] || skip "script not yet implemented"
  local tree
  tree="$(setup_compose_config_tree)"

  # Simulate in-container: the script detects in-container by hostname
  # (check-compose-config.sh line 20: hostname = "poetry-dev"). Override
  # the hostname command with a fake that returns "poetry-dev".
  local fakebin="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$fakebin"
  cat > "$fakebin/hostname" <<'FAKEHOST'
#!/usr/bin/env bash
printf '%s\n' "poetry-dev"
FAKEHOST
  chmod +x "$fakebin/hostname"

  run env PATH="$fakebin:/usr/bin:/bin" bash "$tree/scripts/check-compose-config.sh"

  # The output must contain a visible note about host-scoping
  assert_output_contains "host"
}
