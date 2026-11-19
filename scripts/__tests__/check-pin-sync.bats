#!/usr/bin/env bats
# Unit tests for scripts/check-pin-sync.sh (seam: validator script).
#
# 18-case FAKE-mock matrix (T1-T18) covering every branch of the validator
# against Dockerfile.dev (4 comparisons: 4 pins x 1 Dockerfile):
#   T1  all pins match                          -> exit 0 + four ok lines
#   T2  single pin mismatch (node, Dockerfile.dev) -> exit 1 + fail line
#   T3  multiple pin mismatches (report-ALL)     -> exit 1 + all fail lines
#   T4  .mise.toml missing                      -> exit 2 (INFRA)
#   T5  Dockerfile.dev missing                  -> exit 2 (INFRA)
#   T6  duplicate [tools] key in .mise.toml     -> exit 2 (INFRA ruling)
#   T7  duplicate ARG in Dockerfile.dev         -> exit 2 (INFRA ruling)
#   T8  quote variations                        -> exit 0 after stripping
#   T9  CRLF line endings                       -> exit 0 after stripping
#   T10 whitespace variations                   -> exit 0 after stripping
#   T11 single opencode mismatch (Dockerfile.dev) -> exit 1 + fail line
#   T12 single bun mismatch (Dockerfile.dev)       -> exit 1 + fail line
#   T13 duplicate opencode key in .mise.toml    -> exit 2 (INFRA)
#   T14 duplicate OPENCODE_VERSION ARG           -> exit 2 (INFRA)
#   T15 missing opencode key in .mise.toml       -> exit 2 (INFRA)
#   T16 missing OPENCODE_VERSION ARG             -> exit 2 (INFRA)
#   T17 missing BUN_VERSION ARG                  -> exit 2 (INFRA)
#   T18 report-ALL: all four pins drift          -> exit 1 + four fail lines
#
# Legacy T11-T13 (tools/opencode-docker/Dockerfile tests) removed:
# DIA-260824-8k62 PHASE 3 retired the legacy runtime; check-pin-sync.sh
# now compares only Dockerfile.dev.
#
# FAKE-mock invariant: behavioral tests NEVER read the real repo .mise.toml /
# Dockerfile.dev -- every fixture is planted under $BATS_TEST_TMPDIR via
# setup_pin_sync_tree (test-helper.bash). The ONE exception is the S4-style
# structural assertion below, which reads the real .mise.toml (mirrors
# check-tools.bats S4).

load test-helper

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# Local stderr assertion: `run --separate-stderr` captures fail lines (stderr)
# separately from ok lines (stdout); test-helper has no stderr helper.
assert_stderr_contains() {
  [[ "$stderr" == *"$1"* ]] || {
    echo "assert_stderr_contains: missing substring: $1" >&2
    echo "--- stderr ---" >&2
    echo "$stderr" >&2
    return 1
  }
}

# ---- T1: all 4 pins match ------------------------------------------------
@test "check-pin-sync: T1 all 4 pins match -> exit 0 + four ok lines + summary: 4 ok, 0 fail" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: opencode 1.18.32 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  assert_output_contains "summary: 4 ok, 0 fail"
}

# ---- T2: single node mismatch ---------------------------------------------
@test "check-pin-sync: T2 single pin mismatch (node, Dockerfile.dev) -> exit 1 + fail line + summary: 3 ok, 1 fail" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.19.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: node — .mise.toml=24.18.0 Dockerfile.dev=24.19.0"
  assert_output_contains "summary: 3 ok, 1 fail"
}

# ---- T3: multiple pin mismatches (report-ALL) -----------------------------
@test "check-pin-sync: T3 multiple pin mismatches (report-ALL) -> exit 1 + all fail lines" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.19.0" "10.34.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: node — .mise.toml=24.18.0 Dockerfile.dev=24.19.0"
  assert_stderr_contains "fail: pnpm — .mise.toml=10.33.0 Dockerfile.dev=10.34.0"
  assert_output_contains "summary: 2 ok, 2 fail"
}

# ---- T4: .mise.toml missing (INFRA) --------------------------------------
@test "check-pin-sync: T4 .mise.toml missing -> exit 2 (INFRA) + source-defective fail line" {
  tree="$(setup_pin_sync_tree 0 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: .mise.toml not found at $tree/.mise.toml"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

# ---- T5: Dockerfile.dev missing (INFRA) -----------------------------------
@test "check-pin-sync: T5 Dockerfile.dev missing -> exit 2 (INFRA) + source-defective fail line" {
  tree="$(setup_pin_sync_tree 1 0 "24.18.0" "10.33.0" "24.18.0" "10.33.0")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: Dockerfile.dev not found at $tree/Dockerfile.dev"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

# ---- T6: duplicate node key in .mise.toml (INFRA) -------------------------
@test "check-pin-sync: T6 duplicate [tools] key in .mise.toml -> exit 2 (INFRA) + duplicate-key fail line" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "dup-mise")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: .mise.toml has duplicate key 'node' under [tools]"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

# ---- T7: duplicate NODE_VERSION ARG (INFRA) -------------------------------
@test "check-pin-sync: T7 duplicate ARG in Dockerfile.dev -> exit 2 (INFRA) + duplicate-ARG fail line" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "dup-docker")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: Dockerfile.dev has duplicate ARG 'NODE_VERSION'"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

# ---- T8: quote variations -------------------------------------------------
@test "check-pin-sync: T8 quote variations (single/double/unquoted) -> exit 0 after stripping" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "quotes" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: opencode 1.18.32 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  assert_output_contains "summary: 4 ok, 0 fail"
}

# ---- T9: CRLF line endings ------------------------------------------------
@test "check-pin-sync: T9 CRLF line endings -> exit 0 after stripping" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "crlf" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: opencode 1.18.32 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  assert_output_contains "summary: 4 ok, 0 fail"
}

# ---- T10: whitespace variations -------------------------------------------
@test "check-pin-sync: T10 whitespace variations (extra spaces around =) -> exit 0 after stripping" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "whitespace" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: opencode 1.18.32 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  assert_output_contains "summary: 4 ok, 0 fail"
}

# ---- T11: single opencode mismatch ----------------------------------------
@test "check-pin-sync: T11 single opencode mismatch (Dockerfile.dev) -> exit 1 + fail line + summary: 3 ok, 1 fail" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.99" "1.4.2")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: opencode — .mise.toml=1.18.32 Dockerfile.dev=1.18.99"
  assert_output_contains "summary: 3 ok, 1 fail"
}

# ---- T12: single bun mismatch ---------------------------------------------
@test "check-pin-sync: T12 single bun mismatch (Dockerfile.dev) -> exit 1 + fail line + summary: 3 ok, 1 fail" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.99.0")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: bun — .mise.toml=1.4.2 Dockerfile.dev=1.99.0"
  assert_output_contains "summary: 3 ok, 1 fail"
}

# ---- T13: duplicate opencode key in .mise.toml (INFRA) --------------------
@test "check-pin-sync: T13 duplicate opencode key in .mise.toml -> exit 2 (INFRA)" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "dup-opencode-mise")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: .mise.toml has duplicate key 'opencode' under [tools]"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

# ---- T14: duplicate OPENCODE_VERSION ARG (INFRA) --------------------------
@test "check-pin-sync: T14 duplicate OPENCODE_VERSION ARG in Dockerfile.dev -> exit 2 (INFRA)" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "dup-opencode-docker")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: Dockerfile.dev has duplicate ARG 'OPENCODE_VERSION'"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

# ---- T15: missing opencode key in .mise.toml (INFRA) ----------------------
@test "check-pin-sync: T15 missing opencode key in .mise.toml -> exit 2 (INFRA)" {
  # Plant .mise.toml with ONLY node/pnpm (no opencode) + Dockerfile with all 4 ARGs
  local tree="$BATS_TEST_TMPDIR/pin-sync"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/check-pin-sync.sh" "$tree/scripts/check-pin-sync.sh"
  cat > "$tree/.mise.toml" <<'EOF'
[tools]
node = "24.18.0"
pnpm = "10.33.0"
EOF
  cat > "$tree/Dockerfile.dev" <<'EOF'
ARG NODE_VERSION=24.18.0
ARG PNPM_VERSION=10.33.0
ARG OPENCODE_VERSION=1.18.32
ARG BUN_VERSION=1.4.2
EOF

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: .mise.toml is missing key 'opencode' under [tools]"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

# ---- T16: missing OPENCODE_VERSION ARG (INFRA) ----------------------------
@test "check-pin-sync: T16 missing OPENCODE_VERSION ARG in Dockerfile.dev -> exit 2 (INFRA)" {
  # Plant .mise.toml with all 4 keys + Dockerfile with only node/pnpm/bun ARGs
  local tree="$BATS_TEST_TMPDIR/pin-sync"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/check-pin-sync.sh" "$tree/scripts/check-pin-sync.sh"
  cat > "$tree/.mise.toml" <<'EOF'
[tools]
node = "24.18.0"
pnpm = "10.33.0"
opencode = "1.18.32"
bun = "1.4.2"
EOF
  cat > "$tree/Dockerfile.dev" <<'EOF'
ARG NODE_VERSION=24.18.0
ARG PNPM_VERSION=10.33.0
ARG BUN_VERSION=1.4.2
EOF

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: Dockerfile.dev is missing ARG 'OPENCODE_VERSION'"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

# ---- T17: missing BUN_VERSION ARG (INFRA) ---------------------------------
@test "check-pin-sync: T17 missing BUN_VERSION ARG in Dockerfile.dev -> exit 2 (INFRA)" {
  # Plant .mise.toml with all 4 keys + Dockerfile with only node/pnpm/opencode ARGs
  local tree="$BATS_TEST_TMPDIR/pin-sync"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/check-pin-sync.sh" "$tree/scripts/check-pin-sync.sh"
  cat > "$tree/.mise.toml" <<'EOF'
[tools]
node = "24.18.0"
pnpm = "10.33.0"
opencode = "1.18.32"
bun = "1.4.2"
EOF
  cat > "$tree/Dockerfile.dev" <<'EOF'
ARG NODE_VERSION=24.18.0
ARG PNPM_VERSION=10.33.0
ARG OPENCODE_VERSION=1.18.32
EOF

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 2
  assert_stderr_contains "fail: source defective: Dockerfile.dev is missing ARG 'BUN_VERSION'"
  assert_output_contains "summary: 0 ok, 0 fail (infra)"
}

# ---- T18: all 4 pins drift (report-ALL) -----------------------------------
@test "check-pin-sync: T18 all 4 pins drift (report-ALL) -> exit 1 + four fail lines + summary: 0 ok, 4 fail" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.19.0" "10.34.0" "" "1.18.32" "1.4.2" "1.18.99" "1.99.0")"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: node — .mise.toml=24.18.0 Dockerfile.dev=24.19.0"
  assert_stderr_contains "fail: pnpm — .mise.toml=10.33.0 Dockerfile.dev=10.34.0"
  assert_stderr_contains "fail: opencode — .mise.toml=1.18.32 Dockerfile.dev=1.18.99"
  assert_stderr_contains "fail: bun — .mise.toml=1.4.2 Dockerfile.dev=1.99.0"
  assert_output_contains "summary: 0 ok, 4 fail"
}

# ---- S4: real .mise.toml structural integrity ------------------------------
@test "check-pin-sync: real .mise.toml structural integrity (S4)" {
  # S4-style structural assertion -- the ONE case that reads the real repo file
  # (documented exception to the FAKE-mock invariant; mirrors check-tools.bats).
  assert_file_contains "$REPO_ROOT/.mise.toml" "[tools]"
  assert_file_contains "$REPO_ROOT/.mise.toml" 'node = "24.18.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" 'pnpm = "10.33.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" "derived from Dockerfile.dev ARGs"
  # PHASE 2: the opencode and bun reference pins MUST be present for 4-pin parity
  assert_file_contains "$REPO_ROOT/.mise.toml" 'opencode = "1.18.32"'
  assert_file_contains "$REPO_ROOT/.mise.toml" 'bun = "1.4.2"'
}

# ---- Task 1.3 (S1.1): per-service declared-vs-runtime OpenCode assertion ----
# Campaign DIA-261119-vioa, RED phase. Design D2: three static toolchain pairs
# (.mise.toml vs Dockerfile.dev) stay, and the OpenCode family's partner
# becomes the LIVE runtime (`opencode --version`) instead of a static string.
# The fixture tree models ONE service: all static pairs match (T1 shape) while
# a planted `opencode` on PATH reports a different version.

# plant_opencode_runtime <dir> <version>: fake `opencode` binary printing
# <version>, prepended to PATH -- the "live runtime" seam (design D2).
plant_opencode_runtime() {
  local dir="$1" version="$2"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\n' "$version" > "$dir/opencode"
  chmod +x "$dir/opencode"
  PATH="$dir:$PATH"
  export PATH
}

@test "check-pin-sync: declared vs runtime OpenCode mismatch fails the gate (task 1.3)" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"
  plant_opencode_runtime "$BATS_TEST_TMPDIR/runtime-bin" "1.99.0"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  [ "$status" -ne 0 ] || {
    echo "RED task 1.3: gate never compared declared vs runtime (declared 1.18.32, runtime 1.99.0) and exited 0" >&2
    return 1
  }
  # The failure report must name the runtime version it observed (a static
  # .mise.toml-vs-Dockerfile fail line would not carry it).
  assert_stderr_contains "1.99.0"
}

@test "check-pin-sync: matching declared-vs-runtime passes with three static pairs kept and a fourth runtime comparison (task 1.3)" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"
  plant_opencode_runtime "$BATS_TEST_TMPDIR/runtime-bin" "1.18.32"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  # The three static toolchain pairs must survive (not a tautology).
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  # Not shrunk to three pins: four comparisons must still be reported.
  local ok_lines
  ok_lines="$(printf '%s\n' "$output" | grep -c '^ok:' || true)"
  [ "$ok_lines" -ge 4 ] || {
    echo "gate shrank below four comparisons: $ok_lines ok line(s) in:" >&2
    echo "$output" >&2
    return 1
  }
  # RED today: the fourth family's report only carries the static
  # .mise.toml-vs-Dockerfile wording; design D2 makes its partner the live
  # runtime, so the report must say so.
  assert_output_contains "runtime"
}
