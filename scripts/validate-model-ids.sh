#!/usr/bin/env bash
# validate-model-ids.sh - DIA-261022-6vcz: cross-references every
# dispatch-actuating model ID against the live `opencode models` catalog.
# WHY: test-config validated names/skills/contracts but never model IDs, so a
# dead ID (opencode-go/gemini-4-argon-contributor) reached runtime and killed
# the ai-auditor lane.
#
# Sources: every "model" key in .opencode/oh-my-opencode-slim.jsonc (preset
# arrays - ALL elements, since fallbacks also dispatch; agents block; council
# seats) and in .opencode/opencode.jsonc (agent block) -> HARD validation.
# knowledge/model-registry.yaml model_id entries are documentation -> WARN
# only (never read at dispatch; bare-prefix IDs there are known doc drift).
#
# Severity: ID missing while its provider IS listed -> dead ID, exit 1 (with
# nearest prefix match). Provider absent from the catalog entirely (the three
# github-copilot council seats - pre-existing provider-connect issue, out of
# scope) -> WARN: `opencode models` only lists reachable providers, so
# absence proves nothing there.
# SKIP exit 0: `opencode models` unavailable/empty (offline, CLI missing, CI)
# - a validator that hard-fails a cold checkout is worse than none.
# Line scan, not a JSON parse: JSON string values cannot contain raw quotes,
# so only real keys can match; full-line // comments are skipped.
# Exit: 0 pass/skip, 1 invalid dispatch ID, 2 missing config source.
set -euo pipefail

ROOT="${MODEL_IDS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SLIM="$ROOT/.opencode/oh-my-opencode-slim.jsonc"
OCFG="$ROOT/.opencode/opencode.jsonc"
REGISTRY="$ROOT/knowledge/model-registry.yaml"

catalog="$(command -v opencode >/dev/null 2>&1 && opencode models 2>/dev/null || true)"
if [ -z "$catalog" ]; then
  echo "SKIPPED: opencode models unavailable"
  exit 0
fi
for f in "$SLIM" "$OCFG"; do
  [ -f "$f" ] || { echo "FAIL: missing source $f" >&2; exit 2; }
done

# Extract file<TAB>line<TAB>id triples. emit() pulls quoted tokens out of
# "model": [ ... ] spans; the scalar branch handles "model": "id" (incl.
# inline agent objects). Full-line // comments are skipped.
extracted="$(awk '
  function emit(s) {
    while (match(s, /"[^"]+"/)) {
      print FILENAME "\t" FNR "\t" substr(s, RSTART + 1, RLENGTH - 2)
      s = substr(s, RSTART + RLENGTH)
    }
  }
  /^[[:space:]]*\/\// { next }
  {
    if (in_arr) {
      seg = $0
      if (match(seg, /\]/)) { seg = substr(seg, 1, RSTART - 1); in_arr = 0 }
      emit(seg); next
    }
    if (match($0, /"model"[[:space:]]*:[[:space:]]*\[/)) {
      seg = substr($0, RSTART + RLENGTH)
      if (match(seg, /\]/)) { emit(substr(seg, 1, RSTART - 1)) } else { emit(seg); in_arr = 1 }
      next
    }
    if (match($0, /"model"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
      tok = substr($0, RSTART, RLENGTH)
      sub(/^"model"[[:space:]]*:[[:space:]]*"/, "", tok)
      sub(/"$/, "", tok)
      print FILENAME "\t" FNR "\t" tok
    }
  }
' "$SLIM" "$OCFG")"

providers="$(cut -d/ -f1 <<<"$catalog")"
passed=0 failed=0 warned=0

while IFS=$'\t' read -r file line id; do
  [ -n "$id" ] || continue
  if grep -qxF -- "$id" <<<"$catalog"; then passed=$((passed + 1)); continue; fi
  if [[ "$id" != */* ]]; then
    echo "FAIL: $file:$line: model ID '$id' has no provider prefix" >&2
    failed=$((failed + 1))
    continue
  fi
  prov="${id%%/*}"
  if ! grep -qxF -- "$prov" <<<"$providers"; then
    echo "warn: $file:$line: '$id' - provider '$prov' absent from opencode models (unverifiable; provider-connect issue?)" >&2
    warned=$((warned + 1))
    continue
  fi
  near="$(awk -v bad="$id" '(index(bad, $0) == 1 || index($0, bad) == 1) && length($0) > m { m = length($0); best = $0 } END { if (best) print best }' <<<"$catalog")"
  echo "FAIL: $file:$line: invalid model ID '$id'${near:+ (nearest: $near)}" >&2
  failed=$((failed + 1))
done <<< "$extracted"

# Registry model_id entries: documentation only - WARN, never fail.
if [ -f "$REGISTRY" ]; then
  while IFS=: read -r line rest; do
    id="$(sed -n 's/.*model_id:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$rest")"
    [ -n "$id" ] || continue
    if grep -qxF -- "$id" <<<"$catalog"; then passed=$((passed + 1)); continue; fi
    echo "warn: $REGISTRY:$line: registry model_id '$id' not in opencode models (documentation-only)" >&2
    warned=$((warned + 1))
  done < <(grep -n 'model_id:' "$REGISTRY" || true)
fi

echo "$passed passed, $failed failed, $warned warnings"
[ "$failed" -eq 0 ] || exit 1
