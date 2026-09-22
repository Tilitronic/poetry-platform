#!/usr/bin/env bash
# Validates DIA ticket mention format (DIA-234): every DIA reference in prose
# text should include a human-readable slug (e.g., "DIA-190 'fix-auth-bug'"),
# not a bare ID alone (e.g., just "DIA-190").
#
# Scope: AGENTS.md only (the canonical reference for DIA mention format).
# Dispatch payloads and review output (session logs, handoffs) are ephemeral
# and rotated, so bare references there are acceptable. AGENTS.md is the
# persistent documentation that agents and humans reference, so it must be
# correct. CHANGELOG.md is excluded -- historical bare refs are grandfathered.
# Exclusions: README index table rows, ticket filenames, frontmatter, code.
# Grandfathering: existing bare references in AGENTS.md are allowed (DIA-234).
# Exit codes: 0 clean (warn-only), 1 violations found.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
warned=0

check_file() {
  local src="$1" rel="$2" linenum=0 line
  while IFS= read -r line; do
    linenum=$((linenum + 1))
    # Skip non-prose lines
    case "$line" in
      '---') continue ;;
      '<!--'*) continue ;;
      '-->'*) continue ;;
      '~~~'*) continue ;;
      '    '*) continue ;;
      '| DIA-'*) continue ;;
      'DIA-'*'.md'*) continue ;;
      'schema-version'*) continue ;;
      '#!'*) continue ;;
    esac
    # Find DIA references
    local dia_ids
    dia_ids="$(printf '%s' "$line" | grep -oE 'DIA-[0-9]+(-[a-z0-9]{4})?' || true)"
    [ -n "$dia_ids" ] || continue
    local dia_id rest
    while IFS= read -r dia_id; do
      [ -n "$dia_id" ] || continue
      rest="${line#*"$dia_id"}"
      # Strip leading whitespace, then check for quote (slug follows space+quote)
      rest="${rest#"${rest%%[![:space:]]*}"}"
      if [ "${rest:0:1}" = "'" ] || [ "${rest:0:1}" = '"' ]; then
        continue  # Has slug
      fi
      echo "warn: $rel:$linenum: bare '$dia_id' (expected '$dia_id slug')" >&2
      warned=$((warned + 1))
    done <<< "$dia_ids"
  done < "$src"
}

# Scan AGENTS.md only (CHANGELOG.md excluded -- historical bare refs are grandfathered)
[ -f "$ROOT/AGENTS.md" ] && check_file "$ROOT/AGENTS.md" "AGENTS.md"

if [ "$warned" -gt 0 ]; then
  echo "DIA mention check: $warned bare reference(s) found (grandfathered in AGENTS.md)"
else
  echo "ok: all DIA references in AGENTS.md include slugs"
fi
# Warn-only for now: grandfathered bare references are allowed. When the
# allowlist is pruned, convert specific patterns to hard failures (exit 1).
exit 0
