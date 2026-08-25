#!/usr/bin/env bash
# Shared helpers for bats unit tests under scripts/__tests__.
#
# Why these tests exist: dev-infra artifacts (scripts/dev-stack.sh,
# dev-entrypoint.sh) used to have zero test coverage. These are UNIT tests —
# Docker is never started, `docker` is replaced by a recording fake on PATH.
#
# Isolation strategy:
#   - dev-stack.sh is copied into $BATS_TEST_TMPDIR (with .env.example) and
#     invoked from there, so the real repo .env is never touched.
#   - dev-entrypoint.sh lives at the repo root and hardcodes /run/secrets and
#     /tmp/.X11-unix/X99. Without root we cannot create /run/secrets, so the
#     script runs inside `unshare -r -m` with tmpfs mounted over /run and /tmp
#     — the namespace's fresh /run/secrets and Xvfb lock are fully controllable.
#     Tests skip with a clear message when unprivileged user namespaces are
#     blocked (hardened hosts).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"

# ---------------------------------------------------------------------------
# Minimal assertion helpers (kept local; no bats-assert dependency)
# ---------------------------------------------------------------------------

assert_status() {
  [ "$status" -eq "$1" ] || {
    echo "assert_status: expected $1, got $status" >&2
    echo "--- output ---" >&2
    echo "$output" >&2
    return 1
  }
}

assert_output_contains() {
  [[ "$output" == *"$1"* ]] || {
    echo "assert_output_contains: missing substring: $1" >&2
    echo "--- output ---" >&2
    echo "$output" >&2
    return 1
  }
}

assert_output_not_contains() {
  [[ "$output" != *"$1"* ]] || {
    echo "assert_output_not_contains: unexpected substring: $1" >&2
    echo "--- output ---" >&2
    echo "$output" >&2
    return 1
  }
}

assert_file_exists() {
  [ -e "$1" ] || { echo "assert_file_exists: missing file: $1" >&2; return 1; }
}

assert_file_not_exists() {
  [ ! -e "$1" ] || { echo "assert_file_not_exists: unexpected file: $1" >&2; return 1; }
}

assert_file_contains() {
  grep -qF -- "$2" "$1" || {
    echo "assert_file_contains: $1 missing substring: $2" >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# Fake docker CLI (dev-stack.sh tests)
# ---------------------------------------------------------------------------

# mock_docker: installs a fake `docker` on PATH that records every invocation
# to $FAKE_DOCKER_LOG and answers canned results from env:
#   FAKE_DOCKER_DAEMON_UP       yes|no   (docker info exit code)
#   FAKE_DOCKER_TURBO_INSTALLED yes|no   (node_modules/.bin/turbo exists?)
#   FAKE_DOCKER_SERVICES        string  (verify-pre-push: `compose ps` output)
#   FAKE_DOCKER_FAIL_STEP       string  (verify-pre-push: substring whose
#                                        `compose exec` invocation exits 1)
mock_docker() {
  FAKE_DOCKER_LOG="${FAKE_DOCKER_LOG:-$BATS_TEST_TMPDIR/docker.log}"
  export FAKE_DOCKER_LOG
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
# Fake docker CLI for unit tests. Records every call; canned answers only.
printf '%s\n' "$*" >> "${FAKE_DOCKER_LOG:?FAKE_DOCKER_LOG not set}"

case "${1:-}" in
  info)
    [ "${FAKE_DOCKER_DAEMON_UP:-yes}" = "yes" ] && exit 0 || exit 1
    ;;
  compose)
    shift
    # consume global compose flags (-f <file>)
    if [ "${1:-}" = "-f" ]; then shift 2; fi
    case "${1:-}" in
      exec)
        shift
        # consume flags (-T/-it/--/--user <user>) until the container name
        while [ $# -gt 0 ]; do
          case "$1" in
            --user) shift 2 ;;
            -T|-it|--|--) shift ;;
            *) break ;;
          esac
        done
        shift # container name
        if [ -n "${FAKE_DOCKER_FAIL_STEP:-}" ] && [[ "$*" == *"$FAKE_DOCKER_FAIL_STEP"* ]]; then
          exit 1
        fi
        case "$*" in
          "test -x node_modules/.bin/turbo")
            [ "${FAKE_DOCKER_TURBO_INSTALLED:-yes}" = "yes" ] && exit 0 || exit 1
            ;;
        esac
        exit 0
        ;;
      ps)
        printf '%s\n' "${FAKE_DOCKER_SERVICES:-}"
        exit 0
        ;;
    esac
    exit 0
    ;;
esac
exit 0
FAKEDOCKER
  chmod +x "$bindir/docker"
  PATH="$bindir:$PATH"
  export PATH
}

# mock_docker_down: plants a fake `docker` on PATH whose every probe FAILS
# (exit 1, no output) — the "dev container DOWN" path, so host fallbacks run.
# Per design.md Decision 7 any probe failure means "dev container
# unavailable". Prepends the shim dir to PATH and echoes it; callers that
# build an explicit hermetic PATH (env PATH=...) can use the echoed dir and
# ignore the prepend. Consolidated from check-host-lsp.bats + eval-lite.bats
# (DIA-125).
mock_docker_down() {
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
# Fake docker: container DOWN -> every probe fails.
exit 1
FAKEDOCKER
  chmod +x "$bindir/docker"
  PATH="$bindir:$PATH"
  export PATH
  echo "$bindir"
}

# setup_hermetic_host_context: fake hostname on PATH + isolated
# POETRY_COMMANDS_DIR, so tests exercise the HOST + container-running
# delegation path regardless of where the suite runs (DIA-071, 2026-08-12).
# When the suite runs INSIDE poetry-dev the real hostname IS poetry-dev, so
# is_in_dev_container would flip to the direct-execution path and recurse
# into the real gate chain (unbounded hang). A fake hostname keeps every
# non-direct test in the delegation path; the dedicated "runs steps
# directly" tests shadow it with their own poetry-dev fake. The isolated
# POETRY_COMMANDS_DIR (mirror of the POETRY_WORKSPACE override) keeps the
# /home/qualt guard hermetic regardless of the real repo's
# .opencode/commands state.
setup_hermetic_host_context() {
  local hostbindir="$BATS_TEST_TMPDIR/hostbin"
  mkdir -p "$hostbindir"
  printf '#!/usr/bin/env bash\necho "host-machine"\n' > "$hostbindir/hostname"
  chmod +x "$hostbindir/hostname"
  export PATH="$hostbindir:$PATH"
  export POETRY_COMMANDS_DIR="$BATS_TEST_TMPDIR/commands"
  mkdir -p "$POETRY_COMMANDS_DIR"
}

# setup_dev_stack_tree: copies scripts/dev-stack.sh + .env.example into an
# isolated temp tree so the script never touches the real repo .env.
# Echoes the tree root.
setup_dev_stack_tree() {
  local tree="$BATS_TEST_TMPDIR/stack"
  mkdir -p "$tree/scripts"
  cp "$SCRIPTS_DIR/dev-stack.sh" "$tree/scripts/dev-stack.sh"
  cp "$REPO_ROOT/.env.example" "$tree/.env.example"
  echo "$tree"
}

# ---------------------------------------------------------------------------
# check-tools.sh / check-pin-sync.sh fixtures (FAKE-mock seam)
# ---------------------------------------------------------------------------

# install_check_tools_fakes <dir>: plants fake mise/node/pnpm in <dir> and
# prepends it to PATH. Behavior is driven by env (set per test):
#   FAKE_MISE_WHICH_FAIL=1          mise which exits 1 (shim not active)
#   FAKE_MISE_CURRENT_MISMATCH=1    mise current reports a wrong version
#   FAKE_NODE_MISMATCH=1            node --version reports a wrong version
#   FAKE_PNPM_MISMATCH=1            pnpm --version reports a wrong version
install_check_tools_fakes() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/mise" <<'FAKEMISE'
#!/usr/bin/env bash
case "${1:-}" in
  trust) exit 0 ;;
  install) exit 0 ;;
  which)
    [ "${FAKE_MISE_WHICH_FAIL:-}" = "1" ] && exit 1
    printf '%s\n' "/fake/installs/${2}/current/bin/${2}"
    exit 0
    ;;
  current)
    if [ "${FAKE_MISE_CURRENT_MISMATCH:-}" = "1" ]; then
      printf '%s\n' "99.0.0"
      exit 0
    fi
    case "${2:-}" in
      node) printf '%s\n' "24.18.0" ;;
      pnpm) printf '%s\n' "10.33.0" ;;
      *) exit 1 ;;
    esac
    ;;
  *) exit 1 ;;
esac
FAKEMISE
  cat > "$dir/node" <<'FAKENODE'
#!/usr/bin/env bash
[ "${FAKE_NODE_MISMATCH:-}" = "1" ] && { printf '%s\n' "v99.0.0"; exit 0; }
printf '%s\n' "v24.18.0"
FAKENODE
  cat > "$dir/pnpm" <<'FAKEPNPM'
#!/usr/bin/env bash
[ "${FAKE_PNPM_MISMATCH:-}" = "1" ] && { printf '%s\n' "99.0.0"; exit 0; }
printf '%s\n' "10.33.0"
FAKEPNPM
  chmod +x "$dir/mise" "$dir/node" "$dir/pnpm"
  PATH="$dir:$PATH"
  export PATH
}

# setup_check_tools_tree <with_mise_toml 0|1>: copies check-tools.sh into an
# isolated tree and (optionally) seeds it with a .mise.toml copy. Echoes root.
setup_check_tools_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/check-tools.sh" "$tree/scripts/check-tools.sh"
  if [ "${1:-1}" = "1" ]; then
    cp "$REPO_ROOT/.mise.toml" "$tree/.mise.toml"
  fi
  echo "$tree"
}

# setup_pin_sync_tree <with_mise_toml 0|1> <with_dockerfile_dev 0|1>
#   <with_dockerfile_oc 0|1> <mise_node_pin> <mise_pnpm_pin>
#   <docker_dev_node_pin> <docker_dev_pnpm_pin> <docker_oc_node_pin>
#   <docker_oc_pnpm_pin> [variant]
# Copies check-pin-sync.sh into an isolated tree and plants controlled
# .mise.toml / Dockerfile.dev / tools/opencode-docker/Dockerfile fixtures.
# The optional variant selects fixture formatting (applies per source):
#   default       — node = "<pin>", pnpm = "<pin>", ARG NODE_VERSION=<pin>
#   quotes        — mixed single/double/unquoted spellings
#   crlf          — CRLF line endings in all fixture files
#   whitespace    — extra spaces around '=' and inside values
#   dup-mise      — duplicate node key under [tools] (INFRA fixture)
#   dup-docker    — duplicate ARG NODE_VERSION in Dockerfile.dev (INFRA fixture)
#   dup-docker-oc — duplicate ARG NODE_VERSION in tools/opencode-docker/Dockerfile
# Echoes the tree root.
setup_pin_sync_tree() {
  local with_mise="${1:-1}" with_docker_dev="${2:-1}" with_docker_oc="${3:-1}"
  local mise_node="${4:-24.18.0}" mise_pnpm="${5:-10.33.0}"
  local docker_dev_node="${6:-24.18.0}" docker_dev_pnpm="${7:-10.33.0}"
  local docker_oc_node="${8:-24.18.0}" docker_oc_pnpm="${9:-10.33.0}"
  local variant="${10:-}"
  local tree="$BATS_TEST_TMPDIR/pin-sync"
  mkdir -p "$tree/scripts" "$tree/tools/opencode-docker"
  cp "$REPO_ROOT/scripts/check-pin-sync.sh" "$tree/scripts/check-pin-sync.sh"
  if [ "$with_mise" = "1" ]; then
    case "$variant" in
      dup-mise)
        cat > "$tree/.mise.toml" <<EOF
[tools]
node = "$mise_node"
node = "$mise_node"
pnpm = "$mise_pnpm"
EOF
        ;;
      quotes)
        cat > "$tree/.mise.toml" <<EOF
[tools]
node="$mise_node"
pnpm='$mise_pnpm'
EOF
        ;;
      whitespace)
        printf '[tools]\nnode   =   "%s"\npnpm = "%s"\n' "$mise_node" "$mise_pnpm" > "$tree/.mise.toml"
        ;;
      crlf)
        printf '[tools]\r\nnode = "%s"\r\npnpm = "%s"\r\n' "$mise_node" "$mise_pnpm" > "$tree/.mise.toml"
        ;;
      *)
        cat > "$tree/.mise.toml" <<EOF
[tools]
node = "$mise_node"
pnpm = "$mise_pnpm"
EOF
        ;;
    esac
  fi
  if [ "$with_docker_dev" = "1" ]; then
    case "$variant" in
      dup-docker)
        cat > "$tree/Dockerfile.dev" <<EOF
ARG NODE_VERSION=$docker_dev_node
ARG NODE_VERSION=$docker_dev_node
ARG PNPM_VERSION=$docker_dev_pnpm
EOF
        ;;
      quotes)
        cat > "$tree/Dockerfile.dev" <<EOF
ARG NODE_VERSION=$docker_dev_node
ARG PNPM_VERSION="$docker_dev_pnpm"
EOF
        ;;
      whitespace)
        printf '  ARG NODE_VERSION=%s\nARG PNPM_VERSION=%s   \n' "$docker_dev_node" "$docker_dev_pnpm" > "$tree/Dockerfile.dev"
        ;;
      crlf)
        printf 'ARG NODE_VERSION=%s\r\nARG PNPM_VERSION=%s\r\n' "$docker_dev_node" "$docker_dev_pnpm" > "$tree/Dockerfile.dev"
        ;;
      *)
        cat > "$tree/Dockerfile.dev" <<EOF
ARG NODE_VERSION=$docker_dev_node
ARG PNPM_VERSION=$docker_dev_pnpm
EOF
        ;;
    esac
  fi
  if [ "$with_docker_oc" = "1" ]; then
    case "$variant" in
      dup-docker-oc)
        cat > "$tree/tools/opencode-docker/Dockerfile" <<EOF
ARG NODE_VERSION=$docker_oc_node
ARG NODE_VERSION=$docker_oc_node
ARG PNPM_VERSION=$docker_oc_pnpm
EOF
        ;;
      quotes)
        cat > "$tree/tools/opencode-docker/Dockerfile" <<EOF
ARG NODE_VERSION=$docker_oc_node
ARG PNPM_VERSION="$docker_oc_pnpm"
EOF
        ;;
      whitespace)
        printf '  ARG NODE_VERSION=%s\nARG PNPM_VERSION=%s   \n' "$docker_oc_node" "$docker_oc_pnpm" > "$tree/tools/opencode-docker/Dockerfile"
        ;;
      crlf)
        printf 'ARG NODE_VERSION=%s\r\nARG PNPM_VERSION=%s\r\n' "$docker_oc_node" "$docker_oc_pnpm" > "$tree/tools/opencode-docker/Dockerfile"
        ;;
      *)
        cat > "$tree/tools/opencode-docker/Dockerfile" <<EOF
ARG NODE_VERSION=$docker_oc_node
ARG PNPM_VERSION=$docker_oc_pnpm
EOF
        ;;
    esac
  fi
  echo "$tree"
}

# ---------------------------------------------------------------------------
# dev-entrypoint.sh tests (user-namespace isolation)
# ---------------------------------------------------------------------------

require_unshare() {
  if ! command -v unshare >/dev/null 2>&1; then
    skip "unshare unavailable; cannot isolate /run/secrets"
  fi
  if ! unshare -r -m true 2>/dev/null; then
    skip "unprivileged user namespaces blocked; cannot isolate /run/secrets"
  fi
}

# _build_ns_script <file> <with_xvfb 0|1>: writes the namespace bootstrap
# script to <file>. Shared by run_entrypoint_ns / run_entrypoint_xvfb_ns (they
# differ only in whether tmpfs is also mounted over /tmp and a fake Xvfb is
# planted — the xvfb=1 branch is used when the lock file must be creatable).
_build_ns_script() {
  local file="$1"
  local with_xvfb="${2:-0}"
  if [ "$with_xvfb" = "1" ]; then
    cat > "$file" <<'NS'
#!/usr/bin/env bash
set -euo pipefail
mount -t tmpfs tmpfs /run
mount -t tmpfs tmpfs /tmp
mkdir -p /run/secrets /tmp/fakebin
cat > /tmp/fakebin/Xvfb <<'FAKEXVFB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> /tmp/fake-xvfb.log
FAKEXVFB
chmod +x /tmp/fakebin/Xvfb
if [ -n "${NS_XVFB_LOCK:-}" ]; then
  mkdir -p /tmp/.X11-unix
  : > /tmp/.X11-unix/X99
fi
export PATH="/tmp/fakebin:$PATH"
exec "$@"
NS
  else
    cat > "$file" <<'NS'
#!/usr/bin/env bash
set -euo pipefail
mount -t tmpfs tmpfs /run
if [ -z "${NS_NO_SECRETS:-}" ]; then
  mkdir -p /run/secrets
  if [ -n "${NS_SECRETS_DIR:-}" ] && [ -d "$NS_SECRETS_DIR" ]; then
    cp -a "$NS_SECRETS_DIR/." /run/secrets/
  fi
fi
exec "$@"
NS
  fi
  chmod +x "$file"
}

# install_fake_priv_drop: plants fake gosu/runuser/su on PATH that exec the
# command as the CURRENT (mapped-root) user. Inside `unshare -r` the namespace
# root has no `dev` passwd entry, so the entrypoint's real privilege-drop
# (runuser -u dev) fails with "user dev does not exist". The container's real
# drop is untouched — this shim only makes the unit tests runnable. Echoes the
# shim dir so callers can prepend it to PATH.
install_fake_priv_drop() {
  # Install into /var/tmp, NOT $BATS_TEST_TMPDIR (which lives under /tmp): the
  # xvfb namespace test mounts a fresh tmpfs over /tmp, hiding anything under it
  # — including a shim placed there — so the entrypoint's privilege-drop lookup
  # would miss it and fall through to the real `su` (which fails with "user dev
  # does not exist"). /var/tmp is never shadowed by the test namespaces.
  # Fallback stays OUTSIDE /tmp for the same reason (DIA-260825-nts7 F3): a
  # $BATS_TEST_TMPDIR fallback would silently hide the shims exactly when the
  # xvfb variant runs; a fixed /var/tmp dir fails loud instead.
  local dir
  dir="$(mktemp -d /var/tmp/poetry-nsbin.XXXXXX 2>/dev/null)" || dir="/var/tmp/poetry-nsbin.$$"
  mkdir -p "$dir"
  cat > "$dir/runuser" <<'RU'
#!/usr/bin/env bash
# test shim: exec command as current user (no real privilege drop)
while [ $# -gt 0 ]; do
  case "$1" in
    -u|--user) shift 2 ;;
    --) shift; break ;;
    -*) shift ;;
    *) break ;;
  esac
done
exec "$@"
RU
  cat > "$dir/gosu" <<'GO'
#!/usr/bin/env bash
# test shim: drop the user arg, exec command as current user
shift
exec "$@"
GO
  cat > "$dir/su" <<'SU'
#!/usr/bin/env bash
# test shim: exec the -c command as current user
while [ $# -gt 0 ]; do
  if [ "$1" = "-c" ]; then shift; exec bash -c "$1"; fi
  shift
done
SU
  chmod +x "$dir/runuser" "$dir/gosu" "$dir/su"
  # Hermetic Xvfb: the entrypoint's Xvfb block runs BEFORE the privilege drop,
  # so with a real Xvfb on PATH every ns test launched it against the HOST
  # /tmp — zombie Xvfb processes, ~20MB Mesa .so caches per spawn, and an
  # rm -f against the host's /tmp/.X11-unix/X99. The no-op shim keeps the
  # "Xvfb installed" branch exercised without host side effects. Planted ONLY
  # when the host has a real Xvfb: on Xvfb-less hosts planting one would break
  # the "does not start Xvfb when Xvfb is not installed" test.
  if command -v Xvfb >/dev/null 2>&1; then
    cat > "$dir/Xvfb" <<'XV'
#!/usr/bin/env bash
# test shim: no-op Xvfb (entrypoint backgrounds it; exit immediately)
exit 0
XV
    chmod +x "$dir/Xvfb"
  fi
  echo "$dir"
}

# run_entrypoint_ns: run dev-entrypoint.sh inside `unshare -r -m` with tmpfs
# mounted over /run only (host /tmp stays visible, so fixture dirs and PATH
# shims that live under BATS_TEST_TMPDIR resolve). Fixtures via env (set by
# caller):
#   NS_SECRETS_DIR   directory copied into /run/secrets (default: none)
#   NS_NO_SECRETS    non-empty => /run/secrets is not created at all
run_entrypoint_ns() {
  require_unshare
  unset DISPLAY # hermetic: entrypoint sets it only when it starts Xvfb
  local ns="$BATS_TEST_TMPDIR/ns.sh"
  _build_ns_script "$ns" 0
  local nsbin
  nsbin="$(install_fake_priv_drop)"
  PATH="$nsbin:$PATH" run unshare -r -m bash "$ns" bash "$REPO_ROOT/dev-entrypoint.sh" "$@"
  # teardown (DIA-260825-nts7 F3): the shim dir is per-call; remove it as soon
  # as the run captured, so repeated suite runs cannot accumulate dirs in
  # /var/tmp. Only a SIGKILL mid-test can leak one — acceptable ceiling.
  rm -rf "$nsbin"
}

# run_entrypoint_xvfb_ns: Xvfb-branch variant — ALSO mounts tmpfs over /tmp
# (the host /tmp/.X11-unix is a read-only mount here, so the lock file cannot
# be created from outside) and plants a recording fake Xvfb INSIDE the
# namespace. The fake logs its invocation to /tmp/fake-xvfb.log; tests read it
# back by cat-ing it from the exec'd command's stdout. Lock controlled via
# NS_XVFB_LOCK (non-empty => /tmp/.X11-unix/X99 pre-created).
run_entrypoint_xvfb_ns() {
  require_unshare
  unset DISPLAY
  local ns="$BATS_TEST_TMPDIR/ns-xvfb.sh"
  _build_ns_script "$ns" 1
  local nsbin
  nsbin="$(install_fake_priv_drop)"
  PATH="$nsbin:$PATH" run unshare -r -m bash "$ns" bash "$REPO_ROOT/dev-entrypoint.sh" "$@"
  # teardown: same per-call cleanup as run_entrypoint_ns (DIA-260825-nts7 F3)
  rm -rf "$nsbin"
}
