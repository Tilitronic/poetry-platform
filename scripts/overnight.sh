#!/usr/bin/env bash
# overnight.sh - launch an autonomous overnight opencode session with the
# hardened DIA-126(a) permission profile (Option A full, developer-approved
# 2026-08-13) extended by the DIA-134 overnight destructive command baseline
# v1 (data+git, developer-approved 2026-08-14).
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
#   --auto that gate disappears. This wrapper re-asserts DENY for the full
#   DIA-134 baseline v1 (11 rules - the five interactive-profile destructive
#   rules plus docker volume rm / docker system prune / docker system prune
#   -af / git reset --hard / git clean -fd / git push --force). DENY is
#   enforced even in auto mode (OpenCode short-circuits on deny before any
#   auto-approval).
#
# WHY OPENCODE_PERMISSION (not a plain OPENCODE_CONFIG permission block):
#   Config files are deep-merged in load order (global -> OPENCODE_CONFIG ->
#   project files -> .opencode/ directory files) and the LAST file wins
#   conflicting keys, so the project .opencode/opencode.jsonc clobbers any
#   permission rule an OPENCODE_CONFIG override declares. OPENCODE_PERMISSION
#   is deep-merged into the final permission object AFTER all config files
#   and therefore wins (verified 2026-08-13 with `opencode debug config`:
#   the deny rules resolve to deny, all other rules stay byte-identical).
#
# SAFETY INVARIANT (fail closed, DIA-126(a) + DIA-134 S2):
#   (1) if the hardened permission payload cannot be extracted from the
#       profile, the script exits 1 and NEVER launches opencode;
#   (2) DIA-134 S2: the extracted payload must carry EVERY rule of the
#       OVERNIGHT_DENY_BASELINE array below (the DIA-134 baseline v1) and
#       each must resolve to "deny". A payload that is {} (missing keys) or
#       softened (a rule reverted to "ask") exits 1 with a rule-specific
#       error naming the offending rule - an overnight run without the
#       hardened rules would auto-approve destructive commands.
#   The baseline is defined HERE (the launcher's expected contract) and
#   mirrored in .opencode/opencode-overnight.jsonc (the applied payload,
#   whose permission.bash map is the single source of truth for what the run
#   actually gets). Removing a deny rule from the profile is caught: the
#   payload no longer matches this array.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERNIGHT_CONFIG="$PROJECT_ROOT/.opencode/opencode-overnight.jsonc"
NODE_BIN="${NODE_BIN:-node}"

# DIA-134 overnight destructive command baseline v1 (developer-approved
# 2026-08-14, Baseline A = 5 inherited + 6 data+git candidates). The
# launcher's expected contract: every key below must exist in the extracted
# payload's permission.bash map AND resolve to "deny" or the run is refused.
# Order mirrors the baseline list + permission map in
# .opencode/opencode-overnight.jsonc so the three sources diff 1:1.
OVERNIGHT_DENY_BASELINE=(
  "rm *"
  "rm -rf *"
  "rmdir *"
  "chmod *"
  "chown *"
  "docker volume rm *"
  "docker system prune *"
  "docker system prune -af*"
  "git reset --hard *"
  "git clean -fd*"
  "git push --force*"
)

usage() {
  cat <<'USAGE'
overnight.sh - autonomous overnight opencode session with the DIA-126(a) /
DIA-134 hardened permission profile (DIA-134 baseline v1: rm / rm -rf /
rmdir / chmod / chown / docker volume rm / docker system prune / docker
system prune -af / git reset --hard / git clean -fd / git push --force ->
DENY; --auto auto-approves everything else).

Usage:
  scripts/overnight.sh                  interactive TUI (opencode --auto)
  scripts/overnight.sh run "prompt..."  scripted run (opencode run --auto)
  scripts/overnight.sh [opencode flags] passthrough (e.g. -s <session>)
  scripts/overnight.sh -h|--help        show this usage

The hardened profile lives at .opencode/opencode-overnight.jsonc and is
enforced via OPENCODE_PERMISSION (highest-precedence permission overlay).
The launcher validates the payload against the 11-rule baseline v1 before
launching: a missing or softened deny rule exits 1 (fail closed).
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

# DIA-134 S2 - payload shape validation. The extraction above proves a
# permission block EXISTS; this proves it still carries the full deny
# baseline. A drifted payload ({} or a rule reverted to ask) would silently
# un-harden the run, so we assert every baseline rule resolves to "deny"
# BEFORE exporting OPENCODE_PERMISSION and exec'ing opencode. Node emits the
# rule-specific error; the shell guard adds the generic context line. Never
# exec opencode on failure.
BASELINE_JSON='['
_baseline_sep=''
for _baseline_rule in "${OVERNIGHT_DENY_BASELINE[@]}"; do
  BASELINE_JSON+="${_baseline_sep}\"${_baseline_rule}\""
  _baseline_sep=','
done
BASELINE_JSON+=']'

if ! "$NODE_BIN" - "$PERMISSION_JSON" "$BASELINE_JSON" <<'NODE'
// DIA-134 S2: assert every baseline v1 rule exists in permission.bash and
// resolves to "deny". Exits 1 with a rule-specific error on the first
// violation (missing key OR softened value); exits 0 silently when the
// payload is fully hardened. Argv: [2] = extracted permission JSON,
// [3] = JSON array of expected deny keys.
const payload = JSON.parse(process.argv[2]);
const baseline = JSON.parse(process.argv[3]);
const bash = (payload && typeof payload.bash === 'object' && payload.bash !== null)
  ? payload.bash
  : {};
for (const rule of baseline) {
  if (!Object.prototype.hasOwnProperty.call(bash, rule)) {
    console.error('overnight.sh: payload missing deny rule "' + rule + '" - refusing to launch');
    process.exit(1);
  }
  if (bash[rule] !== 'deny') {
    console.error('overnight.sh: payload deny rule "' + rule + '" is "' + bash[rule] + '" (not "deny") - refusing to launch');
    process.exit(1);
  }
}
NODE
then
  echo "error: overnight permission payload failed DIA-134 baseline v1 shape validation; refusing to launch opencode" >&2
  exit 1
fi

export OPENCODE_CONFIG="$OVERNIGHT_CONFIG"
export OPENCODE_PERMISSION="$PERMISSION_JSON"

echo "=== overnight opencode session (DIA-126(a) + DIA-134 hardened profile) ==="
echo "profile : $OVERNIGHT_CONFIG"
echo "auto    : on (--auto: ask-level permissions auto-approved)"
echo "hardened: DIA-134 baseline v1 - 11 destructive rules -> DENY (enforced in auto mode)"
echo "validate: payload shape checked against baseline v1 (11/11 deny) before launch"
echo "merge   : OPENCODE_PERMISSION applied after all config files (project config cannot clobber it)"

if [ "${1:-}" = "run" ]; then
  shift
  exec opencode run --auto --title "overnight autonomous run (DIA-126 hardened)" "$@"
fi

exec opencode --auto "$@"
