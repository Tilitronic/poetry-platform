#!/usr/bin/env bats
# DIA-104: unit tests for scripts/validate-grilling-gate.sh (2026-08-14,
# implementation lane). The script mechanically validates the grilling-gate
# ticket markers (gate_state/gate_triggers/gate_waivers/gate_override) that
# `tickets new` always emits - rule a: canonical state value; rule b:
# bypassed requires a non-empty gate_override; rule c: absent field =
# legacy/skipped (warn, never fail - grandfather precedent, no retroactive
# backfill).
#
# Isolation strategy (validate-decision-variants.bats / tickets.bats
# conventions): every test builds a throwaway fixture ledger under
# $BATS_TEST_TMPDIR and runs the validator against it via the TICKETS_DIR env
# override. The REAL ledger at docs/dev-infra-audit/tickets/ is NEVER touched.
# The validator resolves ROOT from BASH_SOURCE, so the fixture tree needs no
# scripts/ copy.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-grilling-gate.sh"

# fixture_dir: echoes a fresh throwaway ledger dir (created on demand).
fixture_dir() {
  local dir="$BATS_TEST_TMPDIR/tickets"
  mkdir -p "$dir"
  echo "$dir"
}

# write_ticket <dir> <name> <frontmatter-extra>: writes a minimal ticket with
# the given extra frontmatter lines (may be empty for a legacy ticket).
write_ticket() {
  local dir="$1" name="$2" extra="$3"
  {
    printf -- '---\n'
    printf 'id: DIA-XXX\n'
    printf 'title: "fixture"\n'
    printf 'area: docs\n'
    printf 'severity: Low\n'
    printf 'status: OPEN\n'
    if [ -n "$extra" ]; then
      printf '%s\n' "$extra"
    fi
    printf -- '---\n'
    printf '\n## Description\n\nFixture ticket.\n'
  } > "$dir/$name"
}

@test "validate-grilling-gate: canonical gate_state (skipped/grilled) PASSES" {
  dir="$(fixture_dir)"
  write_ticket "$dir" "DIA-210-skipped.md" 'gate_state: "skipped"'
  write_ticket "$dir" "DIA-211-grilled.md" 'gate_state: "grilled"'

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "ok: validate-grilling-gate: 2 tickets checked, 2 passed, 0 failed"
  assert_output_contains "DIA-210-skipped.md: gate_state 'skipped' valid"
  assert_output_contains "DIA-211-grilled.md: gate_state 'grilled' valid"
  assert_output_not_contains "FAIL"
}

@test "validate-grilling-gate: bypassed WITHOUT override FAILS rule b" {
  dir="$(fixture_dir)"
  write_ticket "$dir" "DIA-212-bypass-no-override.md" 'gate_state: "bypassed"'

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 1
  assert_output_contains "rule b"
  assert_output_contains "DIA-212-bypass-no-override.md"
  assert_output_contains "1 tickets checked, 0 passed, 1 failed"
}

@test "validate-grilling-gate: bypassed WITH override PASSES" {
  dir="$(fixture_dir)"
  write_ticket "$dir" "DIA-213-bypass-override.md" \
    'gate_state: "bypassed"
gate_override: "explicit: proceed without grill - developer accepted the risk"'

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "ok: validate-grilling-gate: 1 tickets checked, 1 passed, 0 failed"
  assert_output_contains "gate_state 'bypassed' valid"
  assert_output_not_contains "FAIL"
}

@test "validate-grilling-gate: invalid gate_state FAILS rule a" {
  dir="$(fixture_dir)"
  write_ticket "$dir" "DIA-214-badstate.md" 'gate_state: "maybe"'

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 1
  assert_output_contains "rule a"
  assert_output_contains "invalid gate_state 'maybe'"
  assert_output_contains "DIA-214-badstate.md"
}

@test "validate-grilling-gate: unquoted bare gate_state value accepted" {
  dir="$(fixture_dir)"
  write_ticket "$dir" "DIA-215-bare.md" 'gate_state: waived'

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "gate_state 'waived' valid"
  assert_output_not_contains "FAIL"
}

@test "validate-grilling-gate: legacy ticket (no gate fields) WARNS but PASSES" {
  dir="$(fixture_dir)"
  write_ticket "$dir" "DIA-216-legacy.md" ""

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "warn: DIA-216-legacy.md: no gate_state field - legacy/skipped"
  assert_output_contains "ok: validate-grilling-gate: 1 tickets checked, 1 passed, 0 failed, 1 warnings"
  assert_output_not_contains "FAIL"
}

@test "validate-grilling-gate: _TEMPLATE.md is never validated" {
  dir="$(fixture_dir)"
  cat > "$dir/_TEMPLATE.md" <<'TICKET'
---
id: DIA-TPL
title: "template"
area: docs
severity: Info
status: OPEN
---
TICKET

  TICKETS_DIR="$dir" run bash "$VALIDATOR"

  assert_status 0
  assert_output_contains "0 tickets checked, 0 passed, 0 failed"
}

@test "validate-grilling-gate: missing TICKETS_DIR exits 2 (INFRA)" {
  TICKETS_DIR="$BATS_TEST_TMPDIR/nonexistent" run bash "$VALIDATOR"

  assert_status 2
  assert_output_contains "tickets dir not found"
}

@test "validate-grilling-gate: Makefile wiring - test-config references the validator" {
  # Same seam-guard shape as validate-decision-variants.bats: a future edit
  # cannot silently drop the validator from the config gate. Recipe line form
  # is `bash scripts/validate-grilling-gate.sh` (same shape as the other
  # validate-*.sh calls).
  assert_file_contains "$REPO_ROOT/Makefile" "bash scripts/validate-grilling-gate.sh"
}
