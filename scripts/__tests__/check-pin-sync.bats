#!/usr/bin/env bats
# Unit tests for scripts/check-pin-sync.sh (seam: validator script).
#
# 20-case FAKE-mock matrix (T1-T18, T11a-c) covering every branch of the
# validator against Dockerfile.dev (4 comparisons: 4 pins x 1 Dockerfile):
#   T1  static pairs match, runtime unavailable  -> exit 0 + 3 ok + skip (S2)
#   T2  single pin mismatch (node, Dockerfile.dev) -> exit 1 + fail line
#   T3  multiple pin mismatches (report-ALL)     -> exit 1 + all fail lines
#   T4  .mise.toml missing                      -> exit 2 (INFRA)
#   T5  Dockerfile.dev missing                  -> exit 2 (INFRA)
#   T6  duplicate [tools] key in .mise.toml     -> exit 2 (INFRA ruling)
#   T7  duplicate ARG in Dockerfile.dev         -> exit 2 (INFRA ruling)
#   T8  quote variations                        -> exit 0 after stripping
#   T9  CRLF line endings                       -> exit 0 after stripping
#   T10 whitespace variations                   -> exit 0 after stripping
#   T11a V1 context, differing opencode decls   -> exit 0, line names V1 pin
#   T11b V2 context                             -> exit 0, image ARG used
#   T11c V1 declared-vs-runtime mismatch        -> exit 1 + fail line
#   T12 single bun mismatch (Dockerfile.dev)       -> exit 1 + fail line
#   T13 duplicate opencode key in .mise.toml    -> exit 2 (INFRA)
#   T14 duplicate OPENCODE_VERSION ARG           -> exit 2 (INFRA)
#   T15 missing opencode key in .mise.toml       -> exit 0/1 (P3: never INFRA)
#   T16 missing OPENCODE_VERSION ARG             -> exit 2 (INFRA)
#   T17 missing BUN_VERSION ARG                  -> exit 2 (INFRA)
#   T18 report-ALL: static pins drift (differing opencode pair is NOT a
#       fail)                                   -> exit 1 + three fail lines
#
# Legacy T11-T13 (tools/opencode-docker/Dockerfile tests) removed:
# DIA-260824-8k62 PHASE 3 retired the legacy runtime; check-pin-sync.sh
# now compares only Dockerfile.dev.
# The old T11 (global .mise.toml-vs-Dockerfile.dev opencode equality) was
# replaced by T11a-c per campaign ticket DIA-261119-vioa task 1.3: the two
# declarations are per-service and are never compared to each other.
#
# FAKE-mock invariant: behavioral tests NEVER read the real repo .mise.toml /
# Dockerfile.dev -- every fixture is planted under $BATS_TEST_TMPDIR via
# setup_pin_sync_tree (test-helper.bash). The ONE exception is the S4-style
# structural assertion below, which reads the real .mise.toml (mirrors
# check-tools.bats S4).

load test-helper

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# Every test resolves as V1 unless it plants its own hostname (T11b): the
# service context must not depend on which container runs the suite.
setup() {
  plant_hostname "$BATS_TEST_TMPDIR/hostbin-v1" "poetry-dev"
}

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

# plant_hostname <dir> <name>: fake `hostname` binary prepended to PATH, so
# the script's V1/V2 service-context resolution is deterministic regardless
# of which container runs the suite (same mock pattern as check-stack-ready).
plant_hostname() {
  local dir="$1" name="$2"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\necho "%s"\n' "$name" > "$dir/hostname"
  chmod +x "$dir/hostname"
  PATH="$dir:$PATH"
  export PATH
}

# ---- T1: static pairs match; unavailable runtime is a skip, not an ok ------
# S2: with no usable `opencode --version`, the fourth verdict must be a skip:
# line and must NOT be counted, so the summary reads 3 ok (not 4). The stub
# answers nothing, which is the same empty-runtime branch as a missing binary.
@test "check-pin-sync: T1 three static pairs match -> exit 0 + skip line (runtime unavailable) + summary: 3 ok, 0 fail" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"
  plant_opencode_runtime "$BATS_TEST_TMPDIR/runtime-bin" ""

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  # S2: skip line, never a counted ok: line. Names the V1 service context
  # and the declaration it resolved (DIA-261119-vioa task 1.3).
  assert_output_contains "skip: opencode V1 declared from .mise.toml toolchain pin=1.18.32 (declared-vs-runtime assertion skipped: opencode --version unavailable)"
  assert_output_contains "summary: 3 ok, 0 fail"
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
  assert_output_contains "ok: opencode V1 declared from .mise.toml toolchain pin=1.18.32 runtime=1.18.32 matches declared"
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
  assert_output_contains "ok: opencode V1 declared from .mise.toml toolchain pin=1.18.32 runtime=1.18.32 matches declared"
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
  assert_output_contains "ok: opencode V1 declared from .mise.toml toolchain pin=1.18.32 runtime=1.18.32 matches declared"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  assert_output_contains "summary: 4 ok, 0 fail"
}

# ---- T11a: V1 context, differing declarations -> exit 0, V1 pin used ------
# Campaign DIA-261119-vioa task 1.3: toolchain pin 1.18.32 (V1) and image
# ARG 2.3.2 (V2) intentionally differ. In V1 context the verdict resolves
# the V1 toolchain pin and holds it against the live runtime; the pair is
# never compared to each other.
@test "check-pin-sync: T11a V1 context with differing declarations -> exit 0 + line names the V1 toolchain pin" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "2.3.2" "1.4.2")"
  # setup() already planted hostname poetry-dev (V1 context).
  plant_opencode_runtime "$BATS_TEST_TMPDIR/runtime-bin" "1.18.32"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: opencode V1 declared from .mise.toml toolchain pin=1.18.32 runtime=1.18.32 matches declared"
  assert_output_contains "summary: 4 ok, 0 fail"
  # A cross-declaration report would leak the image ARG value (2.3.2) into
  # the output; a differing pair must stay silent.
  [[ "$output$stderr" != *"2.3.2"* ]] || {
    echo "cross-declaration comparison leaked the image ARG (2.3.2) into the report:" >&2
    echo "$output" >&2
    echo "$stderr" >&2
    return 1
  }
}

# ---- T11b: V2 context -> the image ARG is the declared value --------------
@test "check-pin-sync: T11b V2 context resolves the image ARG (not the toolchain pin) -> exit 0 + line names 2.3.2" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "2.3.2" "1.4.2")"
  plant_hostname "$BATS_TEST_TMPDIR/hostbin-v2" "poetry-dev-v2"
  # Runtime answers the image ARG: had the V1 toolchain pin been resolved
  # (1.18.32 != 2.3.2) the gate would exit 1 instead.
  plant_opencode_runtime "$BATS_TEST_TMPDIR/runtime-bin" "2.3.2"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: opencode V2 declared from Dockerfile.dev ARG=2.3.2 runtime=2.3.2 matches declared"
  assert_output_contains "summary: 4 ok, 0 fail"
  # The V1 pin must not appear in the V2 verdict.
  [[ "$output$stderr" != *"1.18.32"* ]] || {
    echo "V2 verdict reported the V1 toolchain pin (1.18.32):" >&2
    echo "$output" >&2
    echo "$stderr" >&2
    return 1
  }
}

# ---- T11c: genuine within-service mismatch -> exit 1 ----------------------
@test "check-pin-sync: T11c V1 declared-vs-runtime mismatch exits 1 even with a differing pair" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "2.3.2" "1.4.2")"
  plant_opencode_runtime "$BATS_TEST_TMPDIR/runtime-bin" "1.99.0"

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: opencode V1 runtime mismatch: declared from .mise.toml toolchain pin=1.18.32 runtime=1.99.0"
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

# ---- T15: missing opencode key in .mise.toml is NOT INFRA (P3) -----------
@test "check-pin-sync: T15 missing opencode key in .mise.toml -> real verdict (exit 0 or 1), never exit 2 (P3)" {
  # P3: slice 1.2 retires the .mise.toml opencode declaration, so its absence
  # must not fail the source check. The declared value lives in the
  # Dockerfile.dev build ARG; node/pnpm/bun stay required static pairs.
  local tree="$BATS_TEST_TMPDIR/pin-sync"
  mkdir -p "$tree/scripts"
  cp "$REPO_ROOT/scripts/check-pin-sync.sh" "$tree/scripts/check-pin-sync.sh"
  cat > "$tree/.mise.toml" <<'EOF'
[tools]
node = "24.18.0"
pnpm = "10.33.0"
bun = "1.4.2"
EOF
  cat > "$tree/Dockerfile.dev" <<'EOF'
ARG NODE_VERSION=24.18.0
ARG PNPM_VERSION=10.33.0
ARG OPENCODE_VERSION=1.18.32
ARG BUN_VERSION=1.4.2
EOF

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  # A real verdict: exit 0 or 1 only -- never 2, never a missing-declared-value
  # report, never an (infra) summary.
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || {
    echo "P3: expected exit 0 or 1 once the .mise.toml opencode key is gone, got exit $status" >&2
    echo "$stderr" >&2
    return 1
  }
  [[ "$stderr" != *"missing key 'opencode'"* ]] || {
    echo "P3: script reported a missing declared opencode value:" >&2
    echo "$stderr" >&2
    return 1
  }
  [[ "$output" != *"(infra)"* ]] || {
    echo "P3: script rendered an INFRA summary without the .mise.toml opencode key:" >&2
    echo "$output" >&2
    return 1
  }
  # The three static pairs still render a verdict.
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
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

# ---- T18: static pins drift (report-ALL); opencode pair differs silently ---
@test "check-pin-sync: T18 static pins drift (report-ALL) + differing opencode pair is not a fail -> exit 1 + three fail lines + summary: 0 ok, 3 fail" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.19.0" "10.34.0" "" "1.18.32" "1.4.2" "1.18.99" "1.99.0")"
  plant_opencode_runtime "$BATS_TEST_TMPDIR/runtime-bin" ""

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: node — .mise.toml=24.18.0 Dockerfile.dev=24.19.0"
  assert_stderr_contains "fail: pnpm — .mise.toml=10.33.0 Dockerfile.dev=10.34.0"
  assert_stderr_contains "fail: bun — .mise.toml=1.4.2 Dockerfile.dev=1.99.0"
  # The differing opencode pair (1.18.32 vs 1.18.99) is NOT a fail: V1
  # resolves the toolchain pin; with the runtime stub answering nothing the
  # fourth verdict is a skip (S2), never a counted ok.
  assert_output_contains "skip: opencode V1 declared from .mise.toml toolchain pin=1.18.32 (declared-vs-runtime assertion skipped: opencode --version unavailable)"
  [[ "$stderr" != *"opencode —"* ]] || {
    echo "T18: cross-declaration opencode fail line still emitted:" >&2
    echo "$stderr" >&2
    return 1
  }
  assert_output_contains "summary: 0 ok, 3 fail"
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
# Campaign DIA-261119-vioa. Design D2 INVARIANT: three static toolchain pairs
# (.mise.toml vs Dockerfile.dev) stay static, while the OpenCode family's
# partner is the LIVE runtime (`opencode --version`) - a report that carries
# only the static comparison is a gate failure. The fixture tree models ONE
# service: all static pairs match (T1 shape) while a planted `opencode` on
# PATH reports a different version.

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
  # INVARIANT (design D2): the fourth family's report must name the live
  # runtime comparison, not just the static .mise.toml-vs-Dockerfile wording -
  # a report without "runtime" means the static-only gate ran.
  assert_output_contains "runtime"
}
