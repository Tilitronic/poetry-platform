#!/usr/bin/env bats
# Gate tests for scripts/validate-memory-shelf.sh — the JSON Schema gate for
# .opencode/memory-shelf.yaml (DIA-180 A2, wired into `make test-config`).
#
# Hermetic FAKE-mock pattern (check-host-lsp.bats): the validator and its
# schema file are copied into an isolated temp tree, and the shelf under test
# is a committed fixture (scripts/__tests__/fixtures/) selected via the
# SHELF_FILE env override — the REAL 69 KB shelf is never read here (it is
# validated by `make test-config` against the repo file directly).
#
# The fixture shape mirrors the real shelf's observed structure: five item
# sections (conspects/analyses/adrs/specs/architectures) of {name, description,
# path, created} plus the optional extras seen in the wild (status, task_ref,
# id, title, date) and the empty rag_bases list. Assertions stay on the
# validator's stable protocol (exit code, summary line, generic FAIL: lines).
# Contract parity between the schema layer and the embedded structural
# fallback is pinned MECHANICALLY (re-review 1/2, Standards Minor #1; OBS-1):
# the divergence fixtures (malformed optional `date`, empty-string optional
# `date`, whitespace-only `name`) run on BOTH layers — the fallback via a
# jsonschema.py shim that raises ImportError on PYTHONPATH — and both runs
# must produce the same outcome.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FIXTURES="$REPO_ROOT/scripts/__tests__/fixtures"

# setup_tree: copies the validator + schema into an isolated temp tree so the
# script's relative script-dir path resolution (scripts/schemas/) works
# without touching the repo. Echoes the tree root.
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts/schemas"
  cp "$REPO_ROOT/scripts/validate-memory-shelf.sh" "$tree/scripts/validate-memory-shelf.sh"
  cp "$REPO_ROOT/scripts/schemas/memory-shelf.schema.json" "$tree/scripts/schemas/memory-shelf.schema.json"
  echo "$tree"
}

# run_validator <tree> <shelf_file>: runs the validator with a hermetic
# SHELF_FILE override (no repo-path resolution, no real shelf access).
run_validator() {
  run env SHELF_FILE="$2" bash "$1/scripts/validate-memory-shelf.sh"
}

# block_jsonschema <dir>: plants a jsonschema.py that raises ImportError at
# import time, forcing the validator's embedded structural fallback (the
# bare-host path). Prepending the dir to PYTHONPATH makes the fallback layer
# mechanically runnable from bats — the two-layer parity assertions below
# execute each divergence fixture on BOTH layers and require identical
# outcomes (re-review 1/2, Standards Minor #1).
block_jsonschema() {
  local dir="$1"
  mkdir -p "$dir"
  printf 'raise ImportError("blocked: bare-host fallback test")\n' > "$dir/jsonschema.py"
  echo "$dir"
}

@test "validate-memory-shelf: valid fixture shelf -> exit 0 with ok line and summary" {
  tree="$(setup_tree)"
  run_validator "$tree" "$FIXTURES/memory-shelf-valid.yaml"

  assert_status 0
  assert_output_contains "ok: $FIXTURES/memory-shelf-valid.yaml"
  assert_output_contains "1 passed, 0 failed"
}

@test "validate-memory-shelf: broken fixture (missing keys, bad date, unknown key, non-list section) -> exit 1 with FAIL lines" {
  tree="$(setup_tree)"
  run_validator "$tree" "$FIXTURES/memory-shelf-broken.yaml"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"
}

@test "validate-memory-shelf: top-level mapping without 'shelf' key -> exit 1" {
  tree="$(setup_tree)"
  run_validator "$tree" "$FIXTURES/memory-shelf-not-a-shelf.yaml"

  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"
}

@test "validate-memory-shelf: missing shelf file -> exit 2 INFRA" {
  tree="$(setup_tree)"
  run_validator "$tree" "$BATS_TEST_TMPDIR/does-not-exist.yaml"

  assert_status 2
  assert_output_contains "memory-shelf.yaml not found"
}

@test "validate-memory-shelf: malformed optional date fails identically on schema AND fallback layers" {
  tree="$(setup_tree)"
  blocked="$(block_jsonschema "$BATS_TEST_TMPDIR/nojs")"

  # Layer 1: jsonschema present (this host / dev container).
  run_validator "$tree" "$FIXTURES/memory-shelf-date-divergence.yaml"
  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"

  # Layer 2: jsonschema blocked -> embedded structural fallback. The optional
  # `date` pattern check must fail HERE too (the pre-fix divergence: the
  # fallback only checked `created` and wrongly passed this file).
  run env PYTHONPATH="$blocked" SHELF_FILE="$FIXTURES/memory-shelf-date-divergence.yaml" \
    bash "$tree/scripts/validate-memory-shelf.sh"
  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"
}

@test "validate-memory-shelf: whitespace-only name passes identically on schema AND fallback layers (minLength: 1 contract)" {
  tree="$(setup_tree)"
  blocked="$(block_jsonschema "$BATS_TEST_TMPDIR/nojs")"

  # Layer 1: jsonschema present. `minLength: 1` accepts "   " (len 3).
  run_validator "$tree" "$FIXTURES/memory-shelf-whitespace-name.yaml"
  assert_status 0
  assert_output_contains "1 passed, 0 failed"

  # Layer 2: jsonschema blocked -> embedded structural fallback. Option (i)
  # contract: the fallback checks len >= 1, NOT strip() — whitespace-only
  # passes here too (the pre-fix divergence: strip() wrongly failed it).
  run env PYTHONPATH="$blocked" SHELF_FILE="$FIXTURES/memory-shelf-whitespace-name.yaml" \
    bash "$tree/scripts/validate-memory-shelf.sh"
  assert_status 0
  assert_output_contains "1 passed, 0 failed"
}

@test "validate-memory-shelf: empty-string optional date fails identically on schema AND fallback layers (OBS-1)" {
  tree="$(setup_tree)"
  blocked="$(block_jsonschema "$BATS_TEST_TMPDIR/nojs")"

  # Layer 1: jsonschema present. The schema's `pattern` applies to ANY string
  # instance, so `date: ""` fails — the OBS-1 divergence was the fallback's
  # `and value` truthiness short-circuit, which let "" pass.
  run_validator "$tree" "$FIXTURES/memory-shelf-empty-date.yaml"
  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"

  # Layer 2: jsonschema blocked -> embedded structural fallback. Only the
  # absent-optional case (None) passes; empty-string date must fail HERE too.
  run env PYTHONPATH="$blocked" SHELF_FILE="$FIXTURES/memory-shelf-empty-date.yaml" \
    bash "$tree/scripts/validate-memory-shelf.sh"
  assert_status 1
  assert_output_contains "FAIL:"
  assert_output_contains "0 passed, 1 failed"
}
