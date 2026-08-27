#!/usr/bin/env bash
# DIA-260821-5r03: observer duplicate-registration dedupe gate (make test-config).
#
# Enforces the single-source-of-truth invariant: observer plugins load ONLY via
# auto-discovery of .opencode/plugins/*.ts. No config layer may contain an
# explicit plugin-array entry whose resolved basename matches an auto-discovered
# observer (that would double-load it: explicit + auto-discovery), nor may the
# same basename appear twice within one array.
#
# JSONC note: the config files are JSONC (// and /* */ comments + trailing
# commas). jq cannot parse JSONC, so we strip comments with a small string-aware
# node snippet (mirrors .opencode/scripts/lib/jsonc-parse.js, used by
# validate-opencode-config.sh). The resolution + duplicate logic is pure jq, so
# no new dependency is introduced beyond node (already required by test-config).
#
# Exit codes: 0 no duplicate registration, 1 duplicate found, 2 infra error.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="$ROOT/.opencode/plugins"

# --- Auto-discovered observer basenames (canonical: strip .ts/.js) -----------
observed=""
if [ -d "$PLUGINS_DIR" ]; then
  # Indexed array (bash-3 safe). Collect every *.ts / *.js in the plugins dir.
  files=""
  for f in "$PLUGINS_DIR"/*.ts "$PLUGINS_DIR"/*.js; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    # canonical: drop .ts/.js
    b="${b%.ts}"
    b="${b%.js}"
    if [ -z "$files" ]; then
      files="$b"
    else
      files="$files
$b"
    fi
  done
  observed="$(printf '%s\n' "$files" | grep -v '^$' | jq -R . | jq -s .)"
else
  observed="[]"
fi

# --- Config layers to inspect -------------------------------------------------
CONFIGS=(
  "$ROOT/.opencode/opencode.jsonc"
  "$ROOT/.opencode/oh-my-opencode-slim.jsonc"
  "$ROOT/.opencode/tui.json"
  "$ROOT/tools/opencode-docker/config/opencode.json"
)

# Emit the plugin array (array of strings) as JSON. JSONC comment-stripping via
# node (jq cannot parse JSONC). Returns "[]" when .plugin is absent.
plugin_array() {
  node -e '
    const fs = require("fs");
    const src = fs.readFileSync(process.argv[1], "utf8");
    let out = "", inStr = null, line = false, block = false;
    for (let i = 0; i < src.length; i++) {
      const c = src[i], n = src[i + 1];
      if (line) { if (c === "\n") { line = false; out += c; } continue; }
      if (block) { if (c === "*" && n === "/") { block = false; i++; } continue; }
      if (inStr) {
        if (c === "\\") { out += c + (n || ""); i++; continue; }
        out += c; if (c === inStr) inStr = null; continue;
      }
      if (c === "\"" || c === "'\''") { inStr = c; out += c; continue; }
      if (c === "/" && n === "/") { line = true; i++; continue; }
      if (c === "/" && n === "*") { block = true; i++; continue; }
      if (c === ",") {
        let j = i + 1;
        while (j < src.length && /\s/.test(src[j])) j++;
        if (src[j] === "}" || src[j] === "]") continue;
        out += c; continue;
      }
      out += c;
    }
    const cfg = JSON.parse(out);
    process.stdout.write(JSON.stringify(Array.isArray(cfg.plugin) ? cfg.plugin : []));
  ' "$1"
}

fail=0
for cfg in "${CONFIGS[@]}"; do
  [ -f "$cfg" ] || continue
  arr_json="$(plugin_array "$cfg")"
  # Resolve each entry to a canonical basename and flag duplicates:
  #   within_dup  - same basename twice in this array
  #   explicit_dup - a basename matches an auto-discovered observer
  check="$(printf '%s' "$arr_json" | jq -c --argjson obs "$observed" '
    def canon:
      gsub("^file://"; "")
      | gsub("^\\./"; "")
      | split("/") | last
      | gsub("@[^/]*$"; "")
      | sub("\\.(ts|js)$"; "");
    map(canon) as $names
    | ($names | length) as $n
    | ($names | unique | length) as $u
    | ([$names[] | select(. as $x | $obs | index($x))] | length) as $e
    | {names: $names, within_dup: ($n != $u), explicit_dup: ($e > 0)}
  ')"
  within_dup="$(printf '%s' "$check" | jq -r '.within_dup')"
  explicit_dup="$(printf '%s' "$check" | jq -r '.explicit_dup')"
  if [ "$within_dup" = "true" ] || [ "$explicit_dup" = "true" ]; then
    echo "FAIL  duplicate observer registration in: $cfg"
    echo "      resolved plugin basenames: $(printf '%s' "$check" | jq -c '.names')"
    if [ "$explicit_dup" = "true" ]; then
      echo "      an explicit entry matches an auto-discovered observer in .opencode/plugins/"
    fi
    if [ "$within_dup" = "true" ]; then
      echo "      a basename appears more than once in this plugin array"
    fi
    fail=1
  else
    echo "ok:   no duplicate observer registration in: $cfg"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "error: observer duplicate-registration gate failed." >&2
  exit 1
fi
echo "ok: observer duplicate-registration gate passed"
exit 0
