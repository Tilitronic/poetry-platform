#!/usr/bin/env bats
# Canonical unit tests for scripts/guards/home-qualt.sh -- the shared
# /home/qualt regression guard sourced by both husky hooks (F-6, DIA-139).
#
# Context: an unidentified local writer periodically rewrites
# .opencode/commands/*.md from the portable ${HOME:?HOME must be set} back
# to the literal /home/qualt path (PR #2 comments #2/#3 fixed the original;
# the writer is unknown, so the regression is made impossible to commit).
# The guard greps $COMMANDS_DIR/*.md for the literal path and fails the
# hook when it is found.
#
# This file is the SINGLE canonical home for the guard's grep behavior.
# The hook-level bats files (verify-pre-push.bats / verify-pre-commit.bats)
# only assert that the hook sources and calls the helper -- the two
# duplicated grep-test pairs were removed from there (F-6).
#
# Caller contract (mirrored from the hooks): the helper is SOURCED, not
# executed, and expects $ROOT (for path-stripping in error output) and
# $COMMANDS_DIR (the directory to scan) to be set by the caller first.

load test-helper

@test "guards/home-qualt: helper file exists" {
  local helper="$SCRIPTS_DIR/guards/home-qualt.sh"
  assert_file_exists "$helper"
  # No -x assertion (S-3, DIA-139): the helper is SOURCED, not executed, so
  # the exec bit is not part of its contract -- a chmod -x would be harmless
  # and a test failing on it would be a false positive.
}

@test "guards/home-qualt: defines guard_no_home_qualt" {
  local helper="$SCRIPTS_DIR/guards/home-qualt.sh"
  export ROOT="$REPO_ROOT"
  export COMMANDS_DIR="$BATS_TEST_TMPDIR/commands"
  mkdir -p "$COMMANDS_DIR"
  source "$helper" || { echo "guard helper missing or not sourceable: $helper" >&2; return 1; }
  run type -t guard_no_home_qualt
  assert_status 0
  assert_output_contains "function"
}

@test "guards/home-qualt: exits 1 and names the file when a commands file contains literal /home/qualt" {
  local helper="$SCRIPTS_DIR/guards/home-qualt.sh"
  # ROOT is the temp dir (not $REPO_ROOT) so the ${file#$ROOT/} prefix-strip
  # is observable: with ROOT=$REPO_ROOT the fixture (a temp dir) would never
  # match the strip and the not-contains assertion below would pass vacuously
  # (FALSIFICATION-2, DIA-139).
  export ROOT="$BATS_TEST_TMPDIR"
  export COMMANDS_DIR="$ROOT/commands-dirty"
  mkdir -p "$COMMANDS_DIR"
  printf 'bun run "/home/qualt/.cache/opencode/telemetry/report.ts"\n' > "$COMMANDS_DIR/telemetry-report.md"
  source "$helper" || { echo "guard helper missing or not sourceable: $helper" >&2; return 1; }
  run guard_no_home_qualt
  assert_status 1
  assert_output_contains "ERROR: literal '/home/qualt'"
  # the printed path must be relative to $ROOT: a broken ${file#$ROOT/} strip
  # would leak the full temp-dir prefix into the error output
  assert_output_not_contains "$ROOT/"
  assert_output_contains "commands-dirty/telemetry-report.md"
}

@test "guards/home-qualt: exits 0 silently when no commands file contains literal /home/qualt" {
  local helper="$SCRIPTS_DIR/guards/home-qualt.sh"
  export ROOT="$REPO_ROOT"
  export COMMANDS_DIR="$BATS_TEST_TMPDIR/commands-clean"
  mkdir -p "$COMMANDS_DIR"
  source "$helper" || { echo "guard helper missing or not sourceable: $helper" >&2; return 1; }
  run guard_no_home_qualt
  assert_status 0
  [ -z "$output" ]
}
