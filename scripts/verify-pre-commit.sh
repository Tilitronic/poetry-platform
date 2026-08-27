#!/usr/bin/env bash
# Autofix gate for the husky pre-commit hook. Runs lint-staged, which applies
# eslint --fix / prettier --write / ruff --fix+format / bash -n to staged files.
#
# Execution context:
#   - inside the dev container -> run npx lint-staged directly in /workspace
#   - on the host              -> delegate via `docker compose exec dev`
#
# Unlike pre-push (which warns and passes when the container is down), this
# hook FAILS by default (D1): a commit-time autofix gate that silently skips
# would let unformatted code into the staging area. The developer can start the
# stack (`make up`) or bypass explicitly with `git commit --no-verify`.
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

container_running() {
  docker compose -f "$ROOT/docker-compose.yml" ps --services --status running 2>/dev/null | grep -qx "dev"
}

# run_workspace <command string>: executes <command> from the workspace root in
# the right context — directly inside the container, or delegated on the host.
run_workspace() {
  local cmd="$1"
  echo "==> $cmd"
  if is_in_dev_container; then
    (cd "$WORKSPACE" && bash -lc "$cmd")
  else
    docker compose -f "$ROOT/docker-compose.yml" exec -T dev bash -lc "cd \"${WORKSPACE}\" && ${cmd}"
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
  if ! container_running; then
    # DIA-260821-aoag: distinguish "inside opencode-docker without the engine
    # socket" (developer forgot --with-engine) from "on the host with the stack
    # down". Both make `docker compose ps` fail, but the remediation differs.
    # The OPENCODE_DOCKER sentinel is exported by the launcher for every run.
    if [ "${OPENCODE_DOCKER:-}" = "1" ]; then
      echo "!! Container engine socket not mounted. Relaunch opencode-docker with --with-engine to enable in-container git hooks / docker compose." >&2
    else
      echo "!! dev container not running — start with 'make up', then commit again." >&2
    fi
    exit 1
  fi
  echo "== poetry-platform pre-commit: delegating to dev container =="
fi

# --allow-empty: a commit with no staged files must not fail the hook (E1).
run_workspace "npx lint-staged --allow-empty"

echo "== poetry-platform pre-commit: autofix passed =="
