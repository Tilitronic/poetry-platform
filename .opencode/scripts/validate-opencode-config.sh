#!/usr/bin/env bash
# Validates JSONC syntax of OpenCode config files (`make test-config`).
#
# JSONC = JSON with // and /* */ comments plus trailing commas. Node's
# JSON.parse rejects all three, so we strip comments and trailing commas with a
# small char-level tokenizer that respects string literals — naive regex
# stripping would corrupt URLs such as https://... inside the config.
#
# Exit codes: 0 all valid, 1 validation failure, 2 node unavailable.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

FILES=(
  "$ROOT/.opencode/opencode.jsonc"
  "$ROOT/.opencode/oh-my-opencode-slim.jsonc"
  "$ROOT/.opencode/dcp.jsonc"
  "$ROOT/.opencode/tui.json"
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
  if node - "$file" <<'NODE'
const fs = require('fs');

const src = fs.readFileSync(process.argv[2], 'utf8');
let out = '';
let inString = null;     // quote char (' or ") when inside a string literal
let inLineComment = false;
let inBlockComment = false;

for (let i = 0; i < src.length; i++) {
  const c = src[i];
  const n = src[i + 1];

  if (inLineComment) {
    if (c === '\n') { inLineComment = false; out += c; }
    continue;
  }
  if (inBlockComment) {
    if (c === '*' && n === '/') { inBlockComment = false; i++; }
    continue;
  }
  if (inString) {
    if (c === '\\') { out += c + (n || ''); i++; continue; }
    out += c;
    if (c === inString) inString = null;
    continue;
  }
  if (c === '"' || c === "'") { inString = c; out += c; continue; }
  if (c === '/' && n === '/') { inLineComment = true; i++; continue; }
  if (c === '/' && n === '*') { inBlockComment = true; i++; continue; }
  // trailing comma: drop ',' when the next non-whitespace char is } or ]
  if (c === ',') {
    let j = i + 1;
    while (j < src.length && /\s/.test(src[j])) j++;
    if (src[j] === '}' || src[j] === ']') continue;
    out += c;
    continue;
  }
  out += c;
}

JSON.parse(out);
NODE
  then
    echo "ok: $file"
  else
    echo "FAIL  invalid JSONC: $file"
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "error: $failures config file(s) failed validation." >&2
  exit 1
fi
echo "ok: all OpenCode config files are valid JSONC"
