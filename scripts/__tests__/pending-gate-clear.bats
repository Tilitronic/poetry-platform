#!/usr/bin/env bats
# Tests for scripts/pending-gate-clear (DIA-260825-fjnc, gate Candidate A).
# Fully hermetic: SESSION_DIR / SHELF_FILE / KNOWLEDGE_DIR point at temp
# fixtures - the real .opencode/session flags, memory-shelf.yaml, and
# knowledge/ tree are never touched.

load test-helper

PGC="$REPO_ROOT/scripts/pending-gate-clear"

setup() {
  SD="$BATS_TEST_TMPDIR/session"
  KD="$BATS_TEST_TMPDIR/knowledge"
  SHELF="$BATS_TEST_TMPDIR/memory-shelf.yaml"
  mkdir -p "$SD" "$KD"
  # Minimal valid shelf: one conspects entry for res-test.
  printf '%s\n' 'shelf:' \
    '  conspects:' \
    '    - name: test conspect' \
    '      path: knowledge/res-test/res-test-conspect.md' > "$SHELF"
}

# make_res <res>: builds a fully verified res dir (sources/ + conspect .md).
make_res() {
  mkdir -p "$KD/$1/sources"
  printf 'x' > "$KD/$1/sources/source-a.md"
  printf 'x' > "$KD/$1/$1-conspect.md"
}

write_flag() {
  printf '%s' "$2" > "$SD/$1.json"
}

run_clear() {
  run env SESSION_DIR="$SD" SHELF_FILE="$SHELF" KNOWLEDGE_DIR="$KD" bash "$PGC" "$1"
}

@test "pending-gate-clear: missing flag -> info + exit 2" {
  run_clear conspect-pending
  assert_status 2
  assert_output_contains "info: no such flag"
}

@test "pending-gate-clear: unknown name -> usage error, exit 2" {
  run_clear bogus-flag
  assert_status 2
  assert_output_contains "unknown flag name"
}

@test "pending-gate-clear: no args -> usage error, exit 2" {
  run bash "$PGC"
  assert_status 2
  assert_output_contains "usage:"
}

@test "pending-gate-clear: legacy persistence-pending deletes WITHOUT verification" {
  # No res key, no artifacts anywhere - still cleared (legacy orphan rule).
  write_flag persistence-pending '{"session_id":"ses_old","agent":"researcher"}'
  run_clear persistence-pending
  assert_status 0
  assert_output_contains "legacy (renamed to conspect-pending per DIA-260819-qibv)"
  assert_output_contains "ok: cleared persistence-pending"
  assert_file_not_exists "$SD/persistence-pending.json"
}

@test "pending-gate-clear: analysis-pending status=verified -> cleared without artifact checks" {
  write_flag analysis-pending '{"session_id":"ses_c","status":"verified"}'
  run_clear analysis-pending
  assert_status 0
  assert_output_contains "ok: cleared analysis-pending"
  assert_file_not_exists "$SD/analysis-pending.json"
}

@test "pending-gate-clear: analysis-pending status=skipped -> cleared" {
  write_flag analysis-pending '{"session_id":"ses_c","status":"skipped"}'
  run_clear analysis-pending
  assert_status 0
  assert_output_contains "ok: cleared analysis-pending"
}

@test "pending-gate-clear: unverified analysis-pending falls through to artifact checks" {
  write_flag analysis-pending '{"session_id":"ses_c","status":"pending_verification"}'
  run_clear analysis-pending
  assert_status 1
  assert_output_contains "refused: missing"
  assert_file_exists "$SD/analysis-pending.json"
}

@test "pending-gate-clear: conspect-pending with all artifacts -> cleared" {
  make_res res-test
  write_flag conspect-pending '{"session_id":"ses_r","res":"res-test"}'
  run_clear conspect-pending
  assert_status 0
  assert_output_contains "ok: cleared conspect-pending"
  assert_file_not_exists "$SD/conspect-pending.json"
}

@test "pending-gate-clear: missing sources/ -> refused exit 1, flag kept" {
  mkdir -p "$KD/res-test"
  printf 'x' > "$KD/res-test/res-test-conspect.md"
  write_flag conspect-pending '{"res":"res-test"}'
  run_clear conspect-pending
  assert_status 1
  assert_output_contains "refused: missing sources/"
  assert_file_exists "$SD/conspect-pending.json"
}

@test "pending-gate-clear: missing shelf entry -> refused exit 1" {
  mkdir -p "$KD/res-test/sources"
  printf 'x' > "$KD/res-test/sources/a.md"
  printf 'x' > "$KD/res-test/res-test-conspect.md"
  printf '%s\n' 'shelf:' '  conspects: []' > "$SHELF"
  write_flag conspect-pending '{"res":"res-test"}'
  run_clear conspect-pending
  assert_status 1
  assert_output_contains "refused: missing"
  assert_output_contains "memory-shelf"
}

@test "pending-gate-clear: stray .md but NO conspect file -> refused exit 1" {
  # Fix cycle 2: any .md no longer passes - the gate wants a conspect file.
  mkdir -p "$KD/res-test/sources"
  printf 'x' > "$KD/res-test/sources/a.md"
  printf 'x' > "$KD/res-test/stray-notes.md"
  write_flag conspect-pending '{"res":"res-test"}'
  run_clear conspect-pending
  assert_status 1
  assert_output_contains "refused: missing"
  assert_output_contains "named conspect file"
  assert_file_exists "$SD/conspect-pending.json"
}

@test "pending-gate-clear: *conspect*.md fallback satisfies the named check" {
  mkdir -p "$KD/res-test/sources"
  printf 'x' > "$KD/res-test/sources/a.md"
  printf 'x' > "$KD/res-test/res-test-my-conspect.md"
  write_flag conspect-pending '{"res":"res-test"}'
  run_clear conspect-pending
  assert_status 0
  assert_output_contains "ok: cleared conspect-pending"
}

@test "pending-gate-clear: unsafe res name (path traversal) -> refused exit 1, flag kept" {
  write_flag conspect-pending '{"res":"../escape"}'
  run_clear conspect-pending
  assert_status 1
  assert_output_contains "refused: missing safe res directory name"
  assert_file_exists "$SD/conspect-pending.json"
}

@test "pending-gate-clear: no res in flag -> refused listing what is missing, never guesses" {
  # Mirrors the real live flag shape (session_id only, no res key).
  write_flag conspect-pending '{"session_id":"ses_fd4a1d725ffeiCH7qf0u8hb7pz","agent":"researcher"}'
  run_clear conspect-pending
  assert_status 1
  assert_output_contains "refused: missing res directory"
  assert_file_exists "$SD/conspect-pending.json"
}
