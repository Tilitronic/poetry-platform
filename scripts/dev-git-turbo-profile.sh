#!/usr/bin/env bash
# Dev-container login-shell hook. Sourced by every `docker compose exec ... bash -lc`
# (the husky pre-push gate). The bind-mounted /workspace is owned by the host
# user, which may not match the container user, so git refuses to run there
# ("dubious ownership") and tools that write into the mount (turbo's .turbo
# cache) get EACCES. Instead of chasing UID parity, make the gate independent
# of the mount: trust the workspace for git, move turbo's cache to /tmp.

# (1) Let git operate on the host-owned workspace mount (idempotent).
if ! git config --global --get-all safe.directory 2>/dev/null | grep -qx '/workspace'; then
  git config --global --add safe.directory /workspace 2>/dev/null || true
fi

# (2) Relocate turbo's local cache off the bind-mount to a container-writable dir.
export TURBO_CACHE_DIR="${TURBO_CACHE_DIR:-/tmp/turbo-cache}"
mkdir -p "${TURBO_CACHE_DIR}" 2>/dev/null || true
