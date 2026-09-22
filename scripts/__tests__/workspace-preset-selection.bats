#!/usr/bin/env bats
# Unit tests for scripts/presets.py, the registry reader behind the
# single-path preset launch (campaign ticket DIA-260918-vsq8).
#
# Why this file exists separately from preset-single-path.bats: that suite
# proves the make-level contract (presets list, preset stub, -e PRESET
# forwarding, precedence, loud unknown-name failure). This suite proves the
# helper itself: sorted non-empty list, exact-name check, loud failure with
# the available list, and fail-closed parse errors. No compose, no OMO
# source, no project-local store (the stored-selection path is gone).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HELPER="$REPO_ROOT/scripts/presets.py"

@test "list prints a sorted non-empty registry including free and muse-balanced" {
  run python3 "$HELPER" list
  assert_status 0
  assert_output_contains "free"
  assert_output_contains "muse-balanced"
  [ -n "$output" ]
  sorted="$(printf '%s\n' "$output" | LC_ALL=C sort)"
  [ "$output" = "$sorted" ]
}

@test "check accepts an exact registry name" {
  run python3 "$HELPER" check free
  assert_status 0
  assert_output_contains "free"
}

@test "check rejects an unknown name loudly with the available list" {
  run python3 "$HELPER" check does-not-exist
  [ "$status" -ne 0 ]
  assert_output_contains "does-not-exist"
  assert_output_contains "Available presets"
  assert_output_contains "muse-balanced"
}

@test "check rejects a near-miss name (exact match only, no fuzzy fallback)" {
  run python3 "$HELPER" check Free
  [ "$status" -ne 0 ]
  assert_output_contains "Available presets"
}

@test "usage error exits 2" {
  run python3 "$HELPER" bogus
  assert_status 2
  assert_output_contains "usage"
}

@test "helper uses stdlib only (plus the single-owner sibling stripper)" {
  run grep -E "^import |^from [A-Za-z]" "$HELPER"
  assert_status 0
  [ "$(printf '%s\n' "$output" | grep -cvE '^import (json|os|sys)$|^from jsonc_strip import strip_jsonc([[:space:]]|$)')" -eq 0 ]
}

@test "fail-closed on missing registry" {
  run env PRESETS_JSONC="$BATS_TEST_TMPDIR/does-not-exist.jsonc" python3 "$HELPER" list
  assert_status 1
}

@test "fail-closed on corrupt registry" {
  printf '{not valid jsonc,,,\n' > "$BATS_TEST_TMPDIR/corrupt.jsonc"
  run env PRESETS_JSONC="$BATS_TEST_TMPDIR/corrupt.jsonc" python3 "$HELPER" list
  assert_status 1
}

@test "fail-closed on empty registry and on missing presets key" {
  : > "$BATS_TEST_TMPDIR/empty.jsonc"
  run env PRESETS_JSONC="$BATS_TEST_TMPDIR/empty.jsonc" python3 "$HELPER" list
  assert_status 1
  printf '{"other": {}}\n' > "$BATS_TEST_TMPDIR/no-key.jsonc"
  run env PRESETS_JSONC="$BATS_TEST_TMPDIR/no-key.jsonc" python3 "$HELPER" check free
  assert_status 1
  assert_output_contains "no presets key"
}

@test "stripper keeps URL slashes and apostrophes (double-quote strings only)" {
  printf '{"presets": {"it'"'"'s-free": {}, "free": {}}, "url": "https://example.com/x"} // trailing\n' > "$BATS_TEST_TMPDIR/apos.jsonc"
  run env PRESETS_JSONC="$BATS_TEST_TMPDIR/apos.jsonc" python3 "$HELPER" list
  assert_status 0
  assert_output_contains "free"
}
