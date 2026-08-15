#!/usr/bin/env bash
# Validates the Prognosis schema of a HANDOFF file (`make test-config`, wired
# via `test-config`; standalone: `bash scripts/validate-handoff.sh <path>`).
#
# WHY this gate exists: the fresh-session verifier contract (openspec/templates/
# HANDOFF.md) depends on the `## Prognosis for next cycle` section carrying
# exactly the 5 required `###` subsections - session_summary / fixes_applied /
# open_tickets / verification_request / resume_instructions. A typo in any
# subsection heading (e.g. `session_sumary`, `fixes_aplied`) silently breaks
# batch-approval boot without any gate catching it (DIA-045 audit gap 2).
# This script is the deterministic pre-runtime gate.
#
# Contract (dev-infra-config-validators design.md + DIA-085 parallel-handoff-
# slots design.md sections 1/3/4 - locked rulings):
#   - With a positional path argument: validates that exact file. JSON handoffs
#     (the live current-handoff.json) are validated via the DIA-061 checksum
#     block; markdown handoffs via the heading/subsection schema. Unchanged
#     contract.
#   - With `-s <session-id>`: validates the per-session slot
#     .opencode/session/handoffs/<session-id>.json (DIA-085 slot layout).
#   - With NO argument: resolution chain per DIA-085 design section 3:
#       1. active pointer (handoffs/active.json -> active_session_id)
#       2. newest slot by mtime over handoffs/*.json (pointer missing/stale)
#       3. legacy .opencode/session/current-handoff.json
#       4. reference template (terminal fallback - preserves the make-callable
#          contract in fresh clones/worktrees where .opencode/session/ is
#          gitignored and therefore absent; .gitignore line 82)
#   - The 5 required subsection names are taken from the reference template
#     openspec/templates/HANDOFF.md (strict literal match, Q2 ruling 7).
#   - Extra `###` subsections under `## Prognosis for next cycle` are SOFT
#     warnings (do not flip the exit code, Q5 ruling).
#   - Stream contract: `ok:` to stdout; `FAIL:`/`warn:`/`info:`/`skip:` to
#     stderr; final `N passed, M failed, K warnings` to stdout. Collect-all,
#     never fail-fast.
#
# Exit codes: 0 all required headings/subsections present (SOFT warnings may
# print), 1 HARD failure (missing heading/subsection/checksum mismatch),
# 2 infrastructure error (missing/absent target path / unusable -s argument).
#
# HANDOFF_TEMPLATE / HANDOFFS_DIR / LEGACY_HANDOFF env overrides point the
# reference template, the handoffs directory, and the legacy fallback file
# elsewhere (defaults to the repo layout under .opencode/session/) - bats
# meta-tests use them to validate temp fixture trees hermetically.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF_TEMPLATE="${HANDOFF_TEMPLATE:-$ROOT/openspec/templates/HANDOFF.md}"
HANDOFFS_DIR="${HANDOFFS_DIR:-$ROOT/.opencode/session/handoffs}"
LEGACY_HANDOFF="${LEGACY_HANDOFF:-$ROOT/.opencode/session/current-handoff.json}"

# ---------------------------------------------------------------------------
# Argument parsing (DIA-085 T3.1): three mutually exclusive entry points.
# `-s <session-id>` wins over a positional path; no argument triggers the
# design-section-3 resolution chain (see `default` case below).
# ---------------------------------------------------------------------------
mode="default"
target_is_slot=0

if [ "${1:-}" = "-s" ]; then
  if [ -z "${2:-}" ]; then
    echo "FAIL: -s requires a session id (usage: validate-handoff.sh -s <session-id>)" >&2
    exit 2
  fi
  mode="slot"
  session_id="$2"
elif [ $# -gt 0 ]; then
  mode="file"
  if [ -z "$1" ]; then
    echo "FAIL: no HANDOFF file path provided (usage: validate-handoff.sh <handoff-path>)" >&2
    exit 2
  fi
  file_arg="$1"
fi

HANDOFF=""

case "$mode" in
  slot)
    # Explicit slot target: handoffs/<session-id>.json (design section 1).
    HANDOFF="$HANDOFFS_DIR/$session_id.json"
    if [ ! -f "$HANDOFF" ]; then
      echo "FAIL: handoff slot not found: $HANDOFF (validate-handoff.sh -s <session-id>)" >&2
      exit 2
    fi
    target_is_slot=1
    echo "info: validating slot '$session_id' ($HANDOFF)" >&2
    ;;
  file)
    HANDOFF="$file_arg"
    if [ ! -f "$HANDOFF" ]; then
      echo "FAIL: HANDOFF file not found: $HANDOFF" >&2
      exit 2
    fi
    ;;
  default)
    # --- Step 1: active pointer (design section 3) ---
    # The pointer is a dispensable optimization (design section 4 policy
    # principle); a missing, corrupt, or stale pointer must never fail the
    # gate - it degrades to the mtime scan below.
    if [ -d "$HANDOFFS_DIR" ] && [ -f "$HANDOFFS_DIR/active.json" ]; then
      if active_session_id="$(jq -er '.active_session_id // empty' "$HANDOFFS_DIR/active.json" 2>/dev/null)"; then
        if [ -n "$active_session_id" ] && [ -f "$HANDOFFS_DIR/$active_session_id.json" ]; then
          HANDOFF="$HANDOFFS_DIR/$active_session_id.json"
          target_is_slot=1
          echo "info: resolved slot via active pointer -> $active_session_id" >&2
        else
          echo "info: active pointer points to missing slot '$active_session_id' - resolving newest slot" >&2
        fi
      else
        echo "warn: active pointer unreadable - resolving newest slot" >&2
      fi
    fi

    # --- Step 2: mtime scan (design section 3) ---
    # Newest handoffs/*.json wins. active.json is the pointer (excluded by
    # -name); archive/ lives in a subdir (excluded by maxdepth 1); the
    # .reconciled sidecar has no .json suffix (excluded by -name). Reconciled
    # filtering is deliberately NOT applied here: approval state is boot-gate
    # presentation logic (design section 3 step 2), while this script is an
    # integrity check over the newest slot regardless of approval.
    if [ -z "$HANDOFF" ] && [ -d "$HANDOFFS_DIR" ]; then
      newest_slot="$(find "$HANDOFFS_DIR" -maxdepth 1 -type f -name '*.json' ! -name 'active.json' -printf '%T@ %p\n' 2>/dev/null | sort -rn | sed -n '1p' | cut -d' ' -f2- || true)"
      if [ -n "$newest_slot" ]; then
        HANDOFF="$newest_slot"
        target_is_slot=1
        echo "info: resolved newest slot by mtime ($(basename "$newest_slot"))" >&2
      fi
    fi

    # --- Step 3: legacy fallback (design section 3) ---
    if [ -z "$HANDOFF" ] && [ -f "$LEGACY_HANDOFF" ]; then
      HANDOFF="$LEGACY_HANDOFF"
      echo "info: no handoff slots present - validating legacy current-handoff.json" >&2
    fi

    # --- Step 4: reference template (make-callable contract) ---
    # .opencode/session/ is gitignored, so a fresh clone or worktree has no
    # session state at all; validating the committed template keeps the
    # `make test-config` no-arg invocation meaningful there (the pre-DIA-085
    # default) instead of failing infra on absent transient state.
    if [ -z "$HANDOFF" ] && [ -f "$HANDOFF_TEMPLATE" ]; then
      HANDOFF="$HANDOFF_TEMPLATE"
      echo "info: no session handoff state - validating reference template" >&2
    fi

    # --- Step 5: nothing to validate ---
    if [ -z "$HANDOFF" ]; then
      echo "FAIL: no handoff target found (checked pointer $HANDOFFS_DIR/active.json, slots in $HANDOFFS_DIR, legacy $LEGACY_HANDOFF, template $HANDOFF_TEMPLATE)" >&2
      exit 2
    fi
    ;;
esac

# Slots are always JSON (design section 1: identical schema to
# current-handoff.json). A non-JSON slot is corrupt state - fail loudly with
# the exact path rather than running the markdown branch on foreign content.
if [ "$target_is_slot" -eq 1 ] && ! jq -e . "$HANDOFF" >/dev/null 2>&1; then
  echo "FAIL: handoff slot is not valid JSON: $HANDOFF" >&2
  exit 1
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
