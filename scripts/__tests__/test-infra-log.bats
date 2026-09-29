#!/usr/bin/env bats
# Unit tests for scripts/test-infra-log.sh (DIA-260927-vmpa, review FIX 2b).
#
# The wrapper is the load-bearing half of `make test-infra`'s logging: it
# truncates the log per run, mirrors stdout+stderr into it, records the
# INNER command's exit code in the trailer line, and exits with that same
# code. These tests drive the production helper itself - success and failure
# inner commands, no container engine, temp log only (the real
# .opencode/session/test-infra.log is never touched) - because a wrapper that
# can log a green 0 over a failed run is worse than no log at all (FIX 1).

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/test-infra-log.sh"

setup() {
  LOG="$BATS_TEST_TMPDIR/test-infra.log"
  # Seed a stale log so truncation-vs-append is observable: an appending
  # wrapper would keep the stale "exit code: 0" line next to the new one.
  printf 'STALE PREVIOUS RUN\n==> test-infra exit code: 0\n' >"$LOG"
}

@test "wrapper: successful inner command -> exit 0, both streams logged, trailer records 0" {
  run bash "$WRAPPER" "$LOG" bash -c 'echo "to stdout"; echo "to stderr" >&2'
  assert_status 0
  assert_output_contains "to stdout"
  assert_output_contains "to stderr"
  assert_file_contains "$LOG" "to stdout"
  assert_file_contains "$LOG" "to stderr"
  assert_file_contains "$LOG" "==> test-infra exit code: 0"
}

@test "wrapper: failing inner command -> wrapper exit code and trailer both record 7" {
  run bash "$WRAPPER" "$LOG" bash -c 'echo "before failure"; exit 7'
  assert_status 7
  assert_file_contains "$LOG" "before failure"
  assert_file_contains "$LOG" "==> test-infra exit code: 7"
}

@test "wrapper: log is truncated per run - stale content never survives" {
  run bash "$WRAPPER" "$LOG" bash -c 'exit 1'
  assert_status 1
  assert_file_contains "$LOG" "==> test-infra exit code: 1"
  if grep -qF "STALE PREVIOUS RUN" "$LOG"; then
    echo "stale log content survived truncation (append instead of truncate)" >&2
    return 1
  fi
}

@test "wrapper: fails loud through a non-bash shell (pipefail guarantee must not be assumed)" {
  # The guard is reachable only where the interpreter is NOT bash: when
  # /bin/sh IS bash, `sh script` is bash in POSIX mode, pipefail works, and
  # the guard correctly does not fire (see the wrapper's header comment).
  # Prefer a real non-bash shell; skip only where none exists.
  if command -v dash >/dev/null 2>&1; then
    nonbash=dash
  elif sh -c 'test -n "${BASH_VERSION:-}"' >/dev/null 2>&1; then
    skip "/bin/sh is bash here and dash is unavailable; the non-bash guard path is unreachable"
  else
    nonbash=sh
  fi
  run "$nonbash" "$WRAPPER" "$LOG" bash -c 'exit 0'
  assert_status 2
  assert_output_contains "bash required"
}
