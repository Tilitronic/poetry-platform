#!/usr/bin/env bats
# Tests for scripts/changelog-add (DIA-260825-k8mc item 4): PyYAML append +
# auto validate + render. Hermetic via the CHANGELOG_FILE override (same name
# as validate-changelog.sh); the derived MD lands next to the temp ledger
# (CHANGELOG_MD derivation), so the real .opencode/CHANGELOG.{yaml,md} are
# never touched. The committed 2-entry fixture seeds the temp ledger.

load test-helper

CHANGELOG_ADD="$REPO_ROOT/scripts/changelog-add"
FIXTURES="$REPO_ROOT/scripts/__tests__/fixtures"

setup() {
  LEDGER="$BATS_TEST_TMPDIR/CHANGELOG.yaml"
}

seed_ledger() {
  cp "$FIXTURES/changelog-valid.yaml" "$LEDGER"
}

entry_count() {
  python3 -c "import yaml,sys; print(len(yaml.safe_load(open('$1'))))"
}

@test "changelog-add: missing --ticket -> usage error, no write" {
  seed_ledger
  run env CHANGELOG_FILE="$LEDGER" bash "$CHANGELOG_ADD" --summary "s"
  assert_status 2
  assert_output_contains "--ticket is required"
  assert_file_contains "$LEDGER" "DIA-183"
}

@test "changelog-add: missing --summary -> usage error, no write" {
  seed_ledger
  run env CHANGELOG_FILE="$LEDGER" bash "$CHANGELOG_ADD" --ticket DIA-X
  assert_status 2
  assert_output_contains "--summary is required"
}

@test "changelog-add: no --scope and no --area -> usage error, no write" {
  seed_ledger
  run env CHANGELOG_FILE="$LEDGER" bash "$CHANGELOG_ADD" --ticket DIA-X --summary "s"
  assert_status 2
  assert_output_contains "scope required"
}

@test "changelog-add: happy path appends entry, warns manual, validates + renders" {
  seed_ledger
  run env CHANGELOG_FILE="$LEDGER" bash "$CHANGELOG_ADD" \
    --ticket DIA-260825-k8mc --summary "reflect batch landed" \
    --area dev-infra --files scripts/lane-resume,scripts/changelog-add

  assert_status 0
  assert_output_contains "warn: verification defaults to 'manual'"
  assert_output_contains "ok: appended entry for DIA-260825-k8mc"
  # Auto-run validators produced their ok lines.
  assert_output_contains "ok: wrote $BATS_TEST_TMPDIR/CHANGELOG.md (3 entries)"

  # Ledger grew 2 -> 3 and the new entry carries the schema-required fields.
  [ "$(entry_count "$LEDGER")" = "3" ]
  assert_file_contains "$LEDGER" "ticket: DIA-260825-k8mc"
  assert_file_contains "$LEDGER" "verification: manual"
  assert_file_contains "$LEDGER" "area: dev-infra"
  # Comma-split files list survived the PyYAML round trip.
  assert_file_contains "$LEDGER" "- scripts/lane-resume"
  # Derived view was regenerated next to the temp ledger.
  assert_file_contains "$BATS_TEST_TMPDIR/CHANGELOG.md" "DIA-260825-k8mc"
}

@test "changelog-add: non-ASCII summary -> loud rejection, exit 2, no write" {
  # S3 fix: DIA-079 loud reject instead of silent PyYAML escaping.
  # $(printf '\xc3\xa9') is a UTF-8 e-acute built at runtime so this file
  # itself stays ASCII-only (DIA-079).
  seed_ledger
  run env CHANGELOG_FILE="$LEDGER" bash "$CHANGELOG_ADD" \
    --ticket DIA-ASCII --summary "caf$(printf '\xc3\xa9') ascii" --scope dev-infra
  assert_status 2
  assert_output_contains "non-ASCII input rejected (DIA-079)"
  # Ledger untouched by the rejected call (still the seeded 2 entries).
  [ "$(entry_count "$LEDGER")" = "2" ]

  # Control: the ASCII spelling goes through fine.
  run env CHANGELOG_FILE="$LEDGER" bash "$CHANGELOG_ADD" \
    --ticket DIA-ASCII --summary "cafe au lait" --scope dev-infra
  assert_status 0
  [ "$(entry_count "$LEDGER")" = "3" ]
}

@test "changelog-add: scope derived from --area when --scope absent" {
  seed_ledger
  run env CHANGELOG_FILE="$LEDGER" bash "$CHANGELOG_ADD" \
    --ticket DIA-SCOPE --summary "s" --area opencode-config

  assert_status 0
  assert_file_contains "$LEDGER" "scope: opencode-config"
}
