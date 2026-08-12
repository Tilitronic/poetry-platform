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
#   - Stream contract: `ok:` to stdout; `FAIL:`/`warn:`/`info:`/`skip:` to
#     stderr; final `N passed, M failed, K warnings` to stdout. Collect-all,
#     never fail-fast.
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

# JSON-handoff detection (DIA-045 F6): JSON handoffs (e.g. the live
# .opencode/session/current-handoff.json) carry the `checksum` field and are
# validated by the checksum block below — the markdown heading/subsection
# schema applies only to markdown handoffs. Previously the markdown check ran
# first, so a JSON handoff spuriously FAILed with "missing required heading"
# and never reached checksum validation. `jq -e .` is the JSON parse probe:
# valid JSON exits 0, any non-JSON (markdown) input exits 1. The probe runs
# exactly once; both the markdown/checksum branches branch on the flag.
json_handoff=0
if jq -e . "$HANDOFF" >/dev/null 2>&1; then
  json_handoff=1
fi

if [ "$json_handoff" -eq 1 ]; then
  echo "info: JSON handoff detected — skipping markdown schema check" >&2
elif grep -qxF "## Prognosis for next cycle" "$HANDOFF"; then
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

# Checksum validation (DIA-061) — reject placeholder/fake checksums and verify
# integrity against the canonical serialization
# (`jq -c '.prognosis | to_entries | sort_by(.key) | from_entries'` — sorted
# keys, compact JSON). The block applies only to JSON handoffs
# (current-handoff.json): the no-argument / `make test-config` path validates
# the markdown reference template (openspec/templates/HANDOFF.md), which has no
# `checksum` field — that path skips checksum validation so the
# prognosis-schema gate stays green (DIA-061 does not change the markdown
# template contract).
if [ "$json_handoff" -eq 1 ]; then
  checksum_field="$(jq -r '.checksum // empty' "$HANDOFF" 2>/dev/null || true)"
  if [ -z "$checksum_field" ]; then
    echo "FAIL: missing or empty 'checksum' field" >&2
    failed=$((failed + 1))
  elif ! echo "$checksum_field" | grep -qE '^[0-9a-f]{64}$'; then
    echo "FAIL: 'checksum' is not a valid 64-hex SHA256: $checksum_field" >&2
    failed=$((failed + 1))
  elif echo "$checksum_field" | grep -qE '^(.)\1{63}$'; then
    # Any 64-identical-char value is a placeholder — a real SHA256 hex digest
    # can never be 64 identical characters (rejects 0{64}, f{64}, a{64}, 1{64}, …).
    echo "FAIL: 'checksum' is a placeholder (all-same-char): $checksum_field" >&2
    failed=$((failed + 1))
  else
    prognosis_canonical="$(jq -c '.prognosis | to_entries | sort_by(.key) | from_entries' "$HANDOFF" 2>/dev/null || true)"
    if [ -n "$prognosis_canonical" ]; then
      computed_checksum="$(printf '%s' "$prognosis_canonical" | sha256sum | cut -d' ' -f1)"
      if [ "$computed_checksum" != "$checksum_field" ]; then
        echo "FAIL: checksum mismatch (computed=$computed_checksum, stored=$checksum_field)" >&2
        failed=$((failed + 1))
      else
        echo "ok: checksum verified"
        passed=$((passed + 1))
      fi
    else
      echo "warn: could not extract prognosis for checksum verification" >&2
      warnings=$((warnings + 1))
    fi
  fi
else
  echo "skip: not a JSON handoff — checksum validation not applicable" >&2
fi

echo "$passed passed, $failed failed, $warnings warnings"
if [ "$failed" -gt 0 ]; then
  exit 1
fi
exit 0
