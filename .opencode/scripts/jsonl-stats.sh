#!/usr/bin/env bash
# jsonl-stats.sh — messages.jsonl session rollup (audit reader, G9)
#
# On-demand machine-readable audit reader for the orchestrator session log
# (.opencode/session/messages.jsonl, semconv v1.42.0). messages.jsonl is
# primarily a WRITE-ONLY audit trail — this script is the read-side consumer
# for cross-session analysis (events by type / agent / lane / cycle, token
# usage, first/last event).
#
# Usage: .opencode/scripts/jsonl-stats.sh [path]
#   path  optional — default .opencode/session/messages.jsonl
#   exit 1 if the file is missing.
# Requires jq for detailed breakdowns; degrades to a plain line count +
# a note when jq is absent.
set -euo pipefail

FILE="${1:-.opencode/session/messages.jsonl}"

if [[ ! -f "$FILE" ]]; then
  echo "error: $FILE not found" >&2
  exit 1
fi

echo "=== Messages Rollup: $FILE ==="
echo

total="$(wc -l < "$FILE" | tr -d ' ')"
echo "Total events: $total"
echo

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required for detail (not found) — install jq to see per-event breakdowns."
  echo
  echo "=== End Rollup ==="
  exit 0
fi

rollup() {
  local label="$1"
  local expr="$2"
  echo "## $label"
  # shellcheck disable=SC2016
  jq -r "$expr" < "$FILE" | sort | uniq -c | sort -rn
  echo
}

rollup "Events by type" '.event_type // "unknown"'
rollup "Events by agent" '."gen_ai.agent.name" // "unknown"'
rollup "Events by lane" '.lane_id // "no-lane"'
rollup "Cycle attribution" '.cycle_id // "no-cycle"'
rollup "Resolution status" '.resolution_status // "unset"'

echo "## Token usage (lanes with gen_ai.usage)"
if jq -s -e 'any(."gen_ai.usage.input_tokens" != null)' < "$FILE" >/dev/null 2>&1; then
  jq -r 'select(."gen_ai.usage.input_tokens" != null) |
    [.lane_id // "no-lane", ."gen_ai.usage.input_tokens", ."gen_ai.usage.output_tokens"] |
    @tsv' < "$FILE" | column -t -s $'\t'
else
  echo "(no token usage rows recorded — populated only at cycle boundaries/handoff)"
fi
echo

echo "## First event"
jq -r '.[0] | "\(.timestamp) | \(.event_type // "?") | \(.lane_id // "-")"' < <(jq -s . "$FILE")
echo "## Last event"
jq -r '.[-1] | "\(.timestamp) | \(.event_type // "?") | \(.lane_id // "-")"' < <(jq -s . "$FILE")
echo

echo "## Dangling delegations (A3 — DISPATCHED/RUNNING with no completion)"
REGISTRY="$(dirname "$FILE")/registry.jsonl"
# A delegation is dangling only when its group (session_id ?? task_id — the
# same id space: task() returns the child session id) has non-terminal rows
# and NO terminal row. The registry is append-only, so the earlier
# 'invoked'/'running' rows always remain after a 'completed'/'failed' row —
# counting raw non-terminal rows would flag EVERY delegation (S5). Rows
# without both ids cannot be grouped, so each is keyed uniquely and treated
# individually. task_no_id rows (the EXPECTED abort/cancel path, RR-5a) carry
# a synthetic group_key prefixed with __task_no_id__ that is excluded below —
# the expected path is not defensive noise, but a genuine id-less 'invoked'
# row still falls through to __row__<seq> and IS flagged.
DANGLING_SELECT='[.[] | ._gk = (.group_key // .session_id // .task_id // ("__row__" + (.seq | tostring)))] | map(select((._gk | startswith("__task_no_id__")) | not)) | group_by(._gk) | map(select(any(.dispatch_state == "completed" or .dispatch_state == "failed") | not)) | map(select(any(.dispatch_state == "invoked" or .dispatch_state == "running")))'
if [[ -f "$REGISTRY" ]] && command -v jq >/dev/null 2>&1; then
  dangling=$(jq -s "$DANGLING_SELECT | add | length" < "$REGISTRY")
  if [[ "$dangling" -gt 0 ]]; then
    echo "  WARNING: $dangling dangling delegation(s) — non-terminal rows with no terminal event"
    jq -rs "$DANGLING_SELECT | add | .[] | \"  seq=\(.seq) event=\(.event // \"?\") delegation=\(.session_id // .task_id // \"?\") agent=\(.agent // \"?\") state=\(.dispatch_state) since=\(.dispatched_at // .timestamp)\"" < "$REGISTRY"
  else
    echo "  (no dangling delegations — every non-terminal group has a terminal row)"
  fi
else
  echo "  (registry.jsonl not found or jq unavailable — skipped)"
fi
echo
echo "## Orphan dispatches (C3 — task() invoked but no session.created observed)"
# Same grouping as dangling: a dispatch is an orphan only if its group has an
# 'invoked' row and never observed a child session (no running/completed/failed
# row for the same key). Raw invoked-row counting would flag every completed
# delegation's retained task_success row (same class of bug as S5). task_no_id
# rows (expected abort/cancel path, RR-5a) are excluded via their synthetic
# __task_no_id__ group_key prefix, mirroring the dangling check.
ORPHAN_SELECT='[.[] | ._gk = (.group_key // .session_id // .task_id // ("__row__" + (.seq | tostring)))] | map(select((._gk | startswith("__task_no_id__")) | not)) | group_by(._gk) | map(select(any(.dispatch_state == "invoked"))) | map(select(any(.dispatch_state == "running" or .dispatch_state == "completed" or .dispatch_state == "failed") | not))'
if [[ -f "$REGISTRY" ]] && command -v jq >/dev/null 2>&1; then
  orphans=$(jq -s "$ORPHAN_SELECT | add | length" < "$REGISTRY")
  if [[ "$orphans" -gt 0 ]]; then
    echo "  WARNING: $orphans orphan dispatch(es) — task() invoked but no child session observed"
    jq -rs "$ORPHAN_SELECT | add | .[] | \"  seq=\(.seq) event=\(.event // \"?\") delegation=\(.session_id // .task_id // \"?\") since=\(.dispatched_at // .timestamp)\"" < "$REGISTRY"
  else
    echo "  (all dispatches have observed child sessions — clean)"
  fi
fi
echo
echo "## Session attribution coverage"
if command -v jq >/dev/null 2>&1; then
  total_events=$(jq -s 'length' < "$FILE")
  with_session=$(jq -s '[.[] | select(."gen_ai.agent.id" != null)] | length' < "$FILE")
  if [[ "$total_events" -gt 0 ]]; then
    pct=$(( (with_session * 100) / total_events ))
    echo "  $with_session / $total_events events have session attribution ($pct%)"
  fi
  if [[ -f "$REGISTRY" ]]; then
    reg_total=$(jq -s 'length' < "$REGISTRY")
    reg_with_session=$(jq -s '[.[] | select(.session_id != null)] | length' < "$REGISTRY")
    if [[ "$reg_total" -gt 0 ]]; then
      reg_pct=$(( (reg_with_session * 100) / reg_total ))
      echo "  Registry: $reg_with_session / $reg_total rows have session_id ($reg_pct%)"
    fi
  fi
fi
echo

echo "=== End Rollup ==="
