#!/usr/bin/env bats
# DIA-260914-tqor RED-G: explicit operator maintenance boundary.
# All fixtures are disposable; the live .opencode/session tree is never used.

load test-helper

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CLI="$REPO_ROOT/scripts/registry-maintenance.mjs"

setup_fixture() {
  local dir="$BATS_TEST_TMPDIR/maintenance"
  mkdir -p "$dir"
  printf '%s\n' '{"seq":1,"event":"session_spawn","session_id":"ses_live","dispatch_state":"running"}' > "$dir/registry.jsonl"
  printf '%s\n' '{"row_id":1,"event":"delegation","gen_ai.agent.id":"ses_live"}' > "$dir/messages.jsonl"
  echo "$dir"
}

@test "registry-maintenance: health is read-only and returns machine-readable bounded diagnostics" {
  dir="$(setup_fixture)"
  before="$(sha256sum "$dir/registry.jsonl" | awk '{print $1}')"

  run node "$CLI" health --registry "$dir/registry.jsonl" --messages "$dir/messages.jsonl" \
    --archive-dir "$dir/archive" --json

  assert_status 0
  assert_output_contains '"active_bytes"'
  assert_output_contains '"archive_count"'
  assert_output_contains '"index_dirty"'
  [ "$(sha256sum "$dir/registry.jsonl" | awk '{print $1}')" = "$before" ]
  assert_file_not_exists "$dir/archive"
}

@test "registry-maintenance: rotate requires explicit flag and emits one JSON receipt" {
  dir="$(setup_fixture)"
  run node "$CLI" rotate --registry "$dir/registry.jsonl" --messages "$dir/messages.jsonl" \
    --archive-dir "$dir/archive" --json

  assert_status 0
  assert_output_contains '"ok":true'
  assert_output_contains '"archivePath"'
  assert_output_contains '"manifestPath"'
  assert_output_contains '"checksum"'
  assert_output_contains '"sourceBytes"'
  assert_output_contains '"archiveBytes"'
  assert_output_contains '"retainedActive"'
  assert_output_contains '"registrySeq"'
  assert_output_contains '"messageRowId"'
  assert_output_contains '"elapsedMs"'
  [ -f "$dir/registry.jsonl" ]
  [ -d "$dir/archive" ]
}

@test "registry-maintenance: no command never rotates and missing explicit workspace is usage error" {
  dir="$(setup_fixture)"
  run node "$CLI" --registry "$dir/registry.jsonl" --messages "$dir/messages.jsonl" \
    --archive-dir "$dir/archive" --json
  assert_status 2
  assert_output_contains "explicit command"
  assert_file_not_exists "$dir/archive"
}

@test "registry-maintenance: injected publication failure preserves source and fails closed" {
  dir="$(setup_fixture)"
  before="$(sha256sum "$dir/registry.jsonl" | awk '{print $1}')"
  run node "$CLI" rotate --registry "$dir/registry.jsonl" --messages "$dir/messages.jsonl" \
    --archive-dir "$dir/archive" --inject-failure rename --json

  assert_status 1
  assert_output_contains '"ok":false'
  assert_output_contains '"stage":"rename"'
  [ "$(sha256sum "$dir/registry.jsonl" | awk '{print $1}')" = "$before" ]
}
