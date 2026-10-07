#!/usr/bin/env bats
# DIA-182: unit tests for scripts/session-analytics.sh — the canned analytics
# wrapper over OpenCode's NATIVE telemetry surface (`opencode stats` +
# `opencode db`). The script is read-only and idempotent; it renders four
# canned views (per-agent cost/tokens, top-N models, top-N tools, delegation
# hierarchy) and guards against the native surface being unavailable.
#
# Test strategy (per the ticket):
#   - ARG/ERROR handling is HERMETIC: a recording fake `opencode` is planted
#     on PATH (same pattern as the fake docker in test-helper.bash). The fake
#     logs every invocation so tests can assert both exit behavior AND which
#     canned query/flag reached the native surface.
#   - The real opencode queries are SMOKE-TESTED LIVE (not mocked): a live
#     run against the real data dir and a live guard run against an
#     uncreatable data dir both skip with a message when `opencode` is not
#     on PATH, so the suite stays green on hosts without OpenCode.
#
# Isolation: every test uses $BATS_TEST_TMPDIR; the real OpenCode data dir is
# only touched by the explicitly-live tests (read-only SELECT / stats).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/session-analytics.sh"

# ---------------------------------------------------------------------------
# Hermetic fixtures
# ---------------------------------------------------------------------------

# install_fake_opencode <datadir>: plants a recording fake `opencode` on PATH.
#   db path       -> prints $FAKE_OC_DATA_DIR/opencode.db, or FAILS (exit 1)
#                    when the data dir does not exist (guard simulation:
#                    "pointing at a nonexistent data dir")
#   db <sql>      -> logs the SQL; prints a canned TSV table (header + 2 rows)
#                    unless FAKE_OC_EMPTY=1, which prints header-only
#   stats <flag>  -> logs the flags; prints a one-line canned summary
# Every invocation is appended to $FAKE_OC_LOG for later assertions.
install_fake_opencode() {
  local datadir="$1"
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir" "$datadir"
  cat > "$bindir/opencode" <<'FAKEO'
#!/usr/bin/env bash
# Recording fake opencode for session-analytics tests (hermetic; DIA-182).
printf '%s\n' "$*" >> "${FAKE_OC_LOG:?}"
case "${1:-}" in
  db)
    case "${2:-}" in
      path)
        if [ ! -d "${FAKE_OC_DATA_DIR:?}" ]; then
          echo "fake opencode: data dir unavailable" >&2
          exit 1
        fi
        printf '%s\n' "$FAKE_OC_DATA_DIR/opencode.db"
        ;;
      *)
        if [ "${FAKE_OC_EMPTY:-0}" = "1" ]; then
          printf 'agent\tsessions\tcost\ttokens_input\n'
        else
          printf 'agent\tsessions\tcost\ttokens_input\n'
          printf 'ai-specialist\t156\t11.50\t106054\n'
          printf 'coder\t662\t7.04\t22150711\n'
        fi
        ;;
    esac
    ;;
  stats)
    printf '== fake stats: %s %s ==\n' "${2:-}" "${3:-}"
    ;;
  *) exit 1 ;;
esac
FAKEO
  chmod +x "$bindir/opencode"
  PATH="$bindir:$PATH"
  export PATH
  export FAKE_OC_LOG="$BATS_TEST_TMPDIR/opencode.log"
  export FAKE_OC_DATA_DIR="$datadir"
  : > "$FAKE_OC_LOG"
}

# require_real_opencode: skips when the REAL opencode CLI is not on PATH (the
# live smoke + live guard tests depend on it; the hermetic tests do not).
require_real_opencode() {
  if ! command -v opencode >/dev/null 2>&1; then
    skip "real opencode CLI not on PATH; live smoke tests skipped"
  fi
}

# ---------------------------------------------------------------------------
# Arg / error handling (hermetic)
# ---------------------------------------------------------------------------

@test "session-analytics: unknown option rejected non-zero with usage hint" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --frobnicate

  assert_status 2
  assert_output_contains "error: unknown option: --frobnicate"
}

@test "session-analytics: unknown view rejected non-zero" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --view bogus

  assert_status 2
  assert_output_contains "error: unknown view: bogus"
}

@test "session-analytics: --view without a value rejected non-zero" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --view

  assert_status 2
  assert_output_contains "--view requires a value"
}

@test "session-analytics: --top must be a positive integer (zero rejected)" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --view tools --top 0

  assert_status 2
  assert_output_contains "--top must be a positive integer"
}

@test "session-analytics: --top must be a positive integer (garbage rejected)" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --view models --top abc

  assert_status 2
  assert_output_contains "--top must be a positive integer"
}

@test "session-analytics: --help exits 0 and documents the CLI surface" {
  run bash "$SCRIPT" --help

  assert_status 0
  assert_output_contains "--view"
  assert_output_contains "--top"
  assert_output_contains "agents"
  assert_output_contains "hierarchy"
}

@test "session-analytics: bash -n passes (script is valid bash)" {
  run bash -n "$SCRIPT"
  assert_status 0
}

# ---------------------------------------------------------------------------
# Guard: never silently empty success (hermetic)
# ---------------------------------------------------------------------------

@test "guard: opencode missing from PATH -> exit 1, clear message, no output" {
  # Simulate "opencode unavailable" hermetically: a PATH with no opencode.
  # $BASH is bats' own interpreter path, resolved before PATH is stripped.
  mkdir -p "$BATS_TEST_TMPDIR/emptybin"
  unset SESSION_ANALYTICS_TOP

  run env PATH="$BATS_TEST_TMPDIR/emptybin" "$BASH" "$SCRIPT" --view agents

  assert_status 1
  assert_output_contains "error: 'opencode' CLI not found on PATH"
  assert_output_not_contains "Per-agent cost/tokens"
}

@test "guard: nonexistent data dir -> exit 1, clear message, no empty success" {
  # The ticket's guard simulation: point the script at a data dir that does
  # not exist. The fake's `db path` fails with exit 1 exactly like the real
  # `opencode db path` fails when XDG_DATA_HOME is outside a real data dir.
  local datadir="$BATS_TEST_TMPDIR/does-not-exist"
  install_fake_opencode "$datadir"
  rm -rf "$datadir" # plant the dir during install, then remove it

  run bash "$SCRIPT" --view agents

  assert_status 1
  assert_output_contains "cannot access the OpenCode data dir"
  # the guard must NOT fall through to an empty success render
  assert_output_not_contains "Per-agent cost/tokens"
  assert_output_not_contains "ai-specialist"
}

@test "guard: failing canned query -> exit 1, underlying error shown" {
  # A data dir that EXISTS but whose canned query is poisoned: the fake
  # returns exit 1 for `db <sql>` when FAKE_OC_QUERY_FAIL=1, simulating a
  # native query failure (e.g. schema drift). The guard must surface it.
  local datadir="$BATS_TEST_TMPDIR/data"
  install_fake_opencode "$datadir"
  FAKE_OC_QUERY_FAIL=1
  export FAKE_OC_QUERY_FAIL
  # make the fake's `db <sql>` arm fail
  cat > "$BATS_TEST_TMPDIR/bin/opencode" <<'FAKEO'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_OC_LOG:?}"
case "${1:-}" in
  db)
    if [ "${2:-}" = "path" ]; then
      printf '%s\n' "$FAKE_OC_DATA_DIR/opencode.db"
    else
      echo "fake opencode: query failed (simulated)" >&2
      exit 1
    fi
    ;;
  *) exit 1 ;;
esac
FAKEO
  chmod +x "$BATS_TEST_TMPDIR/bin/opencode"

  run bash "$SCRIPT" --view agents

  assert_status 1
  assert_output_contains "error: 'opencode db' query failed"
  assert_output_contains "query failed (simulated)"
}

# ---------------------------------------------------------------------------
# Canned views (hermetic; asserts the canned query/flag reached opencode)
# ---------------------------------------------------------------------------

@test "agents view: renders header + rows and passes the proven query shape" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --view agents

  assert_status 0
  assert_output_contains "== Per-agent cost/tokens"
  assert_output_contains "ai-specialist"
  assert_output_contains "coder"
  # the proven DIA-182 query shape reached the native surface verbatim:
  # subagent filter + aggregate columns + cost-DESC ordering
  assert_file_contains "$FAKE_OC_LOG" "parent_id IS NOT NULL"
  assert_file_contains "$FAKE_OC_LOG" "GROUP BY agent"
  assert_file_contains "$FAKE_OC_LOG" "ORDER BY cost DESC"
  assert_file_contains "$FAKE_OC_LOG" "COUNT(*) AS sessions"
  assert_file_contains "$FAKE_OC_LOG" "ROUND(SUM(cost),2) AS cost"
  assert_file_contains "$FAKE_OC_LOG" "SUM(tokens_input) AS tokens_input"
}

@test "agents view: header-only result prints an explicit no-sessions note" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"
  FAKE_OC_EMPTY=1
  export FAKE_OC_EMPTY

  run bash "$SCRIPT" --view agents

  assert_status 0
  assert_output_contains "(no subagent sessions recorded)"
  # ...and NOT a silent blank render
  assert_output_contains "agent"
}

@test "models view: --top flag reaches 'opencode stats --models N'" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --view models --top 3

  assert_status 0
  assert_output_contains "== Top-3 models"
  assert_file_contains "$FAKE_OC_LOG" "stats --models 3"
}

@test "models view: SESSION_ANALYTICS_TOP env supplies the default N" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"
  SESSION_ANALYTICS_TOP=7
  export SESSION_ANALYTICS_TOP

  run bash "$SCRIPT" --view models

  assert_status 0
  assert_file_contains "$FAKE_OC_LOG" "stats --models 7"
}

@test "tools view: --top flag reaches 'opencode stats --tools N'" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --view tools --top 5

  assert_status 0
  assert_output_contains "== Top-5 tools"
  assert_file_contains "$FAKE_OC_LOG" "stats --tools 5"
}

@test "hierarchy view: runs the root/subagent counts and depth CTE queries" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --view hierarchy

  assert_status 0
  assert_output_contains "== Session hierarchy sanity"
  assert_output_contains "root vs subagent session counts"
  assert_output_contains "chain depth distribution"
  assert_file_contains "$FAKE_OC_LOG" "parent_id IS NULL"
  assert_file_contains "$FAKE_OC_LOG" "parent_id IS NOT NULL"
  assert_file_contains "$FAKE_OC_LOG" "RECURSIVE chain"
}

@test "idempotent re-run: identical output and exit 0 on both runs" {
  install_fake_opencode "$BATS_TEST_TMPDIR/data"

  run bash "$SCRIPT" --view agents
  assert_status 0
  local first="$output"

  run bash "$SCRIPT" --view agents
  assert_status 0

  [ "$first" = "$output" ] || {
    echo "re-run output differs from first run" >&2
    echo "--- first ---" >&2
    echo "$first" >&2
    echo "--- second ---" >&2
    echo "$output" >&2
    return 1
  }
}

@test "session-analytics: Makefile wiring - test-shell auto-discovers the suite" {
  # Seam guard (same shape as session-query.bats): the bats suite is
  # auto-discovered by bats-wrapper.sh (exec "$BATS" "$TESTS_DIR"), so the
  # wiring seam is the script's presence under scripts/ — assert the script,
  # the suite, and the Makefile target exist.
  assert_file_exists "$REPO_ROOT/scripts/session-analytics.sh"
  assert_file_exists "$REPO_ROOT/scripts/__tests__/session-analytics.bats"
  assert_file_contains "$REPO_ROOT/Makefile" "session-analytics"
}

# ---------------------------------------------------------------------------
# Live smoke (real opencode; skipped when unavailable)
# ---------------------------------------------------------------------------

@test "LIVE smoke: per-agent view against the real data dir, exit 0" {
  require_real_opencode
  if ! opencode db path >/dev/null 2>&1; then
    skip "real OpenCode data dir unavailable; live smoke skipped"
  fi

  run bash "$SCRIPT" --view agents

  assert_status 0
  assert_output_contains "== Per-agent cost/tokens"
  # DIA-182 live-smoke environment-dependence: the per-agent view renders the
  # tokens_input header only when the real DB holds >=1 subagent session
  # (parent_id IS NOT NULL). On an empty-subagent data state the script
  # explicitly prints "(no subagent sessions recorded)" (view_agents in
  # session-analytics.sh) instead of a header row, so skip rather than fail
  # on a data-state-dependent assertion. The data-present case below stays
  # fully asserted.
  if [[ "$output" == *"(no subagent sessions recorded)"* ]]; then
    skip "live DB has no subagent sessions (environment-dependent data state)"
  fi
  assert_output_contains "tokens_input"
}

@test "LIVE smoke: hierarchy view against the real data dir, exit 0" {
  require_real_opencode
  if ! opencode db path >/dev/null 2>&1; then
    skip "real OpenCode data dir unavailable; live smoke skipped"
  fi

  run bash "$SCRIPT" --view hierarchy

  assert_status 0
  assert_output_contains "root vs subagent session counts"
  assert_output_contains "chain depth distribution"
}

@test "LIVE guard: uncreatable data dir -> exit 1 with clear message" {
  require_real_opencode
  # Point XDG_DATA_HOME at a path whose parent is a REGULAR FILE: opencode's
  # eager mkdir then fails with ENOTDIR for ANY user (even root) — the same
  # deterministic failure as a genuinely nonexistent data dir, but hermetic
  # against where the suite runs.
  local trapdir="$BATS_TEST_TMPDIR/notadir"
  mkdir -p "$trapdir"
  touch "$trapdir/blocker"

  run env XDG_DATA_HOME="$trapdir/blocker/sub" bash "$SCRIPT" --view agents

  assert_status 1
  assert_output_contains "cannot access the OpenCode data dir"
  # no silent empty success
  assert_output_not_contains "Per-agent cost/tokens"
}
