#!/usr/bin/env bash
# overnight.sh - launch an autonomous overnight opencode session with the
# hardened DIA-126(a) permission profile (Option A full, developer-approved
# 2026-08-13).
#
# Usage:
#   scripts/overnight.sh                  interactive TUI (opencode --auto)
#   scripts/overnight.sh run "prompt..."  scripted run (opencode run --auto)
#   scripts/overnight.sh [opencode flags] passthrough (e.g. -s <session>)
#   scripts/overnight.sh -h|--help        show usage
#
# WHY (the DIA-126 overnight stall/destruction problem):
#   An unattended run uses `opencode --auto`, which auto-approves every
#   ASK-level permission. The interactive profile keeps rm / rm -rf / rmdir /
#   chmod / chown at ASK so a human confirms destructive commands; under
#   --auto that gate disappears. This wrapper re-asserts DENY for exactly
#   those five rules. DENY is enforced even in auto mode (OpenCode short-
#   circuits on deny before any auto-approval).
#
# WHY OPENCODE_PERMISSION (not a plain OPENCODE_CONFIG permission block):
#   Config files are deep-merged in load order (global -> OPENCODE_CONFIG ->
#   project files -> .opencode/ directory files) and the LAST file wins
#   conflicting keys, so the project .opencode/opencode.jsonc clobbers any
#   permission rule an OPENCODE_CONFIG override declares. OPENCODE_PERMISSION
#   is deep-merged into the final permission object AFTER all config files
#   and therefore wins (verified 2026-08-13 with `opencode debug config`:
#   the five rules resolve to deny, all other rules stay byte-identical).
#
# SAFETY INVARIANT (fail closed): if the hardened permission payload cannot
#   be extracted from the profile, the script exits 1 and NEVER launches
#   opencode. An overnight run without the hardened rules would auto-approve
#   destructive commands.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERNIGHT_CONFIG="$PROJECT_ROOT/.opencode/opencode-overnight.jsonc"
NODE_BIN="${NODE_BIN:-node}"

usage() {
  cat <<'USAGE'
overnight.sh - autonomous overnight opencode session with the DIA-126(a)
hardened permission profile (rm / rm -rf / rmdir / chmod / chown -> DENY;
--auto auto-approves everything else).

Usage:
  scripts/overnight.sh                  interactive TUI (opencode --auto)
  scripts/overnight.sh run "prompt..."  scripted run (opencode run --auto)
  scripts/overnight.sh [opencode flags] passthrough (e.g. -s <session>)
  scripts/overnight.sh -h|--help        show this usage

The hardened profile lives at .opencode/opencode-overnight.jsonc and is
enforced via OPENCODE_PERMISSION (highest-precedence permission overlay).
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ ! -f "$OVERNIGHT_CONFIG" ]; then
  echo "error: overnight profile not found: $OVERNIGHT_CONFIG" >&2
  exit 1
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "error: opencode not found on PATH" >&2
  exit 1
fi

# Extract the permission block from the JSONC profile. Same char-level
# tokenizer as .opencode/scripts/validate-opencode-config.sh (string-aware,
# comment and trailing-comma tolerant) so the profile stays the single
# source of truth for the hardened rules. Node is required (the config
# validation gate already depends on it).
PERMISSION_JSON="$("$NODE_BIN" - "$OVERNIGHT_CONFIG" <<'NODE'
const fs = require('fs');
const src = fs.readFileSync(process.argv[2], 'utf8');
let out = '';
let inString = null;
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
  if (c === ',') {
    let j = i + 1;
    while (j < src.length && /\s/.test(src[j])) j++;
    if (src[j] === '}' || src[j] === ']') continue;
    out += c;
    continue;
  }
  out += c;
}
const parsed = JSON.parse(out);
process.stdout.write(JSON.stringify(parsed.permission !== undefined ? parsed.permission : null));
NODE
)" || {
  echo "error: failed to extract the permission block from $OVERNIGHT_CONFIG (node required)" >&2
  exit 1
}

if [ -z "$PERMISSION_JSON" ] || [ "$PERMISSION_JSON" = "null" ]; then
  echo "error: no permission block found in $OVERNIGHT_CONFIG; refusing to launch unhardened" >&2
  exit 1
fi

export OPENCODE_CONFIG="$OVERNIGHT_CONFIG"
export OPENCODE_PERMISSION="$PERMISSION_JSON"

echo "=== overnight opencode session (DIA-126(a) hardened profile) ==="
echo "profile : $OVERNIGHT_CONFIG"
echo "auto    : on (--auto: ask-level permissions auto-approved)"
echo "hardened: rm / rm -rf / rmdir / chmod / chown -> DENY (enforced in auto mode)"
echo "merge   : OPENCODE_PERMISSION applied after all config files (project config cannot clobber it)"

if [ "${1:-}" = "run" ]; then
  shift
  exec opencode run --auto --title "overnight autonomous run (DIA-126 hardened)" "$@"
fi

exec opencode --auto "$@"
