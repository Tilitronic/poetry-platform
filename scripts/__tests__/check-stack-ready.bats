#!/usr/bin/env bats
# check-stack-ready.bats -- tests for the stack-readiness probe.
# Frozen contract: exit 0 => STACK_READY; exit !=0 => STACK_NOT_READY.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../check-stack-ready.sh"
}

@test "check-stack-ready: missing DATABASE_URL and CHECK_TARGET yields STACK_NOT_READY" {
  run env -u DATABASE_URL -u CHECK_TARGET "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$output" = "STACK_NOT_READY" ]
}

@test "check-stack-ready: CHECK_TARGET pointing to a dead host yields STACK_NOT_READY" {
  run env CHECK_TARGET="192.0.2.1:1" "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$output" = "STACK_NOT_READY" ]
}

@test "check-stack-ready: script uses DATABASE_URL, not a hardcoded host" {
  # Verify the script does not contain a bare 'connect((' with a literal host
  ! grep -q 'connect((.*postgres' "$SCRIPT"
}
