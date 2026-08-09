---
name: research-pipeline
description: Use when orchestrator dispatches standalone research that should produce persistent knowledge artifacts — defines the full researcher → conspecter → memory shelf pipeline. Do not use for quick lookups that don't need persistence.
---

# Research-to-Persistence Pipeline

## Role
The orchestrator uses this skill when standalone research should produce persistent knowledge artifacts. The orchestrator controls the pipeline end-to-end, delegating each phase to the appropriate specialist.

## Workflow Phases

### Phase 1: Research Dispatch
Dispatch `@researcher` with a specific question, scope, and output format requirements. Wait for structured findings.

**Researcher output contract:**
- Structured summary organized by topic
- Source URLs for every claim
- Confidence assessment (High/Medium/Low)
- `PERSISTENCE_RECOMMENDED: true/false` flag with reason

**Missing flag:** If the researcher's output does not include `PERSISTENCE_RECOMMENDED`, apply the Phase 2 criteria table yourself to assess persistence worthiness before proceeding. Do not silently skip the pipeline — the flag is a convenience, not a gate.

### Phase 2: Persistence Decision (Practice-Protected)
Evaluate the researcher's findings against these criteria. **Present to the developer** — do not auto-decide:

| Criterion | Threshold |
|-----------|-----------|
| Source count | ≥3 external sources |
| Reusability | Topic non-obvious, likely needed in future sessions |
| Domain gap | No existing conspect in memory shelf covering this topic |
| Volatility | Sources may change (pricing, API docs, version-specific) |

If ANY criterion met → recommend persistence. If researcher flagged `PERSISTENCE_RECOMMENDED: true` → strong signal.

The developer decides: persist, skip, or partial (persist specific findings/sources only).

### Phase 3: Conspecter Dispatch
If persistence approved, dispatch `@conspecter` with:
1. **Researcher's findings** — the structured summary as input context
2. **Source URLs** — for download and archival
3. **Naming** — determine the next available `<id>` for `knowledge/res<id>-<topic>/` by checking existing `knowledge/res*/` directories via delegated read lane

**Current state:** res001 and res002 are registered in memory-shelf.yaml. Next ID: res003 (verify by checking both memory-shelf.yaml and any existing `knowledge/` directories — the conspecter creates the directory if it doesn't exist).

Wait for conspecter to complete. Verify:
- `knowledge/res<id>-<topic>/sources/` has .md files
- `knowledge/res<id>-<topic>/res<id>-<topic>-conspect.md` exists
- `.source-urls.txt` has all URLs

### Phase 4: Memory Shelf Registration
Verify conspecter registered the entry in `.opencode/memory-shelf.yaml` under `shelf.conspects`. If missing, flag it — do not silently add it yourself.

Confirm with developer: pipeline complete.

## Guard Gates
- **No silent persistence** — Phase 2 must involve developer decision
- **No orphaned sources** — if conspecter fails, sources/ may exist but no conspect; flag to developer
- **No duplicate IDs** — always check existing res* directories before assigning `<id>`
- **Quick lookups skip this skill** — single-source fact checks, general programming questions, ephemeral findings do not trigger this pipeline

## Archive-Before-Claim Policy
- A fact without a saved source must not count in the conspect.
- If conspecter Phase A cannot archive a URL (all methods exhausted),
  the corresponding claims are EXCLUDED from the conspect body and
  listed separately under "Unarchived Sources" with the flag
  `[source not archived — excluded per DIA-072 policy]`.
- The orchestrator reviews excluded claims and decides whether to
  retry with alternative URLs or accept the gap.
- The conspecter's Phase A MUST use the 3-tier fallback chain (JSON API
  for registry.npmjs.org → trafilatura markdown → curl+browser-UA →
  crawl4ai headless) before declaring a source unarchivable.

## Delegation Rules
- Phase 1: `@researcher` (read-only, returns findings in conversation)
- Phase 2: Orchestrator + developer (practice-protected decision)
- Phase 3: `@conspecter` (writes to knowledge/)
- Phase 4: Orchestrator verification (delegated read lane if needed)
