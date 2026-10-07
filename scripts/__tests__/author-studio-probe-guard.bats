#!/usr/bin/env bats
# Unit tests for scripts/author-studio-probe-guard.sh (DIA-048 Fix b).
#
# The guard is a pure filesystem probe: it decides, from the shape of the
# workspace node_modules tree, whether the author-studio smoke probe can run.
# Fixture trees are built under $BATS_TEST_TMPDIR so no real node_modules is
# involved. The final test asserts the smoke test actually invokes the guard
# (wiring regression guard — the probe must not silently revert to a
# presence-only inline check).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
GUARD="$REPO_ROOT/scripts/author-studio-probe-guard.sh"

# build_tree <dir> <turbo 0|1> <quasar 0|1>: plants node_modules/.bin/turbo and
# apps/author-studio/node_modules/@quasar/app-vite (or omits them). The quasar
# fixture is a plain directory — the guard's `test -e` resolves it the same as
# the real pnpm symlink (which is dangling when the pnpm_store volume is stale).
build_tree() {
  local dir="$1" turbo="$2" quasar="$3"
  mkdir -p "$dir/node_modules/.bin"
  if [ "$turbo" = "1" ]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$dir/node_modules/.bin/turbo"
    chmod +x "$dir/node_modules/.bin/turbo"
  fi
  if [ "$quasar" = "1" ]; then
    mkdir -p "$dir/apps/author-studio/node_modules/@quasar/app-vite"
    printf '{"name":"@quasar/app-vite"}\n' > "$dir/apps/author-studio/node_modules/@quasar/app-vite/package.json"
  fi
}

@test "guard: fresh tree (turbo + @quasar/app-vite) -> exit 0, probe allowed" {
  build_tree "$BATS_TEST_TMPDIR/ws" 1 1

  run bash "$GUARD" "$BATS_TEST_TMPDIR/ws"

  assert_status 0
  assert_output_contains "ok: author-studio toolchain fresh"
}

@test "guard: stale tree (turbo present, @quasar/app-vite missing) -> exit 1, fails loudly" {
  build_tree "$BATS_TEST_TMPDIR/ws" 1 0

  run bash "$GUARD" "$BATS_TEST_TMPDIR/ws"

  assert_status 1
  assert_output_contains "not resolvable"
  assert_output_contains "pnpm_store"
  assert_output_contains "docker volume rm pnpm_store"
}

@test "guard: absent tree (no turbo) -> exit 2, skip with make install pointer" {
  build_tree "$BATS_TEST_TMPDIR/ws" 0 0

  run bash "$GUARD" "$BATS_TEST_TMPDIR/ws"

  assert_status 2
  assert_output_contains "make install"
}

@test "guard: incomplete tree (turbo present, apps/ dir absent) -> exit 1" {
  build_tree "$BATS_TEST_TMPDIR/ws" 1 0
  rm -rf "$BATS_TEST_TMPDIR/ws/apps"

  run bash "$GUARD" "$BATS_TEST_TMPDIR/ws"

  assert_status 1
  assert_output_contains "not resolvable"
}

@test "guard: default workspace is /workspace (in-container contract)" {
  # The smoke test invokes the guard with NO argument inside the container,
  # where /workspace is the repo bind mount. The default must stay /workspace —
  # a drifted default would silently probe the wrong tree.
  assert_file_contains "$GUARD" 'WS="${1:-/workspace}"'
}

@test "smoke wiring: test-docker-smoke.sh invokes the guard script" {
  assert_file_contains "$REPO_ROOT/scripts/test-docker-smoke.sh" "author-studio-probe-guard.sh"
}
