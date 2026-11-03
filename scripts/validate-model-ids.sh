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
# nearest prefix match). Provider absent from the catalog entirely -> exit 1
# (a typo'd prefix such as "opencode-goo/..." must fail the gate, not slip
# through as a warning), EXCEPT providers on the explicit
# KNOWN_DISCONNECTED_PROVIDERS allowlist (the three github-copilot council
# seats - pre-existing provider-connect issue), which stay WARN: `opencode
# models` only lists reachable providers, so absence proves nothing for a
# provider known to be disconnected.
# SKIP exit 0: `opencode models` unavailable/empty (offline, CLI missing, CI)
# - a validator that hard-fails a cold checkout is worse than none.
# Line scan, not a JSON parse: JSON string values cannot contain raw quotes,
# so only real keys can match; // and /* */ comments are stripped first by a
# quote-respecting char-level stripper (reuse: audit-agent-tool-coverage.sh
# strip_jsonc), so inline comments cannot contribute quoted strings.
# Exit: 0 pass/skip, 1 invalid dispatch ID, 2 missing config source.
set -euo pipefail

ROOT="${MODEL_IDS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SLIM="$ROOT/.opencode/oh-my-opencode-slim.jsonc"
OCFG="$ROOT/.opencode/opencode.jsonc"
REGISTRY="$ROOT/knowledge/model-registry.yaml"

# Named allowlist of known-disconnected providers: newline-separated prefixes
# whose seats we KNOW are disconnected from this host's `opencode models`
# (the github-copilot council seats - pre-existing provider-connect issue).
# Only these stay WARN on provider absence; any OTHER unknown/typo'd prefix
# is a hard failure.
KNOWN_DISCONNECTED_PROVIDERS="github-copilot"

catalog="$(command -v opencode >/dev/null 2>&1 && opencode models 2>/dev/null || true)"
if [ -z "$catalog" ]; then
  echo "SKIPPED: opencode models unavailable"
  exit 0
fi
for f in "$SLIM" "$OCFG"; do
  [ -f "$f" ] || { echo "FAIL: missing source $f" >&2; exit 2; }
done

# Strip comments BEFORE quoted-string extraction, so an inline // tail or a
# /* */ block on a "model" line can never contribute quoted strings (false
# positives) and a real ID next to a comment is still checked. REUSE: the
# char-level quote-respecting JSONC stripper (strip_jsonc) copied verbatim
# from scripts/audit-agent-tool-coverage.sh lines 93-139 (the same pattern
# mirrors validate-opencode-config.sh). One documented adaptation: newlines
# inside a removed /* */ block are re-emitted so FNR line numbers in FAIL
# messages still point at the original file line. Output lands in a temp dir
# (removed on exit); original paths are restored by extract_file below.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
python3 - "$SLIM" "$OCFG" "$tmpdir" <<'PYEOF'
import os
import sys


def strip_jsonc(src):
    """Char-level JSONC comment/trailing-comma stripper (mirrors
    validate-opencode-config.sh; copied from audit-agent-tool-coverage.sh
    lines 93-139). Comments are removed only outside string
    literals; URLs (https://...) survive because '/' inside a string never
    enters comment-scanning. Adaptation: newlines inside a removed block
    comment are re-emitted, preserving line numbers for FNR reporting."""
    out = []
    i = 0
    n = len(src)
    in_string = None
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if in_string:
            out.append(c)
            if c == "\\":
                i += 1
                if i < n:
                    out.append(src[i])
            elif c == in_string:
                in_string = None
            i += 1
            continue
        if c in "\"'":
            in_string = c
            out.append(c)
            i += 1
            continue
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                if src[i] == "\n":
                    out.append("\n")
                i += 1
            i += 2
            continue
        if c == ",":
            j = i + 1
            while j < n and src[j].isspace():
                j += 1
            if j < n and src[j] in "}]":
                i += 1
                continue
        out.append(c)
        i += 1
    return "".join(out)


slim_path, ocfg_path, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
for src_path, out_name in ((slim_path, "slim.jsonc"), (ocfg_path, "ocfg.jsonc")):
    with open(src_path, encoding="utf-8") as fh:
        stripped = strip_jsonc(fh.read())
    with open(os.path.join(outdir, out_name), "w", encoding="utf-8") as fh:
        fh.write(stripped)
PYEOF

# Extract file<TAB>line<TAB>id triples from the comment-stripped copies.
# emit() pulls quoted tokens out of "model": [ ... ] spans; the scalar branch
# handles "model": "id" (incl. inline agent objects). -v orig= restores the
# real config path in the output (the awk runs on stripped temp copies).
extract_file() { # <original-path> <stripped-copy>
  awk -v orig="$1" '
  function emit(s) {
    while (match(s, /"[^"]+"/)) {
      print orig "\t" FNR "\t" substr(s, RSTART + 1, RLENGTH - 2)
      s = substr(s, RSTART + RLENGTH)
    }
  }
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
      print orig "\t" FNR "\t" tok
    }
  }
  ' "$2"
}
extracted="$(extract_file "$SLIM" "$tmpdir/slim.jsonc"; extract_file "$OCFG" "$tmpdir/ocfg.jsonc")"

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
    if grep -qxF -- "$prov" <<<"$KNOWN_DISCONNECTED_PROVIDERS"; then
      echo "warn: $file:$line: '$id' - provider '$prov' absent from opencode models (allowlisted known-disconnected provider; unverifiable)" >&2
      warned=$((warned + 1))
      continue
    fi
    echo "FAIL: $file:$line: invalid model ID '$id' - provider '$prov' absent from opencode models (typo'd prefix? not on the KNOWN_DISCONNECTED_PROVIDERS allowlist)" >&2
    failed=$((failed + 1))
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
