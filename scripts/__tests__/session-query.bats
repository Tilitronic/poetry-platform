#!/usr/bin/env bats
# DIA-156: unit tests for scripts/session-query.mjs — the V2 read-only query
# layer over orchestrator session records (node:sqlite :memory:, zero deps).
#
# The script loads registry.jsonl + messages.jsonl into an in-memory sqlite
# DB and prints only the requested rows (token-economy reads). JSONL stays
# the canonical source of truth; no binary files are ever created.
#
# Isolation strategy (jsonl-cross-check.bats / validate-grilling-gate.bats
# conventions): every test writes hermetic fixture JSONL files into
# $BATS_TEST_TMPDIR and passes explicit --registry/--messages paths. The
# REAL .opencode/session/*.jsonl files are NEVER touched.
#
# node:sqlite is required (Node >= 22.5). The script is a plain Node ESM
# script with no package.json deps — the make test-shell host node must
# provide the built-in. Skip-with-message if it is absent so the suite stays
# green on older host nodes while still gating the feature where it exists.
#
# Malformed-line policy under test (documented in the script header):
# warn-and-skip — a bad line is skipped with a stderr warning, the query
# proceeds over valid rows, exit stays 0.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
QUERY="$REPO_ROOT/scripts/session-query.mjs"

# ---------------------------------------------------------------------------
# Hermetic fixtures
# ---------------------------------------------------------------------------

# write_base_fixtures <dir>: the standard 3-registry-row + 2-messages-row set
# used by most tests. Registry rows: ses_aaa (spawn RUNNING + complete
# COMPLETE), ses_bbb (spawn RUNNING), ses_ccc (spawn RUNNING). Messages rows:
# one delegation keyed to ses_aaa, one decision keyed to ses_bbb.
write_base_fixtures() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-10T10:00:00.000Z","event":"session_spawn","session_id":"ses_aaa","status":"RUNNING","writer":"plugin"}
{"seq":2,"timestamp":"2026-08-10T10:05:00.000Z","event":"session_complete","session_id":"ses_aaa","status":"COMPLETE","writer":"plugin"}
{"seq":3,"timestamp":"2026-08-10T11:00:00.000Z","event":"session_spawn","session_id":"ses_bbb","status":"RUNNING","writer":"plugin"}
{"seq":4,"timestamp":"2026-08-10T12:00:00.000Z","event":"session_spawn","session_id":"ses_ccc","status":"RUNNING","writer":"plugin"}
JSONL
  cat > "$dir/messages.jsonl" <<'JSONL'
{"timestamp":"2026-08-10T10:00:02.000Z","gen_ai.agent.id":"ses_aaa","gen_ai.agent.name":"coder","lane_id":"cod-1","event_type":"delegation","resolution_status":"done"}
{"timestamp":"2026-08-10T11:00:02.000Z","gen_ai.agent.id":"ses_bbb","gen_ai.agent.name":"reviewer","lane_id":"rev-1","event_type":"decision","resolution_status":"in-flight"}
JSONL
}

# write_malformed_fixtures <dir>: base set with a garbage line injected into
# registry.jsonl (line 3 position) so the warn-and-skip path is exercised.
write_malformed_fixtures() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/registry.jsonl" <<'JSONL'
{"seq":1,"timestamp":"2026-08-10T10:00:00.000Z","event":"session_spawn","session_id":"ses_aaa","status":"RUNNING","writer":"plugin"}
{"seq":2,"timestamp":"2026-08-10T10:05:00.000Z","event":"session_complete","session_id":"ses_aaa","status":"COMPLETE","writer":"plugin"}
this line is not valid json
{"seq":3,"timestamp":"2026-08-10T11:00:00.000Z","event":"session_spawn","session_id":"ses_bbb","status":"RUNNING","writer":"plugin"}
JSONL
  cat > "$dir/messages.jsonl" <<'JSONL'
{"timestamp":"2026-08-10T10:00:02.000Z","gen_ai.agent.id":"ses_aaa","gen_ai.agent.name":"coder","lane_id":"cod-1","event_type":"delegation","resolution_status":"done"}
JSONL
}

# require_node_sqlite: skips the whole suite when the host node lacks the
# built-in module (Node < 22.5). The ticket mandates node:sqlite and
# forbids polyfills, so absence is a skip, not a fallback.
require_node_sqlite() {
  if ! node -e "require('node:sqlite')" >/dev/null 2>&1; then
    skip "node:sqlite not available in host node ($(node --version 2>/dev/null))"
  fi
}

setup() {
  require_node_sqlite
}

# ---------------------------------------------------------------------------
# (a) recall a single session_id returns ONLY that session's rows
# ---------------------------------------------------------------------------

@test "session-query: recall single session_id returns only that session's rows" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --session ses_aaa

  assert_status 0
  # both registry rows for ses_aaa present
  assert_output_contains '"session_id":"ses_aaa","status":"RUNNING"'
  assert_output_contains '"session_id":"ses_aaa","status":"COMPLETE"'
  # the messages row keyed by gen_ai.agent.id=ses_aaa present
  assert_output_contains '"gen_ai.agent.id":"ses_aaa"'
  # other sessions NOT returned (the token-economy guarantee)
  assert_output_not_contains 'ses_bbb'
  assert_output_not_contains 'ses_ccc'
  # stdout is exactly the recalled rows — 3 lines of JSON, nothing else
  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --session ses_aaa 2>/dev/null
  [ "$(printf '%s' "$output" | grep -c '^{')" -eq 3 ]
}

@test "session-query: recall unknown session_id returns zero rows, exit 0" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  # The token-economy guarantee is that stdout carries ZERO data rows for an
  # unknown id. bats merges stderr (the import note) into $output, so count
  # JSON data lines on stdout rather than asserting empty output.
  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --session ses_nope

  assert_status 0
  [ "$(printf '%s' "$output" | grep -c '^{')" -eq 0 ]
}

# ---------------------------------------------------------------------------
# (b) count-by aggregation returns the correct aggregate
# ---------------------------------------------------------------------------

@test "session-query: count-by status on registry returns correct aggregate" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --count-by status --table registry

  assert_status 0
  assert_output_contains '{"status":"RUNNING","count":3}'
  assert_output_contains '{"status":"COMPLETE","count":1}'
  # exactly two group rows
  [ "$(printf '%s' "$output" | grep -c '^{')" -eq 2 ]
}

@test "session-query: count-by event_type on messages returns correct aggregate" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --count-by event_type --table messages

  assert_status 0
  assert_output_contains '{"event_type":"delegation","count":1}'
  assert_output_contains '{"event_type":"decision","count":1}'
}

@test "session-query: count-by + --where filter narrows the aggregate" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --count-by status --table registry --where event=session_spawn

  assert_status 0
  assert_output_contains '{"status":"RUNNING","count":3}'
  assert_output_not_contains 'COMPLETE'
}

@test "session-query: --session + --where narrows recall to matching rows" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --session ses_aaa --where status=RUNNING

  assert_status 0
  assert_output_contains '"session_id":"ses_aaa","status":"RUNNING"'
  assert_output_not_contains 'COMPLETE'
}

# ---------------------------------------------------------------------------
# (c) empty input files handled gracefully
# ---------------------------------------------------------------------------

@test "session-query: empty input files -> zero rows, exit 0, no crash" {
  local dir="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$dir"
  : > "$dir/registry.jsonl"
  : > "$dir/messages.jsonl"

  # bats merges stderr into $output; zero JSON data rows on stdout is the
  # graceful-empty contract (exit 0, no crash, no data lines).
  run node "$QUERY" \
    --registry "$dir/registry.jsonl" \
    --messages "$dir/messages.jsonl" \
    --count-by status --table registry

  assert_status 0
  [ "$(printf '%s' "$output" | grep -c '^{')" -eq 0 ]
}

@test "session-query: empty registry with non-empty messages -> recall returns only messages rows" {
  local dir="$BATS_TEST_TMPDIR/empty-reg"
  mkdir -p "$dir"
  : > "$dir/registry.jsonl"
  cat > "$dir/messages.jsonl" <<'JSONL'
{"timestamp":"2026-08-10T10:00:02.000Z","gen_ai.agent.id":"ses_aaa","gen_ai.agent.name":"coder","lane_id":"cod-1","event_type":"delegation","resolution_status":"done"}
JSONL

  run node "$QUERY" \
    --registry "$dir/registry.jsonl" \
    --messages "$dir/messages.jsonl" \
    --session ses_aaa 2>/dev/null

  assert_status 0
  assert_output_contains '"gen_ai.agent.id":"ses_aaa"'
  [ "$(printf '%s' "$output" | grep -c '^{')" -eq 1 ]
}

# ---------------------------------------------------------------------------
# (d) malformed JSONL line handled gracefully (warn-and-skip, documented)
# ---------------------------------------------------------------------------

@test "session-query: malformed JSONL line skipped with warning, valid rows still returned" {
  write_malformed_fixtures "$BATS_TEST_TMPDIR/malformed"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/malformed/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/malformed/messages.jsonl" \
    --count-by status --table registry

  assert_status 0
  assert_output_contains 'malformed JSON - skipped'
  # 3 valid rows remain (2 RUNNING + 1 COMPLETE); the garbage line is
  # excluded from the aggregate entirely
  assert_output_contains '{"status":"RUNNING","count":2}'
  assert_output_contains '{"status":"COMPLETE","count":1}'
  [ "$(printf '%s' "$output" | grep -c '^{')" -eq 2 ]
}

@test "session-query: malformed line does not poison a session recall" {
  write_malformed_fixtures "$BATS_TEST_TMPDIR/malformed"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/malformed/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/malformed/messages.jsonl" \
    --session ses_aaa

  assert_status 0
  assert_output_contains '"session_id":"ses_aaa","status":"COMPLETE"'
  assert_output_not_contains 'not valid json'
}

# ---------------------------------------------------------------------------
# Infra + usage errors (documented exit-code contract: 2 = usage/infra)
# ---------------------------------------------------------------------------

@test "session-query: missing input file -> exit 2, clear error" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/does-not-exist.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --session ses_aaa

  assert_status 2
  assert_output_contains "input file not found: $BATS_TEST_TMPDIR/does-not-exist.jsonl"
}

@test "session-query: --count-by without --table -> usage error, exit 2" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --count-by status

  assert_status 2
  assert_output_contains "--count-by requires --table registry|messages"
}

@test "session-query: --session and --count-by together -> usage error, exit 2" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --session ses_aaa --count-by status --table registry

  assert_status 2
  assert_output_contains "mutually exclusive"
}

@test "session-query: no query mode (bare --where) -> usage error, exit 2" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" \
    --registry "$BATS_TEST_TMPDIR/base/registry.jsonl" \
    --messages "$BATS_TEST_TMPDIR/base/messages.jsonl" \
    --where status=RUNNING

  assert_status 2
  assert_output_contains "one query mode required: --session <id> or --count-by <field>"
}

@test "session-query: unknown flag -> usage error, exit 2" {
  write_base_fixtures "$BATS_TEST_TMPDIR/base"

  run node "$QUERY" --frobnicate

  assert_status 2
  assert_output_contains "unknown option: --frobnicate"
}

@test "session-query: --help exits 0 and documents the CLI surface" {
  run node "$QUERY" --help

  assert_status 0
  assert_output_contains "--session <id>"
  assert_output_contains "--count-by <field>"
  assert_output_contains "--where <k=v>"
}

@test "session-query: node --check passes (script is valid ESM)" {
  run node --check "$QUERY"
  assert_status 0
}

@test "session-query: Makefile wiring - test-shell auto-discovers the bats suite" {
  # Seam guard (same shape as validate-grilling-gate.bats): the bats suite is
  # auto-discovered by bats-wrapper.sh (exec "$BATS" "$TESTS_DIR"), so the
  # wiring seam is the script's presence under scripts/ — assert the script
  # and suite exist and that Makefile references the script for ad-hoc use.
  assert_file_exists "$REPO_ROOT/scripts/session-query.mjs"
  assert_file_exists "$REPO_ROOT/scripts/__tests__/session-query.bats"
  assert_file_contains "$REPO_ROOT/Makefile" "scripts/session-query.mjs"
}
