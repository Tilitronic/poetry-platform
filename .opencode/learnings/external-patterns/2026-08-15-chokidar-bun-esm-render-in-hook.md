---
date: 2026-08-15
topic: chokidar v5 (ESM-only) in the Bun plugin runtime - render-in-hook beats file watchers for derived views
source: ai-specialist phase-1 gate (DIA-155), DIA-137
ticket: DIA-155-chokidar-in-process-file-watching-harness
status: active
---

# chokidar v5 in the Bun plugin runtime: render-in-hook beats file watchers (DIA-155 Phase 1 gate findings)

## 1. FACT: the OpenCode plugin runtime is Bun, not Node (chokidar v5 IS importable)

OpenCode installs npm plugins automatically using Bun at startup (opencode.ai/docs/plugins). Bun natively imports ESM-only packages, so chokidar v5 (ESM-only, Node >= 20.19, single dependency readdirp v5, MIT) IS importable by the delegation-observer plugin - via a `.opencode/package.json` dependency that Bun installs at startup. The root pnpm tree is NOT involved: `.opencode/` has its own dependency tree, so chokidar must never be added to the root package.json (Bun does not read the pnpm tree). The ticket constraint "v5 requires Node >= 20" is therefore satisfied by the Bun runtime without any Node upgrade.

## 2. PATTERN (recommended over watchers): synchronous render-in-hook

The delegation-observer plugin already writes `.opencode/session/*.jsonl` inside its hook handlers (`tool.execute.after` etc.) using silent `appendFileSync` (delegation-observer.ts: registry.jsonl L855, messages.jsonl L1006). Calling the render logic in the SAME hook right after the appendFileSync gives same-tick determinism: the derived view (.md) cannot go stale because write and render are one synchronous unit. Zero new dependencies. Trivially unit-testable (pure render function over the jsonl, invoked synchronously).

A file watcher (chokidar or fs.watch) is strictly worse for this problem: it adds watcher lifecycle (start/stop, error handling), awaitWriteFinish tuning for atomic/partial writes, and a new ESM dependency - all to solve a problem the plugin's existing hooks already solve synchronously. Watchers only earn their place when the writer is OUTSIDE the plugin (e.g. a bash script or a human editor mutates the file and a third party must react to it).

## 3. DIA-086 VERDICT (2026-08-15): status-quo on-demand render retained

No consumer of the derived views (messages.md, ticker.md) demonstrated a stale-view problem:

- Orchestrator boot read, human inspection, and handoff presentation are ALL on-demand reads of freshly rendered views.
- The plugin NEVER regenerates .md views - verified in delegation-observer.ts: only .jsonl appendFileSync write paths exist, no .md write path.
- On-demand render via scripts/session-log render / scripts/ticker-render.sh is deterministic and gate-tested.

DIA-155 is therefore CLOSED as status-quo (developer decision 2026-08-15, EBDV Variant A). Revisit ONLY if a real consumer emerges that reads a stale .md without re-rendering; when that happens, prefer render-in-hook (section 2) over chokidar (section 1).

## 4. Sources

- https://github.com/paulmillr/chokidar/releases/tag/5.0.0 (2026-08-15, Tier-2 - v5 ESM-only, Node >= 20.19, readdirp v5)
- https://opencode.ai/docs/plugins (2026-08-15, Tier-2 - npm plugins installed automatically via Bun at startup)
- https://bun.com/docs/runtime/module-resolution (2026-08-15, Tier-2 - Bun native ESM module resolution)
- https://registry.npmjs.org/chokidar (2026-08-15, Tier-2 - latest version metadata)
- knowledge/res027-orchestrator-routine-work-tools/res027-orchestrator-routine-work-tools-conspect.md (Tier-1 - sections 2.6 + 3: chokidar is the only no-new-process candidate; conditional Variant B design)
- docs/dev-infra-audit/tickets/DIA-137-orchestrator-routine-work-and-artifact-systems-research-lightweight-reliable-tools-to-simplify-operations-sibling-of-dia-136.md (Tier-3 - status-quo verdict; DIA-155 filed as follow-up)
- docs/dev-infra-audit/tickets/DIA-086-scientific-methodology-workflow.md (Tier-3 - the DIA-086 scope guard)
- .opencode/plugins/delegation-observer.ts (Tier-1 - hook handlers write .jsonl via appendFileSync; no .md write path)
- docs/dev-infra-audit/tickets/DIA-155-chokidar-in-process-file-watching-harness.md (Tier-3 - this gate's ticket)
