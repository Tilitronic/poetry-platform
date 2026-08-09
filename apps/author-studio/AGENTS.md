# author-studio — Agent Instructions

The main editor application. Quasar 2 + Vue 3 SPA (Vite 8, TypeScript strict) that hosts
the CodeMirror 6 editor, real-time phonetic analysis via Web Workers, and 2D/3D
visualizations. Consumes six workspace packages: `@poetry/editor-engine`,
`@poetry/stress-lang-core`, `@poetry/phonetics-core`, `@poetry/visualizer-2d`,
`@poetry/visualizer-3d`, `@poetry/data-contracts`.

This is the only package in the monorepo with a `dev` script. It is the primary
integration surface where workspace packages meet the browser.

## Commands

```bash
pnpm --filter author-studio dev          # quasar dev (HMR, baseline-widely-available)
pnpm --filter author-studio build        # quasar build → dist/spa/**
pnpm --filter author-studio lint         # eslint . (flat config, extends repo base)
pnpm --filter author-studio typecheck    # vue-tsc --noEmit (strict)
pnpm --filter author-studio format       # prettier --write
pnpm --filter author-studio test         # ⚠ not yet implemented (exit 0)
```

From the repo root: `turbo run dev --filter=author-studio` (persistent, no cache).

## Source Layout

```
src/
├── App.vue                  # Root — <router-view /> only
├── layouts/MainLayout.vue   # Orchestrator instantiation; 50/50 editor ↔ visualizer split
├── pages/                   # IndexPage (→ MainLayout), ErrorNotFound
├── components/
│   ├── OpusTextEditor/      # Wraps Orchestrator + OpusEditorView from @poetry/editor-engine
│   └── VisualizerContainer/ # 2D tab (D3 SVG, immediate) + 3D tab (TresJS, dynamic import)
├── workers/
│   ├── bootstrap.ts         # MessageChannel init, port1 → W1, port2 → W2
│   ├── w1-stress.ts         # Thin wrapper around @poetry/stress-lang-core
│   └── w2-phonetics.ts      # Thin wrapper around @poetry/phonetics-core
├── stores/                  # Pinia (createPinia in index.ts)
├── router/                  # Hash mode (quasar.config.ts:47)
├── boot/                    # i18n.ts (vue-i18n 11, composition API)
├── i18n/                    # en-US locale
└── css/app.scss             # Global styles + quasar.variables.scss
```

## Architectural Constraints

These are non-negotiable rules from `architecture.md` that apply to every change in this package.

### 1. The main thread never blocks

Anything that takes measurable time (parsing, stress resolution, phonetic analysis)
runs in a Web Worker. The UI thread handles input, rendering, and state updates only.
[architecture.md:430]

### 2. Orchestrator is the single write point

Only the Orchestrator writes to Signia state. No Vue component, no store action, no
event handler reaches in and mutates a line atom directly. All state changes flow
through the Orchestrator's command bus.
[architecture.md:500-529]

### 3. CM6 Rope is the text source of truth

The poem's raw text lives in CodeMirror 6's internal Rope. **Do not duplicate it in
Pinia, Signia, or any other store.** Everything else (tokens, stress, IPA) is layered
on as annotations keyed by stable token IDs. Two copies of the text that must stay in
sync is the exact bug class this architecture eliminates.
[architecture.md:478-486]

### 4. Worker boundaries are thin wrappers

Files in `src/workers/` are thin adapter layers. The actual logic lives in workspace
packages (`@poetry/stress-lang-core`, `@poetry/phonetics-core`). Do not add business
logic to the worker wrapper files. W1 and W2 communicate directly via MessageChannel —
the main thread is **not** a relay between them.
[architecture.md:589-599]

### 5. Revision ordering and priority

The Orchestrator compares `revision_id` on every incoming result and discards stale
responses. Priority order: **user input > MarkPoetry command > automatic worker result**.
A user's explicit stress override is never silently clobbered by a background
recomputation.
[architecture.md:503-509]

### 6. No protobuf on the main thread

Worker results arrive as a plain TS object (scalars/metadata) plus `Transferable`
`ArrayBuffer`s (matrices). This is an in-process-adjacent boundary — adding
serialization overhead here buys nothing. Protobuf/Canonical JSON is reserved for the
Orchestrator ↔ FastAPI boundary.
[architecture.md:515-521]

### 7. Decorations are derived visual feedback

Green (auto), blue (ML), yellow (heteronym), underline (user override) are reactive
hints pushed from Signia into CM6. CM6 never owns this data. Do not store decoration
state in Pinia or local component state.
[architecture.md:559-565]

### 8. Schema decision framework

Before adding any new boundary (new package, new data format, new IPC mechanism),
consult `architecture.md` §3. The question is "what kind of boundary is this?" — not
"which schema tool do we use." Same-process TypeScript types ≠ cross-language contract
≠ static data asset.
[architecture.md:657-706]

## Design Authority

Before any code change, read in this order:

1. **`architecture.md`** — system boundaries, data flow, schema decision framework
2. **`.sdd/`** — module-level architecture decisions (see `.sdd/README.md` for index)
3. **`openspec/changes/`** — active feature specs

Design drives code. If no design document covers the module you're changing, flag the
gap before implementing.

## Coding Standards

- **Self-documenting WHY comments**: document business rules, trade-offs, and edge
  cases — not what the code does. JSDoc on all public APIs.
- **Dependency injection**: the `Orchestrator` instance is created in `MainLayout.vue`
  and passed as a prop. Do not `new Orchestrator()` inside child components — accept it
  via props or inject. (The current `OpusTextEditor.vue:13` fallback `?? new Orchestrator()`
  is a legacy convenience; new code should not add more.)
- **No global state**: each feature's state is scoped to its Signia atom or Pinia store.
- **Testability**: every module must be unit-testable in isolation. Tests are not yet
  implemented for this package — this is a known gap (see `docs/onboarding.md` package status
  table). When adding testable logic, write the test alongside it.
- **Quasar conventions**: use Quasar components (`q-*`) for UI. Configuration lives in
  `quasar.config.ts` (Vite plugins, framework config, SSR/PWA/Electron targets).

## Dependencies That Matter

| Workspace package          | Role in this app                                     |
| -------------------------- | ---------------------------------------------------- |
| `@poetry/editor-engine`    | CM6 editor, Lezer parser, Orchestrator, Signia atoms |
| `@poetry/stress-lang-core` | W1 worker logic (lang detection + WASM stress)       |
| `@poetry/phonetics-core`   | W2 worker logic (IPA + ring buffer + metrics)        |
| `@poetry/visualizer-2d`    | D3 SVG interactive + SSR template renderer           |
| `@poetry/visualizer-3d`    | TresJS/Three.js, loaded via dynamic `import()`       |
| `@poetry/data-contracts`   | PoetryDataContract protobuf schema (Canonical JSON)  |

## Known Gaps

- **No tests** — `test` script is `exit 0`. The onboarding doc (`docs/onboarding.md`) flags this.
- **Worker files are stubs** — `bootstrap.ts`, `w1-stress.ts`, `w2-phonetics.ts` contain
  only `export {};`. Worker integration is not yet wired up.
- **IndexedDB schema versioning** — no migration path defined yet for `LineAtomData`
  shape changes. See `architecture.md` §1 open question.
- **Shared component contract** — `visualizer-2d`/`visualizer-3d` are consumed by both
  this app and the publishing platform, but no semver/change-set discipline exists for
  shared UI components yet. See `architecture.md` §7 open question.
