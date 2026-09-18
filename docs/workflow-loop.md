# Poetry Platform — Development Loop

## ⓪ Explore & Brainstorm

**Researcher** + **Analyzer** explore the idea with the user.

| #   | Tool                  | Type  | Purpose                      | Status       |
| --- | --------------------- | ----- | ---------------------------- | ------------ |
| 1   | `openspec-explore`    | Skill | Thinking partner for ideas   | ✅ ESSENTIAL |
| 2   | `code-navigator`      | Agent | Understand existing codebase | ✅ ESSENTIAL |
| 3   | `mermaid-diagramming` | Skill | Sketch system diagrams       | ✅ ESSENTIAL |

**Removed:** codemap (too expensive), clonedeps (not for exploration), researcher/explorer (broken/replaced)

## ① Plan / Architecture

**Architector** creates the plan and general architecture.

| #   | Tool                  | Type  | Purpose                                          | Status       |
| --- | --------------------- | ----- | ------------------------------------------------ | ------------ |
| 1   | `mermaid-diagramming` | Skill | Architecture diagrams (C4, sequence, flowcharts) | ✅ ESSENTIAL |
| 2   | `teaching`            | Skill | Explain WHY in ADRs (skip if <3 sentences)       | ✅ ESSENTIAL |

## ② OpenSpec

Break the idea into specific features. Write specs for each feature. Each feature is broken into concrete tasks.

> Phase ② is led by the **`@openspec-plan` AGENT** (Socratic interview → spec artifacts `proposal.md` → `design.md` → `tasks.md`). The table lists the **SKILLS** that agent — and the boss's OpenSpec cascade — uses.

| #   | Tool                      | Type  | Purpose                            | Status       |
| --- | ------------------------- | ----- | ---------------------------------- | ------------ |
| 1   | `openspec-explore`        | Skill | Explore ideas before spec creation | ✅ ESSENTIAL |
| 2   | `openspec-propose`        | Skill | Create proposal → design → tasks   | ✅ ESSENTIAL |
| 3   | `openspec-update-change`  | Skill | Fix spec issues found in review    | ✅ ESSENTIAL |
| 4   | `openspec-sync-specs`     | Skill | Sync delta specs → main specs      | ✅ ESSENTIAL |
| 5   | `openspec-archive-change` | Skill | Archive completed change           | ✅ ESSENTIAL |
| 6   | `openspec-apply-change`   | Skill | Implement tasks from the change    | ✅ ESSENTIAL |

**Removed:** `writing-skills` (not for spec auth).

## ③ TDD

### Red

**<b>Coder</b> (Mode 1)** writes tests. They must be **red** (failing).

| Tool                 | Type  | Purpose                           | Status       | Architector Review                                                                                                                                                                                    |
| -------------------- | ----- | --------------------------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tdd-craftsman`      | Skill | Polyglot RED-GREEN-REFACTOR TDD   | ✅ ESSENTIAL | Хребет фази. AAA структура, per-language naming, property-based testing, RED gate, ownership protocol (practice-protected per AGENTS.md §4). Єдиний інструмент що визначає disciplined test writing   |
| `debugging-workflow` | Skill | Language-specific debugging tools | ✅ ESSENTIAL | Root cause analysis коли архітектор просить пофіксити тест-кейси (Red mode variant). 5-stage pipeline: reproduce → isolate → analyze. Для звичайного Red (написати нові тести) — тільки tdd-craftsman |

### Green

**Coder (Mode 2)** implements code. Tests become **green** (passing).

| Tool                 | Type  | Purpose                             | Status          | Architector Review                                                                                                                                                                     |
| -------------------- | ----- | ----------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tdd-craftsman`      | Skill | Polyglot RED-GREEN-REFACTOR TDD     | ✅ ESSENTIAL    | Визначає GREEN constraints: мінімальний код, без speculative features, verification gates (test → typecheck → lint → build → ASan). Ownership checkpoint: "one-line rationale comment" |
| `teaching`           | Skill | Pedagogical explanation of patterns | 🔶 Nice-to-have | Якщо implementer не розуміє WHY. Але ownership checkpoint ("one-line rationale comment") вже покриває це — якщо не можеш написати одне речення, не розумієш достатньо                  |
| `playwright-browser` | Skill | Browser automation for E2E testing  | 🔶 Nice-to-have | Тільки для browser-based features (React, CM6 extensions). Для Python/Rust/C++ packages — ні. Per skill itself: "For unit/integration tests, use tdd-craftsman instead"                |

## ④ Review

**Reviewer** reviews the work done on **two independent axes, reported separately, never merged**:

- **Standards** — repo coding standards (architecture.md, AGENTS.md, .sdd/) plus the Fowler smell baseline (Mysterious Name, Duplicated Code, Feature Envy, Speculative Generality, …)
- **Spec** — faithful implementation of the originating OpenSpec change (proposal.md / design.md / tasks.md); if no spec exists, the Spec axis reports "no spec available" instead of guessing

| Tool                               | Type  | Purpose                     | Status            | Architector Review                                                                                                                                                        |
| ---------------------------------- | ----- | --------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `reflect`                          | Skill | Review recent work patterns | ✅ ESSENTIAL      | Для покращення самого процесу Review. Виявляє workflow-level issues (наприклад, "reviewer consistently misses type bugs"). One = code, other = process                    |
| `teaching`                         | Skill | Pedagogical feedback        | 🔶 Nice-to-have   | Pedagogical feedback для junior devs. Too verbose для senior. book-rag для верифікації, teaching для пояснення                                                            |
| `book-rag`                         | Skill | Grounded review via RAG     | 🔶 Nice-to-have   | Для верифікації чи pattern є anti-pattern. Requires textbooks loaded. Complementary до teaching                                                                           |
| 🆕 Correctness/Security/Perf tools | Skill | Bug/security/perf detection | 🆕 MISSING (HIGH) | Two-axis review не перевіряє bugs, security vulnerabilities, performance issues. Review incomplete без них. Потрібні: correctness oracle, security scanner, perf profiler |

## ⑤ Debug and Fix

One arrow in ("Yes"), one arrow out ("Back to Review"):

- **Coder** uses Mode 3 (Bugfix): debugging-workflow for root cause → tdd-craftsman RED→GREEN → git-diff for context

| Tool                 | Type  | Purpose                           | Status       | Architector Review                                                                                                                                                  |
| -------------------- | ----- | --------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tdd-craftsman`      | Skill | Polyglot RED-GREEN-REFACTOR TDD   | ✅ ESSENTIAL | Bugfix = RED→GREEN цикл. Coder → RED (fix/write failing tests) → GREEN (fix code). Skip REFACTOR unless Review explicitly flagged performance/readability           |
| `debugging-workflow` | Skill | Language-specific debugging tools | ✅ ESSENTIAL | Root cause analysis (Mode 3). Structured hypothesis→evidence loop: reproduce → isolate → analyze → fix. Essential for non-trivial bugs, skip for trivial/pinpointed |
| `git-diff`           | Skill | Inject Git status/diff context    | ✅ ESSENTIAL | Бачити написані тести, план, специфікації перед fix. Кодер має знати що reviewer reviewed і що architect спланував                                                  |

## ⑥ Persist

If no issues — **Memory Manager** writes ADR: who did what, lessons, progress, blockers. End of iteration.

| Tool                           | Type  | Purpose                          | Status          | Architector Review                                                                                          |
| ------------------------------ | ----- | -------------------------------- | --------------- | ----------------------------------------------------------------------------------------------------------- |
| 🆕 `git log`                   | —     | Commit history context           | ✅ ADDED        | Додано в process memory-manager (крок 1)                                                                    |
| 🆕 `openspec/changes/` context | —     | Planned vs. delivered comparison | ✅ ADDED        | Додано в process memory-manager (крок 2)                                                                    |
| `git-diff`                     | Skill | Inject Git status/diff context   | ✅ ESSENTIAL    | Контекст для порівняння planned vs delivered. Memory-manager бачить що фактично змінилось перед записом ADR |
| 🆕 `openspec-archive-change`   | Skill | Archive completed change         | 🔶 Nice-to-have | Natural end-of-iteration housekeeping. Optional step 7 в memory-manager process                             |

**Висновок:** memory-manager самодостатній — зовнішні інструменти не потрібні. Потрібно оновити його внутрішній process (додати git log, openspec/changes/ reading, optional archive step).

---

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {
  'darkMode': true, 'background': '#1e1e2e',
  'primaryColor': '#2d3a5c', 'primaryTextColor': '#e0e0e0',
  'primaryBorderColor': '#5b8def', 'lineColor': '#5b8def',
  'secondaryColor': '#3d3520', 'tertiaryColor': '#2a2a36',
  'labelTextColor': '#e0e0e0'
}}}%%
flowchart TB
    subgraph Phase0["⓪ Explore & Brainstorm"]
        A([Start]) --> B
        B["<b>Researcher</b> + <b>Analyzer</b>\nexplore idea"]
    end

    subgraph Phase1["① Plan / Architecture"]
        B --> C["<b>Architector</b>\ncreates plan & architecture"]
    end

    subgraph Phase2["② OpenSpec"]
        C --> D["Break into features\n& write specs"]
    end

    subgraph TDD["③ TDD"]
        E["<b>Coder</b> (Mode 1)\nwrite tests — RED"]
        F["<b>Coder</b> (Mode 2)\nimplement code — GREEN"]
        G["<b>Coder</b> (Mode 2)\nrefactor — still GREEN"]
    end

    D --> E
    E --> F
    F --> G

    subgraph Phase4["④ Review"]
        G --> H["<b>Reviewer</b> reviews"]
    end

    H --> I{"Issues\nfound?"}

    subgraph DebugAndFix["⑤ Debug & Fix"]
        J["<b>Coder</b> (Mode 3)\ndebugging-workflow: root cause\n→ tdd-craftsman: RED→GREEN\n→ git-diff: context"]
    end

    I -->|"Yes"| DebugAndFix
    DebugAndFix -->|"Back to Review"| H

    subgraph Phase6["⑥ Persist"]
        I -->|"No issues"| L["<b>Memory Manager</b>\nADR: who did what,\nlessons, progress"]
    end

    L --> N([End iteration])

    classDef explore fill:#d4d4d4,stroke:#737373,color:#1e1e1e,stroke-width:2px
    classDef plan fill:#dbeafe,stroke:#3b82f6,color:#1e1e1e,stroke-width:2px
    classDef spec fill:#e9d5ff,stroke:#a855f7,color:#1e1e1e,stroke-width:2px
    classDef tddRed fill:#fee2e2,stroke:#ef4444,color:#1e1e1e,stroke-width:2px
    classDef tddGreen fill:#dcfce7,stroke:#22c55e,color:#1e1e1e,stroke-width:2px
    classDef tddRefactor fill:#dbeafe,stroke:#3b82f6,color:#1e1e1e,stroke-width:2px
    classDef review fill:#ffedd5,stroke:#f97316,color:#1e1e1e,stroke-width:2px
    classDef debugandfix fill:#fee2e2,stroke:#ef4444,color:#1e1e1e,stroke-width:2px
    classDef persist fill:#dcfce7,stroke:#22c55e,color:#1e1e1e,stroke-width:2px
    classDef startend fill:#0f2d1a,stroke:#22c55e,color:#e0e0e0,stroke-width:2px
    classDef decision fill:#3d2e00,stroke:#eab308,color:#e0e0e0,stroke-width:2px

    class A startend
    class B explore
    class C plan
    class D spec
    class E tddRed
    class F tddGreen
    class G tddRefactor
    class H review
    class I decision
    class J debugandfix
    class L persist
    class N startend
```
