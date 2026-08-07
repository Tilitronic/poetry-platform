#!/usr/bin/env bats
# Unit tests for scripts/check-pin-sync.sh (seam: validator script).
#
# 10-case FAKE-mock matrix (T1-T10) covering every branch of the validator:
#   T1  all pins match                          -> exit 0 + ok lines + summary
#   T2  single pin mismatch (node)              -> exit 1 + mismatch fail line
#   T3  multiple pin mismatches (report-ALL)    -> exit 1 + both fail lines
#   T4  .mise.toml missing                      -> exit 2 (INFRA)
#   T5  Dockerfile.dev missing                  -> exit 2 (INFRA)
#   T6  duplicate [tools] key in .mise.toml     -> exit 2 (INFRA ruling)
#   T7  duplicate ARG in Dockerfile.dev         -> exit 2 (INFRA ruling)
#   T8  quote variations                        -> exit 0 after stripping
#   T9  CRLF line endings                       -> exit 0 after stripping
#   T10 whitespace variations                   -> exit 0 after stripping
#
# FAKE-mock invariant: behavioral tests NEVER read the real repo .mise.toml /
# Dockerfile.dev — every fixture is planted under $BATS_TEST_TMPDIR via
# setup_pin_sync_tree (test-helper.bash). The ONE exception is the S4-style
# structural assertion below, which reads the real .mise.toml (mirrors
# check-tools.bats S4).

load test-helper

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# Local stderr assertion: `run --separate-stderr` captures fail lines (stderr)
# separately from ok lines (stdout); test-helper has no stderr helper.
assert_stderr_contains() {
  [[ "$stderr" == *"$1"* ]] || {
    echo "assert_stderr_contains: missing substring: $1" >&2
    echo "--- stderr ---" >&2
    echo "$stderr" >&2
    return 1
  }
}

@test "check-pin-sync: T1 all pins match -> exit 0 + ok lines + summary" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0")"

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity)"
  assert_output_contains "ok: pnpm 10.33.0 (parity)"
  assert_output_contains "summary: 2 ok, 0 fail"
}

@test "check-pin-sync: T2 single pin mismatch (node) -> exit 1 + fail line + summary" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.19.0" "10.33.0")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: node — .mise.toml=24.18.0 Dockerfile.dev=24.19.0"
  assert_output_contains "summary: 1 ok, 1 fail"
}

@test "check-pin-sync: T3 multiple pin mismatches (report-ALL) -> exit 1 + both fail lines" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.19.0" "10.34.0")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: node — .mise.toml=24.18.0 Dockerfile.dev=24.19.0"
  assert_stderr_contains "fail: pnpm — .mise.toml=10.33.0 Dockerfile.dev=10.34.0"
  assert_output_contains "summary: 0 ok, 2 fail"
}

@test "check-pin-sync: T4 .mise.toml missing -> exit 2 (INFRA) + source-defective fail line" {
  tree="$(setup_pin_sync_tree 0 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: .mise.toml not found at $tree/.mise.toml"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

@test "check-pin-sync: T5 Dockerfile.dev missing -> exit 2 (INFRA) + source-defective fail line" {
  tree="$(setup_pin_sync_tree 1 0 "24.18.0" "10.33.0" "24.18.0" "10.33.0")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: Dockerfile.dev not found at $tree/Dockerfile.dev"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

@test "check-pin-sync: T6 duplicate [tools] key in .mise.toml -> exit 2 (INFRA) + duplicate-key fail line" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "dup-mise")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: .mise.toml has duplicate key 'node' under [tools]"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

@test "check-pin-sync: T7 duplicate ARG in Dockerfile.dev -> exit 2 (INFRA) + duplicate-ARG fail line" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "dup-docker")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: Dockerfile.dev has duplicate ARG 'NODE_VERSION'"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

@test "check-pin-sync: T8 quote variations (single/double/unquoted) -> exit 0 after stripping" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "quotes")"

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity)"
  assert_output_contains "ok: pnpm 10.33.0 (parity)"
}

@test "check-pin-sync: T9 CRLF line endings -> exit 0 after stripping" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "crlf")"

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity)"
  assert_output_contains "ok: pnpm 10.33.0 (parity)"
}

@test "check-pin-sync: T10 whitespace variations (extra spaces around =) -> exit 0 after stripping" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "whitespace")"

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity)"
  assert_output_contains "ok: pnpm 10.33.0 (parity)"
}

@test "check-pin-sync: real .mise.toml structural integrity (S4)" {
  # S4-style structural assertion — the ONE case that reads the real repo file
  # (documented exception to the FAKE-mock invariant; mirrors check-tools.bats).
  assert_file_contains "$REPO_ROOT/.mise.toml" "[tools]"
  assert_file_contains "$REPO_ROOT/.mise.toml" 'node = "24.18.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" 'pnpm = "10.33.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" "derived from Dockerfile.dev ARGs"
}
