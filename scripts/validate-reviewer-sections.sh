#!/usr/bin/env bash
# Validates the M3 Falsification section in the reviewer config
# (change dia-086-m1-m5-agent-contracts-eval-lite, task 3.2; design.md
# Seam S2). The Makefile wiring into `make test-config` is Slice B task 8.1;
# this lane only creates the script.
#
# Contract under test (.opencode/oh-my-opencode-slim/reviewer.md):
#   1. A `## Falsification` heading exists.
#   2. It appears AFTER `## Spec` and BEFORE `## Summary` (line-order).
#   3. The section body mentions the `[FALSIFICATION-N]` format and the
#      exactly-3 claims requirement.
#
# Stream contract (mirrors validate-agent-names.sh): `FAIL:`/`warn:` to
# stderr, `ok:` to stdout, final `N passed, M failed, K warnings` summary to
# stdout.
#
# Exit codes: 0 all checks pass, 1 HARD failure (missing / misplaced heading,
# missing body content), 2 INFRA error (reviewer.md missing).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REVIEWER_MD="$ROOT/.opencode/oh-my-opencode-slim/reviewer.md"

passed=0
failed=0
warnings=0

if [ ! -f "$REVIEWER_MD" ]; then
  echo "FAIL: missing reviewer config file $REVIEWER_MD" >&2
  exit 2
fi

# line_of <heading>: first line number matching `^<heading>$`, or empty.
# `|| true` guards `set -e` when the heading is absent (grep exits 1).
line_of() {
  grep -nE "^$1$" "$REVIEWER_MD" | head -n1 | cut -d: -f1 || true
}

spec_line="$(line_of '## Spec')"
fals_line="$(line_of '## Falsification')"
summ_line="$(line_of '## Summary')"

if [ -z "$spec_line" ]; then
  echo "FAIL: no '## Spec' heading found in $REVIEWER_MD" >&2
  failed=$((failed + 1))
fi
if [ -z "$fals_line" ]; then
  echo "FAIL: no '## Falsification' heading found in $REVIEWER_MD" >&2
  failed=$((failed + 1))
fi
if [ -z "$summ_line" ]; then
  echo "FAIL: no '## Summary' heading found in $REVIEWER_MD" >&2
  failed=$((failed + 1))
fi

# Line-order + section-body checks only run when all three headings exist.
if [ -n "$fals_line" ] && [ -n "$spec_line" ] && [ -n "$summ_line" ]; then
  if [ "$fals_line" -le "$spec_line" ]; then
    echo "FAIL: '## Falsification' (line $fals_line) must appear AFTER '## Spec' (line $spec_line)" >&2
    failed=$((failed + 1))
  fi
  if [ "$fals_line" -ge "$summ_line" ]; then
    echo "FAIL: '## Falsification' (line $fals_line) must appear BEFORE '## Summary' (line $summ_line)" >&2
    failed=$((failed + 1))
  fi

  # Section body: the lines strictly between the Falsification heading and the
  # Summary heading (the Falsification section runs to the next heading).
  body="$(awk -v start="$fals_line" -v end="$summ_line" 'NR > start && NR < end' "$REVIEWER_MD")"
  if ! printf '%s\n' "$body" | grep -qF '[FALSIFICATION-N]'; then
    echo "FAIL: Falsification section body must reference the [FALSIFICATION-N] format" >&2
    failed=$((failed + 1))
  fi
  if ! printf '%s\n' "$body" | grep -qF 'exactly 3'; then
    echo "FAIL: Falsification section body must state the exactly-3 claims requirement" >&2
    failed=$((failed + 1))
  fi
fi

if [ "$failed" -eq 0 ]; then
  echo "ok: Falsification section present and correctly positioned ($REVIEWER_MD)"
  passed=$((passed + 1))
fi

echo "$passed passed, $failed failed, $warnings warnings"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
