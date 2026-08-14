#!/usr/bin/env bash
# Mechanical orchestrator-prompt drift checker (DIA-097). Greps the 3 preset
# orchestrator prompts (opencode-go / cebula / free) in
# .opencode/oh-my-opencode-slim.jsonc for REQUIRED delegation-rule markers and
# fails the config gate when any marker is missing from any prompt. Runs from
# `make test-config`; SLIM_JSONC env override keeps it hermetically testable
# against fixture trees (same pattern as validate-decision-variants.sh).
#
# WHY this gate exists: the orchestrator prompts are the only enforcement
# surface for the delegation-only operating rules (DIA-082/083/091/093/097).
# When a rule lands in AGENTS.md/NEXT-RUN.md but is never mirrored into the
# prompts, the orchestrator silently loses the guidance at runtime - "no test
# fails, but delegation behavior regresses" (DIA-045 drift class). This script
# makes that drift mechanically visible.
#
# Required markers (DIA-097 lane scope, current as of 2026-08-13; marker set
# EXTENDED 2026-08-13 by the ai-auditor Minor fix to also lock the DIA-097-added
# content - the DIA-126a read-scope note, the EBDV (DIA-115) clause, and the
# 30/50 threshold text - so future drift of THOSE phrases fails the gate too):
#   delegation-only   role boundary: orchestrator delegates, never executes
#   batch-approval    boot gate: prognosis presented before any delegation
#   DIA-133           registry pointer: consult model-registry.yaml before
#                     escalated dispatch (quota-guard policy)
#   pure-dispatch     PURE-DISPATCH rule A1: task() is the sole tool call
#                     (matched case-insensitively - the prompts write
#                     PURE-DISPATCH)
#   no bash tool      bash-delegation pattern: orchestrator has no bash by
#                     design (DIA-091/093)
#   READ-SCOPE        DIA-126a read-scope note: read/glob allow-list expanded
#                     2026-08-13; see the .opencode/opencode.jsonc orchestrator
#                     permission block for the authoritative list
#   EBDV              DIA-115 evidence-backed decision variants clause: >=2
#                     genuine options each carrying evidence, abort/status-quo
#                     always included, recommendation + chosen record
#   >=30% (primary)   self-rerun threshold text: >=30% (primary) / >=50%
#                     (safety-net) context per NEXT-RUN.md
#
# The marker set is a FIXED contract, not configurable per run - a future
# rule that must live in every orchestrator prompt is appended to MARKERS
# here (and to the prompts) so the gate catches it. PRESETS override exists
# only so bats fixtures can drive the checker against throwaway trees.
#
# Stream contract (mirrors validate-decision-variants.sh): `FAIL:`/`warn:` to
# stderr, `ok:` to stdout, final summary line to stdout.
#
# Exit codes: 0 every prompt carries every marker, 1 a marker (or an entire
# prompt) is missing, 2 INFRA (config file missing / python3 unavailable).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLIM_JSONC="${SLIM_JSONC:-$ROOT/.opencode/oh-my-opencode-slim.jsonc}"
# The 3 presets whose orchestrator prompts are under audit (DIA-097).
PRESETS="${PRESETS:-opencode-go cebula free}"

# Fixed required-marker contract (see header). Matched as fixed strings;
# pure-dispatch additionally case-insensitive (PURE-DISPATCH in the prompts).
MARKERS=(delegation-only batch-approval DIA-133 pure-dispatch no-bash-tool \
  read-scope-note ebdv-clause threshold-30-50)
# The MARKERS tokens stay hyphenated/whitespace-safe; the needles below spell
# out the exact prompt phrases they match (verified present in all 3 prompts
# as of 2026-08-13 - including the DIA-097 additions the ai-auditor Minor
# locks: the DIA-126a READ-SCOPE note, the EBDV (DIA-115) clause, and the
# 30/50 threshold text).
NO_BASH_MARKER="no bash tool"
READ_SCOPE_NOTE_MARKER="READ-SCOPE"
EBDV_CLAUSE_MARKER="EBDV"
THRESHOLD_MARKER="30% (primary)"

if [ ! -f "$SLIM_JSONC" ]; then
  echo "FAIL: oh-my-opencode-slim.jsonc not found: $SLIM_JSONC (run from the repo root or set SLIM_JSONC)" >&2
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to parse JSONC configs." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Extraction: python3 JSONC parser (char-level comment/trailing-comma stripper,
# same rationale as validate-opencode-config.sh) walks presets.<name>
# .orchestrator.prompt for the requested presets. Writes NUL-delimited records
# "name<NUL>prompt<NUL>" to a temp file - the prompts may contain newlines
# after JSON unescaping, so NUL framing (not line framing) keeps record
# boundaries unambiguous, and a FILE (not a command-substitution variable)
# preserves the NUL bytes that bash variables would strip.
# A preset that exists in PRESETS but not in the config emits an EMPTY prompt,
# which the bash loop below turns into a FAIL (prompt missing entirely).
# ---------------------------------------------------------------------------
records_file="$(mktemp)"
trap 'rm -f "$records_file"' EXIT
SLIM_PRESETS="$PRESETS" python3 - "$SLIM_JSONC" > "$records_file" <<'PYEOF'
import json
import os
import sys


def strip_jsonc(src):
    """Char-level JSONC comment/trailing-comma stripper (string-aware).

    Comments (// and /* */) are removed only when outside string literals, and
    trailing commas before } or ] are dropped - mirroring the node tokenizer in
    .opencode/scripts/validate-opencode-config.sh. URLs (https://...) survive
    because the '/' inside a string never enters comment-scanning.
    """
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


try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.loads(strip_jsonc(f.read()))
except Exception as exc:
    print(f"JSONC parse failed: {exc}", file=sys.stderr)
    sys.exit(1)

presets = data.get("presets") or {}
for name in os.environ["SLIM_PRESETS"].split():
    prompt = ""
    block = presets.get(name) or {}
    orch = block.get("orchestrator") or {}
    if isinstance(orch.get("prompt"), str):
        prompt = orch["prompt"]
    sys.stdout.write(name + "\0" + prompt + "\0")
PYEOF

checked=0
missing=0
while IFS= read -r -d '' preset && IFS= read -r -d '' prompt; do
  checked=$((checked + 1))

  if [ -z "$prompt" ]; then
    echo "FAIL: $preset: orchestrator prompt missing entirely" >&2
    missing=$((missing + 1))
    continue
  fi

  for marker in "${MARKERS[@]}"; do
    needle="$marker"
    case "$marker" in
      no-bash-tool)    needle="$NO_BASH_MARKER" ;;
      read-scope-note) needle="$READ_SCOPE_NOTE_MARKER" ;;
      ebdv-clause)     needle="$EBDV_CLAUSE_MARKER" ;;
      threshold-30-50) needle="$THRESHOLD_MARKER" ;;
    esac
    if [ "$marker" = "pure-dispatch" ]; then
      # PURE-DISPATCH (uppercase) in the prompts; match case-insensitively.
      if ! printf '%s' "$prompt" | grep -qiF -- "$needle"; then
        echo "FAIL: $preset: missing required marker '$needle'" >&2
        missing=$((missing + 1))
      fi
    else
      if ! printf '%s' "$prompt" | grep -qF -- "$needle"; then
        echo "FAIL: $preset: missing required marker '$needle'" >&2
        missing=$((missing + 1))
      fi
    fi
  done
done < "$records_file"

if [ "$missing" -gt 0 ]; then
  echo "FAIL: check-orchestrator-prompt-drift: $checked preset(s) checked, $missing marker gap(s)" >&2
  exit 1
fi

echo "ok: check-orchestrator-prompt-drift: $checked preset(s) checked, ${#MARKERS[@]} markers each, 0 gaps"
exit 0
