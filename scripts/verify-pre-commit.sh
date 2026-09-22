#!/usr/bin/env bash
# Autofix gate for the husky pre-commit hook. Runs lint-staged, which applies
# eslint --fix / prettier --write / ruff --fix+format / bash -n to staged files.
#
# Execution context:
#   - inside the dev container -> run npx lint-staged directly in /workspace
#   - on the host              -> prove readiness through the engine adapter,
#     then delegate via the selected native compose command
#
# Unlike pre-push (which warns and passes when the container is down), this
# hook FAILS by default (D1): a commit-time autofix gate that silently skips
# would let unformatted code into the staging area. The developer can start the
# stack (`make up`) or bypass explicitly with `git commit --no-verify`.
#
# DIA-094 strict gate (DIA-260912-y2uo): the host path requires ALL THREE
# adapter stages — selected-engine reachability, selected-stack dev running
# status, AND non-mutating `compose exec -T dev true`. Status alone never
# passes; each failure is distinct and never falls back to the other engine.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Overridable so bats unit tests can point it at an isolated temp tree instead
# of the real container mount.
WORKSPACE="${POETRY_WORKSPACE:-/workspace}"
# Directory scanned by the /home/qualt guard; overridable so bats unit tests
# can point it at an isolated fixture tree instead of the real repo commands
# dir (mirror of the WORKSPACE/POETRY_WORKSPACE seam above).
COMMANDS_DIR="${POETRY_COMMANDS_DIR:-$ROOT/.opencode/commands}"

is_in_dev_container() {
  [ "$(hostname)" = "poetry-dev" ]
}

# Host-side engine contract (DIA-260912-y2uo). Resolves COMPOSE_ENGINE
# (authoritative) or autodetects and exposes the selected native compose
# invocation. All host engine calls below go through it; there is no direct
# docker/podman invocation and no cross-engine fallback.
ENGINE_ADAPTER="$ROOT/scripts/container-engine.sh"

# run_workspace <command string>: executes <command> from the workspace root in
# the right context — directly inside the container, or delegated on the host
# through the selected native compose command.
run_workspace() {
  local cmd="$1"
  echo "==> $cmd"
  if is_in_dev_container; then
    (cd "$WORKSPACE" && bash -lc "$cmd")
  else
    bash "$ENGINE_ADAPTER" compose -f "$ROOT/docker-compose.yml" exec -T dev bash -lc "cd \"${WORKSPACE}\" && ${cmd}"
  fi
}

# /home/qualt regression guard (F-6, DIA-179): the body lives in
# scripts/guards/home-qualt.sh so both hooks share one canonical definition
# (canonical grep tests: scripts/__tests__/guards-home-qualt.bats). Sourced on
# the host BEFORE container detection/delegation so the husky hooks reject
# dirty files even when the dev container is down.
source "$(git rev-parse --show-toplevel)/scripts/guards/home-qualt.sh"

# Fire the guard before any container logic: husky invokes this hook on the
# host, so the regression is blocked at commit time on the host.
guard_no_home_qualt

if is_in_dev_container; then
  echo "== poetry-platform pre-commit: running inside dev container =="
else
  # Strict 3-stage DIA-094 gate via the engine adapter. On failure the gate's
  # own diagnostic is printed first (it names the selected engine and the
  # failed stage); the hook adds only the remediation pointer.
  gate_out="$(bash "$ENGINE_ADAPTER" gate 2>&1)" && gate_rc=0 || gate_rc=$?
  if [ "$gate_rc" -ne 0 ]; then
    echo "$gate_out" >&2
    case "$gate_out" in
      *engine-reachability*)
        echo "!! dev container not running — start with 'make up', then commit again." >&2
        ;;
    esac
    exit 1
  fi
  echo "$gate_out"
  echo "== poetry-platform pre-commit: delegating to dev container =="
fi

# --allow-empty: a commit with no staged files must not fail the hook (E1).
run_workspace "npx lint-staged --allow-empty"

echo "== poetry-platform pre-commit: autofix passed =="
