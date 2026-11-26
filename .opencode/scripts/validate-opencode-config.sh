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
# edit cannot silently diverge. G1 (DIA-260827-ft3z): every pair member must be
# present with a non-empty permission map first - a missing member used to
# compare nothing and print a green "0 keys compared" line.
if ! node "$LIB" --lockstep "$ROOT/.opencode/opencode.jsonc"; then
  failures=$((failures + 1))
fi

# --- deny-first doc contract (DIA-260827-ft3z check B) ------------------------
# Every agent whose EFFECTIVE bash map is deny-scoped (resolved semantically:
# flat "deny", or a map whose last matching rule for an arbitrary probe is
# deny - G2/G3) must not claim a flat allow in any of its doc surfaces:
# .opencode/agents/<name>.md, the agent's orchestratorPrompt AND prompt fields
# in oh-my-opencode-slim.jsonc (agents + presets), and the live prompt-override
# files .opencode/oh-my-opencode-slim/<name>.md / <name>_append.md. Same block
# also fails an agent whose edit is deny-scoped while its bash map is not
# (tracked-debt exemption set lives beside the check in jsonc-parse.js).
if ! node "$LIB" --doc-drift "$ROOT/.opencode/opencode.jsonc"; then
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  echo "error: $failures config file(s) failed validation." >&2
  exit 1
fi
echo "ok: all OpenCode config files are valid JSONC"
