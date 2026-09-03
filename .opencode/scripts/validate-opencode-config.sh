#!/usr/bin/env bash
# Validates JSONC syntax of OpenCode config files (`make test-config`).
#
# JSONC = JSON with // and /* */ comments plus trailing commas. Node's
# JSON.parse rejects all three, so we strip comments and trailing commas with a
# small char-level tokenizer that respects string literals — naive regex
# stripping would corrupt URLs such as https://... inside the config.
# The tokenizer lives in lib/jsonc-parse.js, shared with the coder/coder-
# escalated permission lockstep check below (DIA-260825-nts7 fix-all F2).
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

# --- coder / coder-escalated permission lockstep (DIA-260825-nts7 F2) --------
# coder-escalated is documented in opencode.jsonc as an exact clone of the
# base coder permission map plus task-related keys. Nothing enforced that and
# the maps drifted (reviewer finding). Fail test-config on any drift so the
# next clone edit cannot silently diverge.
if ! node "$LIB" --lockstep "$ROOT/.opencode/opencode.jsonc"; then
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  echo "error: $failures config file(s) failed validation." >&2
  exit 1
fi
echo "ok: all OpenCode config files are valid JSONC"
