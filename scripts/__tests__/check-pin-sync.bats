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
#   T19 V1 on a V2-only tree (no opencode key in .mise.toml, ARG 2.x)
#                                               -> exit 0 + skip line
#   T20 V1 with the opencode key present (main's shape), ARG 2.x
#                                               -> exit 1 + fail line
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
#
# PATH is hermetic: setup plants a stub `hostname` (V1) and a stub `opencode`
# answering the per-test STUB_OPENCODE_VERSION, so no host tool version can
# decide a verdict (the suite used to fail on whatever the container had).

load test-helper

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# Every test resolves as V1 unless it plants its own hostname (T11b): the
# service context must not depend on which container runs the suite. PATH is
# hermetic too: a stub `opencode` answering STUB_OPENCODE_VERSION (default
# 1.18.32, the V1 toolchain pin) shadows any real binary, so no case ever
# compares against whatever `opencode` the host happens to have installed.
setup() {
  export STUB_OPENCODE_VERSION="${STUB_OPENCODE_VERSION:-1.18.32}"
  plant_hostname "$BATS_TEST_TMPDIR/hostbin-v1" "poetry-dev"
  plant_opencode_stub "$BATS_TEST_TMPDIR/hostbin-v1"
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

# plant_opencode_stub <dir>: fake `opencode` on PATH printing
# $STUB_OPENCODE_VERSION (set by setup, overridable per test). The version is
# read at invocation time, so a test sets the variable rather than re-planting
# a binary -- an empty value keeps the "runtime unavailable" (skip) branch.
plant_opencode_stub() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/opencode" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${STUB_OPENCODE_VERSION:-}"
STUB
  chmod +x "$dir/opencode"
}

# ---- T1: static pairs match; unavailable runtime is a skip, not an ok ------
# S2: with no usable `opencode --version`, the fourth verdict must be a skip:
# line and must NOT be counted, so the summary reads 3 ok (not 4). The stub
# answers nothing, which is the same empty-runtime branch as a missing binary.
@test "check-pin-sync: T1 three static pairs match -> exit 0 + skip line (runtime unavailable) + summary: 3 ok, 0 fail, 1 skip" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"
  export STUB_OPENCODE_VERSION=""

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  # S2: skip line, never a counted ok: line. Names the V1 service context
  # and the declaration it resolved (DIA-261119-vioa task 1.3).
  assert_output_contains "skip: opencode V1 declared from .mise.toml toolchain pin=1.18.32 (declared-vs-runtime assertion skipped: opencode --version unavailable)"
  assert_output_contains "summary: 3 ok, 0 fail, 1 skip"
}

# ---- T2: single node mismatch ---------------------------------------------
@test "check-pin-sync: T2 single pin mismatch (node, Dockerfile.dev) -> exit 1 + fail line + summary: 3 ok, 1 fail, 0 skip" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.19.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"
  # The fixtures below declare opencode 1.18.32, so the runtime stub must
  # answer that version -- never whatever binary the host ships (its mismatch
  # would turn the fourth verdict into an unrelated fail).
  export STUB_OPENCODE_VERSION=1.18.32

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: node — .mise.toml=24.18.0 Dockerfile.dev=24.19.0"
  assert_output_contains "summary: 3 ok, 1 fail, 0 skip"
}

# ---- T3: multiple pin mismatches (report-ALL) -----------------------------
@test "check-pin-sync: T3 multiple pin mismatches (report-ALL) -> exit 1 + all fail lines" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.19.0" "10.34.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"
  export STUB_OPENCODE_VERSION=1.18.32

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: node — .mise.toml=24.18.0 Dockerfile.dev=24.19.0"
  assert_stderr_contains "fail: pnpm — .mise.toml=10.33.0 Dockerfile.dev=10.34.0"
  assert_output_contains "summary: 2 ok, 2 fail, 0 skip"
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
  export STUB_OPENCODE_VERSION=1.18.32

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: opencode V1 declared from .mise.toml toolchain pin=1.18.32 runtime=1.18.32 matches declared"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  assert_output_contains "summary: 4 ok, 0 fail, 0 skip"
}

# ---- T9: CRLF line endings ------------------------------------------------
@test "check-pin-sync: T9 CRLF line endings -> exit 0 after stripping" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "crlf" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"
  export STUB_OPENCODE_VERSION=1.18.32

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: opencode V1 declared from .mise.toml toolchain pin=1.18.32 runtime=1.18.32 matches declared"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  assert_output_contains "summary: 4 ok, 0 fail, 0 skip"
}

# ---- T10: whitespace variations -------------------------------------------
@test "check-pin-sync: T10 whitespace variations (extra spaces around =) -> exit 0 after stripping" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "whitespace" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"
  export STUB_OPENCODE_VERSION=1.18.32

  run bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: node 24.18.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: pnpm 10.33.0 (parity @ Dockerfile.dev)"
  assert_output_contains "ok: opencode V1 declared from .mise.toml toolchain pin=1.18.32 runtime=1.18.32 matches declared"
  assert_output_contains "ok: bun 1.4.2 (parity @ Dockerfile.dev)"
  assert_output_contains "summary: 4 ok, 0 fail, 0 skip"
}

# ---- T11a: V1 context, differing declarations -> exit 0, V1 pin used ------
# Campaign DIA-261119-vioa task 1.3: toolchain pin 1.18.32 (V1) and image
# ARG 2.3.2 (V2) intentionally differ. In V1 context the verdict resolves
# the V1 toolchain pin and holds it against the live runtime; the pair is
# never compared to each other.
@test "check-pin-sync: T11a V1 context with differing declarations -> exit 0 + line names the V1 toolchain pin" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "2.3.2" "1.4.2")"
  # setup() already planted hostname poetry-dev (V1 context) plus a runtime
  # stub answering STUB_OPENCODE_VERSION=1.18.32 (setup's default).
  export STUB_OPENCODE_VERSION=1.18.32

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: opencode V1 declared from .mise.toml toolchain pin=1.18.32 runtime=1.18.32 matches declared"
  assert_output_contains "summary: 4 ok, 0 fail, 0 skip"
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
  export STUB_OPENCODE_VERSION=2.3.2

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: opencode V2 declared from Dockerfile.dev ARG=2.3.2 runtime=2.3.2 matches declared"
  assert_output_contains "summary: 4 ok, 0 fail, 0 skip"
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
  export STUB_OPENCODE_VERSION=1.99.0

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: opencode V1 runtime mismatch: declared from .mise.toml toolchain pin=1.18.32 runtime=1.99.0"
  assert_output_contains "summary: 3 ok, 1 fail, 0 skip"
}

# ---- T12: single bun mismatch ---------------------------------------------
@test "check-pin-sync: T12 single bun mismatch (Dockerfile.dev) -> exit 1 + fail line + summary: 3 ok, 1 fail, 0 skip" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.99.0")"
  export STUB_OPENCODE_VERSION=1.18.32

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: bun — .mise.toml=1.4.2 Dockerfile.dev=1.99.0"
  assert_output_contains "summary: 3 ok, 1 fail, 0 skip"
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
@test "check-pin-sync: T18 static pins drift (report-ALL) + differing opencode pair is not a fail -> exit 1 + three fail lines + summary: 0 ok, 3 fail, 1 skip" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.19.0" "10.34.0" "" "1.18.32" "1.4.2" "1.18.99" "1.99.0")"
  export STUB_OPENCODE_VERSION=""

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
  assert_output_contains "summary: 0 ok, 3 fail, 1 skip"
}

# ---- S4: real .mise.toml structural integrity + V1 ARG fallback -----------
@test "check-pin-sync: real .mise.toml structural integrity + V1 falls back to the image ARG (S4)" {
  # S4-style structural assertion -- the ONE case that reads the real repo file
  # (documented exception to the FAKE-mock invariant; mirrors check-tools.bats).
  assert_file_contains "$REPO_ROOT/.mise.toml" "[tools]"
  assert_file_contains "$REPO_ROOT/.mise.toml" 'node = "24.18.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" 'pnpm = "10.33.0"'
  assert_file_contains "$REPO_ROOT/.mise.toml" "derived from Dockerfile.dev ARGs"
  assert_file_contains "$REPO_ROOT/.mise.toml" 'bun = "1.4.2"'
  # Slice 1.2 retired the opencode pin: .mise.toml must NOT declare it, because
  # compare_opencode prefers a V1 .mise.toml key over the image ARG -- a
  # reappearing key would silently change which version V1 asserts.
  ! grep -qE '^opencode[[:space:]]*=' "$REPO_ROOT/.mise.toml" || {
    echo "S4: .mise.toml must not pin opencode (the Dockerfile.dev OPENCODE_VERSION ARG owns it)" >&2
    return 1
  }

  # V1 fallback: with no .mise.toml key the declared value comes from the
  # Dockerfile.dev ARG. Selected form: the COMPARISON verdict, not the T19
  # skip -- this fixture builds a 1.x ARG (2.x would take the skip branch) and
  # the stub runtime answers it, so a wrong resolution (empty declared, or the
  # V1 pin lookup leaking through) exits 1 instead of asserting nothing.
  local tree="$BATS_TEST_TMPDIR/pin-sync-s4"
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
  export STUB_OPENCODE_VERSION=1.18.32

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "ok: opencode V1 declared from Dockerfile.dev ARG=1.18.32 runtime=1.18.32 matches declared"
  assert_output_contains "summary: 4 ok, 0 fail, 0 skip"
}

# ---- Task 1.3 (S1.1): per-service declared-vs-runtime OpenCode assertion ----
# Campaign DIA-261119-vioa. Design D2 INVARIANT: three static toolchain pairs
# (.mise.toml vs Dockerfile.dev) stay static, while the OpenCode family's
# partner is the LIVE runtime (`opencode --version`) - a report that carries
# only the static comparison is a gate failure. The fixture tree models ONE
# service: all static pairs match (T1 shape) while the `opencode` stub on PATH
# (STUB_OPENCODE_VERSION) reports a different version.

@test "check-pin-sync: declared vs runtime OpenCode mismatch fails the gate (task 1.3)" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "1.18.32" "1.4.2")"
  export STUB_OPENCODE_VERSION=1.99.0

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
  export STUB_OPENCODE_VERSION=1.18.32

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

# ---- T19: V1 on a V2-only tree -> skip, never a mismatch fail --------------
# The V2 tree retired the .mise.toml opencode key (it builds 2.x from the image
# ARG); a V1 container on this tree must not be told its 1.x runtime mismatches
# a 2.x pin the tree never declared. No declared V1 pin => skip verdict, exit 0.
@test "check-pin-sync: T19 V1 on a V2-only tree (no mise opencode key, ARG 2.3.2) -> exit 0 + skip line" {
  local tree="$BATS_TEST_TMPDIR/pin-sync-v2-only"
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
ARG OPENCODE_VERSION=2.3.2
ARG BUN_VERSION=1.4.2
EOF
  # setup() planted hostname poetry-dev (V1); 1.18.33 is the V1 runtime the
  # legacy container reports -- the exact case the gate misreported before.
  export STUB_OPENCODE_VERSION=1.18.33

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 0
  assert_output_contains "skip: opencode V1 verdict not applicable - .mise.toml declares no opencode pin and this tree builds OpenCode 2.x; run the pin gate inside poetry-dev-v2"
  assert_output_contains "summary: 3 ok, 0 fail, 1 skip"
  [[ "$stderr" != *"runtime mismatch"* ]] || {
    echo "T19: V2-only tree still reported a V1 runtime mismatch:" >&2
    echo "$stderr" >&2
    return 1
  }
}

# ---- T20: main's shape (mise opencode key present) keeps the mismatch fail --
# Regression guard: the skip above is keyed on the ABSENT key. A tree that
# still declares opencode in .mise.toml (main) must keep failing on a runtime
# mismatch, never silently skip.
@test "check-pin-sync: T20 V1 with a mise opencode key and ARG 2.3.2 -> mismatching runtime still exits 1" {
  tree="$(setup_pin_sync_tree 1 1 "24.18.0" "10.33.0" "24.18.0" "10.33.0" "" "1.18.32" "1.4.2" "2.3.2" "1.4.2")"
  export STUB_OPENCODE_VERSION=1.18.33

  run --separate-stderr bash "$tree/scripts/check-pin-sync.sh"

  assert_status 1
  assert_stderr_contains "fail: opencode V1 runtime mismatch: declared from .mise.toml toolchain pin=1.18.32 runtime=1.18.33"
  assert_output_contains "summary: 3 ok, 1 fail, 0 skip"
}
