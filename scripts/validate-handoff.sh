#!/usr/bin/env bash
# Validates the Prognosis schema of a HANDOFF.md file (`make test-config`,
# wired via `test-config`; standalone: `bash scripts/validate-handoff.sh <path>`).
#
# WHY this gate exists: the fresh-session verifier contract (openspec/templates/
# HANDOFF.md) depends on the `## Prognosis for next cycle` section carrying
# exactly the 5 required `###` subsections — session_summary / fixes_applied /
# open_tickets / verification_request / resume_instructions. A typo in any
# subsection heading (e.g. `session_sumary`, `fixes_aplied`) silently breaks
# batch-approval boot without any gate catching it (DIA-045 audit gap 2).
# This script is the deterministic pre-runtime gate.
#
# Contract (design.md §2, §3, §4 — locked rulings):
#   - Takes ONE positional argument: the HANDOFF file path (exact-name only —
#     no glob, Q2 ruling 6). When NO argument is given, the validator defaults
#     to the reference template itself — this is what makes the make-callable
#     contract work (design §5: `make test-config` invokes the script with no
#     arguments, and validating the template guards the canonical schema
#     against regression, cf. DIA-045 F6/NF-1). The no-argument INFRA case
#     (exit 2) then manifests only when the default template is unavailable.
#   - The 5 required subsection names are taken from the reference template
#     openspec/templates/HANDOFF.md (strict literal match, Q2 ruling 7).
#   - Extra `###` subsections under `## Prognosis for next cycle` are SOFT
#     warnings (do not flip the exit code, Q5 ruling).
#   - Stream contract: `ok:` to stdout, `FAIL:`/`warn:` to stderr, final
#     `N passed, M failed, K warnings` to stdout. Collect-all, never fail-fast.
#
# Exit codes: 0 all required headings/subsections present (SOFT warnings may
# print), 1 HARD failure (missing heading or subsection), 2 infrastructure
# error (missing input path / nonexistent path / reference template missing).
#
# HANDOFF_TEMPLATE env override points the reference template elsewhere
# (defaults to the repo's openspec/templates/HANDOFF.md) — bats meta-tests use
# it to validate temp fixture trees hermetically.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF_TEMPLATE="${HANDOFF_TEMPLATE:-$ROOT/openspec/templates/HANDOFF.md}"
HANDOFF="${1:-$HANDOFF_TEMPLATE}"

if [ -z "$HANDOFF" ]; then
  echo "FAIL: no HANDOFF file path provided (usage: validate-handoff.sh <handoff-path>)" >&2
  exit 2
fi

if [ ! -f "$HANDOFF" ]; then
  echo "FAIL: HANDOFF file not found: $HANDOFF" >&2
  exit 2
fi

if [ ! -f "$HANDOFF_TEMPLATE" ]; then
  echo "FAIL: reference template not found: $HANDOFF_TEMPLATE" >&2
  exit 2
fi

# The 5 required subsection names — strict literal match (Q2 ruling 7). The
# reference template anchors the contract; the names are also declared here so
# the schema is auditable without parsing the template twice.
REQUIRED_SUBSECTIONS=(session_summary fixes_applied open_tickets verification_request resume_instructions)

passed=0
failed=0
warnings=0

# ---------------------------------------------------------------------------
# Extract the `###` subsection names living directly under
# `## Prognosis for next cycle` — i.e. from the Prognosis heading until the
# next `## ` heading (or EOF). Subsection names are printed one per line,
# prefix-stripped. The awk state machine stops at the next level-2 heading so
# later sections (e.g. the template's `## Verification Result` with its own
# `### Outcome rules`) can never be mistaken for Prognosis subsections.
# ---------------------------------------------------------------------------
prognosis_subsection_names() {
  awk -v target="## Prognosis for next cycle" '
    /^## / {
      if (started) exit
      if ($0 == target) started = 1
      next
    }
    started && /^### / { print substr($0, 5) }
  ' "$1"
}

if grep -qxF "## Prognosis for next cycle" "$HANDOFF"; then
  section_names="$(prognosis_subsection_names "$HANDOFF")"

  for name in "${REQUIRED_SUBSECTIONS[@]}"; do
    if grep -qxF -- "$name" <<<"$section_names"; then
      echo "ok: $name"
      passed=$((passed + 1))
    else
      echo "FAIL: missing required subsection '$name' under '## Prognosis for next cycle'" >&2
      failed=$((failed + 1))
    fi
  done

  # SOFT warn for extra subsections (Q5 ruling): additive headings are allowed
  # but surfaced so the author can see they extend the schema.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    is_required=0
    for r in "${REQUIRED_SUBSECTIONS[@]}"; do
      if [ "$name" = "$r" ]; then
        is_required=1
        break
      fi
    done
    if [ "$is_required" -eq 0 ]; then
      echo "warn: extra subsection '$name' under '## Prognosis for next cycle'" >&2
      warnings=$((warnings + 1))
    fi
  done <<< "$section_names"
else
  echo "FAIL: missing required heading '## Prognosis for next cycle'" >&2
  failed=1
fi

echo "$passed passed, $failed failed, $warnings warnings"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
