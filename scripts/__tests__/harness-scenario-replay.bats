#!/usr/bin/env bats
# C5 scenario replay tests (DIA-226): regression tests from the incident
# corpus, driving the real delegation-observer plugin via bun scenario scripts.
#
# Each scenario sets up a fresh mkdtemp workspace inside the Docker container,
# exercises the plugin hooks, and asserts the observable file output. The bun
# scenario scripts are in .opencode/plugins/__tests__/harness-scenarios/.
#
# Exit-code contract:
#   0  all 3 scenarios pass
#   1  any scenario fails
#
# Runs inside the poetry-dev container (bun + TypeScript).

load test-helper

SCENARIOS_DIR="$REPO_ROOT/.opencode/plugins/__tests__/harness-scenarios"

# run_scenario <name>: runs a bun scenario script inside the Docker container.
# The script receives a fresh mkdtemp path via $WORKSPACE and asserts the
# plugin's observable output (registry.jsonl, handoffs/). Exits non-zero on
# assertion failure.
run_scenario() {
  local name="$1"
  local script="$SCENARIOS_DIR/$name.scenario.mjs"
  [ -f "$script" ] || {
    echo "run_scenario: missing script: $script" >&2
    return 1
  }
  docker compose exec -T dev bash -lc \
    "cd /workspace/.opencode/plugins/__tests__/harness-scenarios && bun run $name.scenario.mjs"
}

# ---------------------------------------------------------------------------
# Scenario 1 (DIA-130 class): empty-result SILENT_FAILURE detection
# ---------------------------------------------------------------------------
# Regression: coder-escalated returns empty result. The plugin's session.idle
# handler must emit a SILENT_FAILURE row in registry.jsonl when a child
# session completes with zero file edits.

@test "C5 scenario-1: empty-result session.idle emits SILENT_FAILURE in registry" {
  run_scenario "empty-result-silent-failure"
}

# ---------------------------------------------------------------------------
# Scenario 2 (DIA-085 F-1 class): same-millisecond parallel handoff writes
# ---------------------------------------------------------------------------
# Regression: two successive handoff writes for the same session within the
# same millisecond produce distinct archive filenames (UUID suffix). Before
# the fix, identical ISO timestamps caused the second archive to overwrite
# the first.

@test "C5 scenario-2: same-millisecond parallel handoff writes produce distinct archives" {
  run_scenario "parallel-handoff-archive"
}

# ---------------------------------------------------------------------------
# Scenario 3 (DIA-085 F-3 class): pre-dispatch session slot identity
# ---------------------------------------------------------------------------
# Regression: two pre-dispatch orchestrator sessions writing handoffs must
# create two distinct slot files (ses_X.json, ses_Y.json), not a single
# "unknown.json" clobber. Before the fix, five fallback chains used
# "unknown" as the last resort, causing parallel sessions to collapse.

@test "C5 scenario-3: two pre-dispatch sessions create distinct slot files (no unknown.json clobber)" {
  run_scenario "slot-identity-no-clobber"
}
