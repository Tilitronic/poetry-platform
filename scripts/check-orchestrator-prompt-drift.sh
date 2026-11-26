#!/usr/bin/env bash
# Mechanical orchestrator-prompt drift checker (DIA-097). Reads the SINGLE
# hoisted orchestrator prompt (.opencode/oh-my-opencode-slim/orchestrator.md,
# DIA-261126-q9r9 / ADR 16) for REQUIRED delegation-rule markers and fails the
# config gate when any marker is missing. It also fails when either audited
# preset (mimo-balanced / openai-first-cost-balanced) reappears in
# .opencode/oh-my-opencode-slim.jsonc carrying an INLINE orchestrator.prompt:
# OMO 3.0.7 resolves inlinePrompt ?? filePrompt, so an inline copy silently
# overrides the md file and the marker check above would guard the wrong text.
# Runs from `make test-config`; SLIM_JSONC / ORCH_PROMPT_MD env overrides keep it
# hermetically testable against fixture trees (same pattern as
# validate-decision-variants.sh).
#
# WHY this gate exists: the orchestrator prompt is the only enforcement
# surface for the delegation-only operating rules (DIA-082/083/091/093/097).
# When a rule lands in AGENTS.md/NEXT-RUN.md but is never mirrored into the
# prompt, the orchestrator silently loses the guidance at runtime - "no test
# fails, but delegation behavior regresses" (DIA-045 drift class). This script
# makes that drift mechanically visible.
#
# Required markers (DIA-097 lane scope, current as of 2026-08-13; marker set
# EXTENDED 2026-08-13 by the ai-auditor Minor fix to also lock the DIA-097-added
# content - the DIA-126a read-scope note, the EBDV (DIA-115) clause, and the
# 15/25 threshold text - so future drift of THOSE phrases fails the gate too):
#   delegation-only   role boundary: orchestrator delegates, never executes
#   DIA-133           registry pointer: consult model-registry.yaml before
#                     a quota-metered dispatch (quota-guard policy)
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
#   >=15% (primary)   self-rerun threshold text: >=15% (primary) / >=25%
#                     (safety-net) context per NEXT-RUN.md
#   todowrite-        todowrite discipline (DIA-260819-880v): todowrite for
#   discipline        >=3-step work, one in_progress, mid-stream updates,
#                     terminal-state gate
#
# The marker set is a FIXED contract, not configurable per run - a future
# rule that must live in every orchestrator prompt is appended to MARKERS
# here (and to the prompt file) so the gate catches it. PRESETS override exists
# only so the preset-lockstep check can be scoped by bats fixtures.
#
# Stream contract (mirrors validate-decision-variants.sh): `FAIL:`/`warn:` to
# stderr, `ok:` to stdout, final summary line to stdout.
#
# Exit codes: 0 prompt carries every marker and no preset carries an inline
# copy, 1 a marker is missing / the prompt file is missing / a preset is absent
# / an inline prompt reappeared, 2 INFRA (config file missing / python3
# unavailable).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLIM_JSONC="${SLIM_JSONC:-$ROOT/.opencode/oh-my-opencode-slim.jsonc}"
# Single source of truth for the orchestrator prompt (ADR 16 hoist).
ORCH_PROMPT_MD="${ORCH_PROMPT_MD:-$ROOT/.opencode/oh-my-opencode-slim/orchestrator.md}"
# The 2 presets that used to carry inline orchestrator prompts (DIA-097).
# Inventory truth (DIA-260929-5c6m, 2026-09-29): the config carries exactly
# these 2 presets. They must still exist AND must not carry an inline prompt.
PRESETS="${PRESETS:-mimo-balanced openai-first-cost-balanced}"

# Fixed required-marker contract (see header). Matched as fixed strings;
# pure-dispatch additionally case-insensitive (PURE-DISPATCH in the prompts).
# DIA-261126-q9r9 (ADR 16): the batch-approval marker was dropped in the same
# commit that deleted the boot gate and replaced it with the manual
# /make-handoff + /read-handoff pair - a marker for a retired mechanism would
# otherwise force dead text back into the prompt.
MARKERS=(delegation-only DIA-133 pure-dispatch no-bash-tool \
  read-scope-note ebdv-clause threshold-15-25 todowrite-discipline)
# The MARKERS tokens stay hyphenated/whitespace-safe; the needles below spell
# out the exact prompt phrases they match (verified present in the orchestrator
# prompt as of 2026-09-17 - including the DIA-097 additions the ai-auditor
# Minor locks: the DIA-126a READ-SCOPE note, the EBDV (DIA-115) clause, and the
# 15/25 threshold text).
NO_BASH_MARKER="no bash tool"
READ_SCOPE_NOTE_MARKER="READ-SCOPE"
EBDV_CLAUSE_MARKER="EBDV"
THRESHOLD_MARKER="15% (primary)"
TODOWRITE_MARKER="TODOWRITE DIA-260819-880v"

if [ ! -f "$SLIM_JSONC" ]; then
  echo "FAIL: oh-my-opencode-slim.jsonc not found: $SLIM_JSONC (run from the repo root or set SLIM_JSONC)" >&2
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to parse JSONC configs." >&2
  exit 2
fi

# A missing prompt file is a CONFIG defect (the prompt is simply gone at
# runtime), so it exits 1 like a marker gap - not 2 (INFRA).
if [ ! -f "$ORCH_PROMPT_MD" ]; then
  echo "FAIL: orchestrator prompt missing entirely: $ORCH_PROMPT_MD (set ORCH_PROMPT_MD)" >&2
  exit 1
fi

preset_count=0
for _preset in $PRESETS; do preset_count=$((preset_count + 1)); done

# Preset lockstep: every audited preset must still exist, and NONE may carry an
# inline orchestrator.prompt (the silent-override hazard this gate exists for).
# python3 JSONC parser is the same char-level comment/trailing-comma stripper as
# validate-opencode-config.sh; it only READS the config now - the prompt text
# comes from the md file.
if ! SLIM_PRESETS="$PRESETS" python3 - "$SLIM_JSONC" "$ORCH_PROMPT_MD" <<'PYEOF'
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

prompt_md = sys.argv[2]
presets = data.get("presets") or {}
bad = 0
for name in os.environ["SLIM_PRESETS"].split():
    block = presets.get(name)
    if not isinstance(block, dict):
        print(f"FAIL: {name}: preset missing from config", file=sys.stderr)
        bad += 1
        continue
    orch = block.get("orchestrator")
    if isinstance(orch, dict) and "prompt" in orch:
        print(
            f"FAIL: {name}: inline orchestrator.prompt present - it silently "
            f"overrides {prompt_md} (delete the key; edit the md file)",
            file=sys.stderr,
        )
        bad += 1

sys.exit(1 if bad else 0)
PYEOF
then
  echo "FAIL: check-orchestrator-prompt-drift: $preset_count preset(s) checked, preset/inline-prompt defect(s) found" >&2
  exit 1
fi

prompt="$(cat "$ORCH_PROMPT_MD")"
missing=0
for marker in "${MARKERS[@]}"; do
  needle="$marker"
  case "$marker" in
    no-bash-tool)          needle="$NO_BASH_MARKER" ;;
    read-scope-note)       needle="$READ_SCOPE_NOTE_MARKER" ;;
    ebdv-clause)           needle="$EBDV_CLAUSE_MARKER" ;;
    threshold-15-25)       needle="$THRESHOLD_MARKER" ;;
    todowrite-discipline)  needle="$TODOWRITE_MARKER" ;;
  esac
  if [ "$marker" = "pure-dispatch" ]; then
    # PURE-DISPATCH (uppercase) in the prompt; match case-insensitively.
    if ! printf '%s' "$prompt" | grep -qiF -- "$needle"; then
      echo "FAIL: orchestrator prompt: missing required marker '$needle'" >&2
      missing=$((missing + 1))
    fi
  else
    if ! printf '%s' "$prompt" | grep -qF -- "$needle"; then
      echo "FAIL: orchestrator prompt: missing required marker '$needle'" >&2
      missing=$((missing + 1))
    fi
  fi
done

if [ "$missing" -gt 0 ]; then
  echo "FAIL: check-orchestrator-prompt-drift: $preset_count preset(s) checked, $missing marker gap(s)" >&2
  exit 1
fi

echo "ok: check-orchestrator-prompt-drift: $preset_count preset(s) checked, ${#MARKERS[@]} markers each, 0 gaps, single source orchestrator.md, no inline prompt"
exit 0
