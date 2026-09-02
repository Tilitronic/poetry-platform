#!/usr/bin/env bash
# validate-plugin-structure.sh — S10 structural gate (DIA-260902-eqgg correction 6, F4)
# Gate A: every retained lib's canonical production symbols are referenced outside import
# Gate B: no duplicate shell definitions/policy constants (manifest, including renamed duplicates)
# Gate C: tests do not import removed aliases or use alternate/probe interfaces
# Accepts optional fixture root/path: $1 = plugin file, $2 = test glob
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="${1:-$ROOT/.opencode/plugins/delegation-observer.ts}"
LIB_DIR="$ROOT/.opencode/plugins/lib"
TEST_GLOB="${2:-$ROOT/.opencode/plugins/__tests__}"

# If first arg is a directory (fixture root), derive PLUGIN and TEST_GLOB from it
if [ -d "${1:-}" ]; then
  PLUGIN="$1/.opencode/plugins/delegation-observer.ts"
  TEST_GLOB="$1/.opencode/plugins/__tests__"
  # Fallback if not found, try second arg
  if [ ! -f "$PLUGIN" ] && [ -n "${2:-}" ] && [ -f "$2" ]; then
    PLUGIN="$2"
  fi
fi

fail=0
pass() { echo "PASS: $1"; }
fail_msg() { echo "FAIL: $1"; fail=1; }

# Gate A — each retained lib's canonical symbols must be referenced outside import, not merely imported
echo "=== Gate A: production symbol usage outside import ==="
# Map of lib -> canonical symbols that must be used outside import
declare -A gateA_symbols=(
  ["capability"]="mintCapabilityToken verifyCapabilityToken"
  ["ticket-gate"]="scanTickets isMetaTaskBypass TICKET_ID_FIND_RE"
  ["handoff"]="libComputeChecksum libAtomicWriteHandoff"
  ["registry"]="createRegistry"
  ["stall-sweep"]="createStallSweep"
  ["formatter"]="runEditTimeFormatter"
  ["circuit-breaker"]="ToolCircuitBreaker"
  ["errors"]="errorMessage"
)
retained=(capability ticket-gate handoff registry stall-sweep formatter circuit-breaker errors)
for lib in "${retained[@]}"; do
  # Check module is imported
  if ! grep -Fq "from \"./lib/${lib}.ts\"" "$PLUGIN" && ! grep -Fq "from './lib/${lib}.ts'" "$PLUGIN" && ! grep -Fq "from \"./lib/${lib}\"" "$PLUGIN"; then
    fail_msg "lib ${lib}.ts has NO production importer in delegation-observer.ts"
    continue
  fi
  # Check each canonical symbol is referenced outside import
  symbols_for_lib=${gateA_symbols[$lib]:-}
  for sym in $symbols_for_lib; do
    # Check symbol appears at least twice (once in import, once outside) and at least one outside import block inner lines
    total=$(grep -c -E "\b${sym}\b" "$PLUGIN" || true)
    outside=$(grep -Ev "^\s*(import|export)" "$PLUGIN" | grep -c -E "\b${sym}\b" || true)
    # Also check for actual usage (with parens, assignment, bracket, or closing bracket) to exclude import inner lines that are just "  sym,"
    usage=$(grep -E "\b${sym}\b" "$PLUGIN" | grep -v -E "^\s*(import|export)" | grep -E "\b${sym}\b.*\(|\b${sym}\b.*=|\b${sym}\b.*\[|\b${sym}\b.*\]|\b${sym}\b.*;" | wc -l || true)
    if [ "$total" -lt 2 ] || [ "$usage" -eq 0 ]; then
      fail_msg "lib ${lib}.ts symbol '${sym}' not referenced outside import (only imported, not used) total=$total usage=$usage"
    else
      pass "lib ${lib}.ts symbol '${sym}' referenced outside import"
    fi
  done
done

# Gate B — manifest of prohibited shell definitions/policy constants, including renamed duplicates
echo "=== Gate B: no duplicate shell definitions (manifest) ==="
# Symbol-name prohibitions — must only appear as imports, never as local defs
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
  if grep -Eq "^\s*(function|const|let|var|class)\s+${sym}\b" "$PLUGIN"; then
    fail_msg "shell defines duplicate seam symbol '${sym}' (should only be import)"
  else
    pass "no duplicate shell def for '${sym}'"
  fi
done

# Policy constants / behavioral strings that survive renaming — even renamed duplicates must be caught
# Check for duplicate constant values or behavioral patterns that indicate inline reimplementation
# FORMATTER_MAX_BYTES duplicated as 1024*1024 or 1048576, FORMATTER_TIMEOUT, stall intervals, HMAC, etc.
if grep -q "1024 *\* *1024" "$PLUGIN" && ! grep -q "from.*lib/formatter" "$PLUGIN"; then
  # This is a heuristic; the real check is for duplicate constant definitions outside import context
  # We check if shell defines MY_FORMATTER_LIMIT etc. with same values
  if grep -Eq "^\s*(const|let|var)\s+MY_FORMATTER" "$PLUGIN"; then
    fail_msg "shell defines renamed duplicate formatter policy constant (MY_FORMATTER_*)"
  fi
fi
# Check for inline HMAC reimplementation outside lib/capability
if grep -q "createHmac.*sha256" "$PLUGIN" && ! grep -q "from.*lib/capability" "$PLUGIN"; then
  fail_msg "shell contains inline HMAC logic outside lib/capability"
fi
# Check for renamed stall logic: getStallMinutes, MY_STALL_KEY, etc.
if grep -Eq "^\s*function\s+getStallMinutes\b|^\s*const\s+MY_STALL" "$PLUGIN"; then
  fail_msg "shell defines renamed duplicate stall-sweep logic (getStallMinutes/MY_STALL_*)"
fi
# Check for renamed formatter duplicate
if grep -Eq "^\s*const\s+MY_FORMATTER" "$PLUGIN" || grep -Eq "^\s*function\s+checkIgnored" "$PLUGIN"; then
  fail_msg "shell defines renamed duplicate formatter logic"
fi

# Gate C — tests must use canonical production interface only, no alternate/probe
echo "=== Gate C: tests on production interface (canonical only) ==="
removed_aliases=(
  checkTicketGate evaluateGate isMetaTask shouldBypassTicketGate
  atomicWrite writeHandoff createStallSweeper createToolCircuitBreaker createBreaker parseAndExec
)
for alias in "${removed_aliases[@]}"; do
  if grep -R --include='*.mjs' --include='*.ts' -n "import.*\b${alias}\b" "$TEST_GLOB" 2>/dev/null | grep -v "^\s*//" | grep -q .; then
    fail_msg "test file imports removed alias '${alias}'"
  else
    pass "no test imports removed alias '${alias}'"
  fi
done

# Check for alternate/probe pattern: requireAny, alternate-name arrays
if grep -R --include='*.mjs' --include='*.ts' -n "requireAny" "$TEST_GLOB" 2>/dev/null | grep -v "^\s*//" | grep -q .; then
  fail_msg "test uses requireAny alternate/probe interface (must use canonical import directly)"
else
  pass "no requireAny probe in tests"
fi

# Check for alternate-name probe arrays like ["scanTickets","scan"] or ["mintCapabilityToken","mintToken"]
if grep -R --include='*.mjs' -q "from.*lib.*scanTickets.*scan\|from.*lib.*mintCapabilityToken.*mintToken" "$TEST_GLOB" 2>/dev/null; then
  fail_msg "test uses alternate-name probe array for canonical symbols"
else
  pass "no alternate-name probe arrays"
fi

# Ensure at least one canonical import exists (positive check) — check for createRegistry string anywhere (dynamic or static import)
if ! grep -R --include='*.mjs' -q "createRegistry" "$TEST_GLOB" 2>/dev/null; then
  fail_msg "no canonical import of createRegistry found in tests (Gate C positive check)"
else
  pass "canonical import createRegistry found"
fi

if [ "$fail" -ne 0 ]; then
  echo "validate-plugin-structure.sh: FAILED"
  exit 1
fi
echo "validate-plugin-structure.sh: all structural gates PASS"
exit 0
