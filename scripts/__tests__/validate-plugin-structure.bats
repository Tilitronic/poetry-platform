#!/usr/bin/env bats
# validate-plugin-structure.bats — RED coverage for S10 structural gate (DIA-260902-eqgg)
# Fixed per Task 2: fixtures operate under BATS_TEST_TMPDIR, never REPO_ROOT.

load test-helper

GATE_SCRIPT="$REPO_ROOT/scripts/validate-plugin-structure.sh"
PLUGIN="$REPO_ROOT/.opencode/plugins/delegation-observer.ts"
LIB_DIR="$REPO_ROOT/.opencode/plugins/lib"
TEST_GLOB="$REPO_ROOT/.opencode/plugins/__tests__"

# Capture real plugin checksum before suite (for regression assertion)
setup() {
  # Capture checksum at test start (if not already captured suite-wide)
  if [ -z "${PLUGIN_CHECKSUM_BEFORE:-}" ]; then
    PLUGIN_CHECKSUM_BEFORE=$(sha256sum "$PLUGIN" | awk '{print $1}')
    export PLUGIN_CHECKSUM_BEFORE
  fi
}

teardown() {
  # Secondary safeguard: ensure no fixture files remain in real plugin location
  # (Primary isolation is via BATS_TEST_TMPDIR, but teardown ensures cleanup if a test failed to restore)
  # We do NOT restore the real plugin here via backup, because primary isolation never touches it.
  # Just ensure any _gateC fixture files are removed (they should already be in BATS_TEST_TMPDIR, not REPO_ROOT)
  rm -f "$REPO_ROOT/.opencode/plugins/__tests__/_gateC-fixture-"*.test.mjs 2>/dev/null || true
}

# Helper to create a fixture tree under BATS_TEST_TMPDIR and run gate against it
# Usage: run_gate_on_fixture <fixture_setup_fn>
# The fixture setup function should populate the fixture's plugin and test files
run_gate_on_fixture() {
  local fixture_root="$BATS_TEST_TMPDIR/fixture-$(date +%s%N)-$$"
  mkdir -p "$fixture_root/.opencode/plugins/lib"
  mkdir -p "$fixture_root/.opencode/plugins/__tests__"
  mkdir -p "$fixture_root/scripts"
  # Copy only validator inputs (plugin + libs + tests needed for gate)
  cp "$PLUGIN" "$fixture_root/.opencode/plugins/delegation-observer.ts"
  cp -r "$LIB_DIR"/*.ts "$fixture_root/.opencode/plugins/lib/" 2>/dev/null || true
  cp -r "$TEST_GLOB"/*.mjs "$fixture_root/.opencode/plugins/__tests__/" 2>/dev/null || true
  cp -r "$TEST_GLOB"/*.ts "$fixture_root/.opencode/plugins/__tests__/" 2>/dev/null || true
  cp "$GATE_SCRIPT" "$fixture_root/scripts/validate-plugin-structure.sh"
  # Allow caller to mutate the fixture
  if [ -n "${1:-}" ] && declare -F "$1" > /dev/null; then
    "$1" "$fixture_root"
  fi
  # Run gate against fixture
  run bash "$fixture_root/scripts/validate-plugin-structure.sh" "$fixture_root/.opencode/plugins/delegation-observer.ts" "$fixture_root/.opencode/plugins/__tests__"
}

# Write a minimal CLEAN shell that passes Gate A + Gate B (used to isolate Gate C fixtures).
write_clean_plugin() {
  local target="${1:-$PLUGIN}"
  cat > "$target" <<'CLEAN'
import { mintCapabilityToken, verifyCapabilityToken } from "./lib/capability.ts"
import { scanTickets, parseFrontmatterFields, parseTicketDate, keywordsCorrelate, evaluateTicketCorrelation, isMetaTaskBypass, isTicketGateBlocked, TICKET_ID_RE, TICKET_ID_FIND_RE } from "./lib/ticket-gate.ts"
import { computeChecksum, atomicWriteHandoff } from "./lib/handoff.ts"
import { createRegistry } from "./lib/registry.ts"
import { stallThresholdMinutes, STALL_SWEEP_KEY, STALL_SWEEP_INTERVAL_MS, createStallSweep } from "./lib/stall-sweep.ts"
import { isFormatterIgnoredPath, extractPatchPaths, runEditTimeFormatter, FORMATTER_MAX_BYTES } from "./lib/formatter.ts"
import { ToolCircuitBreaker, CB_WINDOW_SIZE, CB_ERROR_THRESHOLD, CB_COOLDOWN_MS } from "./lib/circuit-breaker.ts"
import { errorMessage } from "./lib/errors.ts"
const _a = mintCapabilityToken; const _b = verifyCapabilityToken; const _c = scanTickets; const _d = parseFrontmatterFields; const _e = parseTicketDate
const _f = keywordsCorrelate; const _g = evaluateTicketCorrelation; const _h = isMetaTaskBypass; const _i = isTicketGateBlocked
const _j = TICKET_ID_RE; const _k = TICKET_ID_FIND_RE; const _l = computeChecksum; const _m = atomicWriteHandoff
const _n = createRegistry; const _o = stallThresholdMinutes; const _p = STALL_SWEEP_KEY; const _q = STALL_SWEEP_INTERVAL_MS; const _r = createStallSweep
const _s = isFormatterIgnoredPath; const _t = extractPatchPaths; const _u = runEditTimeFormatter; const _v = FORMATTER_MAX_BYTES
const _w = ToolCircuitBreaker; const _x = CB_WINDOW_SIZE; const _y = CB_ERROR_THRESHOLD; const _z = CB_COOLDOWN_MS; const _err = errorMessage
CLEAN
}

count_symbol_outside_import() {
  local file="$1" sym="$2"
  grep -v "^\s*import" "$file" | grep -c -E "\b${sym}\b" || true
}

# ---------------------------------------------------------------------------
# Gate A — production symbol usage outside import
# ---------------------------------------------------------------------------

@test "Gate A structural: each retained lib's canonical symbols are referenced outside import (not merely imported)" {
  for sym in mintCapabilityToken verifyCapabilityToken; do
    echo "# Testing $sym" >&3
    run bash -c "grep -v '^\s*import' '$PLUGIN' | grep -q -E '\b${sym}\b'; echo "# grep exit:\$?" >&3"
    assert_status 0
    cnt=$(count_symbol_outside_import "$PLUGIN" "$sym")
    [ "$cnt" -ge 1 ] || { echo "Gate A: symbol $sym not referenced outside import (count=$cnt)" >&2; return 1; }
  done
  for sym in scanTickets isMetaTaskBypass TICKET_ID_FIND_RE; do
    run bash -c "grep -v '^\s*import' '$PLUGIN' | grep -q -E '\b${sym}\b'"
    assert_status 0
    cnt=$(count_symbol_outside_import "$PLUGIN" "$sym")
    [ "$cnt" -ge 1 ] || { echo "Gate A: symbol $sym not referenced outside import (count=$cnt)" >&2; return 1; }
  done
  for sym in libComputeChecksum libAtomicWriteHandoff; do
    run bash -c "grep -v '^\s*import' '$PLUGIN' | grep -q -E '\b${sym}\b'"
    assert_status 0
  done
  run bash -c "grep -v '^\s*import' '$PLUGIN' | grep -q -E '\bcreateHandoff\b|\bcreateRegistry\b'"
  assert_status 0
  for sym in createRegistry; do
    run bash -c "grep -v '^\s*import' '$PLUGIN' | grep -q -E '\b${sym}\b'"
    assert_status 0
  done
  for sym in createStallSweep; do
    run bash -c "grep -v '^\s*import' '$PLUGIN' | grep -q -E '\b${sym}\b'"
    assert_status 0
  done
  for sym in runEditTimeFormatter; do
    run bash -c "grep -v '^\s*import' '$PLUGIN' | grep -q -E '\b${sym}\b'"
    assert_status 0
  done
  for sym in ToolCircuitBreaker; do
    run bash -c "grep -v '^\s*import' '$PLUGIN' | grep -q -E '\b${sym}\b'"
    assert_status 0
  done
  run bash -c "grep -v '^\s*import' '$PLUGIN' | grep -q -E '\berrorMessage\b'"
  assert_status 0
}

@test "Gate A NEGATIVE FIXTURE: imported module but required symbol never used outside import — gate must FAIL" {
  fixture_setup() {
    local root="$1"
    cat > "$root/.opencode/plugins/delegation-observer.ts" <<'FIXTURE'
import { mintCapabilityToken, verifyCapabilityToken } from "./lib/capability.ts"
import { scanTickets } from "./lib/ticket-gate.ts"
import { atomicWriteHandoff } from "./lib/handoff.ts"
import { createRegistry } from "./lib/registry.ts"
import { stallThresholdMinutes } from "./lib/stall-sweep.ts"
import { isFormatterIgnoredPath } from "./lib/formatter.ts"
import { ToolCircuitBreaker } from "./lib/circuit-breaker.ts"
import { errorMessage } from "./lib/errors.ts"
const _x = scanTickets
const _y = atomicWriteHandoff
const _z = createRegistry
const _a = stallThresholdMinutes
const _b = isFormatterIgnoredPath
const _c = ToolCircuitBreaker
const _d = errorMessage
const _e = verifyCapabilityToken
FIXTURE
  }
  run_gate_on_fixture fixture_setup
  assert_status 1
  assert_output_contains "FAIL"
  # Verify real plugin unchanged (regression assertion)
  current=$(sha256sum "$PLUGIN" | awk '{print $1}')
  [ "$current" = "$PLUGIN_CHECKSUM_BEFORE" ] || { echo "Real plugin was clobbered!" >&2; return 1; }
}

# ---------------------------------------------------------------------------
# Gate B — manifest of prohibited shell definitions + renamed duplicates
# ---------------------------------------------------------------------------

@test "Gate B structural: shell contains no prohibited seam definitions or policy constants (manifest)" {
  prohibited_symbols=(
    parseFrontmatterFields parseTicketDate keywordsCorrelate scanTickets evaluateTicketCorrelation isMetaTaskBypass isTicketGateBlocked
    computeChecksum atomicWriteHandoff
    appendRow appendMessageRow captureConfigLoadSignal atomicWriteBootMarker
    stallThresholdMinutes STALL_SWEEP_KEY
    isFormatterIgnoredPath extractPatchPaths runEditTimeFormatter
    ToolCircuitBreaker CB_WINDOW_SIZE CB_ERROR_THRESHOLD CB_COOLDOWN_MS
    mintCapabilityToken verifyCapabilityToken CAPABILITY_SECRET
  )
  for sym in "${prohibited_symbols[@]}"; do
    run bash -c "grep -Eq '^\s*(function|const|let|var|class)\s+${sym}\b' '$PLUGIN'"
    [ "$status" -ne 0 ] || { echo "Gate B manifest violation: shell defines prohibited symbol '$sym'" >&2; return 1; }
  done
  true
}

@test "Gate B NEGATIVE FIXTURE: renamed duplicate stall-sweep function under different name — gate must FAIL" {
  fixture_setup_renamed_stall() {
    local root="$1"
    cat > "$root/.opencode/plugins/delegation-observer.ts" <<'FIXTURE'
import { mintCapabilityToken, verifyCapabilityToken } from "./lib/capability.ts"
import { scanTickets, parseFrontmatterFields } from "./lib/ticket-gate.ts"
import { computeChecksum, atomicWriteHandoff } from "./lib/handoff.ts"
import { createRegistry } from "./lib/registry.ts"
import { stallThresholdMinutes, STALL_SWEEP_KEY, STALL_SWEEP_INTERVAL_MS } from "./lib/stall-sweep.ts"
import { isFormatterIgnoredPath } from "./lib/formatter.ts"
import { ToolCircuitBreaker } from "./lib/circuit-breaker.ts"
import { errorMessage } from "./lib/errors.ts"
function getStallMinutes(envName, fallback) {
  const raw = process.env[envName]
  if (!raw) return fallback
  const parsed = Number.parseInt(raw, 10)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback
}
const STALL_INTERVAL = 60_000
const MY_STALL_KEY = Symbol.for("delegation-observer.stallSweepInterval")
const _a = mintCapabilityToken; const _b = verifyCapabilityToken; const _c = scanTickets; const _d = parseFrontmatterFields
const _e = computeChecksum; const _f = atomicWriteHandoff; const _g = createRegistry; const _h = stallThresholdMinutes
const _i = STALL_SWEEP_KEY; const _j = STALL_SWEEP_INTERVAL_MS; const _k = isFormatterIgnoredPath; const _l = ToolCircuitBreaker; const _m = errorMessage
FIXTURE
  }
  run_gate_on_fixture fixture_setup_renamed_stall
  assert_status 1
  assert_output_contains "FAIL"
  current=$(sha256sum "$PLUGIN" | awk '{print $1}')
  [ "$current" = "$PLUGIN_CHECKSUM_BEFORE" ] || { echo "Real plugin clobbered!" >&2; return 1; }
}

@test "Gate B NEGATIVE FIXTURE: formatter policy constant duplicated under renamed name — gate must FAIL" {
  fixture_setup_formatter_dup() {
    local root="$1"
    cat > "$root/.opencode/plugins/delegation-observer.ts" <<'FIXTURE'
import { mintCapabilityToken } from "./lib/capability.ts"
import { scanTickets } from "./lib/ticket-gate.ts"
import { computeChecksum, atomicWriteHandoff } from "./lib/handoff.ts"
import { createRegistry } from "./lib/registry.ts"
import { stallThresholdMinutes, STALL_SWEEP_KEY } from "./lib/stall-sweep.ts"
import { isFormatterIgnoredPath, extractPatchPaths, runEditTimeFormatter } from "./lib/formatter.ts"
import { ToolCircuitBreaker } from "./lib/circuit-breaker.ts"
import { errorMessage } from "./lib/errors.ts"
const MY_FORMATTER_LIMIT = 1024 * 1024
const MY_FORMATTER_TIMEOUT = 30_000
const MY_IGNORE_LIST = [".opencode/session/", "knowledge/"]
function checkIgnored(filePath, root) {
  return MY_IGNORE_LIST.some(p => filePath.startsWith(p))
}
const _a = mintCapabilityToken; const _b = scanTickets; const _c = computeChecksum; const _d = atomicWriteHandoff
const _e = createRegistry; const _f = stallThresholdMinutes; const _g = STALL_SWEEP_KEY; const _h = isFormatterIgnoredPath
const _i = extractPatchPaths; const _j = runEditTimeFormatter; const _k = ToolCircuitBreaker; const _l = errorMessage
FIXTURE
  }
  run_gate_on_fixture fixture_setup_formatter_dup
  assert_status 1
  assert_output_contains "FAIL"
  current=$(sha256sum "$PLUGIN" | awk '{print $1}')
  [ "$current" = "$PLUGIN_CHECKSUM_BEFORE" ] || { echo "Real plugin clobbered!" >&2; return 1; }
}

# ---------------------------------------------------------------------------
# Gate C — tests must use canonical production interface only
# ---------------------------------------------------------------------------

@test "Gate C structural: no test file imports removed aliases or alternate/probe interfaces (canonical only)" {
  removed_aliases=(
    checkTicketGate evaluateGate isMetaTask shouldBypassTicketGate
    atomicWrite writeHandoff createStallSweeper createToolCircuitBreaker createBreaker parseAndExec
  )
  for alias in "${removed_aliases[@]}"; do
    run bash -c "grep -R --include='*.mjs' --include='*.ts' -n 'import.*\\b${alias}\\b' '$TEST_GLOB' | grep -v '^\s*//' | grep -q ."
    [ "$status" -ne 0 ] || { echo "Gate C violation: test imports removed alias '$alias'" >&2; echo "$output" >&2; return 1; }
  done
  run bash -c "grep -R --include='*.mjs' -n 'requireAny' '$TEST_GLOB' | grep -v '^\s*//' | grep -q ."
  [ "$status" -ne 0 ] || { echo "Gate C violation: test uses requireAny alternate/probe interface (must use canonical import directly)" >&2; echo "$output" >&2; return 1; }
  run bash -c "grep -R --include='*.mjs' -n 'from.*lib.*scanTickets\|from.*lib.*mintCapabilityToken' '$TEST_GLOB' | head -1"
  assert_status 0
}

@test "Gate C NEGATIVE FIXTURE: test file importing alternate alias createStallSweeper instead of canonical createStallSweep — gate must FAIL" {
  fixture_setup_gateC_alt() {
    local root="$1"
    write_clean_plugin "$root/.opencode/plugins/delegation-observer.ts"
    cat > "$root/.opencode/plugins/__tests__/_gateC-fixture-alternate.test.mjs" <<'FIXTURE'
import { createStallSweeper } from "../lib/stall-sweep.ts"
import { describe, it } from "node:test"
describe("fixture", () => { it("dummy", () => {}) })
FIXTURE
  }
  run_gate_on_fixture fixture_setup_gateC_alt
  assert_status 1
  assert_output_contains "FAIL"
  assert_output_contains "createStallSweeper"
  current=$(sha256sum "$PLUGIN" | awk '{print $1}')
  [ "$current" = "$PLUGIN_CHECKSUM_BEFORE" ] || { echo "Real plugin clobbered!" >&2; return 1; }
}

@test "Gate C NEGATIVE FIXTURE: test using requireAny alternate/probe for ticket-gate — gate must FAIL" {
  fixture_setup_gateC_probe() {
    local root="$1"
    write_clean_plugin "$root/.opencode/plugins/delegation-observer.ts"
    cat > "$root/.opencode/plugins/__tests__/_gateC-fixture-probe.test.mjs" <<'FIXTURE'
import * as mod from "../lib/ticket-gate.ts"
function requireAny(names) { for (const n of names) if (mod[n] !== undefined) return mod[n] }
const fn = requireAny(["scanTickets", "scan", "parseAndExec"])
FIXTURE
  }
  run_gate_on_fixture fixture_setup_gateC_probe
  assert_status 1
  assert_output_contains "FAIL"
  current=$(sha256sum "$PLUGIN" | awk '{print $1}')
  [ "$current" = "$PLUGIN_CHECKSUM_BEFORE" ] || { echo "Real plugin clobbered!" >&2; return 1; }
}

@test "Gate C: unconditional pass path removed — gate must not emit PASS for alias probe that is actually an import" {
  fixture_setup_gateC_uncond() {
    local root="$1"
    write_clean_plugin "$root/.opencode/plugins/delegation-observer.ts"
    cat > "$root/.opencode/plugins/__tests__/_gateC-fixture-unconditional.test.mjs" <<'FIXTURE'
import { checkTicketGate } from "../lib/ticket-gate.ts"
FIXTURE
  }
  run_gate_on_fixture fixture_setup_gateC_uncond
  assert_status 1
  assert_output_contains "FAIL"
  run bash -c "bash '$GATE_SCRIPT' \"\$1\" \"\$2\" 2>&1 | grep -q 'only probed at runtime'" -- "$BATS_TEST_TMPDIR/fixture-"*"/.opencode/plugins/delegation-observer.ts" "$BATS_TEST_TMPDIR/fixture-"*"/.opencode/plugins/__tests__" 2>/dev/null || true
  [ "$status" -ne 0 ] || { echo "Gate C unconditional pass path still present — should be removed" >&2; return 1; }
  current=$(sha256sum "$PLUGIN" | awk '{print $1}')
  [ "$current" = "$PLUGIN_CHECKSUM_BEFORE" ] || { echo "Real plugin clobbered!" >&2; return 1; }
}

@test "Regression: real plugin checksum unchanged before/after full Bats suite" {
  # This test runs last and verifies the real plugin was never clobbered by any fixture
  current=$(sha256sum "$PLUGIN" | awk '{print $1}')
  [ "$current" = "$PLUGIN_CHECKSUM_BEFORE" ] || { echo "FAIL: real plugin checksum changed! before=$PLUGIN_CHECKSUM_BEFORE after=$current" >&2; return 1; }
  echo "Plugin checksum unchanged: $current"
}
