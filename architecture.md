# Architecture

```
flowchart TB
    A>Raw Poem Input] --> ED

    subgraph UI ["1. Main Thread — Editor"]
        ED["CodeMirror 6 Editor
        ---
        text lives in CM6's internal Rope,
        we do NOT duplicate it in state —
        only annotations on top of the CM6 tree"]

        MP["Lezer Parser — MarkPoetry DSL
        ---
        incremental: only the changed line"]

        TR["CM6 Tree + Delta
        ---
        ChangeSet with stable token IDs
        and revision_id"]

        ED --> MP
        ED --> TR
    end

    subgraph STATE ["2. Main Thread — State"]
        MO["Orchestrator — Command Pattern
        ---
        single write point,
        compares revision_id,
        stale responses — discard,
        priority: user > markpoetry > auto.
        Sends ONE postMessage to W1,
        receives ONE consolidated payload.
        Two postMessage cycles became one"]

        ST["Signia LINE Atoms
        ---
        NOT a linked list — Map + Order Array:
        linesMap: Map LineId to LineAtom
        lineOrder: string[]  ← array of IDs
        ───────────────────────────
        Inserting a line via Enter:
        splice in lineOrder — O(1) for
        an array of ~100 poem lines,
        plus one entry in the Map.
        Signia tracks only lineOrder,
        not internal atom references.
        No cascading.
        ───────────────────────────
        LineAtom:
          lineId: string
          tokens: IToken[]
            text, lang,
            stressIdx: number | null,
            stressSource: user|auto|ml|heteronym,
            isHeteronym: boolean,
            stressVariants: number[],
            ipa: string,
            syllables: string[]"]

        MO -->|"Single Write"| ST
        ST -.->|"Decorations:
        green  = auto (dictionary)
        blue   = ml (LightGBM)
        yellow = heteronym
        underline = user override"| ED
    end

    TR --> MO
    MP -->|"MarkPoetry command"| MO
    UO>User Overrides
    ---
    language change, stress change,
    heteronym variant selection] -->|"SetLang / SetStress /
    ResolveHeteronym"| MO
    MD>Metadata] --> MO

    ST <-->|"delta sync"| DB[("IndexedDB")]

    subgraph WORKERS ["3. Background Workers — internal pipeline without main thread"]

        MC["MessageChannel
        ---
        direct channel W1 → W2.
        W1 and W2 communicate with each other
        without main thread involvement.
        The main thread is NOT a mediator"]

        subgraph W1 ["Step 1 — Stress and Lang Worker"]
            LD["JS Lang Detector
            ---
            eld or tinyld"]
            WO["WASM Stress Orchestrator"]
            FST[("Rust FST Index
            ---
            stressIdx, isHeteronym, variants[]")]
            ML[("LightGBM ONNX
            ---
            OOV words")]

            LD -->|"Lang ISO"| WO
            FST --> WO
            ML --> WO
        end

        subgraph W2 ["Step 2 — Phonetics and Metrics Worker"]
            RB["Ring Buffer — initialized ONCE
            ---
            fixed Int16Array and Uint32Array
            in the W2 worker heap.
            IP writes via mutation into the existing array.
            AN reads by reference.
            Zero allocations per character inside W2.
            Transferable only for the final
            result emitted out of the worker"]

            PA[("ProtoBuf Phonetic Atlas")]

            IP["IPA Engine
            ---
            receives stress from W1 via MessageChannel,
            writes result into Ring Buffer by mutation"]

            THROTTLE["Debounce Gate — 500ms
            ---
            for global analysis.
            Local IPA — no delay"]

            AN["Patterns Analyzer
            ---
            reads Ring Buffer by reference.
            Matrices: C-contiguous for row-wise,
            F-contiguous for column-wise.
            matrix.flags must be checked explicitly"]

            PA --> IP
            PA --> AN
            IP --> RB --> THROTTLE --> AN
        end

        W1 -->|"W1 result via MessageChannel
        directly to W2, without main thread"| MC
        MC --> IP

        AN -->|"ONE consolidated payload to MO:
        stressIdx + isHeteronym + variants
        + ipa + syllables + metrics snapshot.
        Heavy matrices — Float32Array Transferable.
        Light scalars — JSON.
        revision_id in header"| MO
    end

    MO -->|"ONE postMessage to W1:
    lineId + tokens + revision_id"| W1

    MT["Global Metrics Atom
    ---
    Signia computed atom,
    immutable snapshot.
    Matrices as ArrayBuffer,
    NOT nested JS objects"]

    AN --> MT

    ST --> VI
    MT --> VI
    DB -->|"Static Snapshot"| VI

    VI["PoetryDataContract
    ---
    JSON-safe: linesMap + lineOrder + metrics.
    stressSource=user preserved.
    contract_hash + version for OCC"]

    subgraph VIS_2D ["4A. @poetry/visualizer-2d"]
        TH>UI Thresholds]

        D3["D3 SVG Engine — Interactive
        ---
        PoetryDataContract → SVGElement.
        Does NOT call data().join() on hydration.
        Single click listener on root SVG:
        event delegation by data-token-id.
        DOM is NOT rebuilt on activation"]

        D3_SSR["SSR Template Renderer
        ---
        string template without D3 or DOM.
        Renders geometry and contours.
        All interactive elements have
        data-token-id attributes for
        seamless client hydration"]

        TH --> D3
        VI --> D3 -->|"live SVGElement"| VU
        VI --> D3_SSR -->|"SVG string with data-token-id"| SSR_OUT

        VU(["Vue 2D Grid Wrapper"])
        SSR_OUT(["SSR SVG Output"])
    end

    subgraph VIS_3D ["4B. @poetry/visualizer-3d — lazy"]
        TRES["TresJS + Three.js
        ---
        dynamic import() only on
        3D View click"]
        VI -.-> TRES --> CAN["WebGL Canvas"]
    end

    MO -->|"HTTP POST: save or publish
    ---
    FULL PoetryDataContract:
    linesMap with stressSource=user,
    contract_hash, metadata"| FA

    subgraph CLOUD ["5. Cloud — API and Database"]
        FA["FastAPI Server
        ---
        CRUD only, async/await,
        stores contract_json,
        no heavy computations"]
        AUTH["JWT Auth — Google OAuth"]
        PG[("PostgreSQL
        ---
        poems: id, user_id, raw_text,
          contract_json, contract_hash,
          processed_hash, published_at
        enriched_metrics: poem_id,
          metrics_json, contract_hash")]
        FA <--> AUTH
        FA <--> PG
    end

    subgraph BATCH ["6. Offline Analytics Pipeline"]
        CR["Cron Daemon
        ---
        WHERE contract_hash != processed_hash"]
        PY["Python Analytics Core
        ---
        reads contract_json,
        respects stressSource=user,
        NumPy with explicit C or F layout,
        ProcessPoolExecutor for CPU"]
        UOW["Unit of Work — SINGLE COMMIT
        ---
        1. metrics.upsert(poem_id,
              data, expected_hash) — OCC
        2. poems.mark_as_processed(
              poem_id, new_hash)
        If one fails — ROLLBACK both.
        No partial updates.
        No duplicate processing"]
        CR --> PY
        PG -->|"PoemRepository.get_unprocessed()"| PY
        PY --> UOW --> PG
    end

    subgraph PLATFORM ["7. Publishing Platform — Nuxt 3"]
        PS["Nuxt 3 SSR
        ---
        replaces Astro — Nuxt 3.
        You already know Vue, you know 90% of Nuxt.
        Shared components with author-studio
        via workspace packages.
        SSR for poem pages and author profile.
        nuxt generate for static pages"]
        READ>Public Reader View]
        PG --> PS
        SSR_OUT --> PS
        PS --> READ
        READ -.->|"Intersection Observer →
        event delegation D3,
        DOM is NOT rebuilt"| D3
        READ -.->|"click 3D View →
        dynamic import"| TRES
    end
```

# Repository Structure (Polyglot Monorepo Layout)

```bash
poetry-platform-monorepo/
├── apps/
│   ├── author-studio/               # UI: 1. Main Thread — Editor (QUASAR APP)
│   │   ├── src/
│   │   │   ├── layouts/             # Quasar Layouts (MainLayout.vue with side panels and toolbars)
│   │   │   ├── pages/               # Quasar Pages (EditorPage.vue, ProfileSettings.vue)
│   │   │   ├── components/          # Studio-specific Q-components (heteronym dialogs, toolbars)
│   │   │   ├── css/                 # Global styles and UI customization (quasar.variables.scss)
│   │   │   ├── router/              # Vue Router configuration under Quasar's umbrella
│   │   │   ├── storage/
│   │   │   │   └── idb.ts           # IndexedDB: delta sync and static snapshot
│   │   │   ├── workers/             # Wrappers for background computations
│   │   │   │   ├── bootstrap.ts     # MessageChannel initialization and port passing (port1 -> W1, port2 -> W2)
│   │   │   │   ├── w1-stress.ts     # Native Worker for @poetry/stress-lang-core
│   │   │   │   └── w2-phonetics.ts  # Native Worker for @poetry/phonetics-core
│   │   │   └── App.vue              # Main root Vue 3 component
│   │   ├── quasar.config.ts         # Quasar configuration core (Bundler: Vite, Plugins, Chunk splitting)
│   │   └── package.json             # Dependencies: quasar, vue, signia + workspace packages
│   │
│   ├── publishing-platform/         # PLATFORM: 7. Publishing Platform (Nuxt 3)
│   │   ├── src/
│   │   │   ├── pages/               # Nuxt 3 SSR pages for poem and profile
│   │   │   └── components/          # Shared components with author-studio (via links)
│   │   └── package.json
│   │
│   └── api-server/                  # CLOUD: 5. Cloud — API and Database
│       ├── app/
│       │   ├── api/                 # FastAPI: CRUD only, stores contract_json
│       │   ├── core/
│       │   │   └── auth.py          # JWT Auth — Google OAuth
│       │   └── db/
│       │       └── postgres.py      # Asyncpg: poems and enriched_metrics tables
│       └── pyproject.toml
│
├── packages/
│   ├── data-contracts/              # STATE: PoetryDataContract (Single Source of Truth)
│   │   ├── schemas/
│   │   │   └── contract.json        # linesMap, lineOrder, metrics, contract_hash + version (OCC)
│   │   └── package.json
│   │
│   ├── editor-engine/               # UI & STATE: 1. Editor and 2. State
│   │   ├── src/
│   │   │   ├── cm6/                 # CodeMirror 6 Editor + ChangeSet/stable token IDs
│   │   │   ├── markup-dsl/          # Lezer Parser — MarkPoetry DSL (incremental)
│   │   │   ├── state/
│   │   │   │   ├── atoms.ts         # Signia: linesMap, lineOrder (no cascading), Global Metrics
│   │   │   │   └── decorations.ts   # Annotations: green, blue, yellow, underline
│   │   │   └── orchestrator/
│   │   │       └── command-bus.ts   # Command Pattern: Single Write, revision_id comparison
│   │   └── package.json
│   │
│   ├── stress-lang-core/            # WORKERS: W1 — Stress and Lang Worker
│   │   ├── src/
│   │   │   ├── detector/            # JS Lang Detector (eld/tinyld)
│   │   │   ├── wasm-orchestrator/   # WASM Stress Orchestrator
│   │   │   └── fallback/            # LightGBM ONNX (OOV words)
│   │   ├── rust-fst/                # Rust FST Index (stressIdx, isHeteronym, variants[])
│   │   └── package.json
│   │
│   ├── phonetics-core/              # WORKERS: W2 — Phonetics and Metrics Worker
│   │   ├── src/
│   │   │   ├── memory/
│   │   │   │   └── ring-buffer.ts   # Initialized ONCE: Int16Array/Uint32Array (zero allocations)
│   │   │   ├── engine/
│   │   │   │   └── ipa.ts           # IPA Engine (receives data via MessageChannel, writes by mutation)
│   │   │   ├── analyzer/
│   │   │   │   ├── patterns.ts      # Patterns Analyzer (reads by reference, C/F-contiguous)
│   │   │   │   └── debounce.ts      # Debounce Gate (500ms)
│   │   │   └── atlas/               # ProtoBuf Phonetic Atlas
│   │   └── package.json
│   │
│   ├── visualizer-2d/               # VIS_2D: 4A. @poetry/visualizer-2d
│   │   ├── src/
│   │   │   ├── interactive/         # D3 SVG Engine (event delegation by data-token-id, no DOM rebuild)
│   │   │   └── ssr/                 # D3_SSR Template Renderer (SVG string without DOM for Nuxt)
│   │   └── package.json
│   │
│   ├── visualizer-3d/               # VIS_3D: 4B. @poetry/visualizer-3d
│   │   ├── src/                     # TresJS + Three.js (dynamic import, WebGL Canvas)
│   │   └── package.json
│   │
│   └── analytics-pipeline/          # BATCH: 6. Offline Analytics Pipeline
│       ├── src/
│       │   ├── daemon/
│       │   │   └── cron.py          # Cron Daemon (WHERE contract_hash != processed_hash)
│       │   ├── core/
│       │   │   └── numpy_calc.py    # Python Analytics Core (NumPy, ProcessPoolExecutor)
│       │   └── db/
│       │       └── uow.py           # Unit of Work — SINGLE COMMIT (metrics.upsert + mark_as_processed, OCC)
│       └── pyproject.toml
│
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

### Internal dependency map (NPM Scopes)

Now all local packages use a clear `@poetry/` prefix:

1. **`apps/author-studio`** imports:
   - `"@poetry/editor-engine": "workspace:*"` (embeds the editor).
   - `"@poetry/visualizer-2d": "workspace:*"` (renders the interactive phoneme grid).
   - `"@poetry/visualizer-3d": "workspace:*"` (optional WebGL view).

2. **`apps/publishing-platform`** imports:
   - `"@poetry/visualizer-2d": "workspace:*"` (calls `ssr-render` for instant SVG generation on the server).
   - `"@poetry/visualizer-3d": "workspace:*"` (lazy-loaded via dynamic import on the client, only if the reader clicks "Enter 3D").

3. **`packages/editor-engine`** imports:
   - `"@poetry/phonetics-core": "workspace:*"` (for sending text to transcription and linting).

4. **All visualization packages** import:
   - `"@poetry/data-contracts": "workspace:*"` (guarantees structural compatibility of JSON text/metric snapshots).

### Build pipeline configuration (`turbo.json`)

This config tells Turborepo in which sequence to compile and test code. For example, we cannot build apps until contracts are generated and Lezer grammar is compiled in the editor package.

```json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "generate:contracts": {
      "outputs": ["packages/data-contracts/typescript/**", "packages/data-contracts/python/**"]
    },
    "compile:lezer": {
      "inputs": ["packages/editor-engine/src/markup-dsl/*.grammar"],
      "outputs": ["packages/editor-engine/src/markup-dsl/*.js"]
    },
    "build": {
      "dependsOn": ["generate:contracts", "compile:lezer", "^build"],
      "outputs": ["dist/**", ".output/**", ".astro/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "inputs": ["src/**/*.ts", "tests/**/*.ts"]
    },
    "test:python": {
      "inputs": ["packages/analytics-pipeline/src/**/*.py", "apps/api-server/**/*.py"]
    }
  }
}
```

# Step 1. Initialize Turborepo and pnpm workspaces

First, create the base directory structure and configure workspaces. Open a terminal and run the following commands:

```bash
mkdir poetry-platform-monorepo
cd poetry-platform-monorepo
pnpm init
mkdir apps packages
```

Now create a `pnpm-workspace.yaml` file in the project root. This tells `pnpm` where to find our packages:

```yaml
packages:
  - 'apps/*'
  - 'packages/*'
```

Next, create a base `turbo.json` in the project root that matches your build dependency schema:

```json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "generate:contracts": {
      "outputs": ["packages/data-contracts/typescript/**", "packages/data-contracts/python/**"]
    },
    "compile:lezer": {
      "inputs": ["packages/editor-engine/src/markup-dsl/*.grammar"],
      "outputs": ["packages/editor-engine/src/markup-dsl/*.js"]
    },
    "build": {
      "dependsOn": ["generate:contracts", "compile:lezer", "^build"],
      "outputs": ["dist/**", ".output/**", ".astro/**", ".nuxt/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "inputs": ["src/**/*.ts", "tests/**/*.ts"]
    },
    "test:python": {
      "inputs": ["packages/analytics-pipeline/src/**/*.py", "apps/api-server/**/*.py"]
    }
  }
}
```

# Step 2. Scaffold the `editor-engine` package (Main Thread)

Create the structure for the package that will contain the editor, state, and orchestrator.

```bash
mkdir -p packages/editor-engine/src/{cm6,markup-dsl,orchestrator,state}
cd packages/editor-engine
pnpm init
```

Update this package's `package.json` to set the correct name and prepare exports:

```json
{
  "name": "@poetry/editor-engine",
  "version": "1.0.0",
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "dev": "tsc -w"
  },
  "dependencies": {
    "@codemirror/state": "^6.0.0",
    "@codemirror/view": "^6.0.0",
    "signia": "^2.0.0"
  }
}
```

# Step 3. Design the Orchestrator and Signia State

According to your schema, the state should not use linked lists to avoid cascading updates. Instead, we use a `Map` for isolated line atoms and an index array for ordering.

Here is the basic skeleton for `packages/editor-engine/src/state/PoetryState.ts`:

```typescript
import { atom } from 'signia'

export interface IToken {
  text: string
  lang?: string
  stressIdx: number | null
  stressSource: 'user' | 'auto' | 'ml' | 'heteronym' | null
  isHeteronym: boolean
  stressVariants: number[]
  ipa: string
  syllables: string[]
}

export interface LineAtomData {
  lineId: string
  tokens: IToken[]
}

// 1. Array of line identifiers (for display ordering)
export const lineOrderAtom = atom<string[]>('lineOrder', [])

// 2. Dictionary of isolated line atoms
export const linesMap = new Map<string, ReturnType<typeof atom<LineAtomData>>>()

// Helper to create or retrieve a specific line atom
export function getOrCreateLineAtom(lineId: string, initialData: LineAtomData) {
  if (!linesMap.has(lineId)) {
    linesMap.set(lineId, atom(`line-${lineId}`, initialData))
  }
  return linesMap.get(lineId)!
}
```

Next, define the `Orchestrator` (`packages/editor-engine/src/orchestrator/Orchestrator.ts`), which will be the single write point and manage `revision_id`:

```typescript
import { lineOrderAtom, getOrCreateLineAtom, LineAtomData } from '../state/PoetryState'

export class Orchestrator {
  private currentRevision = 0

  // Increment revision on every CM6 change
  public bumpRevision(): number {
    return ++this.currentRevision
  }

  // Handle consolidated result from Worker W2
  public applyWorkerPayload(payload: {
    revisionId: number
    lineId: string
    updatedTokens: any[]
  }) {
    // Discard stale responses
    if (payload.revisionId < this.currentRevision) {
      console.warn('Discarded stale worker payload', payload.revisionId)
      return
    }

    const lineAtom = getOrCreateLineAtom(payload.lineId, { lineId: payload.lineId, tokens: [] })

    // Single write to the specific atom
    lineAtom.set({
      lineId: payload.lineId,
      tokens: payload.updatedTokens
    })
  }

  // User command (User Overrides) — highest priority
  public setUserOverride(lineId: string, tokenIdx: number, newStress: number) {
    const lineAtom = getOrCreateLineAtom(lineId, { lineId, tokens: [] })
    const currentData = lineAtom.value

    const newTokens = [...currentData.tokens]
    if (newTokens[tokenIdx]) {
      newTokens[tokenIdx].stressIdx = newStress
      newTokens[tokenIdx].stressSource = 'user'
    }

    lineAtom.set({ ...currentData, tokens: newTokens })

    // After manual override, an event must be dispatched to recalculate IPA
  }
}
```
