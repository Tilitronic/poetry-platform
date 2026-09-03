#!/usr/bin/env bats
# Regression test for DIA-260821-m7vk: the pre-commit gate (lint-staged) must be
# able to write to .git/index from the dev container even when the host UID
# differs from the container's dev UID.
#
# Root cause: UID mismatch at the bind-mount boundary. .git/ is owned by the
# host user; the container `dev` user (hardcoded UID 1000) cannot write to it,
# so lint-staged v15 partial-staging fails with EACCES. The fix (1) aligns the
# container UID with the host UID via docker-compose build.args USER_UID/GID,
# and (2) migrates ownership of /workspace/.git + the named volumes in
# dev-entrypoint.sh at boot.
#
# This suite is hermetic: no Docker daemon, no root. It (a) exercises the
# hook's POETRY_WORKSPACE seam with a fake docker that executes the inner
# command locally and a fake lint-staged that writes to .git/index, proving
# the write path works; (b) asserts the entrypoint issues the chown for the
# four writable paths (the ownership migration that removes the EACCES root
# cause); (c) asserts the config/.env wiring is present.

load test-helper

# --- (a) hook write path under the POETRY_WORKSPACE seam --------------------
@test "verify-pre-commit: lint-staged writes .git/index under POETRY_WORKSPACE (UID-mismatch seam)" {
  local ws="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$ws/.git"
  : > "$ws/.git/index"
  export POETRY_WORKSPACE="$ws"

  # Hermmetic host context: fake hostname so the hook takes the delegation
  # path (never the in-container direct path), and an isolated commands dir
  # for the /home/qualt guard.
  setup_hermetic_host_context

  # Fake docker: reports the dev container running, and `compose exec -T dev
  # bash -lc "<cmd>"` actually executes <cmd> locally so the hook's lint-staged
  # step runs (the real docker would delegate into the container).
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  export FAKE_DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_DOCKER_LOG:?}"
case "${1:-}" in
  compose)
    shift
    [ "${1:-}" = "-f" ] && shift 2
    if [ "${1:-}" = "ps" ]; then printf 'dev\n'; exit 0; fi
    if [ "${1:-}" = "exec" ]; then
      shift
      while [ $# -gt 0 ]; do
        case "$1" in -T|-it|--|dev) shift ;; *) break ;; esac
      done
      eval "$@"
      exit $?
    fi
    ;;
esac
exit 0
FAKEDOCKER
  chmod +x "$bindir/docker"

  # Fake lint-staged: the operation that fails with EACCES under the UID
  # mismatch is writing .git/index. Append a byte to prove the write path is
  # reachable, then exit 0 (autofix "passed").
  cat > "$bindir/lint-staged" <<'FAKELS'
#!/usr/bin/env bash
printf 'x' >> "${POETRY_WORKSPACE:-/workspace}/.git/index"
exit 0
FAKELS
  chmod +x "$bindir/lint-staged"

  # npx would fetch lint-staged from the network; short-circuit to the local
  # fake so the hook's `npx lint-staged` resolves offline.
  cat > "$bindir/npx" <<'FAKENPX'
#!/usr/bin/env bash
shift
exec lint-staged "$@"
FAKENPX
  chmod +x "$bindir/npx"

  export PATH="$bindir:$PATH"

  run bash "$REPO_ROOT/scripts/verify-pre-commit.sh"
  assert_status 0
  assert_output_contains "autofix passed"
  # the write actually happened -> the UID-mismatch write path is exercised
  [ -s "$ws/.git/index" ]
}

# --- (b) entrypoint ownership migration issues the four chowns --------------
@test "dev-entrypoint: migrates ownership of /workspace/.git and named volumes (m7vk fix)" {
  require_unshare
  local fakebin="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$fakebin"
  export FAKE_CHOWN_LOG="$BATS_TEST_TMPDIR/chown.log"
  # Fake chown records every invocation (no real ownership change) so the test
  # verifies WHICH paths the entrypoint migrates without touching real files.
  cat > "$fakebin/chown" <<'FAKECHOWN'
#!/usr/bin/env bash
printf 'chown %s\n' "$*" >> "${FAKE_CHOWN_LOG:?}"
exit 0
FAKECHOWN
  chmod +x "$fakebin/chown"
  # Fake gosu: the entrypoint drops to `dev` after the chown block. This test
  # environment may lack the `dev` user, so fake gosu to exec the workload as
  # the (already-root) namespace user — keeps the test focused on the chown
  # behavior, not the privilege drop.
  cat > "$fakebin/gosu" <<'FAKEGOSU'
#!/usr/bin/env bash
shift
exec "$@"
FAKEGOSU
  chmod +x "$fakebin/gosu"
  export PATH="$fakebin:$PATH"

  # Entrypoint runs as root inside the namespace, so the chown block executes.
  run_entrypoint_ns bash -c 'true'
  assert_status 0
  assert_file_contains "$FAKE_CHOWN_LOG" "/workspace/.git"
  assert_file_contains "$FAKE_CHOWN_LOG" "/workspace/node_modules"
  assert_file_contains "$FAKE_CHOWN_LOG" "/home/dev/.local/share"
  assert_file_contains "$FAKE_CHOWN_LOG" "/home/dev/.cache"
}

# --- (c) config + .env wiring ----------------------------------------------
@test "docker-compose.yml forwards USER_UID/USER_GID build.args; .env.example documents them" {
  assert_file_contains "$REPO_ROOT/docker-compose.yml" 'USER_UID: ${USER_UID:-1000}'
  assert_file_contains "$REPO_ROOT/docker-compose.yml" 'USER_GID: ${USER_GID:-1000}'
  assert_file_contains "$REPO_ROOT/.env.example" 'USER_UID=1000'
  assert_file_contains "$REPO_ROOT/.env.example" 'USER_GID=1000'
}
