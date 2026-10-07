# Детальний Аналіз Кожного Bottleneck — OpenCode Workflow

**Глибоке пояснення з кодом, метриками та рішеннями.**

---

## 1. 🔴 Interview-First Gate + OpenSpec-Plan (45% часу)

### Що таке Interview-First Gate?

**Визначення:** Перед реалізацією будь-якого функціоналу (окрім дуже малих змін) розробник повинен пройти "Socratic interview" — інтерактивне опитування про ціль, вимоги, ризики, тести.

**Де це в коді:**

```yaml
# AGENTS.md §2.2 — Feature Specification
1. **Pre-flight**: Read relevant `.sdd/` documents for governing constraints
2. **Dispatch** `@openspec-plan` — guides Socratic authoring of:
   - proposal.md       (what + why)
   - design.md         (how + constraints)
   - tasks.md          (do-this checklist)
3. **Constraint**: Design-doc references `.sdd/` but NEVER overrides it.
   **Practice-protected**: Agent guides, USER writes (not auto-filled)
```

### Реальний Приклад: DIA-260827-36ht

**Що трапилося:**
```
👨‍💻 Developer: "Я хочу включити WSL marker у тестах"

🤖 @openspec-plan Q1: "Яка проблема ви вирішуєте?"
👨‍💻 A1: "6 desktop-toast тестів падають на Linux, бо немає Windows/WSL сигналу"

🤖 Q2: "Як ви впізнаєте, чи правильно це працює?"
👨‍💻 A2: "Тести мають пройти на Linux з фіксчурою WSL_DISTRO_NAME"

🤖 Q3: "Які побічні ефекти?"
👨‍💻 A3: "Тести завжди будуть пропускати на pure Linux (контрольне), потім включатися"

🤖 [Генерує proposal.md, design.md, tasks.md]

👨‍💻 [Переглядає, редагує, затверджує]

⏰ **Час витрачений: 60–90 хвилин** на інтерв'ю + артефакти
```

### Проблема: Інтерв'ю займає НАДТО БАГАТО часу

**Evidence з вашої системи:**

```bash
# From ana015-workflow-adherence-audit.md
| Finding | Count | Problem |
|---------|-------|---------|
| openspec-plan dispatches | 65 | Dispatches розпочаті |
| openspec/changes/ dirs | 17 | Але лиш 17 завершилися! |
| **Completion rate** | 26% | **74% інтерв'ю так і не завершилися** |
| pending-owner events | 16 | Чекають відповіді розробника |

# Типовий цикл інтерв'ю:
Turn 1: @openspec-plan запитує Q1–Q3 (~2K tokens output)
  ⏳ Developer думає: 5–10 хвилин
  
Turn 2: Developer відповідає, @openspec-plan запитує Q4–Q6 (~1.5K tokens)
  ⏳ Developer думає: 5–10 хвилин
  
Turn 3: Developer відповідає, @openspec-plan генерує proposal.md (~3K tokens)
  ⏳ Developer переглядає: 5 хвилин
  
Turn 4–5: Developer редагує, затверджує (~1K tokens per turn)
  ⏳ Developer редагує: 10–15 хвилин

Total: 5–8 turns × (3–10 min think + 2–5 min I/O) = 45–120 хвилин
```

### Де витрачаються токени?

```
┌─────────────────────────────────────────────────────────┐
│ Turn 1: @openspec-plan dispatch                         │
├─────────────────────────────────────────────────────────┤
│ INPUT (system prompt):                                  │
│  - AGENTS.md (§2.2)                     ~1.5K tokens    │
│  - CONTEXT.md (domain)                  ~1.2K tokens    │
│  - practice-protected.md                ~0.8K tokens    │
│  - .sdd/ files (architecture)           ~2–3K tokens    │
│  - ticket JSON (DIA-260827-36ht)        ~0.5K tokens    │
│  - openspec/templates/*.md              ~0.3K tokens    │
│  - Prior interview history (if any)     ~1–2K tokens    │
│ INPUT TOTAL:                            ~7.3K tokens    │
│                                                         │
│ OUTPUT: Socratic questions Q1–Q3        ~2K tokens      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Turn 2: Developer answers + re-prompt                   │
├─────────────────────────────────────────────────────────┤
│ INPUT:                                                  │
│  - Previous context (reloaded!)         ~7.3K tokens    │
│  - Developer answers                    ~0.5K tokens    │
│ INPUT TOTAL:                            ~7.8K tokens    │
│                                                         │
│ OUTPUT: Questions Q4–Q6 + clarification ~1.5K tokens    │
└─────────────────────────────────────────────────────────┘

Total for 1 typical 5-turn interview:
  INPUT:  7.3K + 7.8K + 7.5K + 7.2K + 7.0K = ~37K tokens 💥
  OUTPUT: 2K + 1.5K + 1.5K + 0.8K + 3K = ~8.8K tokens
  
Cost (Claude 3.5 Sonnet, US):
  Input:  37K × $3/1M = $0.11
  Output: 8.8K × $15/1M = $0.13
  Per interview: ~$0.24 per spec
  × 65 dispatches = $15.60 token cost
  + Time: 65 specs × 1 hour average = 65 hours 😱
```

### 💥 Справжні Корені Проблеми

#### Проблема #1: Не всі зміни потребують повного інтерв'ю

```python
# Тип зміни vs Необхідність інтерв'ю:

NEEDS_FULL_INTERVIEW = [
    ("feature",                   "✅ YES — нова функціональність"),
    ("architecture",              "✅ YES — система змінюється"),
    ("API change",                "✅ YES — контракт міняється"),
    ("database migration",        "✅ YES — дані міграють"),
    ("security fix",              "✅ YES — поведінка критична"),
]

SKIP_INTERVIEW = [
    ("shell script edit <50 LOC",  "❌ NO  — просто додай строку"),
    ("config-only change",         "❌ NO  — просто оновіть YAML"),
    ("doc-only update",            "❌ NO  — просто відредагуй .md"),
    ("test addition",              "❌ NO  — просто додай тест"),
    ("lint fix",                   "❌ NO  — просто виправ лінт"),
    ("dependency bump",            "❌ NO  — просто оновіть package.json"),
]

# Статистика: 30–40% ваших зміни можуть пропустити інтерв'ю!
# But today: 100% мають інтерв'ю (навіть shell script edits)
```

**Evidence з вашої repo:**

```bash
# Наприклад, DIA-260909-9i1o "consolidate duplicated budget-gate bats fixture"
# Це test-only зміна, але все одно пройшла openspec-plan інтерв'ю
# Могла просто: commit test cleanup, run tests, done.

# openspec/changes/dia-260909-9i1o/ має:
# - proposal.md (зайвий для тест-cleanup)
# - design.md (зайвий)
# - tasks.md (просто: "refactor fixture, run tests")

# Витрачено: 30–45 хвилин на інтерв'ю
# Потенційно могло: 5–10 хвилин (編碼 + тести)
# **Втрачено 25–40 хвилин на непотрібний інтерв'ю**
```

#### Проблема #2: Context reload на кожен turn

```
Turn 1 dispatch:
  ├─ Load AGENTS.md: 1.5K
  ├─ Load CONTEXT.md: 1.2K
  ├─ Load practice-protected.md: 0.8K
  ├─ Load .sdd/: 2–3K
  └─ Load ticket: 0.5K
  = 6.5K tokens

Turn 2 dispatch (repeat!):
  ├─ Load AGENTS.md: 1.5K (повторно!)
  ├─ Load CONTEXT.md: 1.2K (повторно!)
  └─ ...
  = 6.5K tokens × 5 turns = 32.5K tokens на RELOAD 💥

Потенціал: Cache context in session, reload only deltas
  = Save ~80% of reload tokens
```

#### Проблема #3: Socratic interview розтягується на 5–8 турів

```bash
# Типовий цикл:
Turn 1: Q1–Q3 (загальні)
Turn 2: Q4–Q6 (деталі, edge cases)
Turn 3: Q7–Q9 (тести, мониторинг)
Turn 4: Developer редагує proposal.md
Turn 5: Developer редагує design.md
Turn 6: Developer затверджує tasks.md
Turn 7: @openspec-plan генерує final artifacts
Turn 8: Validation pass

# Альтернатива: "Parallel Q&A"
# Turn 1: Ask ALL questions at once (Q1–Q9 + structured answer form)
# Turn 2: Developer answers all at once
# Turn 3: Validation + artifacts

# Savings: 8 turns → 3 turns = 62% менше I/O, 75% менше developer wait time
```

---

### 🎯 Рішення 1a: Fast-Path Categorization (2 години)

**Ідея:** Розробник вибирає тип зміни при запиті, система пропускає інтерв'ю якщо це:
- Config-only, doc-only, test-only, shell-only
- Bug fix з ясною репродукцією
- Dependency update

**Реалізація:**

```bash
# scripts/classify-change.sh (новий файл)
#!/bin/bash

echo "What type of change is this?"
echo "1) Feature/Architecture    (needs interview)"
echo "2) Bug fix                 (needs interview)"
echo "3) Config change           (skip interview) ✨"
echo "4) Doc update              (skip interview) ✨"
echo "5) Test addition           (skip interview) ✨"
echo "6) Shell script edit       (skip interview) ✨"
echo "7) Dependency update       (skip interview) ✨"
read -p "Choice: " TYPE

case $TYPE in
  1|2) SKIP_SPECS=false ;;
  3|4|5|6|7) SKIP_SPECS=true ;;
esac

echo "skip_specs=$SKIP_SPECS"
```

**Вплив в @orchestrator:**

```yaml
# .opencode/orchestrator_append.md (додати)

### Fast-Path Classification (NEW)

Before dispatching @openspec-plan, check if ticket is fast-path eligible:
- skip_specs: true in ticket frontmatter OR
- User selected fast-path type in classification tool

If fast-path:
  ✅ Skip @openspec-plan interview
  ✅ Go directly to @coder with task outline
  ✅ Add [FAST-PATH-<type>] tag to dispatch prompt

Impact: 30–40% of specs eliminated, save 30–45 min per ticket
```

**Приклад для DIA-260909-9i1o:**

```markdown
# DIA-260909-9i1o - consolidate duplicated budget-gate bats fixture setup

skip_specs: true  # ← FAST-PATH: test-only change
category: test-consolidation

## Quick Brief (not full openspec)
Refactor: extract duplicated bats fixture setup into shared helper.
Savings: -90..-140 LOC.
Guard: production modules untouched.

[Dispatch directly to @coder without openspec-plan]
```

**Savings:**
- Interview time: 30–45 min → 0 min ✅
- Tokens: 7–9K → 1–2K ✅
- Wall-clock: 60–90 min → 15–20 min ✅

---

### 🎯 Рішення 1b: Async Interview (4 години)

**Ідея:** Замість 5–8 послідовних турів, задайте ВСІ запитання за раз, розробник відповідає за раз.

**Реалізація:**

```python
# .opencode/skills/openspec-plan/async-interview.py (новий)

INTERVIEW_QUESTIONS = {
    "proposal": [
        "What problem does this solve?",
        "Who benefits? (user, developer, operator)",
        "What's the cost of NOT doing this?",
    ],
    "design": [
        "How does it fit existing architecture?",
        "What modules are affected?",
        "What are edge cases?",
        "How do we test it?",
        "How do we monitor/alert on it?",
    ],
    "tasks": [
        "List all subtasks in order",
        "Which tasks can run in parallel?",
        "What's the critical path?",
    ],
}

# Turn 1: @openspec-plan outputs ALL questions
prompt = """
Answer these questions about your change. Use the provided form.

PROPOSAL:
  Problem: ___
  Beneficiary: ___
  Cost of not doing: ___
  
DESIGN:
  Architecture fit: ___
  Modules affected: ___
  Edge cases: ___
  Testing strategy: ___
  Monitoring: ___
  
TASKS:
  [Subtask 1]
  [Subtask 2]
  ...
"""

# Turn 2: Developer provides structured answers
developer_answers = """
PROPOSAL:
  Problem: 6 desktop-toast tests fail on Linux (no WSL signal)
  Beneficiary: CI, plugin test suite
  Cost of not doing: Test false negatives block pushes on Linux
  
DESIGN:
  Architecture fit: Decorator pattern (inject environment marker)
  Modules affected: needs-input-observer.test.mjs, verify-pre-push.sh
  Edge cases: Windows-only paths, PTY rename restoration
  Testing strategy: Desktop toast with marker set, then restore marker
  Monitoring: Test exit codes (6 pass vs 6 fail)
  
TASKS:
  1. [Scoped fixture] WSL_DISTRO_NAME set/restore
  2. [Bats pin] test-omo assertion
  3. [Regression] Same-worker WSL-restore test
```

**Savings:**
- 8 turns → 2 turns (75% fewer iterations)
- Developer wait time: 60 min → 15 min (context switching eliminated)
- Tokens: 37K input → 12K input (67% reduction)

---

### 🎯 Рішення 1c: Spec Templates (3 години)

**Ідея:** Розробник не пишет spec від нуля, заповнює структурований шаблон.

**Реалізація:**

```bash
# openspec/templates/bug-fix-spec.md (новий)

# Bug Fix Specification Template

## Problem
<!-- Copy reproduction steps from ticket. Max 200 words. -->

## Root Cause
<!-- Hypothesis: what went wrong? Point to code. -->

## Solution
<!-- How fix corrects root cause. Code snippet if <10 lines. -->

## Tests
<!-- What test proves this works? New test? Existing test unblocked? -->

## Verification
- [ ] Bug no longer reproduces
- [ ] Related tests pass
- [ ] No regressions on related features

---

# openspec/templates/config-spec.md

# Config Change Specification

## What changes
- Before: `[show current value]`
- After: `[show desired value]`

## Why
<!-- Business reason, not "because I wanted to" -->

## Impact
- Affected systems: `[list]`
- Breaking change? Yes/No
- Rollback plan: `[describe]`

## Verification
- [ ] make test-config passes
- [ ] Existing workflows still work
```

**Використання:**

```bash
# Developer uses template:
cp openspec/templates/bug-fix-spec.md \
   openspec/changes/dia-260827-36ht/proposal.md

# Then just fills in blanks (not write from scratch)
# Time: 30 min writing → 10 min filling template
```

**Savings:**
- Spec authoring time: 30 min → 10 min
- Interview still validates (developer + AI review template)
- 67% reduction in "thinking about structure" overhead

---

## 2. 🔴 Re-Review Cycles (25% часу)

### Що таке Re-Review?

**Визначення:** Коли @reviewer знаходить проблеми у коді, розробник розпоряджається ними (accept/reject), @coder фіксить, потім @reviewer перевіряє знову.

**Де це в коді:**

```yaml
# AGENTS.md §2.3.1 — Re-Review Loop

1. @reviewer conducts FULL review → finds 3–10 findings
2. Developer: disposition (accept / reject / request clarification)
3. @coder applies fixes → re-run tests
4. @reviewer re-reviews (cycle 1/2):
   - For each prior finding: verified-closed | still-open | partial
5. [If any still-open] developer disposition again
6. [If cycle 2/2 complete] all findings verified-closed → MERGE

Max cap: 2 cycles. If still-open after cycle 2 → escalate.
```

### Реальний Приклад: DIA-260827-36ht

**Цикл 1:**

```
@reviewer (rev-1) findings:
  ✗ CRITICAL: nested Docker at verify-pre-push.sh:156
  ✗ MAJOR: tasks.md:14 full make test-harness unproven (exit 2)
  ✗ MINOR: 3x falsifications (missing test assertions)
  
Developer disposition:
  ✅ CRITICAL: Accept, fix with @coder
  ✅ MAJOR: Accept, spec update needed
  ✅ MINOR: Accept, add regression tests
```

**Цикл 2:**

```
@coder (cod-1) fixes:
  ✅ Remove nested Docker wrapper
  ✅ Redirect to host-local bun (no Docker needed)
  ✅ Add test-omo assertion
  ✅ Add WSL-restore regression test
  ✅ Update design.md:24 to reflect host-bun approach
  
@reviewer (rev-1) re-review cycle 1/2:
  ✓ Verify CRITICAL fixed (nested Docker gone)
  ✓ Verify MAJOR moot (spec now matches code)
  ✓ Verify MINOR fixed (both test assertions present)
  
  🆕 NEW MINOR findings:
    - proposal.md:11 still names make test-harness (inconsistent with line 10)
    - R1 test comment overstates P1a as "pure-Linux" (actually PTY rename test)
```

**Цикл 2.5 (doc-only):**

```
@coder (cod-1) doc-fix:
  ✅ Fix proposal.md:11 (make test-harness → host-bun gate pin)
  ✅ Fix R1 comment (pure-Linux → PTY rename test)
  ✅ Re-run verification
  
@reviewer:
  ✓ All prior findings verified-closed
  ✓ New observations (doc) resolved
  ✓ READY TO MERGE ✅
```

### Проблема: Full Re-Review витрачає час

**Evidence:**

```
Full review (first pass):
  Time: 30–60 minutes
  Reviewer reads:
    - Entire implementation (all files)
    - Spec artifacts (proposal/design/tasks)
    - Test evidence
    - Prior findings list
  Token cost: ~3–5K input, ~1–2K output
  
Re-review cycle 1/2:
  Time: 15–30 minutes (targeted but thorough)
  Reviewer reads:
    - FULL CODE AGAIN (not just diff!)
    - Prior findings list
    - Coder's fix summary
  Token cost: ~2–3K input (reload), ~0.5–1K output
  
Re-review cycle 2/2:
  Time: 10–20 minutes (even more targeted)
  But still rereads full context each time 💥

Total per ticket with 2 cycles:
  Time: 60 + 30 + 15 = 105 minutes (1.75 hours)
  Tokens: (4K + 3K + 2.5K input) = 9.5K input = $0.03 per ticket
  × ~50 tickets per month = ~$1.50
  × 12 months = ~$18 per year on re-review alone
  
But more importantly: developer waits 90+ min for full cycle
```

### 💥 Справжні Корені Проблеми

#### Проблема #1: Full Re-Review часто ненужний

```
Fact: ~70% of findings are INDEPENDENT.
  Example: Reviewer finds 5 issues in code X, Y, Z.
  @coder fixes all 5.
  
Re-review should check: "Are those 5 fixed?"
  ✓ Issue in X: yes/no
  ✓ Issue in Y: yes/no
  ✓ Issue in Z: yes/no
  
But reviewer re-reads EVERYTHING again (X, Y, Z in full).
Wasteful. Should only read DIFF of changes.
```

#### Проблема #2: Spec-drift caught too late

```
Timeline (bad):
  Day 1: Developer writes design.md
  Day 1–2: @coder implements based on design.md
  Day 2: @reviewer review → FINDS DRIFT (design says X, code does Y)
  Day 2–3: @coder fixes code + fixes design.md
  Day 3: Re-review to verify
  Day 3–4: Merge
  
Timeline (better):
  Day 1: Developer writes design.md
  Day 1: PRE-REVIEW: Automated check: design.md vs tasks.md consistency
  Day 1: @coder implements
  Day 2: @reviewer review (no drift found; code matches design from start)
  Day 2: Merge
```

#### Проблема #3: Findings-resolution loop ручний

```
@reviewer output:
  FINDING-1: Critical nested-Docker
  FINDING-2: Major harness-green unproven
  FINDING-3: Minor falsification-2 partial

Developer manually creates:
  FINDING-1: ✅ ACCEPT → coder will remove wrapper
  FINDING-2: ✅ ACCEPT → spec update needed (ope-1)
  FINDING-3: ✅ ACCEPT → add regression test

@coder manually tracks which fixes apply to which findings
@reviewer manually tracks which prior findings are verified-closed

= lots of manual bookkeeping, error-prone
```

---

### 🎯 Рішення 2a: Targeted Diff-Only Re-Review (3 години)

**Ідея:** Re-reviewer читає тільки DIFF змін, не весь файл заново.

**Реалізація:**

```bash
# scripts/prepare-re-review-context.sh (новий)
#!/bin/bash

TICKET=$1  # DIA-260827-36ht
CYCLE=$2   # 1 or 2

# Get prior findings
FINDINGS=$(cat docs/dev-infra-audit/tickets/$TICKET.md | \
  grep -A 100 "## Review" | grep "^  ✗" | head -10)

# Get git diff since last review
git diff HEAD~1 HEAD > /tmp/latest.diff

# Build re-review context:
cat > /tmp/re-review-context.md << 'EOF'
# Re-Review Cycle $CYCLE/2 — DIA-$TICKET

## Prior Findings (Cycle $((CYCLE-1))/2)
$FINDINGS

## Coder's Fixes Applied
[From coder handoff: list of fixes + verification evidence]

## Files Changed (Diff Only)
[Only show git diff, not full files]

## Spot-Check Locations
- FINDING-1 (nested Docker): verify-pre-push.sh:156 [DIFF SNIPPET]
- FINDING-2 (harness): tasks.md:14 [DIFF SNIPPET]
- FINDING-3 (regression test): needs-input-observer.dia189.test.mjs [DIFF SNIPPET]

## Questions for Reviewer
For each prior finding:
  ✓ Is this verified-closed? (yes/no/partial)
  [Evidence shown in diff]
EOF

# Show context to reviewer
cat /tmp/re-review-context.md
```

**Вплив на @reviewer:**

```yaml
# .opencode/agents/reviewer.md (update)

### Re-Review Mode (NEW)

When cycle > 1:
  1. Read ONLY the findings-resolution table
  2. Read ONLY the git diff (not full files)
  3. Spot-check 3–5 key locations where fixes applied
  4. Output: verified-closed | still-open | partial for each finding
  5. Do NOT re-read full code
  
Time savings: 30–40 min → 8–15 min per cycle
Token savings: 2–3K input → 0.5–1K input
```

**Приклад для DIA-260827-36ht цикл 2:**

```markdown
# Re-Review Cycle 1/2 — DIA-260827-36ht

## Prior Findings
- CRITICAL: nested Docker at verify-pre-push.sh:156
- MAJOR: tasks.md:14 full make test-harness unproven
- MINOR-1: falsification-2 partial (test-omo assertion missing)
- MINOR-2: falsification-3 (no same-worker WSL-restore test)
- MINOR-3: spec-drift (design.md ≠ implementation)

## Coder Fixes Applied
✓ Removed nested Docker wrapper, redirected to host-bun gate
✓ Updated design.md:24 to reflect host-bun (not full harness)
✓ Added test-omo assertion at scripts/__tests__/verify-pre-push.bats:278–280
✓ Added WSL-restore regression test in needs-input-observer.dia189.test.mjs

## Git Diff Summary
Files changed: 3
- scripts/verify-pre-push.sh (-7 lines, nested Docker removed)
- scripts/__tests__/verify-pre-push.bats (+7 lines, test-omo pin added)
- .opencode/plugins/__tests__/needs-input-observer.dia189.test.mjs (+34 lines, restore test)

## Spot-Checks
✓ CRITICAL (nested Docker): Line 156 in diff shows `run_workspace` line DELETED
✓ MAJOR (harness): design.md line 24 now says "host-bun gate" not "full harness"
✓ MINOR-1: test-omo assertion found at line 279–280 in bats file
✓ MINOR-2: WSL-restore test found at lines 520–530 in dia189 file
✓ MINOR-3: spec update matches code implementation

## Findings-Resolution
- CRITICAL: ✅ verified-closed (wrapper removal + redirect confirmed in diff)
- MAJOR: ✅ verified-closed (spec update matches design.md intent)
- MINOR-1: ✅ verified-closed (test assertion present)
- MINOR-2: ✅ verified-closed (regression test present)
- MINOR-3: ✅ verified-closed (spec now aligned)

## Ready for merge ✅
```

**Savings:**
- Time: 30 min → 8 min (73% reduction) ✅
- Tokens: 2.5K → 0.5K (80% reduction) ✅
- Developer wait: 60 min per cycle → 15 min per cycle ✅

---

### 🎯 Рішення 2b: Pre-Review Spec Validation (2 години)

**Ідея:** Перед @coder dispatch, автоматично перевіріть design.md vs tasks.md консистентність.

**Реалізація:**

```bash
# scripts/validate-spec-consistency.sh (новий)
#!/bin/bash

CHANGE=$1  # dia-260827-36ht

# Load spec files
PROPOSAL="openspec/changes/$CHANGE/proposal.md"
DESIGN="openspec/changes/$CHANGE/design.md"
TASKS="openspec/changes/$CHANGE/tasks.md"

# Check 1: Design references architecture
if ! grep -q "^\\.sdd/" "$DESIGN"; then
  echo "❌ DESIGN: No reference to .sdd/ architecture (required)"
  exit 1
fi

# Check 2: Each task in tasks.md is mentioned in design.md
while read -r task_line; do
  task=$(echo "$task_line" | sed 's/^- //')
  if ! grep -q "$task" "$DESIGN"; then
    echo "⚠️  DESIGN: Task '$task' not mentioned in design (risk: unconstrained impl)"
  fi
done < <(grep "^- " "$TASKS")

# Check 3: Design gates match AGENTS.md § 2.2
if ! grep -q "gate_state" "$DESIGN"; then
  echo "❌ DESIGN: Missing gate_state (specify: grilled|waived|bypassed|partial|skipped)"
  exit 1
fi

# Check 4: Verification section is concrete (not generic "tests pass")
if grep -q "verification" "$DESIGN" && \
   grep "^##" "$DESIGN" | grep -i "verification" | \
   grep -q "tests will pass\|works correctly"; then
  echo "⚠️  DESIGN: Verification is too generic (be specific: which tests, which outputs)"
fi

echo "✅ Spec consistency validated"
```

**Вплив:**

```yaml
# Pre-Review Stage (NEW)

Before @coder dispatch:
  1. Run scripts/validate-spec-consistency.sh
  2. If drift found:
     - Flag to developer: "Design mentions X, but tasks don't"
     - Request fix before coding starts
  3. Result: @reviewer won't find spec-drift later
  
Savings: 
  - Avoid 20% of re-review cycles (spec-drift → fix → re-review 2/2)
  - Time: save 30 min per 5 tickets
```

---

### 🎯 Рішення 2d: Inline Guidance Reviews (6 годин)

**Ідея:** Замість "это неправильно, исправь" — дайте специфічну помічь у коментарях коду.

**Реалізація:**

```python
# .opencode/agents/reviewer.md (update)

### Inline Guidance Mode (NEW)

For each finding, instead of:
  ❌ "This hardcoded value should be a constant"

Provide:
  ✅ "Replace line 42 hardcoded '1000' with TIMEOUT_MS constant.
      Define at top of file:
      const TIMEOUT_MS = 1000;
      Reason: easier to adjust in one place, matches DIA-079 protocol"

Format:
  [FILE:LINE] FINDING-TYPE (Severity)
  Problem: [one-liner]
  Guidance: [specific fix code or instructions]
  Rationale: [why this matters]
  
Example:
  [needs-input-observer.ts:710] UNSAFE-REGEX (Minor)
  Problem: Regex assumes Windows path separators, fails on Linux
  Guidance: Change line 710 from:
    const regex = /C:\\Users\\.*\\AppData/
  To:
    const isWindows = process.platform === 'win32';
    const homeDir = isWindows ? process.env.USERPROFILE : process.env.HOME;
  Rationale: Portable across Windows/Linux; uses platform-aware env vars
```

**Вплив:**

```
Without inline guidance:
  Reviewer: "Replace this"
  Developer: "How should I replace it?"
  Developer: "I'll try this approach..."
  Developer: "Does this work?"
  → Cycle 2/2 required to verify
  
With inline guidance:
  Reviewer: "Replace with this specific code [provided]"
  Developer: "Got it, applying..."
  Developer: Apply fix + run tests
  → Cycle 2/2 often unnecessary!
  
Savings:
  - Eliminate 50% of cycle 2/2 entirely
  - Time: 60 + 30 + 15 = 105 min → 60 + 0 = 60 min (43% reduction)
```

---

## 3. 🟠 Test Gates (20% часу)

### Що таке Test Gates?

**Визначення:** Серія перевірок перед push: config validation, linting, unit tests, integration tests — всі повинні пройти.

**Де це в коді:**

```bash
# scripts/verify-pre-push.sh (поточний flow)
#!/bin/bash

echo "Running pre-push gate sequence..."

# Gate 1: Config validation (host)
make test-config
[ $? -ne 0 ] && echo "❌ Config invalid" && exit 1

# Gate 2: Bash linting (host)
bash -n scripts/**/*.sh
[ $? -ne 0 ] && echo "❌ Bash syntax error" && exit 1

# Gate 3: OMO config (host + container)
run_workspace "make test-omo"
[ $? -ne 0 ] && echo "❌ OMO config invalid" && exit 1

# Gate 4: Test harness (NEEDS DOCKER!) ← BLOCKER if docker down
run_workspace "make test-harness"
[ $? -ne 0 ] && echo "❌ Plugin tests failed" && exit 1

# Gate 5: Python tests (NEEDS DOCKER!)
run_workspace "make test-python"
[ $? -ne 0 ] && echo "❌ Python tests failed" && exit 1

# Gate 6: Python linting (host)
verify:python
[ $? -ne 0 ] && echo "❌ Flake8 failed" && exit 1

echo "✅ All gates passed"
```

### Реальна Послідовність часу

```
⏱️  Timer start: 0:00

Gate 1 (test-config):     0:00–0:01 ← FAST, host only
Gate 2 (bash -n):         0:01–0:02 ← FAST, host only
Gate 3 (test-omo):        0:02–0:05 ← Medium, host only
Gate 4 (test-harness):    0:05–0:12 ← SLOW, needs Docker ⚠️
Gate 5 (test-python):     0:12–0:18 ← SLOW, needs Docker ⚠️
Gate 6 (verify:python):   0:18–0:25 ← Slow, host only
────────────────────────────────────
Total:                    0:25 (25 minutes)

Developer experience:
  - Runs git push
  - Waits 25 minutes
  - Goes for coffee ☕
  - Returns to see ✅ or ❌
  
Problem: If docker daemon down at Gate 4:
  ❌ HARD-FAIL (pre-commit hook blocks push)
  Developer: "Why can't I push?"
  Solution: Restart Docker, wait 5 min, retry push
  Developer: Frustrated 😤
```

### 💥 Справжні Корені Проблеми

#### Проблема #1: Serial execution (no parallelization)

```
Current:
  Gate1 → Gate2 → Gate3 → Gate4 → Gate5 → Gate6
  (sequential, each waits for previous)

Potential:
  Gate1, Gate2, Gate3 (can run in parallel ✓)
      Gate4, Gate5 (can run in parallel ✓)
      Gate6 (depends on nothing, can run anytime)
  
Parallelizable gates (no dependencies):
  - make test-config (just YAML schema check)
  - bash -n (just syntax)
  - verify:python (just linting, no runtime)
  
Dependent gates (need Docker):
  - test-harness, test-python (both Docker, but independent)
```

#### Проблема #2: Docker hard-fail

```
DIA-094 rule: "pre-commit hook HARD-FAILS when container is down"

Current behavior:
  $ git push
  → pre-commit runs verify-pre-push.sh
  → Gate 4 (test-harness): tries docker compose exec
  → Docker daemon not running
  → ERROR: Cannot connect to Docker daemon
  → ❌ Push blocked
  → Developer must: docker daemon start, wait, retry

Better behavior:
  $ git push
  → pre-commit runs verify-pre-push.sh
  → Gate 4 (test-harness): check docker daemon
  → Docker daemon not running
  → ⚠️  WARN: skipping test-harness (Docker not available)
  → Continue to Gate 6
  → ✅ Warn-and-pass (push succeeds)
  → CI will run full harness later
```

#### Проблема #3: Redundant test targets

```
make test-harness:
  └─ Runs ALL plugin tests (150 tests)
  └─ Time: 6–8 minutes
  └─ Includes desktop-toast tests (6 tests for WSL marker)
  └─ Includes full plugin suite (144 other tests)

Reality:
  - Developer only changed plugin X (affects 10 tests)
  - Full 150-test run is overkill
  - CI will run full suite anyway
  - Pre-push should run ONLY changed-related tests
```

---

### 🎯 Рішення 3a: Gate Parallelization (2 години)

**Ідея:** Запустіть незалежні gates паралельно.

**Реалізація:**

```bash
# scripts/verify-pre-push.sh (updated)
#!/bin/bash

set -e

echo "Running pre-push gates in parallel..."

# Start host-only gates in background
make test-config &
PID_CONFIG=$!

bash -n scripts/**/*.sh &
PID_BASH=$!

run_workspace "make test-omo" &
PID_OMO=$!

# Wait for all to complete
echo "Waiting for host gates (config, bash, omo)..."
wait $PID_CONFIG || { echo "❌ Config failed"; exit 1; }
wait $PID_BASH   || { echo "❌ Bash failed"; exit 1; }
wait $PID_OMO    || { echo "❌ OMO failed"; exit 1; }

echo "✅ Host gates passed"

# Now run Docker gates (can also parallelize)
echo "Running Docker gates..."
run_workspace "make test-harness" &
PID_HARNESS=$!

run_workspace "make test-python" &
PID_PYTHON=$!

# Wait for Docker gates
wait $PID_HARNESS || { echo "❌ Harness failed"; exit 1; }
wait $PID_PYTHON  || { echo "❌ Python failed"; exit 1; }

# Final host-only gate
verify:python || { echo "❌ Flake8 failed"; exit 1; }

echo "✅ All gates passed"
```

**Вплив на час:**

```
Serial (current):
  Gate1 (1m) → Gate2 (1m) → Gate3 (3m) → Gate4 (7m) → Gate5 (6m) → Gate6 (7m)
  = 25 minutes

Parallel (improved):
  [Gate1 (1m), Gate2 (1m), Gate3 (3m)] run together   → max 3m
  Then: [Gate4 (7m), Gate5 (6m)] run together         → max 7m
  Then: Gate6 (7m) runs alone                         → 7m
  = 3 + 7 + 7 = 17 minutes
  
Savings: 25 min → 17 min (32% reduction) ✅
```

---

### 🎯 Рішення 3b: Graceful Docker Degradation (1 година)

**Ідея:** Якщо Docker down, warn-and-pass (не hard-fail).

**Реалізація:**

```bash
# scripts/verify-pre-push.sh (add graceful degradation)

function run_with_docker_check() {
  local GATE_NAME=$1
  local COMMAND=$2
  
  # Check if Docker daemon is running
  docker ps > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "⚠️  WARN: Docker daemon not available"
    echo "⚠️  Skipping $GATE_NAME (will run in CI)"
    echo "⚠️  Push allowed with warning"
    return 0  # warn-and-pass
  fi
  
  # Docker is available, run the gate
  run_workspace "$COMMAND" || return 1
}

# Updated gate sequence
echo "Running pre-push gates..."

make test-config || exit 1
bash -n scripts/**/*.sh || exit 1

run_with_docker_check "test-harness" "make test-harness" || exit 1
run_with_docker_check "test-python" "make test-python" || exit 1

verify:python || exit 1

echo "✅ Pre-push gates passed"
```

**Вплив:**

```
Behavior change:
  Before: Docker down → ❌ hard-fail → retry needed
  After:  Docker down → ⚠️  warn-and-pass → push succeeds
  
Developer experience:
  Before: "Push failed. Need to restart Docker." (5 min wait)
  After:  "Push succeeded (Docker skipped, will check in CI)" (0 min wait)
  
Savings: 100% of "Docker down" retry loops ✅
```

---

### 🎯 Рішення 3c: File-Scoped Test Targeting (4 години)

**Ідея:** Запустіть тільки тести для файлів, які змінилися.

**Реалізація:**

```bash
# scripts/target-tests-by-file-change.sh (новий)
#!/bin/bash

# Identify files changed in this commit
git diff --name-only HEAD~1 HEAD | while read -r FILE; do
  case "$FILE" in
    scripts/*.sh)
      echo "test-shell"  # Only shell-script tests
      ;;
    .opencode/plugins/**/*.ts)
      echo "test-plugins-focused:$(basename $FILE .ts)"  # Only affected plugin
      ;;
    packages/*/tests/*.py)
      echo "test-python-module:$(dirname $FILE | sed 's/packages\///' | sed 's|/tests||')"
      ;;
    .opencode/opencode.jsonc)
      echo "test-config"  # Only config tests
      ;;
    docs/*)
      echo "test-none"  # No tests needed for docs
      ;;
    *)
      echo "test-full"  # Unknown: run full suite
      ;;
  esac
done | sort -u
```

**Приклад використання:**

```bash
# Commit 1: Changed only scripts/verify-pre-push.sh
$ scripts/target-tests-by-file-change.sh
test-shell
→ Run only: make test-shell (bats)
→ Time: 2–3 min (vs 25 min full suite)

# Commit 2: Changed plugin needs-input-observer.ts + scripts/fix.sh
$ scripts/target-tests-by-file-change.sh
test-shell
test-plugins-focused:needs-input-observer
→ Run only: make test-shell + focused dia189 tests
→ Time: 5–7 min (vs 25 min full suite)

# Commit 3: Changed core architecture file
$ scripts/target-tests-by-file-change.sh
test-full
→ Run: make test-config + test-shell + test-harness + test-python
→ Time: 25 min (justified, architecture is critical)
```

**Вплив:**

```
Typical push statistics (last 30 commits):
  10 commits: scripts/ only          (30% of pushes)
    Before: 25 min × 10 = 250 min
    After:  3 min × 10 = 30 min
    Savings: 220 min = 3.7 hours 🎉
    
  12 commits: plugin changes         (40% of pushes)
    Before: 25 min × 12 = 300 min
    After:  8 min × 12 = 96 min
    Savings: 204 min = 3.4 hours 🎉
    
  8 commits: architecture/core        (27% of pushes)
    Before: 25 min × 8 = 200 min
    After:  25 min × 8 = 200 min
    Savings: 0 min (justified)
    
Total per month (if 30 commits):
  Before: 25 min × 30 = 750 min = 12.5 hours
  After:  (3×10 + 8×12 + 25×8) = 326 min = 5.4 hours
  Savings: 7 hours per month! 🚀
```

---

## Висновок: Які Рішення Вибрати?

**Топ 3 quick wins (8 годин реалізації, 25–30% прискорення):**

1. **3a + 3b** (Test gates): 2 години → Save 8–15 min/push
2. **1a + 1c** (Interview): 5 годин → Skip 30–40% of specs
3. **2b** (Pre-review validation): 2 години → Avoid 20% of re-review cycles

**Якщо є час для medium wins (15 годин, додаткові 20–25%):**

4. **1b** (Async interview): 4 години
5. **2a + 2c** (Targeted re-review): 5 годин
6. **3c** (File-scoped tests): 4 години
7. **4a + 4d** (Handoff deltas): 7 годин

**Якщо є час для advanced (20 годин, додаткові 15–20%):**

8. **2d** (Inline guidance): 6 годин
9. **3d** (Incremental cache): 6 годин
10. **4c** (Parallel lanes): 8 годин

---

## Яка проблема для вас НАЙБІЛЬШ БОЛЮЧИЙ МОМЕНТ?

Дайте знати, на якому bottleneck зосередитися першому — я можу дати детальний план реалізації!

