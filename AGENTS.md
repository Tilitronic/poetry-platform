# Poetry Platform Monorepo — AGENTS.md

> **Primary design reference:** `architecture.md` (in this directory) — always consult it before designing or modifying any component.

---

## 0. TDD Mandate (Non-Negotiable Workflow)

This project follows **scientific-grade TDD (RED-GREEN-REFACTOR)** for all code. No exceptions.

### Before writing any implementation code, you MUST:

0. **If this is a NEW FEATURE** (not a refactor/bugfix): Invoke the `feature-interviewer` skill first to interview the developer and produce a spec. Do NOT skip to step 1 until the spec is confirmed. (See §0a below.)
1. **Invoke the `tdd-craftsman` skill** — it contains the full RED-GREEN-REFACTOR workflow, AAA test patterns, isolation rules, and performance constraints.
2. **Invoke the `test-architect` skill** when designing or scaffolding test suites — it enforces AAA methodology, granular assertions, and descriptive naming.
3. **Write the failing test first (RED)** — never write implementation before the test exists.
4. **Implement the minimum code to pass (GREEN)** — no speculative features.
5. **Refactor for performance + clarity (REFACTOR)** — optimization order: hot-path allocation elimination -> lazy computation -> pre-compile constants -> quick-exit patterns -> readability.

### Verification gates (every cycle):

| Gate | Command |
|---|---|
| Tests pass | `vitest run` (or package-specific test command) |
| TypeScript checks | `tsc --noEmit` (zero errors) |
| ESLint | `eslint .` (zero errors) |
| Build | `turbo run build --filter=<package>` |

### Reference files

- `architecture.md` — full system design (components, data flow, constraints). **Read this before implementing any new module.**
- `turbo.json` — build pipeline topology (dependency ordering, outputs).

---

## 0a. Feature-Design Interview Mandate (Before Building)

When the developer asks you to **build a new feature** (not a refactor, bugfix, or trivial change), you MUST **interview them first** to gather a comprehensive specification before writing any code. Do NOT skip to RED phase until the spec is complete.

### Interview questions you must ask (adapt to the feature):

1. **Scope**: What exactly should this feature do? What is explicitly out of scope?
2. **Boundary conditions**: What are the edge cases? What happens on empty input, invalid data, max values?
3. **Performance constraints**: Any latency targets, memory limits, or hot-path requirements?
4. **Integration points**: Which existing modules/packages does this touch? What's the data flow?
5. **Error states**: What failure modes exist? How should each be handled (silent, warn, throw)?
6. **Observability**: Do we need logging, metrics, or tracing for this feature?

### How to conduct the interview:

1. **Invoke the `feature-interviewer` skill** (at `.opencode/skills/feature-interviewer/SKILL.md`) which contains the complete structured interview template with 10 questions and spec format.
2. Present the questions to the developer **one at a time** — don't dump everything at once.
3. After collecting all answers, **summarize the spec** for confirmation before proceeding.
4. Only after the developer confirms the spec, begin the TDD cycle.

If the developer says "just build it" or "no need for interview", add a brief note: *"Skipping feature interview — proceeding directly to TDD."*

---

## 0b. SOLID Architecture & Design Mandate

All code in this project MUST follow SOLID principles and the architectural patterns defined in `architecture.md`.

### SOLID enforcement:

| Principle | How we enforce it |
|---|---|
| **S**ingle Responsibility | Every class/module has exactly one reason to change. If a module has multiple responsibilities, split it. |
| **O**pen/Closed | Extend behavior via composition/DI, not by modifying existing code. Prefer strategy pattern over if-else chains. |
| **L**iskov Substitution | Subtypes must be substitutable for their base types. No unexpected side effects in overrides. |
| **I**nterface Segregation | Keep interfaces small and focused. A worker interface should not expose UI methods. |
| **D**ependency Inversion | Depend on abstractions, not concretions. Use DI for all cross-module dependencies. No `new` inside business logic. |

### Project-specific architectural rules:

- **Orchestrator** is the single write point. State mutations only go through it.
- **Workers** (W1, W2) communicate via MessageChannel — main thread is NOT a mediator.
- **Signia atoms** use `Map<lineId, LineAtom>` + `string[]` for order (avoid linked lists to prevent cascading updates).
- **Data contracts** use OCC (`contract_hash` + `version`) — never mutate shared state without version check.
- **Python packages** (analytics-pipeline, api-server) follow the same SOLID principles using abstract base classes and dependency injection.

---

## 0c. Code Ownership & Maintainability Mandate

This project prioritizes **long-term code ownership** over short-term velocity. Every piece of code must be maintainable by any team member, not just its original author.

### Ownership rules:

| Rule | Enforcement |
|---|---|
| **Single author, single responsibility** | Every module has exactly one owner (one `@module` JSDoc tag). If a module grows beyond one responsibility, split it with a new owner. |
| **Public API = documented contract** | Every exported function/class must have JSDoc/TSDoc explaining WHY it exists, the contract (pre/post conditions), and any side effects. The WHAT is obvious from the code. |
| **Tests are part of ownership** | No module is considered "owned" until it has passing tests covering happy path + edge cases + error states. Code without tests is unowned — do not commit it without a clear owner. |
| **No speculative generality** | Do not add abstractions, hooks, or configuration knobs for use cases that do not exist yet. YAGNI (You Aren't Gonna Need It). When the need arises, refactor then. |
| **Architecture over cleverness** | A simple solution following architecture.md beats a clever solution that violates SOLID. If you see a clever trick, ask: "Is this maintainable in 6 months by someone else?" |
| **Every PR is a code review opportunity** | Before committing, run the `@review` subagent or `/arch-check` command to check for SOLID violations, dead code, and missing tests. |

### What "code ownership" means in practice:

When you write code, imagine the person who will debug it at 2 AM six months from now. That person is you, but you've forgotten everything about this feature. Write code that your future self (or a new team member) can understand, test, and modify without fear.

---

## Available custom commands (Ctrl+K in TUI)

| Command | What it does |
|---|---|
| `/tdd-cycle <feature>` | Full TDD cycle: interview → RED → GREEN → REFACTOR → verify |
| `/test-package <name>` | Run verbose tests for a package (e.g. `editor-engine`) |
| `/arch-check <path>` | Audit code against architecture.md + SOLID |
| `/code-ownership <path>` | Evaluate maintainability score + improvement recommendations |

## Available MCP servers

| Server | What it does | When to use |
|---|---|---|
| `context7` | Searches library docs in real-time | Unsure about an API (NumPy, ProtoBuf, Three.js) |
| `gh_grep` | Searches GitHub for code patterns | Need reference implementations |

---

## Dev commands (root)

| Command | What it runs |
|---|---|
| `pnpm dev` | `turbo run dev` — all apps in dev mode |
| `pnpm build` | `turbo run build` |
| `pnpm lint` | `turbo run lint` |
| `pnpm typecheck` | `turbo run typecheck` |
| `pnpm test` | `turbo test` — runs all package tests via turbo (dependsOn build) |
| `pnpm format` | `prettier --write ...` (direct, not through turbo) |
| `pnpm clean` | `turbo run clean` |

Run from a package/app dir to scope: `pnpm exec turbo run lint --filter=@poetry/editor-engine`

## Monorepo setup

- **pnpm** v10.33.0, workspaces in `apps/*`, `packages/*`
- `.npmrc` has `shamefully-hoist=true`
- **Turborepo** v2 for task orchestration (`turbo.json`)
- Local packages use `workspace:*` protocol, scoped as `@poetry/*`
- `postinstall` in author-studio runs `quasar prepare`

## Structure

```
apps/
  author-studio/          Quasar 2 + Vue 3 SPA (main editor)
  publishing-platform/    Nuxt 3 SSR (public reader) — stub
  api-server/             FastAPI (Python 3.11+)
packages/
  data-contracts/         JSON Schema (PoetryDataContract) — shared by all
  editor-engine/          CodeMirror 6 + Signia state + orchestrator
  stress-lang-core/       W1 worker: lang detection + WASM stress
  phonetics-core/         W2 worker: IPA + metrics
  visualizer-2d/          D3 SVG (interactive + SSR template)
  visualizer-3d/          TresJS/Three.js (lazy dynamic import)
  analytics-pipeline/     Python offline analytics (asyncpg, pydantic)
```

## Turbo pipeline quirks

- `build` depends on `compile:lezer` (Lezer grammar to JS) and `^build` (upstream packages first)
- `compile:lezer` only runs when `*.grammar` files in editor-engine change
- `build` outputs: `dist/**`, `.quasar/**`, `dist/spa/**`
- `dev` is `persistent: true, cache: false`

## Code conventions

- **TypeScript**: `type: "module"` everywhere, `module: "Preserve"`, `moduleResolution: "Bundler"`, `noEmit: true`
- **ESLint**: flat config. `eslint.base.config.js` is shared; each app/package has its own `eslint.config.js` that extends it. Python directories are ignored in the base config.
- **Prettier**: `singleQuote: true`, `printWidth: 100`
- **EditorConfig** for `*.{js,jsx,mjs,cjs,ts,tsx,vue}`: 2-space indent, LF, UTF-8
- **Imports**: `@typescript-eslint/consistent-type-imports` enforced (`prefer: "type-imports"`)
- **Python**: `requires-python >=3.11`, `asyncio_mode = "auto"` in pytest

## Architecture (key design points)

See `architecture.md` for the full design. See §0b above for SOLID enforcement rules. Key principles:

- **State**: Signia atoms — `Map<lineId, LineAtom>` + `string[]` for order (NOT linked list, avoids cascading updates)
- **Orchestrator** is the single write point (Single Responsibility + Dependency Inversion); compares `revision_id` to discard stale worker responses
- **Workers**: W1 (stress/lang) -> MessageChannel -> W2 (phonetics/metrics) — main thread is NOT a mediator (Interface Segregation)
- **W2** uses a fixed ring buffer (`Int16Array` + `Uint32Array`) allocated once; zero allocations per character
- **Priority**: user > markpoetry > auto
- **OCC** via `contract_hash` + `version` in `PoetryDataContract`
- **visualizer-2d** has dual entry: `exports.browser` (interactive D3) and `exports.node` (SSR string template)
- **analytics-pipeline** + **api-server** are Python; they have no TypeScript ESLint coverage

## Current state

Working packages with actual implementation:

| Package | Status | Tests |
|---|---|---|
| `editor-engine` | Working formatter filter (`opusFormattingFilter.ts`) | `opusFormattingFilter.test.ts` (Vitest) |
| `data-contracts` | Schema defined | Not yet |
| `stress-lang-core` | In progress | Not yet |
| `phonetics-core` | In progress (ring buffer, IPA engine, patterns) | Not yet |
| `visualizer-2d` | SSR + interactive entry points | Not yet |
| `visualizer-3d` | Stub (`export {}`) | Not yet |
| `analytics-pipeline` (Python) | UoW, cron, numpy calc stubs | Not yet |
| `author-studio` (app) | Workers, stores, router scaffolded | Not yet |
| `publishing-platform` (app) | Stub | Not yet |
| `api-server` (Python) | Not yet created | Not yet |

## Testing setup

**TypeScript packages**: Vitest is the test runner.

| Package | Config | Run command |
|---|---|---|
| `editor-engine` | `vitest.config.ts` (node env, `src/**/*.test.ts`) | `pnpm --filter @poetry/editor-engine test` |

**Python packages**: pytest with `asyncio_mode = "auto"`.

- `pnpm test` runs `turbo test` — executes each package's `test` script via turbo with proper dependency ordering (dependsOn build).
- The `turbo.json` test task caches test outputs for fast re-runs.
- To add tests to a new package: install `vitest`, create `vitest.config.ts` matching `editor-engine`'s config, add `"test": "vitest run"` to `package.json`.

### Property-based testing

For numerical algorithms (IPA conversion, stress detection, matrix operations, ring buffer logic),
use `fast-check` to verify mathematical invariants across a wide range of random inputs.

Install:
```bash
pnpm add -D @fast-check/vitest
```

Pattern (from `tdd-craftsman` skill — §3a Scientific Code Verification):
```typescript
import fc from 'fast-check';

it('IPA conversion is idempotent', () => {
  fc.assert(
    fc.property(fc.string(), (input) => {
      fc.pre(isValidInput(input));
      const once = toIPA(input);
      const twice = toIPA(once);
      expect(once).toBe(twice);
    })
  );
});
```

### Benchmark regression testing

For hot-path code (ring buffer, formatting filter, parser), add `vitest bench` tests
with threshold enforcement in `vitest.config.ts`:

```typescript
export default defineConfig({
  test: {
    benchmark: {
      threshold: { min: 0, max: 0.001 }, // Fail if > 1μs
    },
  },
});
```

### Adding tests to a package (boilerplate)

Each TS package should mirror the `editor-engine` pattern:

1. `pnpm add -D vitest @fast-check/vitest`
2. `vitest.config.ts`:
   ```ts
   import { defineConfig } from 'vitest/config';
   export default defineConfig({
     test: {
       include: ['src/**/*.test.ts'],
       environment: 'node',
       benchmark: { threshold: { min: 0, max: 0.001 } }, // hot-path perf gate
     },
   });
   ```
3. `package.json` script: `"test": "vitest run"`
4. `turbo.json` task: already configured (test depends on build).
