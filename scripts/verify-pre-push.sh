#!/usr/bin/env bash
# Verification gate for the husky pre-push hook. Runs the full suite:
#   prettier --check, eslint, typecheck, JS tests (vitest), python pytest.
#
# Execution context:
#   - inside the dev container -> run pnpm directly in /workspace
#   - on the host              -> delegate each step via `docker compose exec dev`
#
# A push is never blocked by an offline dev stack: if the container is not
# running the gate prints a warning and passes (start it with `make up`, then
# push again). Each failing step aborts the script with a non-zero exit code,
# which makes the hook block the push.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Overridable so bats unit tests can point it at an isolated temp tree instead
# of the real container mount.
WORKSPACE="${POETRY_WORKSPACE:-/workspace}"

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
    docker compose -f "$ROOT/docker-compose.yml" exec -T dev bash -lc "cd $WORKSPACE && $cmd"
  fi
}

if is_in_dev_container; then
  echo "== poetry-platform pre-push: running inside dev container =="
else
  if ! container_running; then
    echo "!! pre-push verification skipped: dev container not running (start with 'make up')"
    exit 0
  fi
  echo "== poetry-platform pre-push: delegating to dev container =="
fi

run_workspace "pnpm verify:format"
run_workspace "pnpm verify:js"
run_workspace "pnpm verify:js-tests"
run_workspace "pnpm verify:python"

echo "== poetry-platform pre-push: verification passed =="
