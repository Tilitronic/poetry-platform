#!/usr/bin/env bash
# compose-env.sh — compute the merged COMPOSE_FILE for the engine-aware dev
# stack (DIA-260826-766f). Single source of truth shared by the Makefile
# (export COMPOSE_FILE := $(shell scripts/compose-env.sh)) and
# scripts/opencode-dev (delegates its detected engine/OS to this helper).
#
# DOCKER-FREE AT COMPUTE TIME (design.md D2): this script MUST NEVER invoke the
# `docker` or `podman` executables. Engine detection uses only `command -v` +
# `readlink -f` (a path probe — a Podman shim's resolved path contains
# "podman"); OS detection uses only `grep` on /proc/version. This keeps `make`
# parse-time and `make test-shell` free of any daemon dependency. The recording
# fakes in scripts/__tests__/compose-env.bats assert no docker/podman execution.
set -euo pipefail

# --- Engine detection (docker-free) -----------------------------------------
# COMPOSE_ENGINE override wins (podman|docker). Otherwise probe the docker
# client path without starting a daemon: `command -v docker` locates the
# client, `readlink -f` resolves symlinks; a Podman shim resolves to a path
# containing "podman". No docker client at all -> default "docker" (a harmless
# string; a real error only surfaces on `docker compose up`).
engine="${COMPOSE_ENGINE:-}"
# Trust-boundary validation (DIA-260912-y2uo): an explicit override other than
# docker|podman is rejected before any mapping, so a typo can never silently
# resolve to the docker stack. Mirrors container_engine_select in
# scripts/container-engine.sh; keep the accepted values in sync.
case "$engine" in
  ""|docker|podman) ;;
  *)
    printf '%s\n' \
      "compose-env: error: unsupported COMPOSE_ENGINE='$engine' (expected 'docker' or 'podman')" >&2
    exit 1
    ;;
esac
if [ -z "$engine" ]; then
  if command -v docker >/dev/null 2>&1; then
    docker_path="$(readlink -f "$(command -v docker)" 2>/dev/null || true)"
    case "$docker_path" in
      *podman*) engine="podman" ;;
      *)
        engine="docker"
        # Ambiguous autodetection: a docker CLI that is NOT a podman shim was
        # found, but COMPOSE_ENGINE is unset. We default to docker (docker-free,
        # readlink-only probe cannot see a podman-backed docker API). Warn so a
        # Fedora/Podman host operator knows to set COMPOSE_ENGINE=podman.
        printf '%s\n' \
          "compose-env: WARNING: docker CLI detected is not a podman shim; defaulting to docker engine. Set COMPOSE_ENGINE=podman explicitly if this host uses Podman (e.g. Fedora)." >&2
        ;;
    esac
  else
    engine="docker"
  fi
fi

# --- OS detection (docker-free) ----------------------------------------------
# COMPOSE_OS override wins (wsl|native). Otherwise probe /proc/version for
# Microsoft/WSL markers.
wsl=0
if [ -n "${COMPOSE_OS:-}" ]; then
  case "${COMPOSE_OS}" in
    wsl) wsl=1 ;;
    *)   wsl=0 ;;
  esac
else
  if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    wsl=1
  fi
fi

# --- Override mapping (replicated from scripts/opencode-dev lines 45-60) -----
case "$engine" in
  podman) engine_file="docker-compose.podman.yml" ;;
  docker) engine_file="docker-compose.rootless-docker.yml" ;;
  *)
    printf '%s\n' \
      "compose-env: error: internal: unexpected engine '$engine' (expected 'docker' or 'podman')" >&2
    exit 1
    ;;
esac

# --- Assemble merged COMPOSE_FILE (colon-separated, no trailing colon) -------
compose_list="docker-compose.yml:${engine_file}"
if [ "$wsl" = "1" ]; then
  compose_list="${compose_list}:docker-compose.wsl.yml"
fi

printf '%s\n' "$compose_list"
