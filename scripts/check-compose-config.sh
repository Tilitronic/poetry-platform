#!/usr/bin/env bash
# check-compose-config.sh — HOST-ONLY client-side compose validation (PHASE 5).
# WHY: after the Docker CLI removal from Dockerfile.dev (T12.5), the compose-config
# gate relocates to the host where the engine CLI always exists. This script runs
# `<engine> compose config --quiet` via scripts/container-engine.sh. When the
# engine CLI is unavailable it HARD-FAILS with a non-zero exit and an actionable
# message (install/start guidance). It must NEVER silently skip -- that is the
# explicit testable acceptance criterion (the PHASE 3 false-green lesson).
# Client-side validation needs no daemon, so the documented "offline dev stack
# never blocks" contract holds.
# Bash-3 compatible (ADR 8). No daemon required.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_ADAPTER="$ROOT_DIR/scripts/container-engine.sh"

# Source shared in-container detection (S6, DIA-260922-cp0m).
source "$ROOT_DIR/scripts/in-container.sh"

# Detect in-container: hostname "poetry-dev" signals the in-container path.
# When running in-container, print a visible host-scoped note instead of
# silently passing.
if is_in_dev_container; then
  echo "NOTE: compose config validation is host-scoped and runs host-side via check-compose-config (see verify-pre-push.sh). Skipped in-container."
  exit 0
fi

# Resolve the engine. container_engine_select prints docker|podman to stdout.
engine="$(bash "$ENGINE_ADAPTER" select 2>/dev/null)" || {
  echo "FAIL: compose config validation requires a container engine (docker or podman)." >&2
  echo "Install Docker or Podman, or ensure COMPOSE_ENGINE is set. See docs/docker-dev.md for setup instructions." >&2
  exit 1
}

# Verify the resolved engine binary is actually on PATH (P3, DIA-260922-cp0m).
# container_engine_select autodetects "docker" even when the binary is absent
# (line 69 of container-engine.sh: it returns "docker" as the default). The
# actual failure would come from `compose config` with a misleading message,
# so we fail early with correct guidance.
if ! command -v "$engine" >/dev/null 2>&1; then
  echo "FAIL: ${engine} not found on PATH. Install ${engine} or set COMPOSE_ENGINE to an available engine. See docs/docker-dev.md for setup instructions." >&2
  exit 1
fi

# Run compose config --quiet through the engine adapter. Client-side only, no daemon.
if ! bash "$ENGINE_ADAPTER" compose config --quiet 2>/dev/null; then
  echo "FAIL: ${engine} compose config --quiet failed. Check docker-compose.yml and override files for syntax errors." >&2
  exit 1
fi

exit 0
