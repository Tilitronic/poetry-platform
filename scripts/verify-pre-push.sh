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

# Recursion guard (ana015): if this script is already running in the process
# tree (e.g., verify-pre-push.sh -> make test-shell -> bats -> nested
# verify-pre-push.sh), skip the gates to prevent unbounded recursion. The flag
# propagates through process spawns (bash -> make -> bats -> test -> nested
# script). Test-side: verify-pre-push.bats setup() unsets this flag so every
# test exercises the public entry behavior with a clean environment (hook
# context inherits the flag).
if [ -n "${VERIFY_PRE_PUSH_RUNNING:-}" ]; then
  echo "!! verify-pre-push.sh: already running (recursion guard; skipping)"
  exit 0
fi

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
    # < /dev/null: the pre-push hook is invoked by git with the pushed ref spec
    # on stdin; forwarding that into the container would leak it into any
    # delegated command that reads stdin (e.g. the dev-entrypoint no-command
    # bats test executes `bash dev-entrypoint.sh`, which then tries to run the
    # ref spec line as a command -> "No such file or directory" -> exit 127 ->
    # spurious test failure under the hook). Closing stdin keeps every
    # delegated gate hermetic; the in-container branch above needs no redirect
    # (stdin is a terminal there).
    # DESIGN: run_workspace never forwards stdin; pipe data via files or args.
    docker compose -f "$ROOT/docker-compose.yml" exec -T --user dev dev bash -lc "cd \"${WORKSPACE}\" && ${cmd}" < /dev/null
  fi
}

# /home/qualt regression guard (F-6, DIA-179): the body lives in
# scripts/guards/home-qualt.sh so both hooks share one canonical definition
# (canonical grep tests: scripts/__tests__/guards-home-qualt.bats). Sourced on
# the host BEFORE container detection/delegation so the husky hooks reject
# dirty files even when the dev container is down.
source "$(git rev-parse --show-toplevel)/scripts/guards/home-qualt.sh"

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

# Fast-to-fail step ladder (F-1, DIA-179): six steps in the order format, js,
# js-tests, test-config, python, test-shell LAST. The four fast pnpm gates and
# the OpenCode config validator (make test-config: agent-name drift, JSONC,
# skill frontmatter) surface a regression in ~1.2 s instead of ~25 s; the slow
# bats suite (make test-shell, 100+ tests) is the final step so a
# format/typecheck failure aborts before it ever runs. Delegated via
# run_workspace like every other step: the container ships make, bats is
# vendored on the shared /workspace mount, and the pre-push contract
# (warn+pass when the container is down, DIA-094) is preserved. Hosts without
# make never reach these lines because they cannot have started the stack
# (make is the documented entrypoint).
export VERIFY_PRE_PUSH_RUNNING=1
run_workspace "pnpm verify:format"
run_workspace "pnpm verify:js"
run_workspace "pnpm verify:js-tests"
run_workspace "make test-config"
run_workspace "make test-omo"
run_workspace "pnpm verify:python"
run_workspace "make test-shell"

echo "== poetry-platform pre-push: verification passed =="
