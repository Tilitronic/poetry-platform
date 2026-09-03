#!/usr/bin/env bash
# jsonl-cross-check.sh — P5 registry↔messages completeness cross-check
# (ana007 silent-session-logging, Option E arc-1, Phase-5 validation).
#
# WHY: silent session logging makes messages.jsonl the canonical plugin-written
# session log and registry.jsonl the plugin's complementary lifecycle log
# (.opencode/session/README.md). Phase 5 validates that the plugin captured
# EVERY delegation in messages.jsonl: completeness >= threshold vs the
# registry ground truth. This script is that cross-check, run on demand
# (make jsonl-cross-check) — pre-restart it documents the legacy gap,
# post-restart it proves the plugin is not losing rows.
#
# WHY --since (timestamp filter): the registry's task_success rows span two
# eras. Rows before 2026-08-06T19:30:00Z (seq 1-682) were written by the
# LEGACY orchestrator BEFORE the messages.jsonl plugin writer existed — their
# messages rows carry no gen_ai.agent.id, so they are STRUCTURALLY UNMATCHABLE
# and would pin completeness near 0% forever (measured 3.8% on the
# 2026-08-06 corpus: 200 legacy rows outside any ±5s match). The plugin itself
# is healthy (7/7 smoke rows match); the legacy rows merely predate it.
# 19:30:00Z is the plugin messages-writer activation boundary (first
# plugin-written messages row: 2026-08-06T19:30:20.746Z; 19:30:00Z is the
# clean minute boundary). The gate scopes its universe to what the plugin
# observes (timestamp >= --since); legacy rows are still counted in the report
# split for transparency. NOTE: `writer` is NOT a usable discriminator — every
# registry row (legacy included) already carries writer:"plugin" because the
# registry IS the plugin's original output. Timestamp is the only split.
#
# Algorithm (approved design, ana007 report §5 Phase 5 + §6 item 4):
#   universe     = registry.jsonl rows with event == "task_success" AND task_id
#                  AND timestamp >= --since (default 2026-08-06T19:30:00Z)
#   candidates   = messages.jsonl rows with event_type == "delegation"
#   match        = a universe row has >=1 candidate whose
#                  gen_ai.agent.id == registry.task_id AND whose timestamps
#                  are within ±5 seconds (the design's stated tolerance)
#   completeness = matched / universe * 100
#   verdict      = PASS if completeness >= threshold (default 0.99), else FAIL
#
# Schema mapping (read from .opencode/session/README.md — NOT invented):
#   registry.task_id          — from task() result (success path only)
#   messages.gen_ai.agent.id  — project extension "agent instance identifier";
#                               the plugin writes BOTH fields from the same
#                               taskId variable (delegation-observer.ts
#                               appendMessageRow call site), and empirically
#                               they share the ses_* id space (200/205 overlap
#                               on the 2026-08-06 corpus). messages.jsonl has
#                               NO task_id field in its schema, so
#                               gen_ai.agent.id is the correct join key.
#   timestamps                — both are write-time `new Date().toISOString()`;
#                               the plugin writes the registry task_success row
#                               and the messages delegation row in the same
#                               hook invocation, so plugin rows align within
#                               milliseconds. Rows whose timestamp does not
#                               parse are skipped with a warning (bad_ts in
#                               the report split), never counted as matched.
#   NOTE: jq's fromdateiso8601 rejects fractional seconds (jq 1.8), so the
#   timestamp is normalized by stripping the ".mmm" fraction before parsing —
#   immaterial at a ±5s tolerance.
#
# Exit codes:
#   0  PASS  — completeness >= threshold
#   1  FAIL  — completeness < threshold
#   2  usage/input error — bad args, missing file, missing jq, invalid
#      threshold/since, zero task_success rows, or zero in-universe rows after
#      the --since cutoff (fail-loud: a vacuous pass could mask a silently
#      dead plugin).
#
# Bash-3 compatible (macOS stock bash 3.2): no [[ ]], no associative arrays,
# no ${!var} — same contract as scripts/session-log. Requires jq (fail-loud
# if absent).
set -euo pipefail

# Force C locale so printf uses '.' as the decimal separator regardless of the
# host locale (comma-locale hosts rendered "100,0%" and broke the tests). jq is
# locale-independent for number output; only the printf formatting needs this.
export LC_ALL=C

REG_FILE=".opencode/session/registry.jsonl"
MSG_FILE=".opencode/session/messages.jsonl"
THRESHOLD="0.99"
TOLERANCE=5
# Plugin messages-writer activation boundary (first plugin-written messages
# row: 2026-08-06T19:30:20.746Z; 19:30:00Z is the clean minute boundary).
SINCE="2026-08-06T19:30:00Z"

fail_usage() {
  echo "error: $*" >&2
  echo "usage: jsonl-cross-check.sh [registry.jsonl] [messages.jsonl] [--threshold <0..1>] [--since <ISO-8601>]" >&2
  exit 2
}

fail_input() {
  echo "error: $*" >&2
  exit 2
}

require_jq() {
  command -v jq >/dev/null 2>&1 || \
    fail_input "jq required (not found on PATH) — install jq (e.g. sudo apt install jq, brew install jq, or mise install jq)"
}

# classify_lines <file>: classify every line as OK/BAD (one jq -R pass; empty
# lines are OK, anything that fails fromjson is BAD). WHY shared (rev-1 finding
# 1): the OK/BAD classification is the single source of truth for BOTH the
# skip+warn policy and the malformed summary count — the two call sites used to
# duplicate the same jq expression and could drift.
classify_lines() {
  jq -Rr 'if length == 0 then "OK" else try (fromjson | "OK") catch "BAD" end' "$1"
}

# warn_malformed <file>: skip + warn policy for malformed JSON lines — one
# jq -R pass classifies every line (OK/BAD), BAD line numbers are printed as
# warnings on stderr; malformed rows never crash the cross-check (mirrors
# scripts/session-log).
warn_malformed() {
  local f="$1"
  local bad
  bad="$(classify_lines "$f" \
    | grep -n '^BAD$' \
    | sed 's/:BAD$//' || true)"
  if [ -n "$bad" ]; then
    echo "$bad" | while read -r n; do
      echo "warning: $f line $n is malformed JSON — skipped" >&2
    done
  fi
}

# count_malformed <file>: number of BAD lines (summary line).
count_malformed() {
  local f="$1"
  classify_lines "$f" \
    | grep -c '^BAD$' || true
}

# --- argument parsing: two positional file paths + --threshold/--since anywhere.
REG_ARG=""
MSG_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --threshold)
      shift
      [ $# -gt 0 ] || fail_usage "--threshold requires a value"
      THRESHOLD="$1"
      ;;
    --since)
      shift
      [ $# -gt 0 ] || fail_usage "--since requires a value"
      SINCE="$1"
      ;;
    --help|-h)
      echo "usage: jsonl-cross-check.sh [registry.jsonl] [messages.jsonl] [--threshold <0..1>] [--since <ISO-8601>]"
      echo "  registry.jsonl  plugin delegation registry (default .opencode/session/registry.jsonl)"
      echo "  messages.jsonl  session log (default .opencode/session/messages.jsonl)"
      echo "  --threshold     pass threshold as a 0..1 fraction (default 0.99)"
      echo "  --since         only registry task_success rows at/after this UTC"
      echo "                  ISO-8601 timestamp are in the universe (default"
      echo "                  2026-08-06T19:30:00Z — plugin messages-writer activation)"
      exit 0
      ;;
    *)
      if [ -z "$REG_ARG" ]; then
        REG_ARG="$1"
      elif [ -z "$MSG_ARG" ]; then
        MSG_ARG="$1"
      else
        fail_usage "unexpected argument: $1"
      fi
      ;;
  esac
  shift
done

[ -z "$REG_ARG" ] || REG_FILE="$REG_ARG"
[ -z "$MSG_ARG" ] || MSG_FILE="$MSG_ARG"

require_jq
[ -f "$REG_FILE" ] || fail_input "$REG_FILE not found — run from the repo root (or pass the registry path)"
[ -f "$MSG_FILE" ] || fail_input "$MSG_FILE not found — run from the repo root (or pass the messages path)"

# Validate the threshold is a number in [0, 1] (jq does the float check; bash
# has no float arithmetic).
threshold_ok="$(jq -n --arg t "$THRESHOLD" 'try ($t | tonumber) catch null | (. != null and . >= 0 and . <= 1)')"
[ "$threshold_ok" = "true" ] || fail_usage "--threshold must be a number between 0 and 1 (got: $THRESHOLD)"

# Validate --since parses as ISO-8601 UTC (strip a ".mmm" fraction first — jq
# 1.8 fromdateiso8601 rejects fractional seconds; same normalization as row
# timestamps). The normalized epoch is also the numeric cutoff the universe
# filter compares against.
since_epoch="$(jq -rn --arg s "$SINCE" 'try (($s | sub("\\.[0-9]+Z$"; "Z")) | fromdateiso8601) catch null')"
[ "$since_epoch" != "null" ] || fail_usage "--since must be an ISO-8601 UTC timestamp, e.g. 2026-08-06T19:30:00Z (got: $SINCE)"

# --- gather rows -----------------------------------------------------------
warn_malformed "$REG_FILE"
warn_malformed "$MSG_FILE"
reg_bad="$(count_malformed "$REG_FILE")"
msg_bad="$(count_malformed "$MSG_FILE")"

# Universe: registry task_success rows (with task_id) at/after --since.
# One projection pass computes the report split:
#   total           — every task_success row (legacy + plugin era)
#   no_id           — rows lacking task_id (schema anomaly, README: set on success)
#   bad_ts          — rows whose timestamp does not parse (skipped + warned)
#   legacy          — valid-timestamp rows BEFORE the cutoff (structurally
#                     unmatchable; excluded from the universe)
#   in_universe     — valid-timestamp rows AT/AFTER the cutoff (report split)
#   universe        — the cross-check set: in_universe rows WITH task_id
#                     (rev-1 finding 2: null-tid rows are excluded so a null
#                     task_id never "matches" a null gen_ai.agent.id — the
#                     summary already reports the no-id counts)
#   universe_no_id  — in_universe rows lacking task_id (schema-anomaly guard)
reg_proj="$(jq -Rrc 'if length == 0 then empty else try fromjson catch empty end' "$REG_FILE" \
  | jq -sc --argjson since "$since_epoch" '
      [.[] | select(.event == "task_success")
       | {tid: .task_id, ts: (try ((.timestamp | sub("\\.[0-9]+Z$"; "Z")) | fromdateiso8601) catch null)}]
      | { total: length,
          no_id: ([.[] | select(.tid == null)] | length),
          bad_ts: ([.[] | select(.ts == null)] | length),
          legacy: ([.[] | select(.ts != null and .ts < $since)] | length),
          in_universe: [.[] | select(.ts != null and .ts >= $since)],
          universe: [.[] | select(.ts != null and .ts >= $since and .tid != null)],
          universe_no_id: ([.[] | select(.ts != null and .ts >= $since and .tid == null)] | length) }')"

reg_total="$(printf '%s' "$reg_proj" | jq -r '.total')"
reg_no_id="$(printf '%s' "$reg_proj" | jq -r '.no_id')"
reg_bad_ts="$(printf '%s' "$reg_proj" | jq -r '.bad_ts')"
reg_legacy="$(printf '%s' "$reg_proj" | jq -r '.legacy')"
reg_rows="$(printf '%s' "$reg_proj" | jq -c '.universe')"
in_universe_all="$(printf '%s' "$reg_proj" | jq -r '.in_universe | length')"
reg_universe="$(printf '%s' "$reg_proj" | jq -r '.universe | length')"
universe_no_id="$(printf '%s' "$reg_proj" | jq -r '.universe_no_id')"

if [ "$reg_bad_ts" -gt 0 ]; then
  echo "warning: $reg_bad_ts registry task_success row(s) have unparseable/missing timestamps — excluded from the universe" >&2
fi

if [ "$reg_total" -eq 0 ]; then
  fail_input "registry has 0 task_success rows — nothing to cross-check (if this is the P5 smoke, the plugin may not be live yet)"
fi
if [ "$in_universe_all" -eq 0 ]; then
  fail_input "registry has 0 in-universe task_success rows at/after --since $SINCE — nothing to cross-check (fail-loud: a vacuous pass could mask a silently dead plugin; all $reg_total task_success rows predate the cutoff)"
fi
if [ "$universe_no_id" -eq "$in_universe_all" ]; then
  fail_input "all $in_universe_all in-universe task_success rows lack task_id — schema anomaly (README: task_id is set on the success path)"
fi

msg_rows="$(jq -Rrc 'if length == 0 then empty else try fromjson catch empty end' "$MSG_FILE" \
  | jq -sc '[.[] | select(.event_type == "delegation") | {tid: (."gen_ai.agent.id" // null), ts: (try ((.timestamp | sub("\\.[0-9]+Z$"; "Z")) | fromdateiso8601) catch null)}]')"

# --- cross-check (one jq pass over both projections) -----------------------
# For each universe row: within = candidate count with same tid + |dt| <= 5s;
# same_id = candidate count with same tid regardless of timestamp.
result="$(jq -n --argjson reg "$reg_rows" --argjson msg "$msg_rows" --argjson tol "$TOLERANCE" '
  ($reg | map(
    . as $r
    | ($msg | map(select(.tid == $r.tid and .ts != null and $r.ts != null and (((.ts - $r.ts) | fabs) <= $tol))) | length) as $within
    | ($msg | map(select(.tid == $r.tid)) | length) as $same_id
    | { within: $within, same_id: $same_id }
  )) as $rows
  | ($rows | length) as $total
  | ($rows | map(select(.within > 0)) | length) as $matched
  | ($rows | map(select(.within == 0 and .same_id > 0)) | length) as $same_id_outside
  | ($rows | map(select(.within == 0 and .same_id == 0)) | length) as $unmatched
  | { total: $total,
      matched: $matched,
      same_id_outside: $same_id_outside,
      unmatched: $unmatched,
      pct: (if $total == 0 then 0 else ($matched / $total) * 100 end) }
')"

matched="$(printf '%s' "$result" | jq -r '.matched')"
same_id_outside="$(printf '%s' "$result" | jq -r '.same_id_outside')"
unmatched="$(printf '%s' "$result" | jq -r '.unmatched')"
pct="$(printf '%s' "$result" | jq -r '.pct')"
msg_deleg="$(printf '%s' "$msg_rows" | jq 'length')"
msg_no_id="$(printf '%s' "$msg_rows" | jq '[.[] | select(.tid == null)] | length')"
# Object count for the registry display (rev-1 finding 3): registry.jsonl is
# plugin-written NDJSON — one JSON object per line — so a jq object count is the
# accurate metric; `wc -l` would undercount a file lacking a trailing newline.
# messages.jsonl keeps the raw line count (the same NDJSON argument applies).
reg_objects="$(jq -Rrc 'if length == 0 then empty else try fromjson catch empty end' "$REG_FILE" | wc -l | tr -d ' ')"
msg_lines="$(wc -l < "$MSG_FILE" | tr -d ' ')"

threshold_num="$(jq -n --arg t "$THRESHOLD" '$t | tonumber')"
target_pct="$(jq -n --argjson t "$threshold_num" '$t * 100')"

# pct is a percentage (0..100 scale); threshold is a fraction (0..1 scale) —
# normalize pct to a fraction before comparing.
verdict="$(jq -rn --argjson p "$pct" --argjson t "$threshold_num" 'if (($p / 100) >= $t) then "PASS" else "FAIL" end')"

# --- summary ---------------------------------------------------------------
echo "=== Registry ↔ Messages Cross-Check ==="
echo "registry:  $REG_FILE ($reg_objects objects; $reg_total task_success, $reg_no_id without task_id)"
echo "messages:  $MSG_FILE ($msg_lines lines; $msg_deleg delegation rows, $msg_no_id without gen_ai.agent.id)"
echo "malformed: registry $reg_bad, messages $msg_bad (warnings above, lines skipped)"
echo
echo "report split (registry task_success, cutoff --since $SINCE):"
echo "  legacy:         $reg_legacy rows before cutoff — pre-plugin orchestrator rows, structurally unmatchable, excluded"
echo "  in-universe:    $in_universe_all rows at/after cutoff — plugin-era rows ($reg_universe in the cross-check set with task_id)"
if [ "$reg_bad_ts" -gt 0 ]; then
  echo "  bad timestamp:  $reg_bad_ts rows with unparseable/missing timestamp (excluded; see warning above)"
fi
echo
echo "universe:         $reg_universe registry task_success rows (in-universe, with task_id)"
echo "matched:          $matched ($(printf '%.1f' "$pct")%) — delegation row with same task_id + timestamp within ${TOLERANCE}s"
echo "  outside ±${TOLERANCE}s: $same_id_outside — same task_id but timestamp delta > ${TOLERANCE}s (NOT counted)"
echo "  unmatched:      $unmatched — no delegation row carries that task_id"
echo "completeness:    $(printf '%.1f' "$pct")% (target >= $(printf '%.1f' "$target_pct")%)"
echo "verdict:         $verdict (exit $([ "$verdict" = "PASS" ] && echo 0 || echo 1))"
echo "=== End Cross-Check ==="

if [ "$verdict" = "PASS" ]; then
  exit 0
else
  exit 1
fi
