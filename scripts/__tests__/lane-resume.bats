#!/usr/bin/env bats
# Tests for scripts/lane-resume (DIA-260825-k8mc item 3): jq triage over a
# registry.jsonl fixture via the REGISTRY_FILE env override (mirrors
# TICKETS_DIR). Decision contract:
#   errored                                  -> fresh-required
#   complete but no terminal event or empty  -> resume-recommended
#   terminal ok                              -> landed-or-complete
#   no matching rows                         -> unknown-id
# The real .opencode/session/registry.jsonl is never read here.

load test-helper

LANE_RESUME="$REPO_ROOT/scripts/lane-resume"

write_registry() {
  printf '%s\n' "$@" > "$REGISTRY"
}

setup() {
  REGISTRY="$BATS_TEST_TMPDIR/registry.jsonl"
}

@test "lane-resume: no args -> usage error, exit 2" {
  run bash "$LANE_RESUME"
  assert_status 2
  assert_output_contains "usage:"
}

@test "lane-resume: missing registry file -> exit 2" {
  run env REGISTRY_FILE="$BATS_TEST_TMPDIR/nope.jsonl" bash "$LANE_RESUME" ses_x
  assert_status 2
  assert_output_contains "registry not found"
}

@test "lane-resume: id not in registry -> unknown-id, exit 0" {
  write_registry \
    '{"seq":1,"session_id":"ses_other","event":"session_spawn","dispatch_state":"running"}'
  run env REGISTRY_FILE="$REGISTRY" bash "$LANE_RESUME" ses_unknown
  assert_status 0
  assert_output_contains "rows=0"
  assert_output_contains "decision: unknown-id"
}

@test "lane-resume: session_failed row -> fresh-required" {
  write_registry \
    '{"seq":1,"session_id":"ses_err","event":"session_spawn","dispatch_state":"running","agent":"coder"}' \
    '{"seq":2,"session_id":"ses_err","event":"session_failed","dispatch_state":"failed","agent":"coder"}'
  run env REGISTRY_FILE="$REGISTRY" bash "$LANE_RESUME" ses_err
  assert_status 0
  assert_output_contains "last_state=failed agent=coder terminal_event=no"
  assert_output_contains "decision: fresh-required"
}

@test "lane-resume: completed but no terminal event -> resume-recommended" {
  write_registry \
    '{"seq":1,"session_id":"ses_trunc","event":"session_spawn","dispatch_state":"running"}' \
    '{"seq":2,"session_id":"ses_trunc","event":"empty_result_detected","dispatch_state":"completed"}'
  run env REGISTRY_FILE="$REGISTRY" bash "$LANE_RESUME" ses_trunc
  assert_status 0
  assert_output_contains "terminal_event=no"
  assert_output_contains "decision: resume-recommended (load resume-truncated-lane skill)"
}

@test "lane-resume: session_complete terminal -> landed-or-complete" {
  write_registry \
    '{"seq":1,"session_id":"ses_ok","event":"session_spawn","dispatch_state":"running","agent":"coder"}' \
    '{"seq":2,"session_id":"ses_ok","event":"task_success","dispatch_state":"completed","agent":"coder"}' \
    '{"seq":3,"session_id":"ses_ok","event":"session_complete","dispatch_state":"completed","agent":"coder"}'
  run env REGISTRY_FILE="$REGISTRY" bash "$LANE_RESUME" ses_ok
  assert_status 0
  assert_output_contains "last_state=completed agent=coder terminal_event=yes"
  assert_output_contains "decision: landed-or-complete"
}

@test "lane-resume: last dispatch_state=running -> still-running, exit 0" {
  # F2 fix: a possibly-live session must not be classified resume-recommended.
  write_registry \
    '{"seq":1,"session_id":"ses_live","event":"session_spawn","dispatch_state":"running","agent":"coder"}'
  run env REGISTRY_FILE="$REGISTRY" bash "$LANE_RESUME" ses_live
  assert_status 0
  assert_output_contains "last_state=running"
  assert_output_contains "decision: still-running (possibly live session, do not double-dispatch)"
}

@test "lane-resume: matches on task_id as well as session_id" {
  write_registry \
    '{"seq":1,"task_id":"task-42","session_id":"ses_inner","event":"session_failed","dispatch_state":"failed"}'
  run env REGISTRY_FILE="$REGISTRY" bash "$LANE_RESUME" task-42
  assert_status 0
  assert_output_contains "rows=1"
  assert_output_contains "decision: fresh-required"
}
