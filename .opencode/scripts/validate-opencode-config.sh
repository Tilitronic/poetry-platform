#!/usr/bin/env bash
# Validates JSONC syntax of OpenCode config files (`make test-config`).
#
# JSONC = JSON with // and /* */ comments plus trailing commas. Node's
# JSON.parse rejects all three, so we strip comments and trailing commas with a
# small char-level tokenizer that respects string literals — naive regex
# stripping would corrupt URLs such as https://... inside the config.
# The tokenizer lives in lib/jsonc-parse.js, shared with the permission
# lockstep check (coder + analyzer base/escalated pairs, DIA-260825-nts7 F2 +
# DIA-260827-ft3z check A) and the deny-first doc-contract check
# (DIA-260827-ft3z check B).
#
# Exit codes: 0 all valid, 1 validation failure, 2 node unavailable.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/.opencode/scripts/lib/jsonc-parse.js"

FILES=(
  "$ROOT/.opencode/opencode.jsonc"
  "$ROOT/.opencode/oh-my-opencode-slim.jsonc"
  "$ROOT/.opencode/tui.json"
  # DIA-126(a) overnight permission profile (2026-08-13): validated alongside
  # the main configs so a syntax error in the hardened profile fails test-config.
  "$ROOT/.opencode/opencode-overnight.jsonc"
)

if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required to validate JSONC configs." >&2
  exit 2
fi

failures=0
for file in "${FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "FAIL  missing: $file"
    failures=$((failures + 1))
    continue
  fi
  if node "$LIB" "$file"; then
    echo "ok: $file"
  else
    echo "FAIL  invalid JSONC: $file"
    failures=$((failures + 1))
  fi
done

# --- permission lockstep (DIA-260825-nts7 F2, DIA-260827-ft3z check A) -------
# coder-escalated is documented as an exact clone of the base coder permission
# map plus task-related keys; analyzer-escalated is documented as an exact
# clone of base analyzer. Neither was enforced and the coder maps already
# drifted (reviewer finding). Fail test-config on any drift so the next clone
# edit cannot silently diverge.
if ! node "$LIB" --lockstep "$ROOT/.opencode/opencode.jsonc"; then
  failures=$((failures + 1))
fi

# --- deny-first doc contract (DIA-260827-ft3z check B) ------------------------
# Every agent whose configured bash map is deny-first must not claim a flat
# allow in its docs: .opencode/agents/<name>.md (if present) and the agent's
# orchestratorPrompt in oh-my-opencode-slim.jsonc (if present). Drift class
# seen twice in one session; no gate compared these surfaces before.
if ! node "$LIB" --doc-drift "$ROOT/.opencode/opencode.jsonc"; then
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  echo "error: $failures config file(s) failed validation." >&2
  exit 1
fi
echo "ok: all OpenCode config files are valid JSONC"
