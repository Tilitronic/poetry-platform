#!/usr/bin/env bash
# Validates the M1 (analyzer) + M2 (conspecter) output-contract HTML comment
# header blocks (change dia-086-m1-m5-agent-contracts-eval-lite, task 1.2;
# design.md Seam S1). The Makefile wiring into `make test-config` is Slice B
# task 8.1; this lane only creates the script.
#
# Contract under test (design.md Seam S1):
#   .opencode/agents/analyzer.md MUST carry an <!-- ANALYZER-OUTPUT-CONTRACT
#     --> block with fields: schema-version: 1.0, agent: analyzer, claim-type,
#     evidence-source, confidence (value one of High|Medium|Low),
#     shelf-registration (references memory-shelf.yaml shelf.analyses).
#   .opencode/agents/conspecter.md MUST carry an <!-- CONSPECTER-OUTPUT-CONTRACT
#     --> block with fields: schema-version: 1.0, agent: conspecter,
#     phase-a-source-count (non-negative integer), phase-a-failures
#     (non-negative integer), shelf-registration (references memory-shelf.yaml
#     shelf.conspects).
#
# Stream contract (mirrors validate-agent-names.sh): `FAIL:`/`warn:` to
# stderr, `ok:` to stdout, final `N passed, M failed, K warnings` summary to
# stdout.
#
# Exit codes: 0 both blocks pass, 1 HARD failure (missing field / invalid
# value), 2 INFRA error (agent file missing).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANALYZER_MD="$ROOT/.opencode/agents/analyzer.md"
CONSPECTER_MD="$ROOT/.opencode/agents/conspecter.md"

passed=0
failed=0
warnings=0

# ---------------------------------------------------------------------------
# Source existence gates (INFRA -> exit 2). Mirrors validate-agent-names.sh:
# exit 2 is reserved for "the validator's own environment is broken -- cannot
# run the check at all" (design.md Seam S1: task 1.2 AC4).
# ---------------------------------------------------------------------------
for src in "$ANALYZER_MD" "$CONSPECTER_MD"; do
  if [ ! -f "$src" ]; then
    echo "FAIL: missing agent file $src" >&2
    exit 2
  fi
done

# ---------------------------------------------------------------------------
# Block extraction: print every line from the block opening marker (inclusive)
# through the closing `-->` (inclusive). awk always exits 0, so it is safe
# under `set -e`.
# extract_block <file> <marker-regex>
# ---------------------------------------------------------------------------
extract_block() {
  awk -v marker="$2" '
    $0 ~ marker { in_block = 1 }
    in_block { print }
    in_block && /-->/ { exit }
  ' "$1"
}

# ---------------------------------------------------------------------------
# Field value: first line matching `^<field>:` (leading whitespace tolerated),
# printed with the field name stripped and trimmed. sed always exits 0.
# field_value <block-text> <field>
# ---------------------------------------------------------------------------
field_value() {
  printf '%s\n' "$1" | sed -n "s/^[[:space:]]*$2:[[:space:]]*//p" | head -n1
}

# is_nonneg_int <value>: 0 iff the value is a non-negative integer (empty and
# non-digit values fail). Uses a case glob because `grep -E '^[0-9]+$'` under
# `set -e` needs a guard at every call site; case is unconditional.
is_nonneg_int() {
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

# ---------------------------------------------------------------------------
# M1: analyzer output contract.
# ---------------------------------------------------------------------------
m1_block="$(extract_block "$ANALYZER_MD" '<!-- ANALYZER-OUTPUT-CONTRACT')"
if [ -z "$m1_block" ]; then
  echo "FAIL: M1: no <!-- ANALYZER-OUTPUT-CONTRACT ... --> block found in $ANALYZER_MD" >&2
  failed=$((failed + 1))
else
  m1_failed=0
  for field in schema-version agent claim-type evidence-source confidence shelf-registration; do
    if [ -z "$(field_value "$m1_block" "$field")" ]; then
      echo "FAIL: M1: missing field '$field' in ANALYZER-OUTPUT-CONTRACT block ($ANALYZER_MD)" >&2
      m1_failed=1
    fi
  done
  if [ -n "$(field_value "$m1_block" 'schema-version')" ] && [ "$(field_value "$m1_block" 'schema-version')" != "1.0" ]; then
    echo "FAIL: M1: schema-version must be 1.0, got '$(field_value "$m1_block" 'schema-version')' ($ANALYZER_MD)" >&2
    m1_failed=1
  fi
  if [ -n "$(field_value "$m1_block" 'agent')" ] && [ "$(field_value "$m1_block" 'agent')" != "analyzer" ]; then
    echo "FAIL: M1: agent must be 'analyzer', got '$(field_value "$m1_block" 'agent')' ($ANALYZER_MD)" >&2
    m1_failed=1
  fi
  m1_conf="$(field_value "$m1_block" 'confidence')"
  case "$m1_conf" in
    High | Medium | Low) : ;;
    *)
      echo "FAIL: M1: confidence must be one of High|Medium|Low, got '${m1_conf:-<missing>}' ($ANALYZER_MD)" >&2
      m1_failed=1
      ;;
  esac
  m1_shelf="$(field_value "$m1_block" 'shelf-registration')"
  if [ -z "$m1_shelf" ]; then
    : # field already reported missing above
  elif ! printf '%s\n' "$m1_shelf" | grep -q 'memory-shelf.yaml'; then
    echo "FAIL: M1: shelf-registration must reference .opencode/memory-shelf.yaml, got '$m1_shelf' ($ANALYZER_MD)" >&2
    m1_failed=1
  elif ! printf '%s\n' "$m1_shelf" | grep -q 'shelf.analyses'; then
    echo "FAIL: M1: shelf-registration must reference shelf.analyses, got '$m1_shelf' ($ANALYZER_MD)" >&2
    m1_failed=1
  fi
  if [ "$m1_failed" -eq 1 ]; then
    failed=$((failed + 1))
  else
    echo "ok: M1 analyzer output-contract block valid ($ANALYZER_MD)"
    passed=$((passed + 1))
  fi
fi

# ---------------------------------------------------------------------------
# M2: conspecter output contract.
# ---------------------------------------------------------------------------
m2_block="$(extract_block "$CONSPECTER_MD" '<!-- CONSPECTER-OUTPUT-CONTRACT')"
if [ -z "$m2_block" ]; then
  echo "FAIL: M2: no <!-- CONSPECTER-OUTPUT-CONTRACT ... --> block found in $CONSPECTER_MD" >&2
  failed=$((failed + 1))
else
  m2_failed=0
  for field in schema-version agent phase-a-source-count phase-a-failures shelf-registration; do
    if [ -z "$(field_value "$m2_block" "$field")" ]; then
      echo "FAIL: M2: missing field '$field' in CONSPECTER-OUTPUT-CONTRACT block ($CONSPECTER_MD)" >&2
      m2_failed=1
    fi
  done
  if [ -n "$(field_value "$m2_block" 'schema-version')" ] && [ "$(field_value "$m2_block" 'schema-version')" != "1.0" ]; then
    echo "FAIL: M2: schema-version must be 1.0, got '$(field_value "$m2_block" 'schema-version')' ($CONSPECTER_MD)" >&2
    m2_failed=1
  fi
  if [ -n "$(field_value "$m2_block" 'agent')" ] && [ "$(field_value "$m2_block" 'agent')" != "conspecter" ]; then
    echo "FAIL: M2: agent must be 'conspecter', got '$(field_value "$m2_block" 'agent')' ($CONSPECTER_MD)" >&2
    m2_failed=1
  fi
  for field in phase-a-source-count phase-a-failures; do
    m2_val="$(field_value "$m2_block" "$field")"
    if [ -n "$m2_val" ] && ! is_nonneg_int "$m2_val"; then
      echo "FAIL: M2: $field must be a non-negative integer, got '$m2_val' ($CONSPECTER_MD)" >&2
      m2_failed=1
    fi
  done
  m2_shelf="$(field_value "$m2_block" 'shelf-registration')"
  if [ -z "$m2_shelf" ]; then
    : # field already reported missing above
  elif ! printf '%s\n' "$m2_shelf" | grep -q 'memory-shelf.yaml'; then
    echo "FAIL: M2: shelf-registration must reference .opencode/memory-shelf.yaml, got '$m2_shelf' ($CONSPECTER_MD)" >&2
    m2_failed=1
  elif ! printf '%s\n' "$m2_shelf" | grep -q 'shelf.conspects'; then
    echo "FAIL: M2: shelf-registration must reference shelf.conspects, got '$m2_shelf' ($CONSPECTER_MD)" >&2
    m2_failed=1
  fi
  if [ "$m2_failed" -eq 1 ]; then
    failed=$((failed + 1))
  else
    echo "ok: M2 conspecter output-contract block valid ($CONSPECTER_MD)"
    passed=$((passed + 1))
  fi
fi

echo "$passed passed, $failed failed, $warnings warnings"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
