#!/usr/bin/env bats
# C5 scenario replay tests (DIA-226): regression tests from the incident
# corpus, driving the real delegation-observer plugin via bun scenario scripts.
#
# Each scenario sets up a fresh mkdtemp workspace inside the Docker container,
# exercises the plugin hooks, and asserts the observable file output. The bun
# scenario scripts are in .opencode/plugins/__tests__/harness-scenarios/.
#
# Exit-code contract:
#   0  the scenario passes
#   1  the scenario fails
#
# Runs inside the poetry-dev container (bun + TypeScript).

load test-helper
source "$REPO_ROOT/scripts/container-engine.sh"

SCENARIOS_DIR="$REPO_ROOT/.opencode/plugins/__tests__/harness-scenarios"

# run_scenario <name>: runs a bun scenario script inside the selected container.
# The script receives a fresh mkdtemp path via $WORKSPACE and asserts the
# plugin's observable output (registry.jsonl). Exits non-zero on assertion
# failure.
run_scenario() {
  local name="$1"
  local script="$SCENARIOS_DIR/$name.scenario.mjs"
  [ -f "$script" ] || {
    echo "run_scenario: missing script: $script" >&2
    return 1
  }
  # Skip when the selected host engine is unavailable. These tests require a
  # host-side compose exec and therefore cannot run from inside the container.
  if ! container_engine_reachable; then
    echo "# skip: selected container engine unavailable" >&3
    return 0
  fi
  container_engine_compose exec -T dev bash -lc \
    "cd /workspace/.opencode/plugins/__tests__/harness-scenarios && bun run $name.scenario.mjs"
}

# ---------------------------------------------------------------------------
# Scenario 1 (DIA-130 class): empty-result detection
# ---------------------------------------------------------------------------
# Regression: a coder dispatch returns an EMPTY <task_result> body. The
# plugin's session.idle handler must emit an empty_result_detected row with
# dispatch_state EMPTY_RESULT in registry.jsonl (DIA-260926-ch1d: absent TEXT,
# not the retired zero-file-edit proxy).

@test "C5 scenario-1: empty-result session.idle emits EMPTY_RESULT in registry" {
  run_scenario "empty-result-silent-failure"
}
