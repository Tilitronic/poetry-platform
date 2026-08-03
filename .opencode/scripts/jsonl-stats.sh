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
if jq -e 'any(."gen_ai.usage.input_tokens" != null)' < "$FILE" >/dev/null 2>&1; then
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

echo "=== End Rollup ==="
