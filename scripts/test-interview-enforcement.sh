#!/usr/bin/env bash
# Validates the interview-first spec-authoring enforcement changes:
#   1. OMO presets (promo/openai-first-cost-balanced) deny openspec-propose to the boss
#      orchestrator via the skills denylist (['*', '!openspec-propose']).
#   2. Banned "one-step" / momentum phrases are gone from the openspec-propose
#      skill and the /opsx-* commands.
#   3. The openspec-propose skill leads with interview-first language.
#   4. No tdd-cycle / test-package direct-coder command blocks in opencode.jsonc
#      (DIA-260831-h3i4 F2 containment).
#   5. The boss fast-path opt-in gate exists in orchestrator_append.md (the live
#      prompt file; boss_append.md was deleted as a dead duplicate - DIA-160).
# Run from the repo root: bash scripts/test-interview-enforcement.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OMO="$ROOT/.opencode/oh-my-opencode-slim.jsonc"
OPENCODE="$ROOT/.opencode/opencode.jsonc"
SKILL="$ROOT/.opencode/skills/openspec-propose/SKILL.md"
CMD_PROPOSE="$ROOT/.opencode/commands/opsx-propose.md"
CMD_NEW="$ROOT/.opencode/commands/opsx-new.md"
CMD_CONTINUE="$ROOT/.opencode/commands/opsx-continue.md"
BOSS_APPEND="$ROOT/.opencode/oh-my-opencode-slim/orchestrator_append.md"

FAILURES=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

# ---------------------------------------------------------------------------
# Check 1: OMO presets orchestrator.skills deny openspec-propose
# ---------------------------------------------------------------------------
if python3 - "$OMO" <<'PYEOF'
import json
import sys


def strip_jsonc(text):
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                i += 1
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


with open(sys.argv[1]) as f:
    data = json.loads(strip_jsonc(f.read()))
for preset in ('promo', 'openai-first-cost-balanced'):
    skills = data['presets'][preset]['orchestrator']['skills']
    if '!openspec-propose' not in skills:
        print(f"  {preset} orchestrator.skills missing '!openspec-propose': {skills}", file=sys.stderr)
        sys.exit(1)
PYEOF
then
    pass "Check 1: OMO presets (promo/openai-first-cost-balanced) orchestrator.skills contain '!openspec-propose'"
else
    fail "Check 1: OMO presets (promo/openai-first-cost-balanced) orchestrator.skills contain '!openspec-propose'"
fi

# ---------------------------------------------------------------------------
# Check 2: banned phrases absent from skill + /opsx-* commands
# ---------------------------------------------------------------------------
BANNED=("generated in one step" "all artifacts in one step" "in one pass" "prefer making reasonable decisions to keep momentum")
check2_ok=1
for phrase in "${BANNED[@]}"; do
    for file in "$SKILL" "$CMD_PROPOSE" "$CMD_NEW" "$CMD_CONTINUE"; do
        if grep -Fq "$phrase" "$file"; then
            echo "  banned phrase '$phrase' found in $file" >&2
            check2_ok=0
        fi
    done
done
if [ "$check2_ok" -eq 1 ]; then
    pass "Check 2: banned one-step/momentum phrases absent from skill + /opsx-* commands"
else
    fail "Check 2: banned one-step/momentum phrases absent from skill + /opsx-* commands"
fi

# ---------------------------------------------------------------------------
# Check 3: interview-first phrases present in the openspec-propose skill
# ---------------------------------------------------------------------------
check3_ok=1
for phrase in "Socratic interview" "interview-first" "transcript"; do
    if ! grep -Fq "$phrase" "$SKILL"; then
        echo "  missing interview-first phrase '$phrase' in $SKILL" >&2
        check3_ok=0
    fi
done
if [ "$check3_ok" -eq 1 ]; then
    pass "Check 3: interview-first phrases ('Socratic interview'/'interview-first'/'transcript') present in SKILL.md"
else
    fail "Check 3: interview-first phrases ('Socratic interview'/'interview-first'/'transcript') present in SKILL.md"
fi

# ---------------------------------------------------------------------------
# Check 4 (DIA-260831-h3i4 F2): direct-coder TDD/test shortcuts are GONE from
# opencode.jsonc. tdd-cycle + test-package carried agent:coder bindings that
# execute as coder with no task() dispatch, so the DIA-217 ticket gate never
# fired. TDD now flows through @coder lane dispatch (with ticket) via the
# tdd-craftsman skill; tests via make test-*. Neither block may reappear.
# ---------------------------------------------------------------------------
check4_ok=1
if grep -Fq '"tdd-cycle"' "$OPENCODE"; then
    echo "  'tdd-cycle' command block present in opencode.jsonc (direct-coder bypass)" >&2
    check4_ok=0
fi
if grep -Fq '"test-package"' "$OPENCODE"; then
    echo "  'test-package' command block present in opencode.jsonc (direct-coder bypass)" >&2
    check4_ok=0
fi
if [ "$check4_ok" -eq 1 ]; then
    pass "Check 4: no tdd-cycle / test-package direct-coder blocks in opencode.jsonc"
else
    fail "Check 4: no tdd-cycle / test-package direct-coder blocks in opencode.jsonc"
fi

# ---------------------------------------------------------------------------
# Check 5: boss fast-path opt-in gate present
# ---------------------------------------------------------------------------
check5_ok=1
if ! grep -Fq "fast-path approved" "$BOSS_APPEND"; then
    echo "  'fast-path approved' missing from orchestrator_append.md" >&2
    check5_ok=0
fi
if ! grep -Fq "NEVER auto-classifies" "$BOSS_APPEND"; then
    echo "  'NEVER auto-classifies' missing from orchestrator_append.md" >&2
    check5_ok=0
fi
if [ "$check5_ok" -eq 1 ]; then
    pass "Check 5: orchestrator_append.md contains fast-path opt-in gate ('fast-path approved' + 'NEVER auto-classifies')"
else
    fail "Check 5: orchestrator_append.md contains fast-path opt-in gate ('fast-path approved' + 'NEVER auto-classifies')"
fi

# ---------------------------------------------------------------------------
echo
if [ "$FAILURES" -eq 0 ]; then
    echo "All checks passed."
    exit 0
else
    echo "$FAILURES check(s) FAILED."
    exit 1
fi
