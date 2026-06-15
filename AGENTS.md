# Poetry Platform Monorepo — AGENTS.md

## Dev commands (root)

| Command | What it runs |
|---|---|
| `pnpm dev` | `turbo run dev` — all apps in dev mode |
| `pnpm build` | `turbo run build` |
| `pnpm lint` | `turbo run lint` |
| `pnpm typecheck` | `turbo run typecheck` |
| `pnpm test` | `turbo test` (note: no `run`) |
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

- `build` depends on `compile:lezer` (Lezer grammar → JS) and `^build` (upstream packages first)
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

## Architecture (key design points from architecture.md)

- **State**: Signia atoms — `Map<lineId, LineAtom>` + `string[]` for order (NOT linked list, avoids cascading updates)
- **Orchestrator** is the single write point; compares `revision_id` to discard stale worker responses
- **Workers**: W1 (stress/lang) → MessageChannel → W2 (phonetics/metrics) — main thread is NOT a mediator
- **W2** uses a fixed ring buffer (`Int16Array` + `Uint32Array`) allocated once; zero allocations per character
- **Priority**: user > markpoetry > auto
- **OCC** via `contract_hash` + `version` in `PoetryDataContract`
- **visualizer-2d** has dual entry: `exports.browser` (interactive D3) and `exports.node` (SSR string template)
- **analytics-pipeline** + **api-server** are Python; they have no TypeScript ESLint coverage

## Current state

Most source files are stubs (`export {}`). The repo is in early implementation — `architecture.md` is the design reference.

## Testing

- No test framework is set up yet for TypeScript packages. `pnpm test` runs `turbo test` which has no configured tasks — it resolves to each package's own `test` script.
- Python packages configure `[tool.pytest.ini_options]` with `asyncio_mode = "auto"`.
