#!/usr/bin/env bash
# session-analytics.sh — canned analytics over OpenCode's native telemetry
# surface (opencode stats + opencode db), DIA-182.
#
# WHY THIS EXISTS: the operational question "which agent/tool actually brings
# value" was originally going to be answered by a custom telemetry plugin
# (per-tool hooks writing toolcalls.jsonl). Investigation on 2026-08-14
# (res006 conspect) proved that redundant: OpenCode natively stores per
# session cost/tokens/agent/model/parent_id in its sqlite DB (via `opencode
# db`) and exposes aggregate overviews (via `opencode stats`). This wrapper
# turns that proven surface into four canned READ-ONLY views — zero plugin
# code, zero section-10 config change.
#
# Views (--view, default: agents):
#   agents     per-agent value table over SUBAGENT sessions only
#              (parent_id IS NOT NULL): session count, cost, input tokens,
#              sorted by cost DESC. This is the DIA-182 proven query.
#   models     top-N model usage (opencode stats --models N)
#   tools      top-N tool usage (opencode stats --tools N)
#   hierarchy  session hierarchy sanity: root vs subagent session counts plus
#              a chain-depth distribution via a recursive CTE over parent_id
#
# Guard (never silently empty success): fails with a clear message and a
# non-zero exit when the native surface is unavailable — `opencode` missing
# from PATH, or `opencode db path` failing (e.g. the OpenCode data dir is
# unreachable / outside a real data dir). An AVAILABLE but EMPTY database is
# a legitimate state and exits 0 with the header row (or an explicit
# "(no subagent sessions)" note for the agents view), never a silent blank.
#
# ORDER BY note (WHY the aliases): the DIA-182 query text orders by bare
# `cost`. Under SQLite GROUP BY, a bare column in ORDER BY binds to the RAW
# session column (arbitrary per-row value per group), so the output comes
# back effectively unsorted — verified live on 2026-08-15. Aliasing the
# aggregates (COUNT(*) AS sessions, ROUND(SUM(cost),2) AS cost) makes ORDER
# BY resolve to the aggregate, giving the intended cost-DESC ranking, and
# makes the TSV header human-readable at the same time.
#
# Idempotent by construction: the script only reads (SELECT / stats); it
# writes no files and keeps no state, so re-running against the same data
# yields byte-identical output.
#
# Zero new runtime dependencies: bash + the opencode CLI (sqlite is reached
# through `opencode db`; no sqlite3 binary, no node, no python).
#
# Usage:
#   session-analytics.sh [--view agents|models|tools|hierarchy] [--top N]
#
# Options:
#   --view VIEW   canned view to render (default: agents)
#   --top N       top-N for the models/tools views (default: 10, or
#                 $SESSION_ANALYTICS_TOP). Ignored by agents/hierarchy.
#   -h, --help    show this help and exit
#
# Environment:
#   SESSION_ANALYTICS_TOP   default for --top when the flag is not passed
#
# Exit codes:
#   0  success
#   1  native surface unavailable / query failed (guard)
#   2  usage error

set -euo pipefail

DEFAULT_TOP=10

usage() {
  cat <<'EOF'
usage: session-analytics.sh [--view agents|models|tools|hierarchy] [--top N]

Canned analytics over OpenCode's native telemetry (DIA-182). Read-only:
reads the OpenCode sqlite DB via `opencode db` and aggregate views via
`opencode stats`; writes nothing; idempotent.

Views:
  agents     per-agent cost/tokens over subagent sessions (parent_id IS
             NOT NULL), sorted by cost DESC  [default]
  models     top-N model usage  (opencode stats --models N)
  tools      top-N tool usage   (opencode stats --tools N)
  hierarchy  root vs subagent counts + chain-depth distribution (parent_id)

Options:
  --view VIEW   canned view to render (default: agents)
  --top N       top-N for models/tools views (default: 10 or $SESSION_ANALYTICS_TOP)
  -h, --help    show this help and exit

Exit codes: 0 success, 1 native surface unavailable, 2 usage error.
EOF
}

# --- Arg parsing ------------------------------------------------------------
VIEW="agents"
TOP="${SESSION_ANALYTICS_TOP:-$DEFAULT_TOP}"

while [ $# -gt 0 ]; do
  case "$1" in
    --view)
      VIEW="${2:-}"
      if [ -z "$VIEW" ]; then
        echo "error: --view requires a value (agents|models|tools|hierarchy)" >&2
        exit 2
      fi
      shift 2
      ;;
    --top)
      TOP="${2:-}"
      if [ -z "$TOP" ]; then
        echo "error: --top requires a positive integer" >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$VIEW" in
  agents|models|tools|hierarchy) ;;
  *)
    echo "error: unknown view: $VIEW (expected agents|models|tools|hierarchy)" >&2
    exit 2
    ;;
esac

# --top must be a positive integer (no negatives, no floats, no garbage).
if [[ ! "$TOP" =~ ^[0-9]+$ ]] || [ "$TOP" -lt 1 ]; then
  echo "error: --top must be a positive integer (got: '$TOP')" >&2
  exit 2
fi

# --- Guard: never silently empty success ------------------------------------
# Three independent checks, each with a clear non-zero failure:
#   1. `opencode` must exist on PATH.
#   2. `opencode db path` must succeed — it fails when the data dir cannot
#      be created/resolved (e.g. XDG_DATA_HOME points outside a real data
#      dir), which is exactly the "unavailable" case the ticket mandates.
#   3. Each canned query is checked for a non-zero exit; a failing query
#      prints the underlying error instead of a silent blank table.
if ! command -v opencode >/dev/null 2>&1; then
  echo "error: 'opencode' CLI not found on PATH - cannot run session analytics" >&2
  echo "       (install OpenCode, or run inside the poetry-dev container)" >&2
  exit 1
fi

DB_PATH=""
if ! DB_PATH="$(opencode db path 2>&1)"; then
  echo "error: cannot access the OpenCode data dir ('opencode db path' failed):" >&2
  echo "       $DB_PATH" >&2
  echo "       Is the OpenCode data dir available? (e.g. XDG_DATA_HOME outside a real data dir)" >&2
  exit 1
fi

# run_db_query <sql>: run a canned query through `opencode db` and print its
# output verbatim (TSV with a header). A failing query is a guard violation.
run_db_query() {
  local sql="$1"
  local out
  if ! out="$(opencode db "$sql" 2>&1)"; then
    echo "error: 'opencode db' query failed:" >&2
    echo "$out" >&2
    exit 1
  fi
  printf '%s\n' "$out"
}

# run_stats <flag> <n>: pass through `opencode stats --models N` /
# `--tools N` (the flag carries its own argument). The "Large dataset
# detected" stderr line is opencode's own; 2>&1 keeps it visible with the
# report. A failing stats call is a guard violation, not silent success.
run_stats() {
  local flag="$1"
  local n="$2"
  if ! opencode stats "$flag" "$n" 2>&1; then
    echo "error: 'opencode stats $flag $n' failed - cannot render the view" >&2
    exit 1
  fi
}

# --- Views ------------------------------------------------------------------
view_agents() {
  echo "== Per-agent cost/tokens (subagent sessions, parent_id IS NOT NULL) =="
  echo "== data dir: $DB_PATH"
  local out
  out="$(run_db_query \
    "SELECT agent, COUNT(*) AS sessions, ROUND(SUM(cost),2) AS cost, SUM(tokens_input) AS tokens_input FROM session WHERE parent_id IS NOT NULL GROUP BY agent ORDER BY cost DESC")"
  printf '%s\n' "$out"
  # A header-only result means the data dir is healthy but no subagent
  # sessions are recorded yet — say so explicitly instead of leaving a
  # bare header as the whole answer.
  if [ "$(printf '%s\n' "$out" | wc -l)" -le 1 ]; then
    echo "(no subagent sessions recorded)"
  fi
}

view_models() {
  echo "== Top-$TOP models by usage (opencode stats --models $TOP) =="
  run_stats --models "$TOP"
}

view_tools() {
  echo "== Top-$TOP tools by usage (opencode stats --tools $TOP) =="
  run_stats --tools "$TOP"
}

view_hierarchy() {
  echo "== Session hierarchy sanity (delegation chains via parent_id) =="
  echo "-- root vs subagent session counts --"
  run_db_query \
    "SELECT (SELECT COUNT(*) FROM session WHERE parent_id IS NULL) AS root_sessions, (SELECT COUNT(*) FROM session WHERE parent_id IS NOT NULL) AS subagent_sessions"
  echo "-- chain depth distribution (0 = root session, N = N levels below a root) --"
  # Depth is bounded (AND c.depth < 20) so a cyclic parent_id cycle cannot
  # blow up the recursion: SQLite's default recursive-CTE limit is 1000
  # iterations, and an unbound cycle would terminate with an error instead
  # of a result. 20 levels is far beyond any real delegation chain (the
  # proven data shows depth <= 1) while still returning a complete
  # distribution for pathological data.
  run_db_query \
    "WITH RECURSIVE chain(id, depth) AS (SELECT id, 0 FROM session WHERE parent_id IS NULL UNION ALL SELECT s.id, c.depth + 1 FROM session s JOIN chain c ON s.parent_id = c.id AND c.depth < 20) SELECT depth, COUNT(*) AS sessions FROM chain GROUP BY depth ORDER BY depth"
}

case "$VIEW" in
  agents)    view_agents ;;
  models)    view_models ;;
  tools)     view_tools ;;
  hierarchy) view_hierarchy ;;
esac
