#!/usr/bin/env bats
# Unit tests for .opencode/scripts/jsonl-cross-check.sh (ana007 Option E
# Phase 5 — registry↔messages completeness cross-check). Hermetic pattern from
# session-log.bats: the script is copied into an isolated temp tree
# (setup_tree) and every invocation runs against fixture jsonl files in
# BATS_TEST_TMPDIR — the real .opencode/session/*.jsonl are never touched.
# jq is NOT faked: the check-host-jq probe is a make test-shell prerequisite,
# so a functional jq is guaranteed on PATH when this suite runs.
#
# Every invocation passes an explicit `--since` so fixtures stay hermetic and
# do not depend on the real default cutoff (2026-08-06T19:30:00Z — plugin
# messages-writer activation). Fixture timestamps are all on 2026-08-06.
#
# 11-case matrix: pass / fail / missing-file / malformed-skip+warn /
# threshold override / outside-tolerance diagnostic / empty-registry fail-loud /
# legacy-excluded / since-override-changes-universe / all-below-cutoff fail-loud /
# bad-timestamp skip+warn.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# setup_tree: copies jsonl-cross-check.sh into an isolated temp tree. Echoes
# the tree root (mirrors session-log.bats setup_tree).
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/.opencode/scripts"
  cp "$REPO_ROOT/.opencode/scripts/jsonl-cross-check.sh" \
    "$tree/.opencode/scripts/jsonl-cross-check.sh"
  echo "$tree"
}

# write_fixture <dir> <name>: writes the named registry.jsonl + messages.jsonl
# pair into <dir>.
#   pass       — 2 task_success (t-1, t-2), 2 delegations within ±5s  -> 100%
#   half       — 2 task_success, 1 delegation (t-1)                    -> 50%
#   stale      — 2 task_success, 1 delegation with SAME task_id but a
#                timestamp 13h away (legacy-style round-minute)        -> 0% within
#   malformed  — pass pair with a garbage line inside registry.jsonl   -> warn+skip
#   empty      — registry with only a session_spawn (no task_success)  -> exit 2
#   split      — 2 legacy (10:00, before cutoff) + 2 in-universe (13:00),
#                delegations for the in-universe pair                   -> 100%
#   alllegacy  — 2 task_success BEFORE cutoff, delegations present      -> exit 2
#   badts      — 1 valid + 1 task_success with unparseable timestamp,
#                delegation for the valid row                           -> warn+skip, 100%
write_fixture() {
  local dir="$1"
  local name="$2"
  mkdir -p "$dir"
  case "$name" in
    pass)
      cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-06T10:00:00.000Z","event":"task_success","task_id":"t-1","writer":"plugin"}
{"seq":2,"timestamp":"2026-08-06T10:01:00.000Z","event":"task_success","task_id":"t-2","writer":"plugin"}
JSONL
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":1,"timestamp":"2026-08-06T10:00:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","gen_ai.agent.id":"t-1","from":"orchestrator","event_type":"delegation","task_ref":"Task one","lane_id":"cod-1","writer":"plugin"}
{"row_id":2,"timestamp":"2026-08-06T10:01:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"reviewer","gen_ai.agent.id":"t-2","from":"orchestrator","event_type":"delegation","task_ref":"Task two","lane_id":"rev-1","writer":"plugin"}
JSONL
      ;;
    half)
      cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-06T10:00:00.000Z","event":"task_success","task_id":"t-1","writer":"plugin"}
{"seq":2,"timestamp":"2026-08-06T10:01:00.000Z","event":"task_success","task_id":"t-2","writer":"plugin"}
JSONL
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":1,"timestamp":"2026-08-06T10:00:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","gen_ai.agent.id":"t-1","from":"orchestrator","event_type":"delegation","task_ref":"Task one","lane_id":"cod-1","writer":"plugin"}
JSONL
      ;;
    stale)
      cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-06T10:00:00.000Z","event":"task_success","task_id":"t-1","writer":"plugin"}
{"seq":2,"timestamp":"2026-08-06T10:01:00.000Z","event":"task_success","task_id":"t-2","writer":"plugin"}
JSONL
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":1,"timestamp":"2026-08-06T23:15:00Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","gen_ai.agent.id":"t-1","from":"orchestrator","event_type":"delegation","task_ref":"Task one","lane_id":"cod-1"}
JSONL
      ;;
    malformed)
      cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-06T10:00:00.000Z","event":"task_success","task_id":"t-1","writer":"plugin"}
this is not json
{"seq":2,"timestamp":"2026-08-06T10:01:00.000Z","event":"task_success","task_id":"t-2","writer":"plugin"}
JSONL
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":1,"timestamp":"2026-08-06T10:00:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","gen_ai.agent.id":"t-1","from":"orchestrator","event_type":"delegation","task_ref":"Task one","lane_id":"cod-1","writer":"plugin"}
{"row_id":2,"timestamp":"2026-08-06T10:01:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"reviewer","gen_ai.agent.id":"t-2","from":"orchestrator","event_type":"delegation","task_ref":"Task two","lane_id":"rev-1","writer":"plugin"}
JSONL
      ;;
    empty)
      cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-06T10:00:00.000Z","event":"session_spawn","session_id":"s-x","writer":"plugin"}
JSONL
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":1,"timestamp":"2026-08-06T10:00:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","gen_ai.agent.id":"t-1","from":"orchestrator","event_type":"delegation","task_ref":"Task one","lane_id":"cod-1","writer":"plugin"}
JSONL
      ;;
    split)
      cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-06T10:00:00.000Z","event":"task_success","task_id":"legacy-1","writer":"plugin"}
{"seq":2,"timestamp":"2026-08-06T10:01:00.000Z","event":"task_success","task_id":"legacy-2","writer":"plugin"}
{"seq":3,"timestamp":"2026-08-06T13:00:00.000Z","event":"task_success","task_id":"t-1","writer":"plugin"}
{"seq":4,"timestamp":"2026-08-06T13:01:00.000Z","event":"task_success","task_id":"t-2","writer":"plugin"}
JSONL
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":1,"timestamp":"2026-08-06T13:00:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","gen_ai.agent.id":"t-1","from":"orchestrator","event_type":"delegation","task_ref":"Task one","lane_id":"cod-1","writer":"plugin"}
{"row_id":2,"timestamp":"2026-08-06T13:01:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"reviewer","gen_ai.agent.id":"t-2","from":"orchestrator","event_type":"delegation","task_ref":"Task two","lane_id":"rev-1","writer":"plugin"}
JSONL
      ;;
    alllegacy)
      cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-06T10:00:00.000Z","event":"task_success","task_id":"t-1","writer":"plugin"}
{"seq":2,"timestamp":"2026-08-06T10:01:00.000Z","event":"task_success","task_id":"t-2","writer":"plugin"}
JSONL
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":1,"timestamp":"2026-08-06T10:00:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","gen_ai.agent.id":"t-1","from":"orchestrator","event_type":"delegation","task_ref":"Task one","lane_id":"cod-1","writer":"plugin"}
{"row_id":2,"timestamp":"2026-08-06T10:01:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"reviewer","gen_ai.agent.id":"t-2","from":"orchestrator","event_type":"delegation","task_ref":"Task two","lane_id":"rev-1","writer":"plugin"}
JSONL
      ;;
    badts)
      cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-06T13:00:00.000Z","event":"task_success","task_id":"t-1","writer":"plugin"}
{"seq":2,"timestamp":"not-a-timestamp","event":"task_success","task_id":"t-2","writer":"plugin"}
JSONL
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":1,"timestamp":"2026-08-06T13:00:02.000Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","gen_ai.agent.id":"t-1","from":"orchestrator","event_type":"delegation","task_ref":"Task one","lane_id":"cod-1","writer":"plugin"}
JSONL
      ;;
  esac
}

@test "jsonl-cross-check: pass — all registry task_success matched within 5s" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/pass" pass

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/pass/registry.jsonl" \
    "$BATS_TEST_TMPDIR/pass/messages.jsonl" \
    --since 2026-08-06T00:00:00Z

  assert_status 0
  assert_output_contains "completeness:    100.0% (target >= 99.0%)"
  assert_output_contains "verdict:         PASS (exit 0)"
}

@test "jsonl-cross-check: fail — half the registry rows unmatched -> exit 1" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/half" half

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/half/registry.jsonl" \
    "$BATS_TEST_TMPDIR/half/messages.jsonl" \
    --since 2026-08-06T00:00:00Z

  assert_status 1
  assert_output_contains "completeness:    50.0% (target >= 99.0%)"
  assert_output_contains "verdict:         FAIL (exit 1)"
}

@test "jsonl-cross-check: missing registry file -> fail-loud, exit 2" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/pass" pass

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/does-not-exist.jsonl" \
    "$BATS_TEST_TMPDIR/pass/messages.jsonl"

  assert_status 2
  assert_output_contains "not found"
}

@test "jsonl-cross-check: malformed line skipped with warning, pass intact" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/malformed" malformed

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/malformed/registry.jsonl" \
    "$BATS_TEST_TMPDIR/malformed/messages.jsonl" \
    --since 2026-08-06T00:00:00Z

  assert_status 0
  assert_output_contains "warning: $BATS_TEST_TMPDIR/malformed/registry.jsonl line 2 is malformed JSON — skipped"
  assert_output_contains "malformed: registry 1, messages 0"
  assert_output_contains "verdict:         PASS (exit 0)"
}

@test "jsonl-cross-check: threshold override — 50% passes at --threshold 0.5" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/half" half

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/half/registry.jsonl" \
    "$BATS_TEST_TMPDIR/half/messages.jsonl" \
    --threshold 0.5 \
    --since 2026-08-06T00:00:00Z

  assert_status 0
  assert_output_contains "target >= 50.0%"
  assert_output_contains "verdict:         PASS (exit 0)"
}

@test "jsonl-cross-check: same task_id but timestamp outside ±5s is NOT matched" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/stale" stale

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/stale/registry.jsonl" \
    "$BATS_TEST_TMPDIR/stale/messages.jsonl" \
    --since 2026-08-06T00:00:00Z

  assert_status 1
  assert_output_contains "outside ±5s: 1"
  assert_output_contains "completeness:    0.0%"
  assert_output_contains "verdict:         FAIL (exit 1)"
}

@test "jsonl-cross-check: empty registry (no task_success) -> exit 2, not a vacuous pass" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/empty" empty

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/empty/registry.jsonl" \
    "$BATS_TEST_TMPDIR/empty/messages.jsonl" \
    --since 2026-08-06T00:00:00Z

  assert_status 2
  assert_output_contains "registry has 0 task_success rows"
}

@test "jsonl-cross-check: legacy rows before cutoff excluded from universe -> 100% pass" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/split" split

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/split/registry.jsonl" \
    "$BATS_TEST_TMPDIR/split/messages.jsonl" \
    --since 2026-08-06T12:00:00Z

  assert_status 0
  assert_output_contains "legacy:         2 rows before cutoff"
  assert_output_contains "in-universe:    2 rows at/after cutoff"
  assert_output_contains "completeness:    100.0% (target >= 99.0%)"
  assert_output_contains "verdict:         PASS (exit 0)"
}

@test "jsonl-cross-check: --since override changes the universe" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/split" split

  # Wide cutoff: both 13:00 rows in-universe -> universe 2, matched 2, 100%.
  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/split/registry.jsonl" \
    "$BATS_TEST_TMPDIR/split/messages.jsonl" \
    --since 2026-08-06T12:00:00Z
  assert_status 0
  assert_output_contains "in-universe:    2 rows at/after cutoff"

  # Narrow cutoff (13:00:30): only the 13:01 row remains -> universe 1.
  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/split/registry.jsonl" \
    "$BATS_TEST_TMPDIR/split/messages.jsonl" \
    --since 2026-08-06T13:00:30Z
  assert_status 0
  assert_output_contains "in-universe:    1 rows at/after cutoff"
  assert_output_contains "legacy:         3 rows before cutoff"
}

@test "jsonl-cross-check: all registry rows below cutoff (empty in-universe) -> exit 2" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/alllegacy" alllegacy

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/alllegacy/registry.jsonl" \
    "$BATS_TEST_TMPDIR/alllegacy/messages.jsonl" \
    --since 2026-08-06T12:00:00Z

  assert_status 2
  assert_output_contains "registry has 0 in-universe task_success rows at/after --since"
}

@test "jsonl-cross-check: unparseable registry timestamp skipped with warning, pass intact" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/badts" badts

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/badts/registry.jsonl" \
    "$BATS_TEST_TMPDIR/badts/messages.jsonl" \
    --since 2026-08-06T12:00:00Z

  assert_status 0
  assert_output_contains "warning: 1 registry task_success row(s) have unparseable/missing timestamps"
  assert_output_contains "bad timestamp:  1 rows with unparseable/missing timestamp"
  assert_output_contains "in-universe:    1 rows at/after cutoff"
  assert_output_contains "completeness:    100.0% (target >= 99.0%)"
  assert_output_contains "verdict:         PASS (exit 0)"
}

@test "jsonl-cross-check: malformed --since value -> usage error, exit 2" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/pass" pass

  run bash "$tree/.opencode/scripts/jsonl-cross-check.sh" \
    "$BATS_TEST_TMPDIR/pass/registry.jsonl" \
    "$BATS_TEST_TMPDIR/pass/messages.jsonl" \
    --since not-a-timestamp

  assert_status 2
  assert_output_contains "--since must be an ISO-8601 UTC timestamp"
}
