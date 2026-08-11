#!/usr/bin/env bash
#
# test-ticket-gate.sh — static regression probe for the DIA-076 ticket-gate
# fixes in .opencode/plugins/delegation-observer.ts.
#
# No plugin test harness exists (specialist recommendation, DIA-076), so this
# is a lightweight STATIC probe: it asserts the edited patterns are present
# in the plugin source:
#   1. Path-1 tri-state immediate `return mentioned.length > 0` when an
#      explicitly-referenced DIA-id matches an OPEN ticket (no recency/
#      session-ownership requirement — DIA-076 A1).
#   C1. Strict tri-state (DIA-076 C1): the old Path-1 fall-through literal
#      (`mentioned.some((t) => isSessionOwned(t) || isRecent(t))`) must NOT
#      reappear — an explicit DIA-id that resolves to NO open ticket must
#      fail hard, never fall through to Path-2/Path-3.
#   2. Narrowed ticket-gate exemption regex: `checksum\s+verif` +
#      `handoff\s*integrit` present (boot-gate checksum verification is NOT
#      §10 work — circular-deadlock fix) and the bare `sha256\b` arm ABSENT
#      (DIA-076 M1 — a bare keyword is too easy to trigger in unrelated §10
#      text).
#   3. configWorkHint first regex narrowed: `/opencode\.jsonc|AGENTS\.md|
#      skill|plugin/i` present and `.opencode\/` removed from it (runtime
#      artifacts .opencode/session/* and .opencode/learnings/* are not config).
#   4. `ticket_gate_weak_correlation` warn-not-throw branch exists (Path-3
#      failures no longer hard-block).
#
# Run: bash scripts/test-ticket-gate.sh
# Wired into `make test-config` (DIA-076) — must exit 0.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/.opencode/plugins/delegation-observer.ts"

fail=0
pass() { echo "PASS: $1"; }
fail_check() { echo "FAIL: $1"; fail=1; }

if [[ ! -f "$PLUGIN" ]]; then
  echo "FAIL: plugin file not found: $PLUGIN"
  exit 1
fi

# --- Check 1: Path-1 tri-state return + open-ticket comment marker ---
if grep -Fq 'return mentioned.length > 0' "$PLUGIN" &&
   grep -Fq '// OPEN ticket is the STRONGEST correlation signal' "$PLUGIN"; then
  pass "Path-1 tri-state return mentioned.length > 0 (open-ticket comment marker present)"
else
  fail_check "Path-1: 'return mentioned.length > 0' and open-ticket comment marker missing"
fi

# --- Check C1: strict tri-state — no Path-2/3 fall-through for explicit DIA-id ---
# The C1 re-fix replaced `if (mentioned.length > 0) return true` (which
# allowed an unresolvable explicit DIA-id to fall through to Path-2/Path-3)
# with a hard `return mentioned.length > 0`. Assert the new form AND the
# absence of the old fall-through literal that would mask an explicit
# citation that does not resolve to live work.
if grep -Fq 'return mentioned.length > 0' "$PLUGIN" &&
   ! grep -Fq 'mentioned.some((t) => isSessionOwned(t) || isRecent(t))' "$PLUGIN"; then
  pass "C1 tri-state: explicit DIA-id resolves ONLY against OPEN tickets (old Path-2/3 fall-through literal absent)"
else
  fail_check "C1 tri-state: 'return mentioned.length > 0' missing or old 'mentioned.some(...)' fall-through literal present"
fi

# --- Check 2: narrowed exemption regex (checksum\s+verif + handoff\s*integrit
# present; sha256\b arm dropped) ---
# Scope the probe to the exemption-regex line (the single line carrying the
# `/create\s+(a\s+)?ticket\b ...` literal) so the `sha256` absence assertion
# is about the REGEX, not the unrelated `createHash("sha256")` helper at the
# checksum-computation site.
EXEMPT_RE="$(grep -F '/create\s+(a\s+)?ticket\b' "$PLUGIN" || true)"
if grep -Fq 'checksum\s+verif' <<<"$EXEMPT_RE" &&
   grep -Fq 'handoff\s*integrit' <<<"$EXEMPT_RE" &&
   ! grep -Fq 'sha256' <<<"$EXEMPT_RE"; then
  pass "exemption regex narrowed (checksum\\s+verif | handoff\\s*integrit present; sha256 arm dropped)"
else
  fail_check "exemption regex missing checksum\\s+verif / handoff\\s*integrit, or sha256 arm still present"
fi

# --- Check 3: configWorkHint first regex narrowed (no .opencode\/) ---
if grep -Fq '/opencode\.jsonc|AGENTS\.md|skill|plugin/i' "$PLUGIN"; then
  pass "configWorkHint first regex narrowed to /opencode\\.jsonc|AGENTS\\.md|skill|plugin/i"
else
  fail_check "configWorkHint first regex literal /opencode\\.jsonc|AGENTS\\.md|skill|plugin/i missing"
fi
# The old first-regex literal began with `/.opencode\/|opencode\.jsonc` — if it
# is still present, `.opencode\/` was NOT removed from the first regex.
if grep -Fq '/.opencode\/|opencode\.jsonc' "$PLUGIN"; then
  fail_check "configWorkHint first regex still contains .opencode\\/ (old literal present)"
else
  pass "configWorkHint first regex does NOT contain .opencode\\/"
fi

# --- Check 4: ticket_gate_weak_correlation branch exists ---
if grep -Fq 'ticket_gate_weak_correlation' "$PLUGIN"; then
  pass "ticket_gate_weak_correlation warn-not-throw branch present"
else
  fail_check "ticket_gate_weak_correlation branch missing"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "test-ticket-gate.sh: FAILED (one or more regression patterns missing)"
  exit 1
fi

echo "test-ticket-gate.sh: all regression patterns present — OK"
exit 0
