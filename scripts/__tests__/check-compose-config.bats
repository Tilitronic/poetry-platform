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

# Source shared in-container detection (S6, DIA-260922-cp0m).
source "$REPO_ROOT/scripts/in-container.sh"

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

# plant_hostname <dir> <name>: writes a fake `hostname` script into <dir>
# echoing <name> and prepends <dir> to PATH, so is_in_dev_container (sourced
# from in-container.sh) evaluates against <name> regardless of the real
# hostname. Lets these tests run on ANY host AND inside the container without
# skipping.
plant_hostname() {
  local dir="$1" name="$2"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\n' "$name" > "$dir/hostname"
  chmod +x "$dir/hostname"
  PATH="$dir:$PATH"
  export PATH
}

# plant_non_container_hostname <dir>: fake hostname echoing a NON-container
# name (back-compat wrapper over plant_hostname).
plant_non_container_hostname() {
  plant_hostname "$1" "test-host"
}

# compose_service_block <service>: print the body of a service in the real
# docker-compose.yml (from the two-space-indented service key until the next
# service key). Service keys sit at 2 spaces; deeper keys/lists never match.
compose_service_block() {
  awk -v svc="  $1:" '
    index($0, svc) == 1 { grab = 1; next }
    grab && /^  [A-Za-z0-9_-]+:/ { exit }
    grab { print }
  ' "$REPO_ROOT/docker-compose.yml"
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

setup() {
  # Hermetic engine selection (DIA-260909-9api, container-engine.bats:32):
  # ignore any inherited COMPOSE_ENGINE; tests that need an override export
  # it explicitly.
  unset COMPOSE_ENGINE
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
  plant_non_container_hostname "$BATS_TEST_TMPDIR/bin"
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

  # S4 + Obs-3: genuinely hermetic PATH. Build a temp bin with ONLY the
  # binaries the script's code path invokes (bash, hostname) and deliberately
  # NO docker, NO podman. When COMPOSE_ENGINE=podman, container_engine_select
  # returns "podman" immediately (no command -v / readlink needed); the script's
  # P3 guard then checks `command -v podman` which fails under this PATH.
  local hermetic_bin="$BATS_TEST_TMPDIR/hermetic-bin"
  mkdir -p "$hermetic_bin"
  ln -sf "$(command -v bash)" "$hermetic_bin/bash"
  # Plant a fake hostname that returns a NON-container name so is_in_dev_container
  # evaluates to FALSE. The real hostname returns "poetry-dev" in-container, which
  # would trigger the host-scoped skip guard. This mock keeps the test hermetic.
  cat > "$hermetic_bin/hostname" <<'FAKEHOSTNAME'
#!/usr/bin/env bash
printf '%s\n' "test-host"
FAKEHOSTNAME
  chmod +x "$hermetic_bin/hostname"
  ln -sf "$(command -v dirname)" "$hermetic_bin/dirname"
  # Precondition assertion: prove podman is NOT in the hermetic bin.
  # If this ever fails, the test must fail LOUDLY — never silently revert.
  [ ! -x "$hermetic_bin/podman" ] || {
    echo "PRECONDITION FAILED: podman found in hermetic bin — cannot test CLI-absence path" >&2
    return 1
  }

  run env COMPOSE_ENGINE=podman PATH="$hermetic_bin" bash "$tree/scripts/check-compose-config.sh"

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
  # Fake hostname: returns non-container name so is_in_dev_container is FALSE.
  # The run() call passes PATH="$bindir:$PATH" so this mock takes precedence.
  cat > "$bindir/hostname" <<'FAKEHOSTNAME'
#!/usr/bin/env bash
printf '%s\n' "test-host"
FAKEHOSTNAME
  chmod +x "$bindir/hostname"
  PATH="$bindir:$PATH"
  export PATH
  local tree
  tree="$(setup_compose_config_tree)"

  run env COMPOSE_ENGINE=docker bash "$tree/scripts/check-compose-config.sh"

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

# ---------------------------------------------------------------------------
# tasks.md 1.1 (S1.1): dev-v2 compose service shape -- RED phase, campaign
# DIA-261119-vioa. Asserted against the real docker-compose.yml at file level
# (the same seam compose-overrides.bats uses for service shape; no engine
# needed). Each test fails TODAY on a missing-behavior assertion: the dev-v2
# service does not exist yet. Guards on the unchanged V1 `dev` service run
# first so a V1 regression is reported separately from the missing V2 work.
# ---------------------------------------------------------------------------

@test "task 1.1: dev-v2 mounts the full repo at /workspace with working_dir in the v2 worktree" {
  local compose="$REPO_ROOT/docker-compose.yml"
  # RED marker: the worktree working_dir does not exist yet (D1a N1).
  assert_file_contains "$compose" "working_dir: /workspace/.worktrees/opencode-v2"
  local block
  block="$(compose_service_block dev-v2)"
  [ -n "$block" ] || { echo "docker-compose.yml: missing service block 'dev-v2'" >&2; return 1; }
  # Full-repo mount: source is exactly '.', optional mode suffix (:z etc).
  grep -qE '^[[:space:]]*-[[:space:]]+\.:/workspace(:[a-zA-Z]+)?[[:space:]]*$' <<<"$block" || {
    echo "dev-v2 must mount the full repo as '- .:/workspace' (NOT a single directory):" >&2
    echo "$block" >&2
    return 1
  }
  # NEGATIVE: no './<subdir>:/workspace' bind -- it would hide /workspace/.git/objects.
  if grep -qE '^[[:space:]]*-[[:space:]]+\./[^:]+:/workspace(:[a-zA-Z]+)?[[:space:]]*$' <<<"$block"; then
    echo "dev-v2 must not bind a subdirectory over /workspace (breaks git object store):" >&2
    echo "$block" >&2
    return 1
  fi
}

@test "task 1.1: dev-v2 declares its own image, container name, hostname and cache/state/pnpm volumes" {
  local compose="$REPO_ROOT/docker-compose.yml"
  # RED marker: hostname poetry-dev-v2 does not exist yet.
  assert_file_contains "$compose" "hostname: poetry-dev-v2"
  local block dev_block top_volumes src shared=""
  block="$(compose_service_block dev-v2)"
  [ -n "$block" ] || { echo "docker-compose.yml: missing service block 'dev-v2'" >&2; return 1; }
  dev_block="$(compose_service_block dev)"
  # Own image tag (design D1 table: poetry-platform-dev-v2:<tag>).
  grep -qE '^[[:space:]]*image:[[:space:]]+poetry-platform-dev-v2' <<<"$block" || {
    echo "dev-v2 must declare its own image tag poetry-platform-dev-v2:" >&2; echo "$block" >&2; return 1; }
  # Own container name: declared, and not V1's poetry-dev.
  grep -qE '^[[:space:]]*container_name:' <<<"$block" || {
    echo "dev-v2 must declare its own container_name:" >&2; echo "$block" >&2; return 1; }
  if grep -qE '^[[:space:]]*container_name:[[:space:]]+poetry-dev[[:space:]]*$' <<<"$block"; then
    echo "dev-v2 container_name must differ from V1's poetry-dev:" >&2; echo "$block" >&2; return 1
  fi
  # V1 identity unchanged (guard).
  grep -qE '^[[:space:]]*container_name:[[:space:]]+poetry-dev[[:space:]]*$' <<<"$dev_block" || {
    echo "V1 dev lost its container_name poetry-dev:" >&2; echo "$dev_block" >&2; return 1; }
  grep -qE '^[[:space:]]*image:[[:space:]]+poetry-platform-dev:latest' <<<"$dev_block" || {
    echo "V1 dev lost its image poetry-platform-dev:latest:" >&2; echo "$dev_block" >&2; return 1; }
  # Own volumes: pnpm store at the worktree path named in tasks.md 1.1, plus
  # dedicated cache/state volumes.
  grep -qF 'pnpm_store_v2:/workspace/.worktrees/opencode-v2/node_modules' <<<"$block" || {
    echo "dev-v2 must mount pnpm_store_v2 at the worktree node_modules path:" >&2; echo "$block" >&2; return 1; }
  grep -qF 'dev_v2_cache' <<<"$block" || {
    echo "dev-v2 must mount its own dev_v2_cache volume:" >&2; echo "$block" >&2; return 1; }
  grep -qF 'dev_v2_state' <<<"$block" || {
    echo "dev-v2 must mount its own dev_v2_state volume:" >&2; echo "$block" >&2; return 1; }
  # Named volumes must be declared top-level or compose rejects the file.
  top_volumes="$(awk '/^volumes:/{f=1;next} /^[A-Za-z]/{f=0} f' "$compose")"
  for src in pnpm_store_v2 dev_v2_cache dev_v2_state; do
    grep -qE "^  ${src}:" <<<"$top_volumes" || {
      echo "top-level volumes: missing named volume '$src'" >&2; return 1; }
  done
  # NEGATIVE: zero shared volume sources between the services (the repo mount
  # '.' is shared on purpose per D1a N1 and is excluded here).
  while IFS= read -r src; do
    [ -n "$src" ] || continue
    [ "$src" = "." ] && continue
    if grep -qF -- "- ${src}:" <<<"$block"; then
      shared="$shared $src"
    fi
  done <<<"$(grep -oE '^[[:space:]]*-[[:space:]]+[A-Za-z0-9_.-]+:' <<<"$dev_block" \
    | sed -E 's/^[[:space:]]*-[[:space:]]+//; s/:$//' | sort -u)"
  [ -z "$shared" ] || {
    echo "dev-v2 shares V1 volume(s):$shared (cache/state/pnpm must be disjoint)" >&2
    return 1
  }
  # V1 keeps its existing volumes (guard).
  grep -qF 'pnpm_store:/workspace/node_modules' <<<"$dev_block" || {
    echo "V1 dev lost its pnpm_store mount:" >&2; echo "$dev_block" >&2; return 1; }
  grep -qF 'dev_state:' <<<"$dev_block" || {
    echo "V1 dev lost its dev_state mount:" >&2; echo "$dev_block" >&2; return 1; }
  grep -qF 'dev_cache:' <<<"$dev_block" || {
    echo "V1 dev lost its dev_cache mount:" >&2; echo "$dev_block" >&2; return 1; }
}

@test "task 1.1: dev-v2 publishes 9100/8100/3100 with env overrides on poetry-net; dev keeps 9000/8000/3000" {
  local compose="$REPO_ROOT/docker-compose.yml"
  # RED marker: no V2 host port published yet.
  assert_file_contains "$compose" "9100"
  local block dev_block line bad=""
  block="$(compose_service_block dev-v2)"
  [ -n "$block" ] || { echo "docker-compose.yml: missing service block 'dev-v2'" >&2; return 1; }
  dev_block="$(compose_service_block dev)"
  # Env-overridable host ports: '- ${*_PORT:-9100}:9100' spelling regardless of
  # the variable name; the default MUST be the V2 host port.
  grep -qF ':-9100}:9100' <<<"$block" || {
    echo "dev-v2 must publish host port 9100 env-overridable (:-9100}:9100):" >&2; echo "$block" >&2; return 1; }
  grep -qF ':-8100}:8100' <<<"$block" || {
    echo "dev-v2 must publish host port 8100 env-overridable (:-8100}:8100):" >&2; echo "$block" >&2; return 1; }
  grep -qF ':-3100}:3100' <<<"$block" || {
    echo "dev-v2 must publish host port 3100 env-overridable (:-3100}:3100):" >&2; echo "$block" >&2; return 1; }
  # Shared postgres network (both services on poetry-net).
  grep -qE '^[[:space:]]*-[[:space:]]*poetry-net[[:space:]]*$' <<<"$block" || {
    echo "dev-v2 must join the shared poetry-net network:" >&2; echo "$block" >&2; return 1; }
  # NEGATIVE: every dev-v2 published port line must carry a V2 host port --
  # this catches both env-default and bare '9000:9000' overlap spellings
  # (the container side may legitimately be 9000/8000/3000).
  while IFS= read -r line; do
    case "$line" in
      *9100*|*8100*|*3100*) ;;
      *) bad="$bad | $line" ;;
    esac
  done < <(grep -E '^[[:space:]]*-[[:space:]].*[0-9]+:[0-9]+' <<<"$block")
  [ -z "$bad" ] || {
    echo "dev-v2 publishes a host port outside 9100/8100/3100 (overlap with V1):$bad" >&2
    return 1
  }
  # V1 keeps its own ports with their env defaults (guard).
  grep -qF ':-9000}:9000' <<<"$dev_block" || {
    echo "V1 dev lost host port 9000:" >&2; echo "$dev_block" >&2; return 1; }
  grep -qF ':-8000}:8000' <<<"$dev_block" || {
    echo "V1 dev lost host port 8000:" >&2; echo "$dev_block" >&2; return 1; }
  grep -qF ':-3000}:3000' <<<"$dev_block" || {
    echo "V1 dev lost host port 3000:" >&2; echo "$dev_block" >&2; return 1; }
}

@test "task 1.8: detector allowlist accepts poetry-dev-v2 and poetry-dev, rejects lookalikes" {
  local hdir="$BATS_TEST_TMPDIR/allowlist-host"
  # Guards (run first): an arbitrary hostname and a poetry-dev prefix
  # lookalike must stay rejected -- the detector is an explicit allowlist,
  # not a prefix match.
  plant_hostname "$hdir" "some-other-host"
  run is_in_dev_container
  [ "$status" -ne 0 ] || {
    echo "detector accepted arbitrary hostname some-other-host" >&2; return 1; }
  plant_hostname "$hdir" "poetry-dev-evil"
  run is_in_dev_container
  [ "$status" -ne 0 ] || {
    echo "detector accepted prefix lookalike poetry-dev-evil (prefix match, not allowlist)" >&2; return 1; }
  plant_hostname "$hdir" "poetry-dev"
  run is_in_dev_container
  [ "$status" -eq 0 ] || {
    echo "detector rejected the V1 hostname poetry-dev" >&2; return 1; }
  # RED today: in-container.sh matches only the literal poetry-dev, so the
  # dev-v2 hostname is treated as 'not in container' and every container-gated
  # script would hard-fail inside dev-v2 (D1a N3).
  plant_hostname "$hdir" "poetry-dev-v2"
  run is_in_dev_container
  [ "$status" -eq 0 ] || {
    echo "RED task 1.8: detector rejects hostname poetry-dev-v2 (allowlist must include it)" >&2
    return 1
  }
}
