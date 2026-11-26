#!/usr/bin/env bash
# Mechanical grilling-gate marker validator for DIA ticket files (DIA-104).
# Runs from `make test-config` as a WARN-NOT-FAIL opt-in gate; TICKETS_DIR env
# override keeps it hermetically testable against fixture trees (same pattern
# as validate-decision-variants.sh / scripts/tickets).
#
# ai--7 validated design (interview session ses_fff4d79b9ffesEQ8b0ZRYvyZJ8):
# the four gate markers (gate_state / gate_triggers / gate_waivers /
# gate_override) are OPTIONAL frontmatter fields always emitted by `tickets
# new` with defaults. Absent = legacy/skipped (GRANDFATHER precedent) - never
# retroactively backfilled. Frontmatter (not body): state is machine-checkable.
#
# Rules:
#   a  if gate_state is present, its value must be one of the canonical states
#      (grilled | waived | bypassed | partial | skipped).
#   b  if gate_state = bypassed, gate_override MUST be non-empty (an override
#      is only legitimate via an explicit developer signal - "proceed without
#      grill" - recorded in the ticket; an empty override with a bypassed
#      state is a silent auto-bypass, which the gate forbids).
#   c  absent gate_state = legacy/skipped ticket: WARN, never fail (grandfather
#      precedent - no retroactive backfill of the ~150 pre-marker tickets).
#
# Stream contract (mirrors validate-decision-variants.sh / validate-output-
# contracts.sh): `FAIL:`/`warn:` to stderr, `ok:` to stdout, final summary
# line to stdout.
#
# Exit codes: 0 every ticket passes (legacy/warn tickets count as passed; a
# dir with zero tickets passes), 1 one or more tickets violate rule a or b,
# 2 INFRA error (tickets dir missing). Unreadable files warn and are skipped
# (non-fatal).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TICKETS_DIR="${TICKETS_DIR:-$ROOT/docs/dev-infra-audit/tickets}"

if [ ! -d "$TICKETS_DIR" ]; then
  echo "FAIL: tickets dir not found: $TICKETS_DIR (run from the repo root or set TICKETS_DIR)" >&2
  exit 2
fi

checked=0
passed=0
failed=0
warnings=0

# Canonical gate states (DIA-104 substance, section (d)/(e) + ticket markers).
STATES="grilled waived bypassed partial skipped"

# fm_field <file> <key>: prints the value of a YAML frontmatter field, with
# surrounding double quotes stripped and any trailing inline comment removed.
# Frontmatter = lines between the FIRST and SECOND `---` separators (the
# session-attribution comment `# --- ... ---` starts with '#', so it never
# toggles the separator state). The value is everything after "<key>:" on the
# key's line: quoted values yield the text between the quotes; bare values
# yield the first whitespace/comment-delimited token.
fm_field() {
  awk -v key="$2" '
    /^---[[:space:]]*$/ { fm = !fm; next }
    fm && $0 ~ "^" key ":" {
      line = $0
      sub(/^[^:]*:[[:space:]]*/, "", line)
      if (line ~ /^"/) {
        first = index(line, "\"")
        rest = substr(line, first + 1)
        qend = index(rest, "\"")
        if (qend > 0) { print substr(rest, 1, qend - 1); exit }
      }
      sub(/[[:space:]#].*$/, "", line)
      print line
      exit
    }
  ' "$1"
}

validate_ticket() {
  local file="$1" name state override
  name="$(basename "$file")"

  if [ ! -r "$file" ]; then
    echo "warn: cannot read $file - skipped" >&2
    warnings=$((warnings + 1))
    return 0
  fi

  state="$(fm_field "$file" gate_state)"

  # Rule c: absent field = legacy/skipped (grandfather precedent). Warn, pass.
  if [ -z "$state" ]; then
    echo "warn: $name: no gate_state field - legacy/skipped ticket (DIA-104 grandfather, no retroactive backfill)" >&2
    warnings=$((warnings + 1))
    checked=$((checked + 1))
    passed=$((passed + 1))
    return 0
  fi

  # Rule a: state must be canonical.
  case " $STATES " in
    *" $state "*) ;;
    *)
      echo "FAIL: $name: rule a: invalid gate_state '$state' (expected one of: $STATES)" >&2
      failed=$((failed + 1))
      checked=$((checked + 1))
      return 0
      ;;
  esac

  # Rule b: bypassed REQUIRES an explicit recorded override.
  if [ "$state" = "bypassed" ]; then
    override="$(fm_field "$file" gate_override)"
    if [ -z "$override" ]; then
      echo "FAIL: $name: rule b: gate_state=bypassed but gate_override is empty (an override needs an explicit developer signal + reason)" >&2
      failed=$((failed + 1))
      checked=$((checked + 1))
      return 0
    fi
  fi

  checked=$((checked + 1))
  passed=$((passed + 1))
  echo "ok: $name: gate_state '$state' valid"
}

# Scan: every *.md directly under TICKETS_DIR (the glob never matches the
# archive/ subdirectory); _TEMPLATE.md and friends are skipped by name.
for f in "$TICKETS_DIR"/*.md; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in
    _*) continue ;;
  esac
  validate_ticket "$f"
done

if [ "$failed" -gt 0 ]; then
  echo "FAIL: validate-grilling-gate: $checked tickets checked, $passed passed, $failed failed" >&2
  exit 1
fi

if [ "$warnings" -gt 0 ]; then
  echo "ok: validate-grilling-gate: $checked tickets checked, $passed passed, 0 failed, $warnings warnings (legacy/skipped)"
else
  echo "ok: validate-grilling-gate: $checked tickets checked, $passed passed, 0 failed"
fi
exit 0
