#!/usr/bin/env bats
# Unit tests for scripts/eval-lite.sh (M5 eval-lite harness, DIA-086 task 6.1;
# this suite is task 7.1). Hermetic: fixtures are synthetic task manifests
# written under $BATS_TEST_TMPDIR, and the container-detection probe is stubbed
# with a fake `docker` on PATH (down = probe fails = dev container
# unavailable). The real dev container, the real manifest, and eval-lite.sh
# itself are never touched.
#
# Seams exercised (design.md Decision 7 / Seam S5):
#   EVAL_LITE_MANIFEST  overrides the manifest path (fixture pointer)
#   PATH docker shim    fakes `docker compose ps --format json dev`
#
# Exit-code contract under test (Seam S5):
#   0  all non-skipped tasks pass (container-bound skips count as pass)
#   1  any non-skipped task fails (FAIL blocks + summary printed)
#   2  manifest file missing (ERROR line)
#   3  manifest exists but contains no task lines (only comments / empty)
#
# Test matrix (maps to task 7.1 AC1-AC7):
#   T1  all-pass fixture         -> exit 0 + "N passed, 0 failed, 0 skipped" (AC1)
#   T2  one-fail fixture         -> exit 1 + FAIL block fields               (AC2)
#   T3  missing manifest path    -> exit 2 + ERROR message                   (AC3)
#   T4  comments-only manifest   -> exit 3                                   (AC5)
#   T5  malformed row (3 fields) -> WARN + processing continues + exit 0     (AC4)
#   T6  container-bound yes row + fake docker DOWN -> skip WARN, K=1, exit 0 (AC6)
#   T7  5-field row              -> WARN + accepted as container-bound: no   (AC7)

load test-helper

bats_require_minimum_version 1.5.0

HARNESS="$REPO_ROOT/scripts/eval-lite.sh"

# mock_docker_down: plants a fake `docker` on PATH whose `compose ps` probe
# FAILS (exit 1, no output). Per design.md Decision 7 any probe failure means
# "dev container unavailable", so the harness skips container-bound tasks.
# Mirrors test-helper.bash's mock_docker pattern, scoped to the harness's
# single probe.
mock_docker_down() {
  local bindir="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$bindir"
  cat > "$bindir/docker" <<'FAKEDOCKER'
#!/usr/bin/env bash
# Fake docker for eval-lite tests: `compose ps` fails => container unavailable.
exit 1
FAKEDOCKER
  chmod +x "$bindir/docker"
  PATH="$bindir:$PATH"
  export PATH
}

# write_fixture <file> <printf-format...>: writes manifest lines to <file>.
# Formats carry literal \t escapes (printf %b turns them into real tabs) so the
# fixture files have the TSV shape the harness expects.
write_fixture() {
  local file="$1"
  shift
  : > "$file"
  local fmt
  for fmt in "$@"; do
    printf '%b\n' "$fmt" >> "$file"
  done
}

@test "eval-lite: T1 all-pass fixture -> exit 0 + 'N passed, 0 failed, 0 skipped'" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t1"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  write_fixture "$manifest" \
    'T-OK\ttrue\t0\tunit\tevidence\tno' \
    'T-OK2\ttrue\t0\tunit\tevidence\tno'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "2 passed, 0 failed, 0 skipped"
  assert_output_not_contains "FAIL:"
  assert_output_not_contains "WARN:"
}

@test "eval-lite: T2 one-fail fixture -> exit 1 + FAIL block fields" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t2"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  write_fixture "$manifest" \
    'T-OK\ttrue\t0\tunit\tevidence\tno' \
    'T-FAIL\tfalse\t0\tunit\tevidence\tno'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 1
  assert_output_contains "FAIL: T-FAIL"
  assert_output_contains "  command: false"
  assert_output_contains "  expected-exit: 0"
  assert_output_contains "  observed-exit: 1"
  assert_output_contains "  source-suite: unit"
  assert_output_contains "  failure-evidence: evidence"
  assert_output_contains "1 passed, 1 failed, 0 skipped"
}

@test "eval-lite: T3 missing manifest -> exit 2 + ERROR message" {
  # No docker mock needed: the file-exists gate (exit 2) fires before the
  # container probe.
  EVAL_LITE_MANIFEST="$BATS_TEST_TMPDIR/does-not-exist.tsv" run bash "$HARNESS"

  assert_status 2
  assert_output_contains "ERROR: docs/dev-infra/eval-lite-tasks.md not found"
}

@test "eval-lite: T4 comments-only manifest -> exit 3" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t4"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  printf '# eval-lite test fixture (comments only)\n# no task lines present\n' > "$manifest"

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 3
  assert_output_contains "contains no task lines"
}

@test "eval-lite: T5 malformed row (wrong field count) -> WARN + processing continues + exit 0" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t5"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  # Line 1: 3 fields (malformed, skipped with WARN). Line 2: valid 6-field row.
  write_fixture "$manifest" \
    'T-MAL\ttrue\t0' \
    'T-OK\ttrue\t0\tunit\tevidence\tno'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "WARN: line 1 has 3 fields (expected 5 or 6) -- skipping"
  assert_output_contains "1 passed, 0 failed, 0 skipped"
  assert_output_not_contains "FAIL:"
}

@test "eval-lite: T6 container-bound yes row + docker probe down -> skip WARN + K=1 + exit 0" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t6"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  write_fixture "$manifest" \
    'T-CONT\ttrue\t0\tunit\tevidence\tyes'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "WARN: skipping container-bound task T-CONT (dev container not running)"
  assert_output_contains "0 passed, 0 failed, 1 skipped"
  assert_output_not_contains "FAIL:"
}

@test "eval-lite: T7 5-field row (missing 6th) -> WARN + assumed container-bound: no + runs + exit 0" {
  local tree manifest
  tree="$BATS_TEST_TMPDIR/t7"
  mkdir -p "$tree"
  manifest="$tree/manifest.tsv"
  # 5 fields: container-bound column absent (pre-M5 backward compat, AC9).
  write_fixture "$manifest" \
    'T-5\ttrue\t0\tunit\tevidence'

  mock_docker_down
  EVAL_LITE_MANIFEST="$manifest" run bash "$HARNESS"

  assert_status 0
  assert_output_contains "WARN: line 1 has 5 fields (missing container-bound field) -- assuming container-bound: no"
  assert_output_contains "1 passed, 0 failed, 0 skipped"
  assert_output_not_contains "FAIL:"
}
