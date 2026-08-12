#!/usr/bin/env bash
# ticker-render - derived-view renderer for the needs-input ticker (DIA-122).
#
# WHY: the needs-input-observer plugin maintains .opencode/session/ticker.json
# (silent plugin write, mirroring delegation-observer's registry.jsonl).
# ticker.md is a DERIVED VIEW of that state - never edit it by hand, always
# regenerate with this script. The renderer surfaces WHICH session awaits
# developer input, which is the core ask of DIA-122: many opencode sessions
# run in parallel (DIA-085 worktree model) and the developer needs to see at a
# glance which sessions are blocked on them.
#
# Usage: scripts/ticker-render.sh
#   TICKER_FILE    input json path   (default .opencode/session/ticker.json)
#   TICKER_OUTPUT  output md path    (default .opencode/session/ticker.md)
#
# Exit 0 ALWAYS: a missing or malformed ticker.json renders the "no sessions
# waiting" state rather than failing - the ticker is a convenience view, never
# a gate. Fail-loud only on missing jq (a `make test-shell` prerequisite,
# guaranteed on PATH) and on internal write errors.
#
# Bash-3 compatible (same contract as scripts/session-log): no [[ ]], no
# associative arrays, no ${!var}. Requires jq for JSON parsing.
set -euo pipefail

TICKER_FILE="${TICKER_FILE:-.opencode/session/ticker.json}"
TICKER_OUTPUT="${TICKER_OUTPUT:-.opencode/session/ticker.md}"

fail() {
  echo "error: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq required (not found on PATH)"

GENERATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Read the ticker state. Missing file or unparseable JSON -> empty state
# (the plugin writes atomically, but a hand-edit or partial write must never
# crash the renderer). The `if type == "array" then . else [] end` guard also
# normalizes a mis-shaped document (e.g. "waiting" as a string).
if [ ! -f "$TICKER_FILE" ]; then
  WAITING="[]"
  ERRORS="[]"
elif ! WAITING="$(jq -c '(.waiting // []) | if type == "array" then . else [] end' "$TICKER_FILE" 2>/dev/null)"; then
  WAITING="[]"
  ERRORS="[]"
else
  ERRORS="$(jq -c '(.errors // []) | if type == "array" then . else [] end' "$TICKER_FILE" 2>/dev/null || echo "[]")"
fi

WAITING_COUNT="$(printf '%s' "$WAITING" | jq 'length')"
ERROR_COUNT="$(printf '%s' "$ERRORS" | jq 'length')"

mkdir -p "$(dirname "$TICKER_OUTPUT")"

# Atomic write: build into <output>.tmp then rename (mirrors scripts/session-log).
{
  echo "# Needs-Input Ticker"
  echo ""
  echo "_Generated: ${GENERATED}_"
  echo ""
  if [ "$WAITING_COUNT" -gt 0 ]; then
    echo "${WAITING_COUNT} session(s) waiting for developer input."
    echo ""
    echo "| session_id | title | agent | reason | detail | since |"
    echo "| --- | --- | --- | --- | --- | --- |"
    printf '%s' "$WAITING" | jq -r '
      def clean: gsub("\\|"; "&#124;") | gsub("[\r\n]+"; " ");
      sort_by(.since // "") | .[] |
        "| \(.session_id // "?" | clean) | \(.title // "" | clean) | \(.agent // "" | clean) | \(.reason // "" | clean) | \(.detail // "" | clean) | \(.since // "" | clean) |"
    '
  else
    echo "No sessions waiting for developer input."
  fi
  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo ""
    echo "## Errors"
    echo ""
    echo "| session_id | title | since | error |"
    echo "| --- | --- | --- | --- |"
    printf '%s' "$ERRORS" | jq -r '
      def clean: gsub("\\|"; "&#124;") | gsub("[\r\n]+"; " ");
      sort_by(.since // "") | .[] |
        "| \(.session_id // "?" | clean) | \(.title // "" | clean) | \(.since // "" | clean) | \(.error // "" | clean) |"
    '
  fi
} > "$TICKER_OUTPUT.tmp"

mv -f "$TICKER_OUTPUT.tmp" "$TICKER_OUTPUT"

exit 0
