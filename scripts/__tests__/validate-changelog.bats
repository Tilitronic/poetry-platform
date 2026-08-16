#!/usr/bin/env bats
# Gate tests for scripts/validate-changelog.sh — the JSON Schema gate for
# .opencode/CHANGELOG.yaml (DIA-194 Variant B, wired into `make test-config`).
#
# Hermetic FAKE-mock pattern (validate-memory-shelf.bats): the validator and
# its schema file are copied into an isolated temp tree, and the ledger under
# test is a committed fixture (scripts/__tests__/fixtures/) selected via the
# CHANGELOG_FILE env override — the REAL ledger is never read here (it is
# validated by `make test-config` against the repo file directly).
#
# The fixture shape mirrors the ledger's observed structure: a top-level
# array of {date, ticket, scope, files, summary, verification} plus the
# optional extras seen in the wild (severity, status, area, route). Assertions
# stay on the validator's stable protocol (exit code, summary line, generic
# FAIL: lines). Contract parity between the schema layer and the embedded
# structural fallback is pinned MECHANICALLY (same shim trick as
# validate-memory-shelf.bats): the malformed-date fixture runs on BOTH layers
# — the fallback via a jsonschema.py shim that raises ImportError on
# PYTHONPATH — and both runs must produce the same outcome.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FIXTURES="$REPO_ROOT/scripts/__tests__/fixtures"

# setup_tree: copies the validator + schema into an isolated temp tree so the
# script's relative script-dir path resolution (scripts/schemas/) works
# without touching the repo. Echoes the tree root.
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts/schemas"
  cp "$REPO_ROOT/scripts/validate-changelog.sh" "$tree/scripts/validate-changelog.sh"
  cp "$REPO_ROOT/scripts/schemas/changelog.schema.json" "$tree/scripts/schemas/changelog.schema.json"
  echo "$tree"
}

# run_validator <tree> <changelog_file>: runs the validator with a hermetic
# CHANGELOG_FILE override (no repo-path resolution, no real ledger access).
run_validator() {
  run env CHANGELOG_FILE="$2" bash "$1/scripts/validate-changelog.sh"
}

# block_jsonschema <dir>: plants a jsonschema.py that raises ImportError at
# import time, forcing the validator's embedded structural fallback (the
# bare-host path). Prepending the dir to PYTHONPATH makes the fallback layer
# mechanically runnable from bats — the two-layer parity assertions below
# execute the malformed-date fixture on BOTH layers and require identical
# outcomes (mirror of validate-memory-shelf.bats's parity pins).
block_jsonschema() {
  local dir="$1"
  mkdir -p "$dir"
  printf 'raise ImportError("blocked: bare-host fallback test")\n' > "$dir/jsonschema.py"
  echo "$dir"
}

@test "validate-changelog: valid fixture ledger -> exit 0 with ok line and summary" {
  tree="$(setup_tree)"
  run_validator "$tree" "$FIXTURES/changelog-valid.yaml"

  assert_status 0
  assert_output_contains "ok: $FIXTURES/changelog-valid.yaml"
  assert_output_contains "1 passed, 0 failed"
}

@test "validate-changelog: missing required fields (summary, verification, files) -> exit 1 with FAIL lines" {
  tree="$(setup_tree)"
  run_validator "$tree" "$FIXTURES/changelog-missing-required.yaml"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"
}

@test "validate-changelog: malformed date fails identically on schema AND fallback layers" {
  tree="$(setup_tree)"
  blocked="$(block_jsonschema "$BATS_TEST_TMPDIR/nojs")"

  # Layer 1: jsonschema present (this host / dev container).
  run_validator "$tree" "$FIXTURES/changelog-bad-date.yaml"
  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"

  # Layer 2: jsonschema blocked -> embedded structural fallback. The `date`
  # pattern check must fail HERE too (the parity pin: the fallback's DATE_RE
  # mirrors the schema's pattern, including the empty-string case).
  run env PYTHONPATH="$blocked" CHANGELOG_FILE="$FIXTURES/changelog-bad-date.yaml" \
    bash "$tree/scripts/validate-changelog.sh"
  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"
}

@test "validate-changelog: extra property -> exit 1 (additionalProperties: false)" {
  tree="$(setup_tree)"
  run_validator "$tree" "$FIXTURES/changelog-extra-property.yaml"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"
}

@test "validate-changelog: empty ledger file -> exit 1 (comment-only file parses to None, not an array)" {
  tree="$(setup_tree)"
  run_validator "$tree" "$FIXTURES/changelog-empty.yaml"

  # An empty/comment-only file parses to None, which is not the schema's
  # top-level array — same fail-closed behavior as validate-memory-shelf.sh
  # on a file with no 'shelf:' mapping. An explicit `[]` (changelog-empty-array.yaml)
  # is the valid empty-ledger spelling.
  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"
}

@test "validate-changelog: explicit empty array -> exit 0 (valid empty ledger)" {
  tree="$(setup_tree)"
  run_validator "$tree" "$FIXTURES/changelog-empty-array.yaml"

  assert_status 0
  assert_output_contains "ok: $FIXTURES/changelog-empty-array.yaml"
  assert_output_contains "1 passed, 0 failed"
}

@test "validate-changelog: missing ledger file -> exit 2 INFRA" {
  tree="$(setup_tree)"
  run_validator "$tree" "$BATS_TEST_TMPDIR/does-not-exist.yaml"

  assert_status 2
  assert_output_contains "CHANGELOG.yaml not found"
}
