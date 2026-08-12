#!/usr/bin/env bats
# Unit tests for scripts/__tests__/check-bats-vendor-drift.sh (DIA-121).
#
# Background: bats-wrapper.sh pins a bats version (BATS_VENDOR_VERSION) and
# clones bats-core into a git-ignored vendor dir on first run. The dir is
# never re-validated, so a machine can silently drift to a different bats
# version (this actually happened: vendor sat at v1.14.0 while the pin
# claimed v1.11.0). The drift check closes that gap by comparing the
# vendored package.json version against the pin.
#
# Seam under test: the check script is a pure function of (pin, vendor dir) —
# each test builds its own temp vendor tree and asserts on exit code + output.
# No network, no real bats, no mutations of the real vendor dir.

load test-helper

# FAL-2 wiring tests use `run -127` (declared non-zero exit for the
# intentionally-incomplete synthetic wrapper tree); flags on `run` need 1.5.0+.
bats_require_minimum_version 1.5.0

# Baseline pin is read from bats-wrapper.sh (the single source of truth for
# BATS_VENDOR_VERSION) instead of being hardcoded, so a future intentional
# re-pin does not silently break these tests (DIA-121 FAL-3). Bats package.json
# versions are tagless semver (no leading "v"). Currently "1.14.0" (matches the
# git-ignored vendor dir at scripts/__tests__/vendor/bats-core).
WRAPPER="$REPO_ROOT/scripts/__tests__/bats-wrapper.sh"
BASELINE_PIN="$(sed -n 's/.*BATS_VENDOR_VERSION="\([^"]*\)".*/\1/p' "$WRAPPER" | head -n 1)"
[ -n "$BASELINE_PIN" ] || { echo "fatal: could not read BATS_VENDOR_VERSION from $WRAPPER" >&2; exit 1; }

# The check script is stored non-executable (repo convention, like every
# script under scripts/), so tests invoke it explicitly via bash.
CHECK_SCRIPT="$BATS_TEST_DIRNAME/check-bats-vendor-drift.sh"

# make_vendor_tree <version>: creates a fake vendored bats-core checkout under
# $BATS_TEST_TMPDIR with a package.json carrying the given version. Echoes the
# checkout path.
make_vendor_tree() {
  local version="$1"
  local dir="$BATS_TEST_TMPDIR/vendor/bats-core"
  mkdir -p "$dir"
  printf '{\n  "name": "bats",\n  "version": "%s"\n}\n' "$version" > "$dir/package.json"
  echo "$dir"
}

# make_nested_version_tree <top_version>: builds a vendor tree whose
# package.json carries a nested "version" key (inside a "scripts" block) BEFORE
# the top-level one. The naive "first version match" extraction would read the
# nested value as the bats version; the hardened extraction must read the
# TOP-LEVEL value (DIA-121 FAL-1). Echoes the checkout path.
make_nested_version_tree() {
  local top_version="$1"
  local dir="$BATS_TEST_TMPDIR/vendor/bats-core"
  mkdir -p "$dir"
  cat > "$dir/package.json" <<JSON
{
  "name": "bats",
  "scripts": {
    "version": "0.0.1-nested"
  },
  "version": "$top_version"
}
JSON
  echo "$dir"
}

@test "drift check passes when vendored version matches the pin" {
  local dir
  dir="$(make_vendor_tree "$BASELINE_PIN")"

  run bash "$CHECK_SCRIPT" "$BASELINE_PIN" "$dir"

  assert_status 0
  assert_output_not_contains "warning"
}

@test "drift check detects the original v1.11.0 pin against a v1.14.0 vendor tree (DIA-121 positive control)" {
  # Reproduces the exact DIA-121 drift: vendor dir at 1.14.0, wrapper pin
  # still claiming 1.11.0. Detection must be reported, not swallowed.
  local dir
  dir="$(make_vendor_tree "$BASELINE_PIN")"

  run bash "$CHECK_SCRIPT" "1.11.0" "$dir"

  assert_status 1
  assert_output_contains "version mismatch"
  assert_output_contains "1.11.0"
  assert_output_contains "1.14.0"
}

@test "drift check detects a vendor upgrade past the current pin" {
  # Future-proofing: a machine whose vendor dir moves ahead of the pin (e.g.
  # a manual re-clone to a newer release) must be flagged too.
  local dir
  dir="$(make_vendor_tree "1.15.0")"

  run bash "$CHECK_SCRIPT" "$BASELINE_PIN" "$dir"

  assert_status 1
  assert_output_contains "version mismatch"
  assert_output_contains "1.15.0"
}

@test "drift check reads the TOP-LEVEL version even when a nested object has a version field first (FAL-1)" {
  # A package.json can carry a nested "version" key (e.g. a "scripts" block
  # naming a version task) before the root one. The extraction must resolve the
  # root-level bats version, not the first "version" key in the file.
  local dir
  dir="$(make_nested_version_tree "$BASELINE_PIN")"

  # Match: the nested "0.0.1-nested" must NOT be mistaken for the bats version.
  run bash "$CHECK_SCRIPT" "$BASELINE_PIN" "$dir"

  assert_status 0
  assert_output_not_contains "warning"

  # Mismatch: the reported version must be the TOP-LEVEL one, not the nested one.
  run bash "$CHECK_SCRIPT" "1.15.0" "$dir"

  assert_status 1
  assert_output_contains "version mismatch"
  assert_output_contains "$BASELINE_PIN"
  assert_output_not_contains "0.0.1-nested"
}

@test "drift check is silent when the vendor dir does not exist" {
  # First-run state: nothing is vendored yet, the fresh clone establishes the
  # version, so there is no drift to report.
  run bash "$CHECK_SCRIPT" "$BASELINE_PIN" "$BATS_TEST_TMPDIR/missing/vendor/bats-core"

  assert_status 0
  assert_output_not_contains "warning"
}

@test "drift check warns when the vendor dir lacks package.json" {
  # A vendor dir that exists but is not a proper bats-core checkout cannot be
  # verified against the pin and must not pass silently.
  mkdir -p "$BATS_TEST_TMPDIR/vendor/bats-core"

  run bash "$CHECK_SCRIPT" "$BASELINE_PIN" "$BATS_TEST_TMPDIR/vendor/bats-core"

  assert_status 1
  assert_output_contains "no package.json"
}

@test "drift check rejects missing arguments with a usage error" {
  run bash "$CHECK_SCRIPT"

  assert_status 2
  assert_output_contains "usage"
}

# make_wrapper_tree <vendor_version>: copies the REAL bats-wrapper.sh and
# check-bats-vendor-drift.sh into an isolated tree and plants a vendored
# bats-core checkout with the given version. The wrapper's ROOT resolves to the
# temp tree, so its drift-check block runs against the planted vendor dir
# (hermetic - the real git-ignored vendor dir is never touched). The synthetic
# tree does NOT contain the wrapper's other dependencies (bash -n targets,
# node script), so the run exits non-zero after the drift block; the FAL-2
# tests assert on the drift warning text, not the overall exit code. Echoes
# the wrapper path.
make_wrapper_tree() {
  local vendor_version="$1"
  local tree="$BATS_TEST_TMPDIR/wrapper-tree"
  local tests_dir="$tree/scripts/__tests__"
  mkdir -p "$tests_dir/vendor/bats-core"
  cp "$REPO_ROOT/scripts/__tests__/bats-wrapper.sh" "$tests_dir/bats-wrapper.sh"
  cp "$REPO_ROOT/scripts/__tests__/check-bats-vendor-drift.sh" "$tests_dir/check-bats-vendor-drift.sh"
  printf '{\n  "name": "bats",\n  "version": "%s"\n}\n' "$vendor_version" > "$tests_dir/vendor/bats-core/package.json"
  echo "$tests_dir/bats-wrapper.sh"
}

@test "wrapper wiring: bats-wrapper.sh invokes the drift check with the pin constant" {
  # Structural guard on the integration seam: if a future edit removes the
  # drift check from the wrapper, the detection silently disappears while the
  # check script's own unit tests above still pass. The pin value is read from
  # the wrapper itself (DIA-121 FAL-3) so an intentional re-pin does not break
  # this test as a side effect.
  local wrapper_pin
  wrapper_pin="$(sed -n 's/.*BATS_VENDOR_VERSION="\([^"]*\)".*/\1/p' "$WRAPPER" | head -n 1)"
  [ -n "$wrapper_pin" ] || { echo "could not read BATS_VENDOR_VERSION from $WRAPPER" >&2; return 1; }
  assert_file_contains "$WRAPPER" "BATS_VENDOR_VERSION=\"$wrapper_pin\""
  assert_file_contains "$WRAPPER" "check-bats-vendor-drift.sh"
}

@test "wrapper wiring end-to-end: drifted vendor emits the drift warning (FAL-2 positive control)" {
  # The wrapper guards the drift check with `|| true` (warn-and-continue), so a
  # regression in the check script or its invocation would otherwise be
  # silently swallowed. This test runs the REAL wrapper (copied at test time)
  # against a planted mismatched vendor dir and proves the drift warning
  # actually reaches stderr.
  #
  # The synthetic tree only carries the two wrapper deps the drift block needs;
  # the later bash -n loop fails on the missing real scripts, so the wrapper
  # exits 127. That is expected - the assertion is on the drift warning text,
  # not the overall exit code (which is why run -127 is declared).
  local wrapper
  wrapper="$(make_wrapper_tree "1.11.0")"

  run -127 bash "$wrapper"

  assert_output_contains "vendored bats version mismatch"
  assert_output_contains "is at v1.11.0"
  assert_output_contains "pins v$BASELINE_PIN"
}

@test "wrapper wiring end-to-end: consistent vendor emits no drift warning (FAL-2 negative control)" {
  # Counterpart of the positive control: on a consistent vendor state the
  # wrapper's drift block must stay silent (no warning text at all). Same
  # synthetic-tree caveat as above -> expected exit 127 from the bash -n loop.
  local wrapper
  wrapper="$(make_wrapper_tree "$BASELINE_PIN")"

  run -127 bash "$wrapper"

  assert_output_not_contains "version mismatch"
  assert_output_not_contains "warning"
}
