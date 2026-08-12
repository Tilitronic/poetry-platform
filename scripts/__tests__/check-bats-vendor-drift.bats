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

# Baseline accepted by the DIA-121 developer decision (matches the git-ignored
# vendor dir at scripts/__tests__/vendor/bats-core, package.json "1.14.0").
BASELINE_PIN="1.14.0"

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

@test "wrapper wiring: bats-wrapper.sh invokes the drift check with the pin constant" {
  # Structural guard on the integration seam: if a future edit removes the
  # drift check from the wrapper, the detection silently disappears while the
  # check script's own unit tests above still pass. Assert both the pin
  # constant and the check invocation exist in the wrapper (same shape as
  # test-config-wiring.bats).
  assert_file_contains "$REPO_ROOT/scripts/__tests__/bats-wrapper.sh" 'BATS_VENDOR_VERSION="1.14.0"'
  assert_file_contains "$REPO_ROOT/scripts/__tests__/bats-wrapper.sh" "check-bats-vendor-drift.sh"
}
