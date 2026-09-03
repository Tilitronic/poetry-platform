---
name: research-pipeline
description: Use when orchestrator dispatches standalone research that should produce persistent knowledge artifacts — defines the full researcher → conspecter → memory shelf pipeline. Do not use for quick lookups that don't need persistence.
---

# Research-to-Persistence Pipeline

## Role
The orchestrator uses this skill when standalone research should produce persistent knowledge artifacts. The orchestrator controls the pipeline end-to-end, delegating each phase to the appropriate specialist.

## Workflow Phases

### Phase 1: ID Pre-Allocation
Before dispatching `@researcher`, run `scripts/allocate-id res <slug>` to obtain a collision-resistant datetime ID (format: res-YYMMDD-<rand4>-<slug>). Pass the returned ID in the dispatch payload: "Write to knowledge/<returned-id>-<topic>/sources/". Never let the researcher or conspecter self-allocate. Never scan knowledge/ for highest existing IDs — that pattern is retired (DIA-260831-9zq6).

### Phase 2: Research + Phase A Source Capture (researcher-owned, D5/D6)
Dispatch `@researcher` with a specific question, scope, the pre-allocated `res<id>`, and output format requirements. The researcher OWNS Phase A source capture: it fetches every source URL ONCE into `knowledge/res<id>-<topic>/sources/` using the 3-tier fallback chain, evaluates each source, and returns structured findings. This single-fetch ownership structurally eliminates the double-fetch defect (no second trafilatura pass by a conspecter).

**3-tier fetch chain (by URL class):**
- **Tier 1 — npm registry JSON API:** `registry.npmjs.org/<package>` -> `curl -s "https://registry.npmjs.org/<package>" > sources/<slug>.json` (the JSON response IS the archive; richer than HTML, no trafilatura needed)
- **Tier 2 — trafilatura:** `trafilatura -u "<URL>" --output-format markdown > sources/<slug>.md` (direct, or after `curl -sL -A "<browser-UA>" "<URL>"` for JS-gated pages; verify content >100 bytes)
- **Tier 3 — crwl headless: LAST-RESORT ONLY.** crwl is NEVER the first attempt (DIA-129). A crwl failure is a signal to SKIP the URL and mark it per DIA-072 — do not keep retrying. Cache crwl outputs per-URL-hash within the session to avoid repeat Chromium launches.

**Quality evaluation (D6):** the researcher MUST evaluate each source for RELEVANCE (does it answer the research question) and RELIABILITY (authority, recency, independence, vendor-vs-independent) before archiving, and record a per-source rating (High/Med/Low each) in the `sources/.source-urls.txt` manifest.

**Researcher output contract:**
- Structured summary organized by topic
- Source URLs for every claim, with the archived `sources/` directory + `.source-urls.txt` manifest (per-source relevance/reliability ratings)
- Confidence assessment (High/Medium/Low)
- `PERSISTENCE_RECOMMENDED: true/false` flag with reason

**Missing flag:** If the researcher's output does not include `PERSISTENCE_RECOMMENDED`, apply the Phase 3 criteria table yourself to assess persistence worthiness before proceeding. Do not silently skip the pipeline — the flag is a convenience, not a gate.

### Phase 2 verification (HARD GATE):
Before accepting the researcher's return, the orchestrator MUST verify
`knowledge/res<id>-<topic>/sources/.source-urls.txt` exists. If missing:
- REJECT the return
- Re-dispatch @researcher with explicit Phase A instructions:
  "Phase A checkpoint failed: sources/.source-urls.txt not found.
  You MUST complete Phase A steps 1-4 before returning findings."

### Phase 3: Quality Gate (auto-proceed, DIA-260819-qibv)
Evaluate the researcher's findings against these quality criteria automatically. No developer decision required:

| Criterion | Threshold |
|-----------|-----------|
| Source count | ≥3 external sources |
| Reusability | Topic non-obvious, likely needed in future sessions |
| Domain gap | No existing conspect in memory shelf covering this topic |
| Volatility | Sources may change (pricing, API docs, version-specific) |

If ANY criterion met AND researcher flagged `PERSISTENCE_RECOMMENDED: true` → auto-proceed to Phase 4.

If NONE met OR researcher flagged `PERSISTENCE_RECOMMENDED: false` → conspect synthesis is still attempted (the researcher's flag is advisory, not a gate). Only skip Phase 4 if sources/ is empty or missing.

There is no developer-facing KEEP/DELETE decision. Conspect creation is automatic after successful Phase 2.

### Phase 4: Conspect Synthesis (conspecter = pure synthesis, D7)
Dispatch `@conspecter` with:
1. **The pre-allocated ID + topic** — `knowledge/res<id>-<topic>/` (already created by the researcher's Phase A capture)
2. **Naming** — the `<id>` was pre-allocated in Phase 1; the conspecter must NOT re-derive it

The conspecter is a PURE SYNTHESIS lane: it reads ONLY the archived sources under `sources/` (NO network fetch — curl/trafilatura/crwl/playwright are revoked), synthesizes the MLA-cited conspect, and reports artifact path; @memory-manager registers in memory-shelf. It must cite ONLY sources that pass the researcher's evaluation; excluded sources are listed under Unarchived/Excluded with reason.

Wait for conspecter to complete. Verify:
- `knowledge/res<id>-<topic>/sources/` has .md files
- `knowledge/res<id>-<topic>/res<id>-<topic>-conspect.md` exists
- `.source-urls.txt` has all URLs with per-source ratings

### Phase 5: Analysis Gate (D4)
Analysis is BLOCKED until the conspect is verified. When the conspecter completes, the delegation-observer plugin drops `.opencode/session/analysis-pending.json` with `{ "status": "pending_verification" }`. Before dispatching `@analyzer`:
1. Verify the conspect artifacts (sources/, conspect file, memory-shelf entry) via a delegated read lane
2. Edit `.opencode/session/analysis-pending.json` to `{ "status": "verified" }` to clear the gate
   (or delete it via `scripts/pending-gate-clear analysis-pending`, DIA-260825-fjnc)
3. Only then dispatch `@analyzer` — analysis consumes the conspect, NOT raw findings

The developer can explicitly skip analysis by setting `status: "skipped"`.

## Guard Gates
- **Conspect is automatic** — Phase 3 is a quality gate (auto-proceed), not a developer decision
- **No orphaned sources** — if conspecter fails, sources/ may exist but no conspect; flag to developer
- **No duplicate IDs** — IDs are pre-allocated by the orchestrator in Phase 1; always check existing res* directories before assigning
- **Analysis blocked until verified** — Phase 5 gate; never dispatch @analyzer while analysis-pending.json is present and unverified
- **Quick lookups skip this skill** — single-source fact checks, general programming questions, ephemeral findings do not trigger this pipeline

## Archive-Before-Claim Policy
- A fact without a saved source must not count in the conspect.
- The researcher's Phase A MUST use the 3-tier fallback chain (registry JSON API → trafilatura markdown → curl+browser-UA → crwl headless LAST-RESORT) before declaring a source unarchivable.
- crwl is NEVER the first attempt; a crwl failure = skip the URL and mark it (DIA-129/DIA-072). Cache crwl outputs per-URL-hash.
- If a URL cannot be archived (all methods exhausted), the corresponding claims are EXCLUDED from the conspect body and listed separately under "Unarchived Sources" with the flag `[source not archived — excluded per DIA-072 policy]`.
- The orchestrator reviews excluded claims and decides whether to retry with alternative URLs or accept the gap.

## Delegation Rules
- Phase 1: Orchestrator (ID pre-allocation)
- Phase 2: `@researcher` (owns research + Phase A source capture; writes knowledge/<resid>-<topic>/sources/)
- Phase 3: Orchestrator (quality check, auto-proceed — no developer decision)
- Phase 4: `@conspecter` (pure synthesis; writes conspect; reports artifact path; @memory-manager registers in memory-shelf)
- Phase 5: Orchestrator verification (delegated read lane if needed) + developer skip option
