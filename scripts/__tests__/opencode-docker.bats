#!/usr/bin/env bats
# Unit tests for the tools/opencode-docker root Makefile gate (DIA-044).
#
# Positive test runs scripts/check-opencode-docker.sh against the REAL
# subproject tree (like check-tools.bats' S4 real-repo test); negative tests
# copy the script into an isolated tree with a controlled tools/opencode-docker
# fixture so failures are deterministic and python3-independent (file-presence
# + bash -n checks). The last test asserts the root Makefile actually wires the
# gate into test-shell (wiring regression guard).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CHECK="$REPO_ROOT/scripts/check-opencode-docker.sh"

# build_fixture <root>: plants a VALID minimal tools/opencode-docker tree under
# <root>. The fixture must satisfy every check the script performs.
build_fixture() {
  local root="$1"
  local ocd="$root/tools/opencode-docker"
  mkdir -p "$ocd/bin" "$ocd/scripts" "$ocd/config"
  printf '#!/usr/bin/env bash\n' > "$ocd/bin/opencode-docker"
  chmod +x "$ocd/bin/opencode-docker"
  printf '# FROM debian:13-slim\n' > "$ocd/Dockerfile"
  printf '#!/usr/bin/env bash\necho ok\n' > "$ocd/scripts/collect-runtime-deps.sh"
  printf '#!/usr/bin/env python3\nprint("ok")\n' > "$ocd/bootstrap.py"
  printf '{}\n' > "$ocd/config/opencode.json"
  printf '.PHONY: build run shell clean\n\nbuild:\n\tpodman build .\n\nrun:\n\tpodman run opencode-docker:latest\n\nshell:\n\tpodman run --entrypoint /bin/bash opencode-docker:builder-tools\n\nclean:\n\tpodman rmi opencode-docker || true\n' > "$ocd/Makefile"
  printf '# AGENTS.md\n' > "$ocd/AGENTS.md"
}

# setup_isolated: copies check-opencode-docker.sh into an isolated tree with a
# valid fixture; echoes the tree root. Negative tests break the fixture after.
setup_isolated() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts"
  cp "$CHECK" "$tree/scripts/check-opencode-docker.sh"
  build_fixture "$tree"
  echo "$tree"
}

@test "opencode-docker gate: real subproject tree -> exit 0" {
  run bash "$CHECK"

  assert_status 0
  assert_output_contains "ok: tools/opencode-docker static integrity passed"
}

@test "opencode-docker gate: isolated valid fixture -> exit 0" {
  local tree
  tree="$(setup_isolated)"

  run bash "$tree/scripts/check-opencode-docker.sh"

  assert_status 0
  assert_output_contains "ok: tools/opencode-docker static integrity passed"
}

@test "opencode-docker gate: missing bin wrapper -> exit 1" {
  local tree
  tree="$(setup_isolated)"
  rm "$tree/tools/opencode-docker/bin/opencode-docker"

  run bash "$tree/scripts/check-opencode-docker.sh"

  assert_status 1
  assert_output_contains "bin/opencode-docker missing"
}

@test "opencode-docker gate: broken collect-runtime-deps.sh syntax -> exit 1" {
  local tree
  tree="$(setup_isolated)"
  printf '#!/usr/bin/env bash\nif [\n' > "$tree/tools/opencode-docker/scripts/collect-runtime-deps.sh"

  run bash "$tree/scripts/check-opencode-docker.sh"

  assert_status 1
  assert_output_contains "collect-runtime-deps.sh"
}

@test "opencode-docker gate: subproject dir missing -> exit 2" {
  local tree="$BATS_TEST_TMPDIR/noocd"
  mkdir -p "$tree/scripts"
  cp "$CHECK" "$tree/scripts/check-opencode-docker.sh"

  run bash "$tree/scripts/check-opencode-docker.sh"

  assert_status 2
  assert_output_contains "tools/opencode-docker directory missing"
}

@test "opencode-docker gate: root Makefile wires the gate into test-shell" {
  assert_file_contains "$REPO_ROOT/Makefile" "test-opencode-docker"
  # fixed-string match on the exact target line (test-helper uses grep -F)
  assert_file_contains "$REPO_ROOT/Makefile" "test-shell: test-opencode-docker"
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/check-opencode-docker.sh"
}
