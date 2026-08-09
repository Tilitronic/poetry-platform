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

# guard_no_home_qualt: blocks a recurring-writer regression — an unidentified
# local writer periodically rewrites .opencode/commands/*.md from the portable
# ${HOME:?HOME must be set} back to the literal /home/qualt path (PR #2
# comments #2/#3 fixed the original; the writer is unknown, so make the
# regression impossible to commit instead of chasing it). Runs on the host
# BEFORE container detection/delegation so the husky hooks reject dirty files
# even when the dev container is down.
guard_no_home_qualt() {
  local hits file
  # grep -l lists the offending files (full paths); no match exits 1 — the
  # clean case, so nothing is printed and the guard passes.
  hits="$(grep -lF '/home/qualt' "$COMMANDS_DIR"/*.md 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    while IFS= read -r file; do
      echo "ERROR: literal '/home/qualt' found in ${file#$ROOT/} — use \${HOME:?HOME must be set} (portability; PR #2 comments #2/#3 fix)" >&2
    done <<< "$hits"
    exit 1
  fi
}

# Fire the guard before any container logic: husky invokes this hook on the
# host, so the regression is blocked at push time on the host.
guard_no_home_qualt

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
