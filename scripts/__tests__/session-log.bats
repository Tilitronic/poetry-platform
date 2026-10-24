#!/usr/bin/env bats
# Unit tests for scripts/session-log (ana007 Option E Phase 2 — messages.md
# derived-view CLI). Hermetic pattern from check-host-jq.bats: the script is
# copied into an isolated temp tree (setup_tree) and every invocation runs
# against fixture jsonl files in BATS_TEST_TMPDIR — no real
# .opencode/session/messages.jsonl is ever touched. jq is NOT faked: the
# check-host-jq probe is a make test-shell prerequisite, so a functional jq
# is guaranteed on PATH when this suite runs.
#
# 7-case matrix: header+N-rows / row_id column / legacy-line fallback /
# atomic write / tail N / missing file / malformed-line skip+warn.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# setup_tree: copies scripts/session-log into an isolated temp tree. Echoes
# the tree root (mirrors check-host-jq.bats setup_tree).
setup_tree() {
  local tree="$BATS_TEST_TMPDIR/tree"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/session-log" "$tree/scripts/session-log"
  echo "$tree"
}

# write_fixture <dir> <name>: writes the named fixture jsonl into <dir>.
#   mixed  — row_id rows + legacy (no row_id) rows + a decision (VP) row
#   ids    — every row carries row_id that DIFFERS from its line number
#   legacy — no row has row_id (sequential fallback path)
#   malformed — valid row + malformed line + valid row
write_fixture() {
  local dir="$1"
  local name="$2"
  mkdir -p "$dir"
  case "$name" in
    mixed)
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":1,"timestamp":"2026-08-06T10:00:00Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","gen_ai.provider.name":"opencode-go","from":"orchestrator","event_type":"delegation","task_ref":"Task one","lane_id":"cod-1","resolution_status":"in-flight","writer":"plugin"}
{"timestamp":"2026-08-06T10:05:00Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"code-executor","gen_ai.provider.name":"opencode-go","from":"orchestrator","event_type":"delegation","task_ref":"Task two","lane_id":"cod-2","resolution_status":"done"}
{"row_id":3,"timestamp":"2026-08-06T10:10:00Z","gen_ai.operation.name":"invoke_workflow","gen_ai.agent.name":"owner","from":"owner","event_type":"decision","task_ref":"Owner approved","lane_id":"dec-1","resolution_status":"acknowledged","content_ref":"batch-approval-complete","cycle_id":"c-20260804-0900","prognosis_ref":"HANDOFF.md#prognosis","channel":"handoff","next_action":"dispatch next lane"}
JSONL
      ;;
    ids)
      cat > "$dir/messages.jsonl" <<'JSONL'
{"row_id":100,"timestamp":"2026-08-06T10:00:00Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","from":"orchestrator","event_type":"delegation","task_ref":"Row with row_id 100","lane_id":"cod-1","resolution_status":"in-flight"}
{"row_id":101,"timestamp":"2026-08-06T10:05:00Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"reviewer","from":"orchestrator","event_type":"delegation","task_ref":"Row with row_id 101","lane_id":"rev-1","resolution_status":"done"}
JSONL
      ;;
    legacy)
      cat > "$dir/messages.jsonl" <<'JSONL'
{"timestamp":"2026-08-06T10:00:00Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","from":"orchestrator","event_type":"delegation","task_ref":"Legacy one","lane_id":"cod-1","resolution_status":"in-flight"}
{"timestamp":"2026-08-06T10:05:00Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"reviewer","from":"orchestrator","event_type":"delegation","task_ref":"Legacy two","lane_id":"rev-1","resolution_status":"done"}
{"timestamp":"2026-08-06T10:10:00Z","gen_ai.operation.name":"invoke_workflow","gen_ai.agent.name":"owner","from":"owner","event_type":"decision","task_ref":"Legacy decision","lane_id":"dec-1","resolution_status":"acknowledged"}
JSONL
      ;;
    malformed)
      cat > "$dir/messages.jsonl" <<'JSONL'
{"timestamp":"2026-08-06T10:00:00Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"coder","from":"orchestrator","event_type":"delegation","task_ref":"Before the bad line","lane_id":"cod-1","resolution_status":"in-flight"}
this is not json
{"timestamp":"2026-08-06T10:10:00Z","gen_ai.operation.name":"invoke_agent","gen_ai.agent.name":"reviewer","from":"orchestrator","event_type":"delegation","task_ref":"After the bad line","lane_id":"rev-1","resolution_status":"done"}
JSONL
      ;;
  esac
}

@test "session-log: render produces a markdown table with header + N rows" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/mixed" mixed

  run bash "$tree/scripts/session-log" render \
    --file "$BATS_TEST_TMPDIR/mixed/messages.jsonl" \
    --output "$BATS_TEST_TMPDIR/mixed/messages.md"

  assert_status 0
  assert_file_exists "$BATS_TEST_TMPDIR/mixed/messages.md"
  assert_file_contains "$BATS_TEST_TMPDIR/mixed/messages.md" \
    "| # | timestamp | from | to | lane/ticket | result | next-action |"
  assert_file_contains "$BATS_TEST_TMPDIR/mixed/messages.md" \
    "| 1 | 2026-08-06T10:00:00Z | orchestrator | coder | cod-1 | Task one [in-flight] |"
  assert_file_contains "$BATS_TEST_TMPDIR/mixed/messages.md" \
    "| 3 | 2026-08-06T10:10:00Z | owner | owner | dec-1 | Owner approved [acknowledged] |"
}

@test "session-log: render uses row_id for the # column when present" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/ids" ids

  run bash "$tree/scripts/session-log" render \
    --file "$BATS_TEST_TMPDIR/ids/messages.jsonl" \
    --output "$BATS_TEST_TMPDIR/ids/messages.md"

  assert_status 0
  # row_id 100/101 (line numbers are 1/2 — row_id wins)
  assert_file_contains "$BATS_TEST_TMPDIR/ids/messages.md" "| 100 | 2026-08-06T10:00:00Z"
  assert_file_contains "$BATS_TEST_TMPDIR/ids/messages.md" "| 101 | 2026-08-06T10:05:00Z"
  run grep -c '^| 1 |' "$BATS_TEST_TMPDIR/ids/messages.md"
  assert_output_contains "0"
}

@test "session-log: render falls back to sequential line numbers for legacy rows" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/legacy" legacy

  run bash "$tree/scripts/session-log" render \
    --file "$BATS_TEST_TMPDIR/legacy/messages.jsonl" \
    --output "$BATS_TEST_TMPDIR/legacy/messages.md"

  assert_status 0
  assert_file_contains "$BATS_TEST_TMPDIR/legacy/messages.md" "| 1 | 2026-08-06T10:00:00Z"
  assert_file_contains "$BATS_TEST_TMPDIR/legacy/messages.md" "| 2 | 2026-08-06T10:05:00Z"
  assert_file_contains "$BATS_TEST_TMPDIR/legacy/messages.md" "| 3 | 2026-08-06T10:10:00Z"
}

@test "session-log: render atomic write — output replaced, no .tmp left behind" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/atomic" mixed
  local out="$BATS_TEST_TMPDIR/atomic/messages.md"
  echo "stale content" > "$out"

  run bash "$tree/scripts/session-log" render \
    --file "$BATS_TEST_TMPDIR/atomic/messages.jsonl" \
    --output "$out"

  assert_status 0
  assert_file_exists "$out"
  assert_file_not_exists "${out}.tmp"
  # stale content was replaced (derived header present, stale line gone)
  assert_file_contains "$out" "# Orchestrator Session Messages Log"
  run grep -c 'stale content' "$out"
  assert_output_contains "0"
}

@test "session-log: tail shows last N rows" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/mixed" mixed

  run bash "$tree/scripts/session-log" tail 2 \
    --file "$BATS_TEST_TMPDIR/mixed/messages.jsonl"

  assert_status 0
  assert_output_contains "Task two [done]"
  assert_output_contains "Owner approved [acknowledged]"
  assert_output_not_contains "Task one [in-flight]"
}

@test "session-log: missing input file -> fail-loud error, exit 1" {
  tree="$(setup_tree)"

  run bash "$tree/scripts/session-log" render \
    --file "$BATS_TEST_TMPDIR/does-not-exist.jsonl" \
    --output "$BATS_TEST_TMPDIR/out.md"

  assert_status 1
  assert_output_contains "not found"
  assert_file_not_exists "$BATS_TEST_TMPDIR/out.md"
}

@test "session-log: malformed JSON line -> graceful skip + warning" {
  tree="$(setup_tree)"
  write_fixture "$BATS_TEST_TMPDIR/malformed" malformed

  run bash "$tree/scripts/session-log" render \
    --file "$BATS_TEST_TMPDIR/malformed/messages.jsonl" \
    --output "$BATS_TEST_TMPDIR/malformed/messages.md"

  # skip + warn policy: exit 0, warning names the bad line, valid rows rendered
  assert_status 0
  assert_output_contains "warning: $BATS_TEST_TMPDIR/malformed/messages.jsonl line 2 is malformed JSON — skipped"
  assert_file_contains "$BATS_TEST_TMPDIR/malformed/messages.md" "Before the bad line"
  assert_file_contains "$BATS_TEST_TMPDIR/malformed/messages.md" "After the bad line"
  run grep -c '^| 3 |' "$BATS_TEST_TMPDIR/malformed/messages.md"
  assert_output_contains "1"
}
