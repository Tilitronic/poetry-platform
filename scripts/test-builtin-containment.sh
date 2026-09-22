#!/usr/bin/env bash
#
# test-builtin-containment.sh — DIA-260831-h3i4 builtin containment gate.
#
# Asserts the native-agent / direct-coder-binding containment holds:
#   P1. agent.build / agent.plan / agent.scout are disable:true in
#       .opencode/opencode.jsonc (explore/general disables retained).
#   P2. No tdd-cycle / test-package command blocks remain in opencode.jsonc
#       (F2: direct agent:coder bindings removed); arch-check /
#       code-ownership (architector, read-only) retained.
#   P2b. frontier.md + rag.md carry no agent binding (fall back to the
#       invoking orchestrator; read-only, no ticket-gate bypass).
#   P3. ticket-gate.ts whitelist is ONLY the literal `scripts/tickets new`
#       invocation (F3: no natural-language substrings, no bookkeeping pair -
#       bookkeeping uses the capability-token path).
#   N1. No bare "meta-task" / "[meta-task]" entry remains in the whitelist
#       array (marker alone must NOT authorize engineering work).
#   N2. The orchestrator task allow-list admits no build/plan/scout lane.
#   N3. AGENTS.md section 9 table lists build/plan/scout (S1 lockstep).
#
# Run: bash scripts/test-builtin-containment.sh
# Wired into `make test-config` (DIA-260831-h3i4) — must exit 0.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCODE="$ROOT/.opencode/opencode.jsonc"
GATE="$ROOT/.opencode/plugins/lib/ticket-gate.ts"
AGENTS_MD="$ROOT/AGENTS.md"

fail=0
pass() { echo "PASS: $1"; }
fail_check() { echo "FAIL: $1"; fail=1; }

# --- P1/P2/N2 via python3 JSONC parse (comment-aware, string-safe) ---
if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 is required." >&2
  exit 2
fi

PY_OUT="$(python3 - "$OPENCODE" <<'PYEOF'
import json, sys

def strip_jsonc(src):
    out, i, n, s = [], 0, len(src), None
    while i < n:
        c, nxt = src[i], src[i+1] if i+1 < n else ""
        if s:
            out.append(c)
            if c == "\\":
                i += 1
                if i < n: out.append(src[i])
            elif c == s: s = None
            i += 1
            continue
        if c in "\"'":
            s, i = c, i+1
            out.append(c)
            continue
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n": i += 1
            continue
        if c == "/" and nxt == "*":
            i += 2
            while i+1 < n and not (src[i] == "*" and src[i+1] == "/"): i += 1
            i += 2
            continue
        if c == ",":
            j = i+1
            while j < n and src[j].isspace(): j += 1
            if j < n and src[j] in "}]":
                i += 1
                continue
        out.append(c)
        i += 1
    return "".join(out)

cfg = json.loads(strip_jsonc(open(sys.argv[1]).read()))
agents = cfg.get("agent", {})
for name in ("build", "plan", "scout", "explore", "general"):
    print("disabled:%s:%s" % (name, (agents.get(name) or {}).get("disable") is True))
task = ((agents.get("orchestrator") or {}).get("permission") or {}).get("task") or {}
admits = [k for k, v in task.items() if k in ("build", "plan", "scout") and v == "allow"]
print("admits-native:%s" % (",".join(admits) if admits else "none"))
cmds = cfg.get("command") or {}
print("has-tdd-cycle:%s" % ("tdd-cycle" in cmds))
print("has-test-package:%s" % ("test-package" in cmds))
print("has-arch-check:%s" % ("arch-check" in cmds))
print("has-code-ownership:%s" % ("code-ownership" in cmds))
PYEOF
)"
echo "$PY_OUT" | while IFS= read -r line; do echo "  info: $line"; done

for name in build plan scout explore general; do
  if echo "$PY_OUT" | grep -Fq "disabled:$name:True"; then
    pass "P1 agent.$name disable:true"
  else
    fail_check "P1 agent.$name NOT disable:true"
  fi
done

if echo "$PY_OUT" | grep -Fq "admits-native:none"; then
  pass "N2 orchestrator task allow-list admits no build/plan/scout"
else
  fail_check "N2 orchestrator task allow-list admits a native lane"
fi

if echo "$PY_OUT" | grep -Fq "has-tdd-cycle:False"; then
  pass "P2 tdd-cycle command block removed from opencode.jsonc"
else
  fail_check "P2 tdd-cycle command block still present in opencode.jsonc"
fi

if echo "$PY_OUT" | grep -Fq "has-test-package:False"; then
  pass "P2 test-package command block removed from opencode.jsonc"
else
  fail_check "P2 test-package command block still present in opencode.jsonc"
fi

if echo "$PY_OUT" | grep -Fq "has-arch-check:True" && echo "$PY_OUT" | grep -Fq "has-code-ownership:True"; then
  pass "P2 arch-check / code-ownership commands retained"
else
  fail_check "P2 arch-check / code-ownership commands missing"
fi

# --- P2b: frontier.md + rag.md carry no agent binding ---
for cmd in frontier rag; do
  if grep -Eq "^agent:" "$ROOT/.opencode/commands/$cmd.md"; then
    fail_check "P2b $cmd.md still carries an agent binding"
  else
    pass "P2b $cmd.md has no agent binding (invoking-agent fallback)"
  fi
done

# --- P3/N1: whitelist declaration line only (not comments below it) ---
WLIT="$(grep -F 'META_TASK_WHITELIST = ' "$GATE" | head -1)"
if grep -Fq '"scripts/tickets new"' <<<"$WLIT"; then
  pass "P3 whitelist holds the literal 'scripts/tickets new' invocation"
else
  fail_check "P3 whitelist missing 'scripts/tickets new'"
fi

# F3: exactly one whitelisted signal - no natural-language substrings, no
# bookkeeping pair (bookkeeping rides the capability-token path instead).
if [ "$(grep -oE '"[^"]+"' <<<"$WLIT" | wc -l)" -eq 1 ]; then
  pass "P3 whitelist holds exactly one signal"
else
  fail_check "P3 whitelist holds more than one signal"
fi

if grep -Fq '"meta-task"' <<<"$WLIT" || grep -Fq '"[meta-task]"' <<<"$WLIT"; then
  fail_check "N1 bare meta-task marker still in whitelist array"
else
  pass "N1 no bare meta-task marker in whitelist array"
fi

# --- N3: AGENTS.md section 9 rows ---
for name in build plan scout; do
  if grep -Fq "\`$name\`" "$AGENTS_MD"; then
    pass "N3 AGENTS.md section 9 lists \`$name\`"
  else
    fail_check "N3 AGENTS.md section 9 missing \`$name\`"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "FAIL: builtin containment gate failed." >&2
  exit 1
fi
echo "ok: builtin containment holds (DIA-260831-h3i4)"
