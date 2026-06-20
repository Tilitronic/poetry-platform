# Onboarding: Poetry Platform & AI-Assisted Development

> **Target audience:** New developers joining the team.
> **What you'll learn:** The project structure, how we work with AI (OpenCode), and how to be productive on day one.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Quick Start](#2-quick-start)
3. [The AI Assistance Architecture](#3-the-ai-assistance-architecture)
4. [The Development Workflow](#4-the-development-workflow)
5. [Reference Tables](#5-reference-tables)
6. [Where Everything Lives](#6-where-everything-lives)

---

## 1. Project Overview

A **poetry analysis platform** — a polyglot monorepo (TypeScript + Python) that:

- Provides a **CodeMirror 6 editor** for writing poetry with real-time linguistic analysis
- Detects **stress patterns** and generates **IPA transcriptions** using Web Workers
- Renders **2D/3D visualizations** of phonetic data
- Publishes poems to a **Nuxt 3 SSR platform**
- Runs **offline analytics** via a Python pipeline

**Tech stack:** pnpm workspaces, Turborepo v2, TypeScript, Vue 3 / Quasar, Python 3.11+, FastAPI

---

## 2. Quick Start

```bash
git clone <repo-url>
cd poetry-platform-monorepo
pnpm install
pnpm dev          # starts all apps in dev mode
pnpm build        # builds everything
pnpm test         # runs all tests
pnpm --filter @poetry/editor-engine test  # test a specific package
```

**OpenCode** is our AI coding assistant. Start it with:
```bash
opencode
```

Then use **Tab** to cycle between Build and Plan agents, or **Ctrl+K** for custom commands.

---

## 3. The AI Assistance Architecture

We built a **layered AI workflow** that ensures code quality, maintainability, and scientific rigor. Think of it as an onion with five layers:

```
                    ┌──────────────────────┐
                    │   LAYER 5: VALUES    │
                    │  Code Ownership      │
                    │  (§0c in AGENTS.md)  │
                    ├──────────────────────┤
                    │   LAYER 4: SPEED     │
                    │  Commands + MCP      │
                    │  (Ctrl+K shortcuts)  │
                    ├──────────────────────┤
                    │   LAYER 3: BUILD     │
                    │  Turbo Pipeline      │
                    │  (turbo.json)        │
                    ├──────────────────────┤
                    │   LAYER 2: SKILLS    │
                    │  Reusable Playbooks  │
                    │  (tdd-craftsman +    │
                    │   feature-interviewer│
                    │   test-architect)    │
                    ├──────────────────────┤
                    │   LAYER 1: AGENTS    │
                    │  Specialized Roles   │
                    │  (build / plan /     │
                    │   @test / @review)   │
                    ├──────────────────────┤
                    │   LAYER 0: CONFIG    │
                    │  Rules + Settings    │
                    │  (opencode.jsonc +   │
                    │   AGENTS.md)         │
                    └──────────────────────┘
```

### Layer 0: Configuration Files

These are the **foundation**. They tell the AI who it is and how to behave.

| File | Purpose | Who reads it |
|---|---|---|
| `opencode.jsonc` | Control panel — agents, tools, MCP servers, commands | The AI |
| `AGENTS.md` | Company handbook — rules, workflow, values | The AI |
| `architecture.md` | System design — data flow, component boundaries | Everyone |
| `turbo.json` | Build pipeline — dependency ordering | The AI + CI |

**Key principle:** `opencode.jsonc` and `AGENTS.md` are the AI's operating instructions. `architecture.md` is its design reference.

### Layer 1: Agents — Specialized AI Roles

We have **6 agents**, each with a different job and different permissions:

```
┌──────────────────────────────────────────────────┐
│              PRIMARY AGENTS                       │
│       (cycle via Tab key)                         │
│                                                   │
│   BUILD           ←── Tab ──→     PLAN            │
│   (default)                        (read-only)    │
│   • Writes code                    • Reviews code │
│   • Full edit permission           • No edit      │
│   • TDD engineer                   • Mentor       │
└──────────────────┬───────────────────────────────┘
                   │
                   │ invokes via @mention
                   ▼
┌──────────────────────────────────────────────────┐
│              SUBAGENTS                            │
│                                                   │
│  @test          @review        @docs-writer       │
│  writes tests   audits SOLID   writes .md files   │
│  never impl.    never writes   never codes        │
│                                                   │
│  @security-auditor                                 │
│  audits Python/TS for vulns                       │
└──────────────────────────────────────────────────┘
```

**Why multiple agents?** Separation of concerns. A code reviewer shouldn't have write access. A test writer should never touch implementation. Each agent is focused and restricted — this prevents the AI from cutting corners.

### Layer 2: Skills — Repeatable Step-by-Step Recipes

Skills are like **cookbook recipes** the AI follows to the letter.

| Skill | Location | What it does |
|---|---|---|
| `tdd-craftsman` | Global (`~/.config/opencode/skills/`) | Full RED → GREEN → REFACTOR cycle with scientific verification |
| `test-architect` | Global | AAA test design patterns for writing great tests |
| `feature-interviewer` | Project (`.opencode/skills/`) | 3-phase structured interview before building new features |

**Why skills instead of just telling the AI?** The AI can "forget" a step or take shortcuts. Skills are structured documents it must follow — they make the workflow repeatable and auditable.

### Layer 3: Turbo Build Pipeline

```
compile:lezer  →  build  →  test
(grammar)        (code)    (verify)
```

Turbo ensures the **build order** is correct — tests never run on stale builds, and packages are built in dependency order. This gives fast feedback.

### Layer 4: Commands & MCP (Speed Layer)

**Custom commands** (press Ctrl+K):
```
/tdd-cycle <feature>      # Full interview + TDD in one command
/test-package <name>      # Run tests for a specific package
/arch-check <path>        # Audit code against architecture standards
/code-ownership <path>    # Get maintainability score
```

**MCP servers** (live AI tool access):
```
context7   → The AI searches library docs in real-time
gh_grep    → The AI searches GitHub for code patterns
```

These give the AI **live access to current information** — its training data is frozen, but MCP lets it look up docs and real-world code.

### Layer 5: Code Ownership & Values (The Philosophy)

This is the **most important layer**. It's documented in `AGENTS.md` §0c.

**The rules:**
1. Every module has one clear owner
2. Every public API has JSDoc explaining **why** (not what)
3. No tests = unowned code — don't commit it
4. No speculative abstractions (YAGNI)
5. Architecture > cleverness
6. Every change gets a `@review` pass before commit

**The motto:** *"Write code that your future self can debug at 2 AM six months from now, after you've forgotten everything about this feature."*

---

## 4. The Development Workflow

Here's what happens step by step when you ask the AI to build something:

```
YOU: "Add heteronym resolution to the editor"

     │
     ▼
┌──────────────────────────────────────────────────────┐
│ 1. INTERVIEW PHASE                                   │
│    AI reads architecture.md silently                 │
│    AI invokes feature-interviewer skill              │
│    AI asks you 7-10 questions one at a time:         │
│      "What's in scope?"                              │
│      "What are the edge cases?"                      │
│      "What are the performance targets?"             │
│      "Which modules does this touch?"                │
│      ...                                             │
│    AI produces a structured spec document            │
│    AI waits for your confirmation                    │
└──────────────────────────────────────────────────────┘
     │
     ▼ CONFIRMED
     │
┌──────────────────────────────────────────────────────┐
│ 2. TDD CYCLE                                         │
│    AI invokes tdd-craftsman skill                    │
│                                                      │
│    RED:    AI invokes @test subagent                 │
│            @test writes failing test (AAA pattern)   │
│            vitest run → FAIL (expected!)              │
│                                                      │
│    GREEN:  AI implements minimum code to pass        │
│            vitest run → PASS                          │
│                                                      │
│    REFACTOR: AI optimizes performance                │
│              (property-based tests for algorithms)   │
│              (benchmark gates for hot paths)         │
│              vitest run → PASS                        │
│              tsc --noEmit → PASS                      │
│              eslint . → PASS                          │
└──────────────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────────┐
│ 3. REVIEW PHASE                                      │
│    AI invokes @review subagent                       │
│    @review checks: SOLID, JSDoc, test coverage       │
│    Reports maintainability score                     │
└──────────────────────────────────────────────────────┘
     │
     ▼
     COMMIT (or fix issues and repeat)
```

**Total time:** You answer ~10 questions, then the AI does the rest. The interview prevents "vibe coding" — building something that looks right but misses all the edge cases.

---

## 5. Reference Tables

### Package Status

| Package | What it does | Tests |
|---|---|---|
| `editor-engine` | CodeMirror 6 editor + Signia state + orchestrator | ✅ 91 tests |
| `data-contracts` | JSON Schema shared across all packages | 🔲 Not yet |
| `stress-lang-core` | W1 worker: lang detection + WASM stress | 🔲 Not yet |
| `phonetics-core` | W2 worker: IPA + metrics + ring buffer | 🔲 Not yet |
| `visualizer-2d` | D3 SVG (interactive + SSR template) | 🔲 Not yet |
| `visualizer-3d` | TresJS/Three.js (lazy dynamic import) | 🔲 Not yet |
| `analytics-pipeline` | Python: offline analytics (NumPy, asyncpg) | 🔲 Not yet |
| `author-studio` | Quasar 2 + Vue 3 SPA (main editor app) | 🔲 Not yet |
| `publishing-platform` | Nuxt 3 SSR (public reader — stub) | 🔲 Not yet |
| `api-server` | FastAPI (Python — not yet created) | 🔲 Not yet |

### Root Commands

| Command | What it does |
|---|---|
| `pnpm dev` | Start all apps in dev mode |
| `pnpm build` | Build everything |
| `pnpm test` | Run all tests (via turbo) |
| `pnpm lint` | Lint all code |
| `pnpm typecheck` | TypeScript type checking |
| `pnpm format` | Prettier formatting |
| `opencode` | Start AI assistant |
| `opencode agent create` | Create a new AI agent |

### OpenCode Custom Commands (Ctrl+K)

| Command | When to use |
|---|---|
| `/tdd-cycle <feature>` | You want to build something new with full discipline |
| `/test-package <name>` | You want to check if a package's tests pass |
| `/arch-check <path>` | You want to verify code follows our architecture rules |
| `/code-ownership <path>` | You want to evaluate code quality and maintainability |

---

## 6. Where Everything Lives

```
poetry-platform-monorepo/
├── opencode.jsonc              AI agent config (team-shared via git)
├── AGENTS.md                   AI rules and workflow handbook
├── architecture.md             System design reference
├── turbo.json                  Build pipeline
├── prompts/                    AI agent system prompts (editable via PRs)
├── docs/
│   ├── onboarding.md           ← You are here
│   └── ...                     (more docs as needed)
├── .opencode/
│   ├── skills/                 Project-specific AI skills
│   ├── agents/                 Project-specific AI agents
│   └── commands/               Project-specific AI commands
├── apps/
│   ├── author-studio/          Vue 3 / Quasar SPA
│   ├── publishing-platform/    Nuxt 3 SSR
│   └── api-server/             FastAPI (Python)
├── packages/
│   ├── editor-engine/          Core editor + state
│   ├── phonetics-core/         IPA + metrics workers
│   ├── stress-lang-core/       Stress detection worker
│   ├── data-contracts/         Shared JSON schemas
│   ├── visualizer-2d/          D3 visualizations
│   ├── visualizer-3d/          Three.js visualizations
│   └── analytics-pipeline/     Python analytics
└── prompts/                    Agent system prompts
```

---

## Need Help?

- **OpenCode docs:** `opencode help` or `https://opencode.ai/docs`
- **Architecture questions:** Read `architecture.md` first
- **AI not behaving?** Check `AGENTS.md` and `prompts/` — those control its behavior
- **Want to add a new agent/command?** Edit `opencode.jsonc` and send a PR

---

*Last updated: June 2026*
