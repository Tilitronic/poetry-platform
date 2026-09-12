#!/usr/bin/env bash
# Verification gate for the husky pre-push hook. Runs the full suite:
#   prettier --check, eslint, typecheck, JS tests (vitest), python pytest.
#
# Execution context:
#   - inside the dev container -> run pnpm directly in /workspace
#   - on the host              -> delegate each step via the selected native
#     compose command (scripts/container-engine.sh)
#
# An offline dev stack never blocks the delegated verification steps: if the
# container is not running those steps print a warning and pass (start it
# with `make up`, then push again). EXCEPTION: the F budget-gate range
# backstop below is host-local and always blocking, so an offline push that
# carries a budget violation is still refused. Each failing step aborts the
# script with a non-zero exit code, which makes the hook block the push.
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

# Host-side engine contract (DIA-260912-y2uo): host engine calls route through
# the selected native compose command. No direct docker/podman invocation.
ENGINE_ADAPTER="$ROOT/scripts/container-engine.sh"

is_in_dev_container() {
  [ "$(hostname)" = "poetry-dev" ]
}

container_running() {
  bash "$ENGINE_ADAPTER" dev-running
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
    bash "$ENGINE_ADAPTER" compose -f "$ROOT/docker-compose.yml" exec -T --user dev dev bash -lc "cd \"${WORKSPACE}\" && ${cmd}" < /dev/null
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

# F budget-gate range backstop (DIA-260903-o7n0): re-check every pushed commit
# through the budget gate in always-blocking --range mode. Placed ABOVE the
# container-down early exit (mirroring the home-qualt placement): the push
# must hit this check even when the dev stack is offline. Host-local
# (bash/git/jq only, never delegated to the container) so it also covers
# pushes made with --no-verify; the gate itself ignores BUDGET_GATE_MODE in
# range mode, so a local report-only setting cannot weaken the push check.
# Runs once here, never inside run_workspace: the hook feeds the pushed ref
# lines on stdin and stdin can be consumed only once. Skipped silently when
# the hook has no ref lines on stdin (manual runs) or when stdin is a
# terminal. New-branch pushes (remote sha all zeros) range from the main
# merge-base; branch deletions (local sha all zeros) carry nothing to check.
ZERO_SHA="0000000000000000000000000000000000000000"
budget_range_failed=0
if [ -t 0 ]; then
  : # manual run, no pushed refs to range-check
else
  # Bare `read` (default IFS splitting) is REQUIRED here: the hook feeds four
  # space-separated fields per line. `IFS= read` would stuff the whole line
  # into the first variable, leaving the sha empty, so the guard below would
  # skip every pushed ref and the backstop would never fire.
  while read -r push_local_ref push_local_sha push_remote_ref push_remote_sha; do
    [ -n "${push_local_sha:-}" ] || continue
    case "$push_local_sha" in "$ZERO_SHA"*) continue ;; esac # branch deletion: nothing to check
    range_rev=""
    case "${push_remote_sha:-}" in
    "$ZERO_SHA"* | "")
      push_base="$(git merge-base main "$push_local_sha" 2>/dev/null || true)"
      if [ -n "$push_base" ]; then
        range_rev="$push_base..$push_local_sha"
      else
        range_rev="$push_local_sha"
      fi
      ;;
    *)
      range_rev="$push_remote_sha..$push_local_sha"
      ;;
    esac
    if ! bash "$ROOT/scripts/check-budget-gate.sh" --range "$range_rev"; then
      budget_range_failed=1
    fi
  done
  if [ "$budget_range_failed" -ne 0 ]; then
    echo "!! pre-push blocked: budget gate range check failed (see FAIL lines above)" >&2
    exit 1
  fi
fi

if is_in_dev_container; then
  echo "== poetry-platform pre-push: running inside dev container =="
else
  if ! container_running; then
    echo "!! pre-push verification skipped: dev container not running (start with 'make up')"
    exit 0
  fi
  echo "== poetry-platform pre-push: delegating to dev container =="
fi

# Fast-to-fail step ladder (F-1, DIA-179; DIA-260827-36ht adds the behavioral
# gate): format, js, js-tests, test-config, test-omo, dia189-toast, python,
# test-shell LAST. The four fast pnpm gates and the OpenCode config validator
# (make test-config: agent-name drift, JSONC, skill frontmatter) surface a
# regression in ~1.2 s instead of ~25 s; the slow bats suite (make test-shell,
# 100+ tests) is the final step so a format/typecheck failure aborts before it
# ever runs. The dia189 desktop-toast leg sits after test-omo and before
# python so the plugin behavioral gate blocks pushes while the slow bats suite
# stays last. It runs host-local via bun (no Docker, no run_workspace):
# nested Docker delegation broke the design.md:24 warn-and-pass contract, and
# host-local bun needs no container so warn-and-pass holds trivially (offline
# pushes exit 0 above before ever reaching this line). Blocking under
# `set -e`: any toast failure aborts the push. SPEC DEVIATION (recorded in
# handoff; spec doc update follows separately): design.md/tasks.md 2.1 said
# to delegate the full harness target via run_workspace. Hosts without bun never reach these lines
# in practice (bun ships with the documented dev entrypoint, same as make).
export VERIFY_PRE_PUSH_RUNNING=1
run_workspace "pnpm verify:format"
run_workspace "pnpm verify:js"
run_workspace "pnpm verify:js-tests"
run_workspace "make test-config"
run_workspace "make test-omo"
echo "==> bun test dia189 desktop-toast (host-local, DIA-260827-36ht)"
(cd "$ROOT/.opencode/plugins/__tests__" && bun test needs-input-observer.dia189.test.mjs -t "desktop toast|Cyrillic|control chars|single quotes|180 chars|C1 control")
run_workspace "pnpm verify:python"
run_workspace "make test-shell"

echo "== poetry-platform pre-push: verification passed =="
