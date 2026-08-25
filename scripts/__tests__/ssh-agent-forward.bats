#!/usr/bin/env bats
# Unit tests for the FUTURE SSH agent forwarding in
# tools/opencode-docker/bin/opencode-docker (DIA-133). TDD RED phase: the
# wrapper has NO SSH_MOUNT block yet, so every SSH-specific test below FAILS
# against the current wrapper. Task 2.1 (SSH_MOUNT implementation) makes
# tests 01-07 and 09-10 green; task 3.1 (GIT_SSH_COMMAND) makes test 08
# green.
#
# SECURITY REQUIREMENT (proposal.md, verbatim intent): the host SSH key
# material must NEVER leak into the container, into git, or anywhere public.
# These tests are the enforcement: they prove the only SSH-related mount is
# the agent SOCKET (read-only at /tmp/ssh-agent.sock) - never ~/.ssh, never
# id_* / *.pub key files, never .git-credentials.
#
# TEST SEAM (design.md D6/S2): the REAL wrapper is executed with a recording
# fake `podman` on PATH (see mock_podman) and a hermetic HOME /
# OPENCODE_WORKSPACE / XDG_RUNTIME_DIR under $BATS_TEST_TMPDIR, so the real
# host agent socket and home dir can never leak into a test. Fake agent
# sockets are REAL unix sockets bound by a background python3 (socat is not
# installed in this sandbox; python3 -c socket.bind is the fallback per the
# task spec), so the wrapper's `-S` probes behave exactly like on the host.
# All assertions inspect the RECORDED `podman run` command line.
#
# CONTRACT FOR T2 (task 2.1; behavioral, so any implementation producing
# these args satisfies it): in tools/opencode-docker/bin/opencode-docker,
# after the SOCKET_MOUNT block, add an SSH_MOUNT detection block (optionally
# factored into a load_ssh_mount_env function) that:
#   1. probes in order: $SSH_AUTH_SOCK, ${XDG_RUNTIME_DIR:-}/keyring/ssh,
#      ${XDG_RUNTIME_DIR:-}/gcr/ssh (first found wins, decision D3)
#   2. mounts the found socket read-only:  -v <sock>:/tmp/ssh-agent.sock:ro
#      (D4 read-only; D1 target /tmp/ssh-agent.sock because the rootfs is
#      --read-only but /tmp is a writable tmpfs)
#   3. appends to EXTRA_ENV:  -e SSH_AUTH_SOCK=/tmp/ssh-agent.sock
#   4. appends to EXTRA_ENV unconditionally (decision Q3):
#      -e GIT_SSH_COMMAND=ssh -o StrictHostKeyChecking=accept-new
#         -o UserKnownHostsFile=/tmp/known_hosts
#         -o IdentityAgent=/tmp/ssh-agent.sock
#   5. when no socket is found: prints a stderr warning mentioning "git push"
#      and "SSH agent", and CONTINUES (exit 0, warn-and-continue).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
WRAPPER="$REPO_ROOT/tools/opencode-docker/bin/opencode-docker"

FAKE_SOCKET_PIDS=()

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# mock_podman: plants a recording fake `podman` on PATH. `image inspect`
# answers OK (the wrapper's pre-flight gate); every other invocation (the
# `podman run ...` we assert on) is appended to $FAKE_PODMAN_LOG as one
# space-joined line (mirrors the mock_docker pattern in test-helper.bash).
mock_podman() {
  FAKE_PODMAN_LOG="$BATS_TEST_TMPDIR/podman.log"
  export FAKE_PODMAN_LOG
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat > "$bindir/podman" <<'FAKEPODMAN'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_PODMAN_LOG:?FAKE_PODMAN_LOG not set}"
case "${1:-}" in
  image) [ "${2:-}" = "inspect" ] ;;
  *) exit 0 ;;
esac
FAKEPODMAN
  chmod +x "$bindir/podman"
  PATH="$bindir:$PATH"
  export PATH
}

# make_fake_socket <path>: binds a REAL unix socket at <path> with a
# background python3 so the wrapper's `-S` probe succeeds. Polls up to 5s for
# the socket to appear; the process is killed by teardown (the stale socket
# file lives inside $BATS_TEST_TMPDIR, which bats removes). Returns non-zero
# when no socket could be bound (python3 missing or bind failed).
make_fake_socket() {
  local path="$1"
  rm -f "$path"
  mkdir -p "$(dirname "$path")"
  python3 - "$path" <<'PY' &
import socket, sys, time
s = socket.socket(socket.AF_UNIX)
try:
    s.bind(sys.argv[1])
except OSError:
    sys.exit(2)
time.sleep(300)
PY
  local pid=$!
  FAKE_SOCKET_PIDS+=("$pid")
  local i
  for ((i = 0; i < 50; i++)); do
    if [ -S "$path" ]; then return 0; fi
    sleep 0.1
  done
  return 1
}

# require_fake_socket <path>: like make_fake_socket, but skips the test with
# a clear message when the sandbox cannot create unix sockets at all.
require_fake_socket() {
  make_fake_socket "$1" \
    || skip "cannot bind a unix socket in this sandbox (python3); SSH socket tests need real socket files for -S probes"
}

# run_line: the recorded `podman run` invocation (one per test; the first
# log line is the `image inspect` pre-flight call, which never matches).
run_line() {
  grep '^run ' "$FAKE_PODMAN_LOG" | tail -n1
}

# run_mount_sources: SOURCE part of every -v mount in the recorded run line.
run_mount_sources() {
  run_line | grep -o -- '-v [^ ]*' | sed 's/^-v //' | cut -d: -f1
}

# run_mount_targets: TARGET part of every -v mount in the recorded run line.
run_mount_targets() {
  run_line | grep -o -- '-v [^ ]*' | sed 's/^-v //' | cut -d: -f2
}

assert_run_contains() {
  grep -qF -- "$1" <<<"$(run_line)" || {
    echo "assert_run_contains: podman run line missing: $1" >&2
    echo "--- run line ---" >&2
    run_line >&2
    return 1
  }
}

assert_run_not_contains() {
  if grep -qF -- "$1" <<<"$(run_line)"; then
    echo "assert_run_not_contains: podman run line unexpectedly contains: $1" >&2
    echo "--- run line ---" >&2
    run_line >&2
    return 1
  fi
  return 0
}

setup() {
  # Hermetic host context: never touch the real $HOME, never inherit the real
  # agent socket or runtime dir. The host may well have SSH_AUTH_SOCK set (an
  # agent is running) - unset it so every test starts from a clean slate.
  export HOME="$BATS_TEST_TMPDIR/home"
  export OPENCODE_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
  export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/runtime"
  unset SSH_AUTH_SOCK SSH_AGENT_PID
  mkdir -p "$HOME" "$OPENCODE_WORKSPACE" "$XDG_RUNTIME_DIR"
  # Hermetic repo dir: the wrapper copies $OPENCODE_DOCKER_REPO/config into
  # $HOME/.opencode-docker/config on every launch. Point it at an empty
  # fixture so tests never copy the real repo's config — which may carry a
  # developer-installed node_modules (~60MB) — into BATS_TEST_TMPDIR under the
  # /tmp tmpfs (10 tests x ~60MB filled a 512M /tmp to ENOSPC mid-suite), and
  # so assertions stay independent of developer-local config state.
  export OPENCODE_DOCKER_REPO="$BATS_TEST_TMPDIR/repo"
  mock_podman
}

teardown() {
  for pid in "${FAKE_SOCKET_PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  FAKE_SOCKET_PIDS=()
}

# ---------------------------------------------------------------------------
# Tests (10 distinct @test blocks, one per required coverage item)
# ---------------------------------------------------------------------------

@test "ssh-agent-forward: 01 socket detection - SSH_AUTH_SOCK is selected and mounted" {
  export SSH_AUTH_SOCK="$BATS_TEST_TMPDIR/ssh/agent.sock"
  require_fake_socket "$SSH_AUTH_SOCK"

  run bash "$WRAPPER"

  assert_status 0
  assert_run_contains "-v $SSH_AUTH_SOCK:/tmp/ssh-agent.sock:ro"
}

@test "ssh-agent-forward: 02 detection fallback - probes keyring/ssh then gcr/ssh" {
  # XDG_RUNTIME_DIR is already the hermetic runtime dir from setup(); both
  # fallback sockets exist, so the keyring one must win (probe order D3).
  local keyring="$XDG_RUNTIME_DIR/keyring/ssh"
  local gcr="$XDG_RUNTIME_DIR/gcr/ssh"
  require_fake_socket "$keyring"
  require_fake_socket "$gcr"

  run bash "$WRAPPER"

  assert_status 0
  assert_run_contains "-v $keyring:/tmp/ssh-agent.sock:ro"
  assert_run_not_contains "gcr/ssh:/tmp/ssh-agent.sock"
}

@test "ssh-agent-forward: 03 socket mount is read-only (:ro)" {
  export SSH_AUTH_SOCK="$BATS_TEST_TMPDIR/ssh/agent.sock"
  require_fake_socket "$SSH_AUTH_SOCK"

  run bash "$WRAPPER"

  assert_status 0
  # the ssh mount must carry the :ro flag (spec: container MUST NOT be able
  # to write to the host agent socket) and must never be rw
  assert_run_contains "/tmp/ssh-agent.sock:ro"
  assert_run_not_contains "/tmp/ssh-agent.sock:rw"
}

@test "ssh-agent-forward: 04 mount target is /tmp/ssh-agent.sock, not a key file" {
  export SSH_AUTH_SOCK="$BATS_TEST_TMPDIR/ssh/agent.sock"
  require_fake_socket "$SSH_AUTH_SOCK"

  run bash "$WRAPPER"

  assert_status 0
  # D1: the in-container path is /tmp/ssh-agent.sock (rootfs is --read-only,
  # /tmp is the writable tmpfs)
  assert_run_contains "/tmp/ssh-agent.sock"
  local target
  for target in $(run_mount_targets); do
    case "$target" in
      */.ssh*|*.pub)
        echo "forbidden mount target: $target" >&2
        echo "--- run line ---" >&2
        run_line >&2
        return 1
        ;;
    esac
  done
}

@test "ssh-agent-forward: 05 SSH_AUTH_SOCK env var set in the container" {
  export SSH_AUTH_SOCK="$BATS_TEST_TMPDIR/ssh/agent.sock"
  require_fake_socket "$SSH_AUTH_SOCK"

  run bash "$WRAPPER"

  assert_status 0
  assert_run_contains "-e SSH_AUTH_SOCK=/tmp/ssh-agent.sock"
}

@test "ssh-agent-forward: 06 SECURITY - no key material mounted (socket only)" {
  export SSH_AUTH_SOCK="$BATS_TEST_TMPDIR/ssh/agent.sock"
  require_fake_socket "$SSH_AUTH_SOCK"

  run bash "$WRAPPER"

  assert_status 0
  # positive control: the agent socket IS forwarded (the ONLY SSH-related
  # mount allowed); without it this test would pass vacuously.
  assert_run_contains "-v $SSH_AUTH_SOCK:/tmp/ssh-agent.sock:ro"
  # STRUCTURAL security assertion (DIA-133 review fix): a static key-name
  # blacklist (id_rsa, *.pub, .git-credentials, ...) is evadable - a mount
  # source like `hidden-keys/` or `*-secret-key` slips through. Instead
  # assert SET-EQUALITY of mount SOURCES: the wrapper's pre-existing mounts
  # (opencode-docker home dirs, config, secrets, workspace, plus the
  # environment-dependent .gitconfig / ponytail / container-socket mounts
  # when present) plus EXACTLY ONE addition - the SSH agent socket. Any
  # source outside that set is key material leaking in.
  local ocd="$HOME/.opencode-docker"
  # the container-socket mount source is environment-dependent (one of the
  # three probe paths in the wrapper wins); derive it from the run line
  # instead of guessing which one this host has
  local docker_src
  docker_src="$(run_line | grep -o -- '-v [^ ]*:/var/run/docker.sock' | sed 's/^-v //; s/:.*//' || true)"
  local src
  for src in $(run_mount_sources); do
    case "$src" in
      "$SSH_AUTH_SOCK" | \
      "$ocd/.local/share" | "$ocd/.local/state" | "$ocd/config" | \
      "$ocd/.cache" | "$ocd/secrets" | "$ocd/.gitconfig" | \
      "$HOME/ponytail" | "$OPENCODE_WORKSPACE" | "$docker_src")
        ;;
      *)
        echo "SECURITY: mount source outside the pre-existing set + SSH socket: $src" >&2
        echo "--- run line ---" >&2
        run_line >&2
        return 1
        ;;
    esac
  done
}

@test "ssh-agent-forward: 07 no socket found - stderr warning and continue (exit 0)" {
  # no SSH_AUTH_SOCK, no keyring/gcr socket under the hermetic runtime dir
  run bash "$WRAPPER"

  assert_status 0
  # spec: the warning MUST mention that git push will not work and suggest
  # checking that the host SSH agent is running and unlocked
  assert_output_contains "git push"
  assert_output_contains "SSH agent"
}

@test "ssh-agent-forward: 08 GIT_SSH_COMMAND set unconditionally (accept-new + UserKnownHostsFile + IdentityAgent pin)" {
  # decision Q3: set regardless of agent presence - run WITHOUT any socket.
  # The value MUST start with the ssh command word (git spawns GIT_SSH_COMMAND
  # verbatim through /bin/sh; a bare "-o ..." fails with "Illegal option -o",
  # DIA-153), point UserKnownHostsFile at the writable /tmp tmpfs so the
  # read-only rootfs cannot produce a known_hosts write warning (DIA-153
  # follow-up), and pin IdentityAgent to the container-side socket so ssh
  # finds the forwarded agent even if SSH_AUTH_SOCK is lost in a child env.
  run bash "$WRAPPER"

  assert_status 0
  assert_run_contains "-e GIT_SSH_COMMAND=ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/tmp/known_hosts -o IdentityAgent=/tmp/ssh-agent.sock"
}

@test "ssh-agent-forward: 09 detection order deterministic - first found wins" {
  # all three candidates exist; SSH_AUTH_SOCK is probed first (D3) and must
  # win over both fallbacks
  export SSH_AUTH_SOCK="$BATS_TEST_TMPDIR/ssh/agent.sock"
  require_fake_socket "$SSH_AUTH_SOCK"
  require_fake_socket "$XDG_RUNTIME_DIR/keyring/ssh"
  require_fake_socket "$XDG_RUNTIME_DIR/gcr/ssh"

  run bash "$WRAPPER"

  assert_status 0
  assert_run_contains "-v $SSH_AUTH_SOCK:/tmp/ssh-agent.sock:ro"
  assert_run_not_contains "keyring/ssh:/tmp/ssh-agent.sock"
  assert_run_not_contains "gcr/ssh:/tmp/ssh-agent.sock"
}

@test "ssh-agent-forward: 10 no regression - docker socket SOCKET_MOUNT intact" {
  # the existing docker-socket loop (DIA-121) must keep working unchanged:
  # the SSH_MOUNT addition must not touch it
  local docker_sock="$XDG_RUNTIME_DIR/podman/podman.sock"
  require_fake_socket "$docker_sock"

  run bash "$WRAPPER"

  assert_status 0
  assert_run_contains "-v $docker_sock:/var/run/docker.sock:ro"
  assert_run_contains "-e DOCKER_HOST=unix:///var/run/docker.sock"
}
