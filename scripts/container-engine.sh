#!/usr/bin/env bash
# container-engine.sh — one host-side container-engine contract (DIA-260912-y2uo).
#
# Selects the host container engine and invokes its NATIVE compose command:
#   docker engine -> `docker compose`
#   podman engine -> `podman compose`
# Every host-side compose config, up, down, exec, reachability, and dev-status
# operation routes through this contract. Commands already executing INSIDE the
# dev container keep their existing behavior (they never touch this adapter).
#
# Selection (docker-free, no daemon call):
#   COMPOSE_ENGINE=docker|podman is authoritative. When unset, autodetect with
#   the same readlink-only probe as scripts/compose-env.sh (`command -v docker`
#   + `readlink -f`; a Podman shim resolves to a path containing "podman").
#   An unsupported explicit value fails with an actionable error BEFORE any
#   engine is invoked. There is NO cross-engine fallback: a selected engine
#   stays selected through a failed check, so a failure can never silently
#   operate on a different stack.
#
# Usage as a CLI:
#   container-engine.sh select                 print docker|podman (or fail)
#   container-engine.sh compose-bin            print the engine binary name
#   container-engine.sh compose <args...>      run <engine> compose <args...>
#   container-engine.sh reachable              <engine> info probe (quiet)
#   container-engine.sh dev-running            selected stack reports dev running
#   container-engine.sh dev-exec               <engine> compose exec -T dev true
#   container-engine.sh gate                   3-stage DIA-094 readiness gate
#
# Usage sourced from another host script:
#   source "$(dirname "$0")/container-engine.sh"
#   engine="$(container_engine_select)" || exit 1
#   container_engine_compose up -d --build
#
# Bash-3 compatible (ADR 8): no associative arrays, no mapfile, no [[ =~ ]].
# ASCII only (DIA-079).
set -euo pipefail

# container_engine_select: print the selected engine (docker|podman) to stdout.
# Validates an explicit COMPOSE_ENGINE at the trust boundary; autodetects only
# when the override is unset. Makes NO daemon call (command -v + readlink only)
# so compose-file computation and Make parse-time stay engine-daemon-free.
# On an unsupported explicit value: stderr diagnostic naming the accepted
# values, stdout empty (no engine reported), exit nonzero.
container_engine_select() {
  local engine="${COMPOSE_ENGINE:-}"
  if [ -n "$engine" ]; then
    case "$engine" in
      docker|podman)
        printf '%s\n' "$engine"
        return 0
        ;;
      *)
        printf '%s\n' \
          "container-engine: error: unsupported COMPOSE_ENGINE='$engine' (expected 'docker' or 'podman')" >&2
        return 1
        ;;
    esac
  fi
  if command -v docker >/dev/null 2>&1; then
    local docker_path
    docker_path="$(readlink -f "$(command -v docker)" 2>/dev/null || true)"
    case "$docker_path" in
      *podman*)
        printf '%s\n' "podman"
        return 0
        ;;
    esac
  fi
  printf '%s\n' "docker"
  return 0
}

# container_engine_compose_bin: print the native binary for the selected engine.
container_engine_compose_bin() {
  container_engine_select
}

# container_engine_compose: run the selected native compose command.
# Extra args pass through verbatim (including -f flags), so migrated callers
# keep their exact compose invocation with only the engine binary resolved.
container_engine_compose() {
  local engine
  engine="$(container_engine_select)" || return 1
  "$engine" compose "$@"
}

# container_engine_reachable: selected-engine reachability probe.
# `<engine> info` exits nonzero when no socket/daemon is reachable and succeeds
# when one exists even if no services run — the same signal the DIA-094 gate
# previously read from `docker info`, now engine-neutral.
container_engine_reachable() {
  local engine
  engine="$(container_engine_select)" || return 1
  "$engine" info >/dev/null 2>&1
}

# container_engine_dev_running: selected-stack dev-service status check.
# Succeeds only when the selected stack reports the dev service running.
# Status alone is NOT readiness proof (see container_engine_gate); it is one
# stage of the three-stage gate.
container_engine_dev_running() {
  local engine
  engine="$(container_engine_select)" || return 1
  "$engine" compose ps --services --status running 2>/dev/null | grep -qx "dev"
}

# container_engine_dev_exec: non-mutating exec proof through the selected engine.
container_engine_dev_exec() {
  local engine
  engine="$(container_engine_select)" || return 1
  "$engine" compose exec -T dev true
}

# container_engine_gate: strict DIA-094 executable dev-service gate.
# Succeeds ONLY when (1) the selected engine is reachable, (2) the selected
# stack reports dev running, and (3) `compose exec -T dev true` succeeds
# through the selected native command. Each stage fails closed with a DISTINCT
# diagnostic (engine-reachability / dev-service-status / dev-service-exec) and
# never falls back to the other engine. The selected engine is echoed into
# every diagnostic so the operator knows which stack was evaluated.
container_engine_gate() {
  local engine
  if ! engine="$(container_engine_select)"; then
    return 1
  fi
  if ! "$engine" info >/dev/null 2>&1; then
    printf '%s\n' \
      "container-engine: engine-reachability failure: selected engine '$engine' is not reachable ('$engine info' failed). Start the engine, then retry. [COMPOSE_ENGINE=$engine selected; no fallback attempted.]" >&2
    return 1
  fi
  if ! "$engine" compose ps --services --status running 2>/dev/null | grep -qx "dev"; then
    printf '%s\n' \
      "container-engine: dev-service-status failure: dev container not running in the selected '$engine' stack. Start it with '$engine compose up -d', then retry. [COMPOSE_ENGINE=$engine selected; no fallback attempted.]" >&2
    return 1
  fi
  if ! "$engine" compose exec -T dev true >/dev/null 2>&1; then
    printf '%s\n' \
      "container-engine: dev-service-exec failure: dev container is running but '$engine compose exec -T dev true' failed. The service cannot execute commands; inspect it with '$engine compose logs dev'. [COMPOSE_ENGINE=$engine selected; no fallback attempted.]" >&2
    return 1
  fi
  printf '%s\n' \
    "container-engine: selected engine '$engine' ready (reachable, dev running, exec ok)"
  return 0
}

# CLI dispatcher (runs only when executed, not when sourced).
case "${0##*/}" in
  container-engine.sh)
    cmd="${1:-}"
    case "$cmd" in
      select)        container_engine_select ;;
      compose-bin)   container_engine_compose_bin ;;
      compose)       shift; container_engine_compose "$@" ;;
      reachable)     container_engine_reachable ;;
      dev-running)   container_engine_dev_running ;;
      dev-exec)      container_engine_dev_exec ;;
      gate)          container_engine_gate ;;
      *)
        printf '%s\n' "usage: container-engine.sh {select|compose-bin|compose|reachable|dev-running|dev-exec|gate}" >&2
        exit 2
        ;;
    esac
    ;;
esac
