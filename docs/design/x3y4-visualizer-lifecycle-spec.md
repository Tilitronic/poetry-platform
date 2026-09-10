# DIA-260831-x3y4 visualizer lifecycle ownership spec (DESIGN ONLY, no implementation)

Ticket: DIA-260831-x3y4 'Visualizer modules shallow lifecycle ownership'
Scope: architecture/spec ONLY. No .ts/.vue edits were made.
Worktree: /workspace/.worktrees/feature-second-session-c3d4-95fv-ezyv-x3y4
Date: 2026-09-10 (UTC)
Author role: architecture/spec lane, campaign ticket DIA-260831-x3y4

## 1. Audit sources (read-only)

- packages/visualizer-2d/src/interactive/index.ts (55 lines)
- packages/visualizer-2d/src/ssr/index.ts (7 lines)
- packages/visualizer-3d/src/index.ts (67 lines)
- apps/author-studio/src/components/VisualizerContainer/VisualizerContainer.vue (53 lines)
- packages/data-contracts/src/index.ts (13 lines, facade: runtime `contract` + type `PoetryDataContract`)
- packages/data-contracts/schemas/contract.json (19 lines, authoritative schema behind the facade)
- packages/editor-engine/src/orchestrator/Orchestrator.ts (42 lines)
- grep over packages/ for orchestrator|Orchestrator|data-contracts|ContractSnapshot|SceneModel (36 matches; zero visualizer-src imports of data-contracts)

## 2. Findings

F1. 2D takes unused whole Orchestrator.
Evidence: interactive/index.ts:8 `initInteractiveVisualizer(selector: string, _orchestrator: any)`.
The parameter is underscore-prefixed (deliberately unused) and typed `any`.
Impact: the interface leaks the whole Orchestrator (single write point, Signia state, CommandBus) to a render leaf without leverage; couples the visualizer seam to editor-engine internals and blocks isolated unit tests.

F2. 2D update() is an empty stub.
Evidence: interactive/index.ts:47-54; `update() { /* stub */ }`.
The container watches tab switches and calls `visualizer2D.update()` (VisualizerContainer.vue:48-52), which is a no-op, so re-render on data change never happens. Initial draw is a static placeholder (circle + crosshair), not contract data.

F3. VisualizerContainer.vue never calls destroy.
Evidence: VisualizerContainer.vue:30-53 imports onMounted only; no onUnmounted import, no destroy() call on unmount, no cleanup on tab switch.
`visualizer2D` is held as `any` (line 36). Remount (route change, HMR, tab panel teardown) leaves D3 DOM nodes and listeners behind; repeated mounts accumulate SVG trees.

F4. Container props pass `any` orchestrator through to both visualizers.
Evidence: VisualizerContainer.vue:34 `defineProps<{ orchestrator: any }>()`; line 24 `:orchestrator="props.orchestrator"`; line 44 passes the same `any` into initInteractiveVisualizer.
No snapshot, no selector, no revision. Both children receive the mutable whole instead of an immutable render input, violating "Orchestrator is the single write point" (visualizers must read, never write).

F5. 3D takes unused `any` orchestrator and renders placeholder, not contract data.
Evidence: visualizer-3d/src/index.ts:7 `orchestrator: { type: Object as PropType<any>, required: false }`; setup() never references props. Scene is a hardcoded wireframe icosahedron + two lights (lines 32-45). SSR 2D renderer likewise returns a hardcoded SVG string (ssr/index.ts:1-7). Neither reads linesMap/lineOrder/metrics.

F6. 3D dispose is partial; GPU resources leak on remount.
Evidence: visualizer-3d/src/index.ts:56-59 cancels RAF and calls `renderer?.dispose()` only.
Missing: geometry.dispose(), material.dispose(), scene traversal for owned resources, removal of renderer.domElement from the container div, nulling scene/camera/renderer refs. geometry/material are function-locals (lines 32-33), unreachable at unmount, so they can never be disposed without restructuring. Remount allocates a new renderer + geometry each time; old GPU buffers persist.

F7. data-contracts is declared but unused by both visualizers.
Evidence: packages/visualizer-2d/package.json:21, packages/visualizer-3d/package.json:13 declare `@poetry/data-contracts: workspace:*`; both tsconfigs map it to `../../packages/data-contracts/schemas/contract.json`. Grep shows zero imports of data-contracts in either visualizer src tree. The declared seam exists on paper only.

## 3. Design: typed contract snapshot

Derive the render input from the data-contracts module payload type
(`PoetryDataContract`, packages/data-contracts/src/index.ts:13), NOT from
`typeof` the raw contract.json schema object. Visualizers MUST NOT import
Orchestrator, and MUST NOT import schemas/contract.json directly.

```ts
// packages/visualizer-2d/src/types.ts (new, implementer creates)
import type { PoetryDataContract } from '@poetry/data-contracts';

export type ContractSnapshot = Pick<
  PoetryDataContract,
  'id' | 'version' | 'contract_hash' | 'linesMap' | 'lineOrder'
> & { metrics?: PoetryDataContract['metrics'] };
```

Rules:

- The snapshot types against the module payload type `PoetryDataContract`
  (the facade export, src/index.ts:13). Never type it as
  `typeof import('.../schemas/contract.json')`: the facade is the single
  type source so consumers cannot drift from the schema.
- `@poetry/data-contracts` MUST resolve to the module facade
  (packages/data-contracts/src/index.ts), not to schemas/contract.json.
  Implementer repoints the visualizer tsconfig mappings that currently aim
  at the JSON file (see F7) to the module.
- Snapshot is immutable (frozen at the container boundary via Object.freeze or readonly type).
- Container derives it from Orchestrator state (selector, not the whole object) and passes it down as a prop / init argument.
- `update(next: ContractSnapshot)` re-renders from the snapshot; revision check (`version` / `contract_hash`) lets visualizers skip stale frames.
- SSR signature becomes `renderVisualizerSSR(snapshot: ContractSnapshot): string` so SSR and interactive render the same data.

## 4. Design: lifecycle interface

One shared handle shape for 2D now; 3D adopts it when it is refactored out of the SFC into a setup/dispose module (recommended, not required by this ticket):

```ts
export interface VisualizerHandle {
  update: (next: ContractSnapshot) => void;
  destroy: () => void;
}
```

Contract:

- `update` is idempotent and synchronous; it diffs on contract_hash and no-ops when unchanged.
- `destroy` is idempotent, callable twice safely, and releases everything `init` acquired (DOM nodes, listeners, RAF, GPU objects).
- Container owns the handle lifetime: init onMounted, destroy onUnmounted, update on snapshot change (watch with deep:false, compare contract_hash).

## 5. Design: SceneModel dispose (3D)

Restructure visualizer-3d setup so owned GPU resources are reachable at unmount:

```ts
interface SceneModel {
  geometry: THREE.BufferGeometry[];
  materials: THREE.Material[];
  renderer: THREE.WebGLRenderer | null;
  host: HTMLElement | null;
}

function disposeSceneModel(m: SceneModel): void {
  cancelAnimationFrame(animId);
  for (const g of m.geometry) g.dispose();
  for (const mat of m.materials) {
    const withMap = mat as THREE.Material & { map?: THREE.Texture | null };
    if (withMap.map) withMap.map.dispose();
    mat.dispose();
  }
  m.renderer?.dispose();
  if (m.host && m.renderer) m.host.removeChild(m.renderer.domElement);
  m.renderer = null;
  m.host = null;
}
```

Notes:

- Traverse Alternatives considered: explicit arrays (above) vs scene.traverse dispose. Prefer explicit ownership lists; traverse risks disposing shared resources. Record choice in ticket UPDATE block.
- Keep `cancelAnimationFrame` first so no further renders race disposal.
- Null refs after dispose so double-unmount is safe.

## 6. Design: container cleanup (VisualizerContainer.vue)

- Change props to `{ snapshot: ContractSnapshot }` (remove `orchestrator: any`; derive snapshot in MainLayout or a selector, not in the container).
- Type the handle: `let visualizer2D: VisualizerHandle | null = null` (remove `any`).
- Add `onUnmounted(() => { visualizer2D?.destroy(); visualizer2D = null; })`.
- Pass snapshot into init: `initInteractiveVisualizer('#poetry-d3-viewport', props.snapshot)`.
- Replace the tab watcher body with `visualizer2D?.update(props.snapshot)`; add a snapshot watcher with contract_hash guard for live updates.
- 3D tab: pass `:snapshot` instead of `:orchestrator` once the 3D component adopts the prop (can land in a follow-up; container change must not break the async import).

## 7. Tests (implementer + separate test-author per DIA-175)

T1. Remount disposes GPU resources (3D).
Mount Visualizer3D, spy on THREE.BufferGeometry.prototype.dispose, THREE.Material.prototype.dispose, WebGLRenderer.prototype.dispose, and cancelAnimationFrame; unmount; assert each dispose spy called at least once and renderer.domElement removed from container. Second unmount asserts no throw (idempotent destroy).
T2. Remount cleans DOM (2D).
Mount VisualizerContainer (or init/destroy pair directly), assert viewport non-empty after init, call destroy, assert viewport empty; re-init asserts exactly one SVG root (no accumulation).
T3. Interface takes typed snapshot, not any.
Type-level test: `initInteractiveVisualizer(sel, snapshot)` compiles with ContractSnapshot; passing an Orchestrator instance fails typecheck (expectTypeOf / @ts-expect-error). Runtime: update with same contract_hash no-ops (render spy not called); update with new hash re-renders.
T4. SSR renders contract data.
`renderVisualizerSSR(snapshot)` output contains one node per lineOrder entry (count line-derived elements), not the fixed placeholder counts.

Test infra: vitest + vue/test-utils already in repo; THREE dispose spies need no GL context if dispose methods are stubbed before mount. No new test framework.

## 8. Out of scope

- No Orchestrator API changes; no Signia shape changes.
- No real phonetic layout algorithm; placeholder geometry replaced only by snapshot-driven node counts, not by a finished design.
- No semver/change-set discipline for shared components (known gap, separate ticket).
- No .ts/.vue edits in this spec lane; implementer lane applies sections 3-6, test-author lane writes section 7 tests first per instance separation.
