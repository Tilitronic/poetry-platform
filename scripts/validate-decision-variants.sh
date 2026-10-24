#!/usr/bin/env bash
# Mechanical EBDV (evidence-backed decision variants) validator for RECORDED
# decisions in DIA ticket files (DIA-115 approved item 1; conspect res022
# section 5 item 1). Runs from `make test-config`; TICKETS_DIR env override
# keeps it hermetically testable against fixture trees (same pattern as
# scripts/tickets).
#
# Scope: only tickets that OPT IN to a decision-variant block are validated -
# a ticket carrying a '## Decision-variants' section, a '## Alternatives
# considered' section, or a '### Chosen:'/'Chosen:' record. Tickets without any
# such block are skipped (they are not decision-variant records). _TEMPLATE.md
# and the archive/ subdirectory are never scanned (the *.md glob excludes the
# archive dir; _TEMPLATE is skipped by name).
#
# Rules (labels a-g per the approved item-1 contract):
#   a  the Decision-variants section contains >=2 variant headings ('Variant
#      A'/... or a '### Variant ' heading), UNLESS the extracted decision
#      section (see extract_section below) carries the explicit marker
#      'fewer-than-2-alternatives' (a documented single-alternative
#      decision). The marker is SECTION-SCOPED: the same text anywhere else
#      in the file (e.g. the Description area) does not satisfy this rule.
#   b  an abort/status-quo variant is present: some variant heading contains
#      'abort' / 'status-quo' / 'do nothing' (case-insensitive; both hyphen
#      and space forms accepted, e.g. 'status quo' or 'do-nothing').
#   c  a '### Chosen:' or 'Chosen:' line records the chosen variant.
#   d+e  every variant block carries at least one evidence marker - a Tier-1
#      pointer (knowledge/resNNN- path, .sdd/ path, or openspec/ path), a
#      Tier-2 dated URL (an http(s) URL plus a 2025/2026 year token in the
#      same block), or an [INFERENCE] label. A block with none of these is
#      evidence-bare and fails. (d) and (e) are the same invariant stated
#      positively and negatively; the violation is reported under label e
#      (the bats fixtures pin that label).
#   f  a single-variant decision whose only variant is [INFERENCE]-only (no
#      Tier-1/Tier-2 anywhere in its block) is rejected: T3 alone never
#      decides (res022: "Pure Tier-3 variants are rejected"). A multi-variant
#      decision passes f even when one variant is [INFERENCE]-only, as long as
#      another carries real evidence (approved item-1 text).
#   g  WHOLE-DECISION evidence (ai-auditor Minor 1 fix): a >=2-variant
#      decision must contain >=1 Tier-1 or Tier-2 evidence hit anywhere in
#      the extracted decision section (across all variant blocks). A decision
#      where EVERY variant is [INFERENCE]-only - no Tier-1/Tier-2 anywhere in
#      the section - is T3-alone at the decision level and is rejected. This
#      closes the mechanical gap previously documented under rule f (a
#      >=2-variant all-[INFERENCE] set used to pass f because no single
#      T3-only variant existed and no block was bare).
#
# Stream contract (mirrors validate-output-contracts.sh): `FAIL:`/`warn:` to
# stderr, `ok:` to stdout, final summary line to stdout.
#
# Exit codes: 0 every scanned ticket passes (skipped tickets count as passed;
# a dir with zero tickets passes), 1 one or more opted-in tickets violate a
# rule, 2 INFRA error (tickets dir missing). Unreadable files warn and are
# skipped (non-fatal).
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

# A ticket opts in to EBDV validation when it carries any of these markers.
OPT_IN_RE='^## Decision-variants|^## Alternatives considered|^### Chosen:|^Chosen:'

# Tier-1 evidence: a committed/archived pointer (knowledge/resNNN- conspect
# path, .sdd/ design doc, or openspec/ artifact). Tier-2: an http(s) URL in
# the same block as a 2025/2026 year token (dated citation). Tier-3: the
# explicit [INFERENCE] label.
T1_RE='knowledge/res[0-9]|\.sdd/|openspec/'
T2_URL_RE='https?://'
T2_YEAR_RE='20(25|26)'
INF_RE='\[INFERENCE\]'

# Variant headings inside a Decision-variants section: a markdown heading with
# a 'Variant ' prefix ('### Variant A: ...') or a bare 'Variant <name>: ...'
# line. Emits 'N:heading' lines (N = line number within the section).
variant_head_lines() {
  printf '%s\n' "$1" | grep -nE '^#{1,6}[[:space:]]*Variant[[:space:]]+|^Variant[[:space:]]+[^:]*:' || true
}

# The Decision-variants section body: from the first '## Decision-variants' or
# '## Alternatives considered' heading to the next '## ' heading (or EOF). If a
# ticket carries both headings, only the first section is analyzed (documented
# deterministic choice).
extract_section() {
  awk '
    /^## Decision-variants|^## Alternatives considered/ { in_sec = 1; next }
    in_sec && /^## / { exit }
    in_sec { print }
  ' "$1"
}

# block_from <start-line> <section>: the variant block starting at <start-line>
# (the heading itself plus everything up to the next variant heading).
block_from() {
  awk -v start="$1" '
    NR < start { next }
    NR == start { print; in_block = 1; next }
    in_block && /^#{1,6}[[:space:]]*Variant[[:space:]]+/ { exit }
    in_block && /^Variant[[:space:]]+[^:]*:/ { exit }
    in_block { print }
  ' <<< "$2"
}

validate_ticket() {
  local file="$1" name section heads count hline ln heading block
  local t1 t2 inf lone_inf t_failed
  name="$(basename "$file")"

  if [ ! -r "$file" ]; then
    echo "warn: cannot read $file - skipped" >&2
    warnings=$((warnings + 1))
    return 0
  fi

  # Opt-in gate: no decision-variant block -> not a decision record, skip.
  if ! grep -qE -- "$OPT_IN_RE" "$file"; then
    checked=$((checked + 1))
    passed=$((passed + 1))
    return 0
  fi

  section="$(extract_section "$file")"
  heads="$(variant_head_lines "$section")"
  count="$(printf '%s\n' "$heads" | sed '/^$/d' | wc -l | tr -d ' ')"
  t_failed=0
  lone_inf=0

  # Rule a: >=2 genuine variants, or the fewer-than-2-alternatives marker
  # INSIDE the extracted decision section (Minor 2 fix: the marker is
  # section-scoped - the same text in the Description area or elsewhere in
  # the file must NOT satisfy this rule).
  if [ "$count" -lt 2 ] && ! printf '%s\n' "$section" | grep -qF 'fewer-than-2-alternatives'; then
    echo "FAIL: $name: rule a: expected >=2 variant headings (or the 'fewer-than-2-alternatives' marker), found $count" >&2
    t_failed=1
  fi

  # Rule b: an abort/status-quo/do-nothing variant is present.
  if ! printf '%s\n' "$heads" | grep -qiE 'abort|status[- ]quo|do[- ]nothing'; then
    echo "FAIL: $name: rule b: no abort/status-quo/do-nothing variant heading found" >&2
    t_failed=1
  fi

  # Rule c: the chosen variant is recorded.
  if ! grep -qE '^#{1,6}[[:space:]]*Chosen:|^Chosen:' "$file"; then
    echo "FAIL: $name: rule c: no '### Chosen:' or 'Chosen:' line found" >&2
    t_failed=1
  fi

  # Rules d/e/f per variant block.
  while IFS= read -r hline; do
    [ -n "$hline" ] || continue
    ln="${hline%%:*}"
    heading="${hline#*:}"
    block="$(block_from "$ln" "$section")"

    t1=0
    t2=0
    inf=0
    if printf '%s\n' "$block" | grep -qE -- "$T1_RE"; then t1=1; fi
    if printf '%s\n' "$block" | grep -qE -- "$T2_URL_RE" \
      && printf '%s\n' "$block" | grep -qE -- "$T2_YEAR_RE"; then t2=1; fi
    if printf '%s\n' "$block" | grep -qiE -- "$INF_RE"; then inf=1; fi

    if [ "$t1" -eq 0 ] && [ "$t2" -eq 0 ] && [ "$inf" -eq 0 ]; then
      echo "FAIL: $name: rule e: variant '$heading' has no evidence marker (rule d requires each variant to carry a Tier-1 knowledge/resNNN-/.sdd//openspec/ pointer, a Tier-2 dated URL, or an [INFERENCE] label)" >&2
      t_failed=1
    fi
    if [ "$t1" -eq 0 ] && [ "$t2" -eq 0 ] && [ "$inf" -eq 1 ]; then
      lone_inf=$((lone_inf + 1))
    fi
  done <<< "$heads"

  # Rule f: a single [INFERENCE]-only variant cannot be the whole decision.
  if [ "$count" -eq 1 ] && [ "$lone_inf" -eq 1 ]; then
    echo "FAIL: $name: rule f: the only variant is [INFERENCE]-only (no Tier-1/Tier-2 evidence in its block) - T3 alone is rejected" >&2
    t_failed=1
  fi

  # Rule g: a >=2-variant decision still needs >=1 Tier-1/Tier-2 hit anywhere
  # in the section (across all variant blocks). An all-[INFERENCE] variant set
  # is T3-alone at the WHOLE-DECISION level and is rejected (ai-auditor Minor
  # 1 fix; res022 "Pure Tier-3 variants are rejected"). The section-level grep
  # is intentionally coarser than the per-block d/e check - rule g asks
  # "does ANY real evidence exist in this decision", not "in which block".
  if [ "$count" -ge 2 ]; then
    if ! printf '%s\n' "$section" | grep -qE -- "$T1_RE" \
      && ! { printf '%s\n' "$section" | grep -qE -- "$T2_URL_RE" \
             && printf '%s\n' "$section" | grep -qE -- "$T2_YEAR_RE"; }; then
      echo "FAIL: $name: rule g: >=2 variants but no Tier-1 (knowledge/resNNN-/.sdd//openspec/) or Tier-2 (dated http(s) URL) evidence anywhere in the decision section - a whole-decision [INFERENCE]-only set is rejected" >&2
      t_failed=1
    fi
  fi

  checked=$((checked + 1))
  if [ "$t_failed" -eq 1 ]; then
    failed=$((failed + 1))
  else
    echo "ok: $name: EBDV decision-variant block valid ($count variants, chosen recorded)"
    passed=$((passed + 1))
  fi
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
  echo "FAIL: validate-decision-variants: $checked tickets checked, $passed passed, $failed failed" >&2
  exit 1
fi

if [ "$warnings" -gt 0 ]; then
  echo "ok: validate-decision-variants: $checked tickets checked, $passed passed, 0 failed, $warnings warnings"
else
  echo "ok: validate-decision-variants: $checked tickets checked, $passed passed, 0 failed"
fi
exit 0
