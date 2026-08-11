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

> **Prerequisite — mise (tool version manager):** the repo pins `node` and
> `pnpm` in `.mise.toml` (node 24.18.0, pnpm 10.33.0) and the dev container
> ships `mise` as the tool manager (replaces Volta — DIA-030 closure). On a
> host shell, install mise from <https://mise.jdx.dev>, then run
> `mise activate bash` (or `mise activate zsh`) once and add it to your shell
> rc so the pinned versions resolve automatically. Inside the dev container,
> `mise` is already on PATH; `make check-tools` verifies the pins resolve.

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

Then use **Ctrl+K** for custom commands. OpenCode starts in **orchestrator** mode — the delegating agent that dispatches specialists via `@mentions` (see [Layer 1](#layer-1-agents--specialized-ai-roles)); it never edits code itself.

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
                    │  LAYER 2: SKILLS    │
                    │  Reusable Playbooks  │
                    │  (tdd-craftsman +    │
                    │   project skills in  │
                    │   .opencode/skills/) │
                    ├──────────────────────┤
                    │   LAYER 1: AGENTS    │
                    │  Specialized Roles   │
                    │  (orchestrator +     │
                    │   12 subagents)      │
                    ├──────────────────────┤
                    │   LAYER 0: CONFIG    │
                    │  Rules + Settings    │
                    │  (opencode.jsonc +   │
                    │   AGENTS.md)         │
                    └──────────────────────┘
```

### Layer 0: Configuration Files

These are the **foundation**. They tell the AI who it is and how to behave.

| File              | Purpose                                              | Who reads it |
| ----------------- | ---------------------------------------------------- | ------------ |
| `opencode.jsonc`  | Control panel — agents, tools, MCP servers, commands | The AI       |
| `AGENTS.md`       | Company handbook — rules, workflow, values           | The AI       |
| `architecture.md` | System design — data flow, component boundaries      | Everyone     |
| `turbo.json`      | Build pipeline — dependency ordering                 | The AI + CI  |

**Key principle:** `opencode.jsonc` and `AGENTS.md` are the AI's operating instructions. `architecture.md` is its design reference.

### Layer 1: Agents — Specialized AI Roles

We have **14 active agents**, each with a different job and different permissions. They are defined in `.opencode/opencode.jsonc` (the orchestrator is registered by the oh-my-opencode-slim plugin):

| Agent              | Role                                                             | Permissions                                                    |
| ------------------ | ---------------------------------------------------------------- | -------------------------------------------------------------- |
| `orchestrator`     | Default agent — delegates to specialists, never edits code       | Read-only + delegation (`task`, `question`, `wait_for_user`)   |
| `architector`      | Architecture & strategy — authors `.sdd/` docs with ADRs         | Read-only                                                      |
| `analyzer`         | Analysis reports & visualizations                                | Read-only subagent                                             |
| `reviewer`         | Two-axis review (Standards + Spec fidelity)                      | Read-only                                                      |
| `coder`            | Bounded implementation, test-first via tdd-craftsman             | Full (edit, bash, tests)                                       |
| `code-navigator`   | Fast codebase recon                                              | Subagent                                                       |
| `researcher`       | External research                                                | Subagent                                                       |
| `designer`         | UI/UX design                                                     | Subagent                                                       |
| `observer`         | Visual/media analysis                                            | Subagent                                                       |
| `explorer`         | Explore mode — thinking partner for ideas/requirements           | Subagent                                                       |
| `memory-manager`   | Knowledge persistence (`.opencode/memory/`, memory shelf)        | Subagent                                                       |
| `council`          | Multi-model consensus                                            | Read-only                                                      |
| `ai-specialist`    | OpenCode tooling best-practices research                         | Read-only subagent (curl/wget only)                            |
| `resource-manager` | Knowledge-source curation (ai-assist-sources.yaml, Tier-1 cache) | Subagent — edit scoped to `knowledge/` (curl/wget/trafilatura) |

> The `openspec-plan` lane (Socratic spec authoring via the openspec-propose skill) is also referenced throughout the workflow — see AGENTS.md §2.2.

**Why multiple agents?** Separation of concerns. A code reviewer shouldn't have write access. A test writer should never touch implementation. Each agent is focused and restricted — this prevents the AI from cutting corners.

### Layer 2: Skills — Repeatable Step-by-Step Recipes

Skills are like **cookbook recipes** the AI follows to the letter.

| Skill                     | Location                      | What it does                                                      |
| ------------------------- | ----------------------------- | ----------------------------------------------------------------- |
| `tdd-craftsman`           | Project (`.opencode/skills/`) | Full RED → GREEN → REFACTOR cycle with scientific verification    |
| `openspec-propose`        | Project (`.opencode/skills/`) | Interview-first OpenSpec change authoring (proposal/design/tasks) |
| `openspec-apply-change`   | Project (`.opencode/skills/`) | Implement tasks from an OpenSpec change                           |
| `openspec-update-change`  | Project (`.opencode/skills/`) | Revise a change's planning artifacts                              |
| `openspec-explore`        | Project (`.opencode/skills/`) | Thinking-partner mode for exploring ideas/requirements            |
| `openspec-archive-change` | Project (`.opencode/skills/`) | Archive a completed change                                        |
| `openspec-sync-specs`     | Project (`.opencode/skills/`) | Sync delta specs to main specs                                    |
| `book-rag`                | Project (`.opencode/skills/`) | Query local engineering textbooks via OpenWebUI RAG               |
| `console-charting`        | Project (`.opencode/skills/`) | Terminal charts/tables for data-driven reports                    |
| `debugging-workflow`      | Project (`.opencode/skills/`) | Language-specific debugging tools and techniques                  |
| `git-diff`                | Project (`.opencode/skills/`) | Inject current git status + diff context                          |
| `mermaid-diagramming`     | Project (`.opencode/skills/`) | Mermaid diagram best practices                                    |
| `playwright-browser`      | Project (`.opencode/skills/`) | Browser automation for acceptance/E2E tests                       |
| `simplify`                | Project (`.opencode/skills/`) | Simplifies code for clarity without changing behavior             |
| `teaching`                | Project (`.opencode/skills/`) | Pedagogical explanations (mental models, worked examples)         |

**Why skills instead of just telling the AI?** The AI can "forget" a step or take shortcuts. Skills are structured documents it must follow — they make the workflow repeatable and auditable.

> **Skill location convention (DIA-084, 2026-08-11):** this project follows a
> two-tier skill layout. Project skills live in `.opencode/skills/` (tracked in
> git — reproducible on any machine); the remaining per-user skills live in
> `~/.config/opencode/skills/` and are intentionally **non-load-bearing** for
> this repo (personal workflow tools only). Skills relevant to the project are
> pinned at project level so they resolve in CI / containers / other machines
> without this user's home directory. See
> `.opencode/skills/README.md` for the full convention, resolution order, and
> the risk outside this user home.

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

This is the **most important layer**. It's documented in `AGENTS.md` (see §1 Architectural Integrity and §2 Feature Workflow Chain).

**The rules:**

1. Every module has one clear owner
2. Every public API has JSDoc explaining **why** (not what)
3. No tests = unowned code — don't commit it
4. No speculative abstractions (YAGNI)
5. Architecture > cleverness
6. Every change gets a `@reviewer` pass before commit

**The motto:** _"Write code that your future self can debug at 2 AM six months from now, after you've forgotten everything about this feature."_

---

## 4. The Development Workflow

Here's what happens step by step when you ask the AI to build something:

```
YOU: "Add heteronym resolution to the editor"

     │
     ▼
┌──────────────────────────────────────────────────────┐
│ 1. SPEC PHASE (@openspec-plan)                       │
│    reads architecture.md + .sdd/ constraints          │
│    Socratic interview — one question at a time:       │
│      "What's in scope?"                              │
│      "What are the edge cases?"                      │
│      "What are the performance targets?"             │
│      "Which modules does this touch?"                │
│      ...                                             │
│    Authors openspec/changes/<name>/proposal.md,      │
│    design.md, tasks.md from the interview            │
│    (practice-protected: you write the substance)     │
└──────────────────────────────────────────────────────┘
     │
     ▼ CONFIRMED
     │
┌──────────────────────────────────────────────────────┐
│ 2. TDD CYCLE (@coder + tdd-craftsman)                │
│    @coder implements tasks.md as vertical slices     │
│    test-first via the tdd-craftsman skill            │
│                                                      │
│    RED:    write a failing test at the pre-agreed    │
│            seam → run → FAIL (expected!)             │
│                                                      │
│    GREEN:  implement the minimum code to pass        │
│            → run → PASS                              │
│                                                      │
│    verify gates after each slice:                    │
│              turbo run typecheck lint test           │
│              (scripts/verify-python.sh for Python)   │
└──────────────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────────┐
│ 3. REVIEW PHASE (@reviewer)                          │
│    @reviewer runs the two-axis review:               │
│      (a) Standards — SOLID, JSDoc, test coverage     │
│      (b) Spec fidelity — matches proposal/design     │
└──────────────────────────────────────────────────────┘
     │
     ▼
     COMMIT (or fix issues and repeat)
```

**Total time:** You answer the interview questions once, then `@coder` implements the slices. The interview prevents "vibe coding" — building something that looks right but misses all the edge cases.

---

## 5. Reference Tables

### Package Status

| Package               | What it does                                      | Tests       |
| --------------------- | ------------------------------------------------- | ----------- |
| `editor-engine`       | CodeMirror 6 editor + Signia state + orchestrator | ✅ 91 tests |
| `data-contracts`      | JSON Schema shared across all packages            | 🔲 Not yet  |
| `stress-lang-core`    | W1 worker: lang detection + WASM stress           | 🔲 Not yet  |
| `phonetics-core`      | W2 worker: IPA + metrics + ring buffer            | 🔲 Not yet  |
| `visualizer-2d`       | D3 SVG (interactive + SSR template)               | 🔲 Not yet  |
| `visualizer-3d`       | TresJS/Three.js (lazy dynamic import)             | 🔲 Not yet  |
| `analytics-pipeline`  | Python: offline analytics (NumPy, asyncpg)        | 🔲 Not yet  |
| `author-studio`       | Quasar 2 + Vue 3 SPA (main editor app)            | 🔲 Not yet  |
| `publishing-platform` | Nuxt 3 SSR (public reader — stub)                 | 🔲 Not yet  |
| `api-server`          | FastAPI (Python — lives in `apps/api-server`)     | 🔲 Not yet  |

### Root Commands

| Command                 | What it does               |
| ----------------------- | -------------------------- |
| `pnpm dev`              | Start all apps in dev mode |
| `pnpm build`            | Build everything           |
| `pnpm test`             | Run all tests (via turbo)  |
| `pnpm lint`             | Lint all code              |
| `pnpm typecheck`        | TypeScript type checking   |
| `pnpm format`           | Prettier formatting        |
| `opencode`              | Start AI assistant         |
| `opencode agent create` | Create a new AI agent      |

### OpenCode Custom Commands (Ctrl+K)

| Command                  | When to use                                            |
| ------------------------ | ------------------------------------------------------ |
| `/tdd-cycle <feature>`   | You want to build something new with full discipline   |
| `/test-package <name>`   | You want to check if a package's tests pass            |
| `/arch-check <path>`     | You want to verify code follows our architecture rules |
| `/code-ownership <path>` | You want to evaluate code quality and maintainability  |

---

## 6. Where Everything Lives

```
poetry-platform-monorepo/
├── opencode.jsonc              AI agent config (team-shared via git)
├── AGENTS.md                   AI rules and workflow handbook
├── architecture.md             System design reference
├── turbo.json                  Build pipeline
├── docs/
│   ├── onboarding.md           ← You are here
│   └── ...                     (more docs as needed)
├── .opencode/
│   ├── opencode.jsonc          Agent definitions, permissions, MCP, commands
│   ├── oh-my-opencode-slim.jsonc  OMO Slim plugin config (agent prompts/presets)
│   ├── agents/                 Project-specific agent prompt overrides
│   ├── commands/               Project-specific AI commands (Ctrl+K)
│   ├── skills/                 Project-specific AI skills (22)
│   ├── scripts/                Python bridge scripts (query_rag.py, query_web.py)
│   └── memory-shelf.yaml       Central index of RAG KBs, conspects, specs
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
```

---

## Need Help?

- **OpenCode docs:** `opencode help` or `https://opencode.ai/docs`
- **Architecture questions:** Read `architecture.md` first
- **AI not behaving?** Check `AGENTS.md` and `.opencode/opencode.jsonc` — those control its behavior
- **Want to add a new agent/command?** Edit `.opencode/opencode.jsonc` and send a PR

---

_Last updated: August 2026_
