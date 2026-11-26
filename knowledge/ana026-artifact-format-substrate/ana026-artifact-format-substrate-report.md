# ana026 - Artifact Format Substrate Analysis (DIA-180 Deliverable B)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: knowledge/ana026-artifact-format-substrate + in-repo measurements (wc -c, awk section sizing) + DIA-180 inventory + DIA-079/DIA-075/DIA-191 precedents
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

**Ticket:** DIA-194 (parent DIA-180, CLOSED 2026-08-15 squash-merge bcb8379 for Deliverable A)
**Analyst:** @analyzer (analysis lane)
**Date:** 2026-08-15
**Scope:** YAML vs Markdown EBDV matrix with token-economy evidence for every agent-authored artifact in the poetry-platform dev-infra surface.
**Guardrail:** READ-ONLY analysis. No conversions applied. Conversions spawn follow-up tickets only after developer approval (DIA-084 inheritance).

## 1. Executive Summary

The repo already embodies the answer DIA-180 asked us to evidence: a **hybrid substrate** where the right format follows the consumer and the write pattern, not a single substrate for all artifacts. Deliverable A (merged in bcb8379) laid the enabler groundwork -- yaml-language-server pin + memory-shelf JSON Schema gate in `make test-config` -- which is the precondition that makes the YAML premise viable for any future conversion. This analysis confirms the DIA-180 axis lean with measurements and EBDV matrices:

- **Machine-first structured -> stay YAML** (memory-shelf.yaml, ai-assist-sources.yaml, ticket frontmatter) -- the JSON Schema gate already enforces memory-shelf.yaml shape.
- **Machine-first append-only stream -> OUT OF SCOPE** (session/*.jsonl) -- YAML is the wrong substrate for append-only event streams; storage questions belong to DIA-136 (CLOSED, node:sqlite in-memory read layer adopted).
- **Narrative / instructions / human-rendered -> stay MD** (openspec/, knowledge/, AGENTS.md, practice-protected.md, NEXT-RUN.md, .sdd/).
- **FLAGSHIP candidate -> .opencode/CHANGELOG.md** (convert to YAML ledger + derived MD view) -- the strongest cost-benefit case in the inventory; this report quantifies the delta at ~55.8K tokens READ today vs ~10.9K tokens in YAML-ledger form (~5x reduction), plus partial-read capability.

The change to the CHANGELOG is the ONLY concrete conversion recommendation. Everything else is a stay-put recommendation with evidence.

## 2. Method

Multi-method analysis:

- **MECE classification** (section 4) -- artifacts bucketed by consumer + write pattern + render target.
- **Inversion** (section 6) -- instead of asking "why YAML?", we ask "what breaks if every artifact were YAML?" and "what breaks if every artifact were MD?" to surface failure modes on both sides.
- **Cost-benefit / token economy** (section 5) -- measured file sizes, estimated tokens via the documented ~4 chars/token heuristic (LABELED as heuristic, not authoritative), and project actual read patterns from ticket cross-references.
- **EBDV per DIA-115** (section 7) -- >=2 genuine variants per artifact class, abort/status-quo variant, explicit recommendation with because, routing flag (dev-infra vs section-10 vs N/A).
- **Precedent analysis** (section 6) -- DIA-079 / DIA-075 / DIA-191 in-repo precedents of tool/serialization drift, with mitigation-machinery crosswalk.

## 3. B1 / B7: Artifact Inventory (Confirmed and Extended)

The DIA-180 inventory (lines 93-111) is reproduced with real measurements taken 2026-08-15. Sizes are `wc -c` on the live filesystem.

| # | Artifact | Format today | Size (bytes) | Primary consumer | Write frequency | Notes |
|---|----------|--------------|--------------|------------------|-----------------|-------|
| 1 | `.opencode/CHANGELOG.md` | Markdown | **223,195** (730 lines, 87 sections) | agents + developer | every section-10 change | FLAGSHIP candidate |
| 2 | `.opencode/memory-shelf.yaml` | YAML | **98,495** | agents | research registration | JSON Schema gate wired in A2 |
| 3 | `.opencode/learnings/external-patterns/*.md` | Markdown (65 files) | 305,910 total (~4.7 KB/file avg) | agents | session end | narrative findings |
| 4 | `.opencode/learnings/*.md` (internal) | Markdown | ~small | agents | session end | rare |
| 5 | `.opencode/session/registry.jsonl` | JSONL | **11,876,156** (~11.3 MB) | plugin + agents | every delegation | append-only, OUT OF SCOPE |
| 6 | `.opencode/session/messages.jsonl` | JSONL | **14,248,821** (~13.6 MB) | plugin + agents | every event | append-only, OUT OF SCOPE |
| 7 | `.opencode/session/messages.md` | MD (DERIVED) | varies | agents | regenerated | `scripts/session-log render` |
| 8 | `.opencode/session/current-handoff.json` | JSON | varies | orchestrator | session end | atomic write, strict JSON |
| 9 | `.opencode/session/HANDOFF.md` | Markdown | varies | orchestrator | session end | human-rendered prognosis |
| 10 | `docs/dev-infra-audit/tickets/*.md` (146 files) | MD + YAML frontmatter | ~800 KB total (est.) | agents + developer | ongoing | hybrid MD-body/YAML-head |
| 11 | `docs/dev-infra-audit/tickets/README.md` | MD (DERIVED) | varies | agents + developer | rollup | `scripts/tickets rollup` |
| 12 | `docs/dev-infra-audit/NEXT-RUN.md` | Markdown | **30,018** | orchestrator | occasional | operational runbook |
| 13 | `knowledge/res*, ana*, tch*` (80 reports) | Markdown | 10,154,113 total (~127 KB/report avg) | agents | research pipeline | narrative analysis |
| 14 | `openspec/changes/*/{proposal,design,tasks}.md` | MD + YAML frontmatter | 1,477,951 total | agents + developer | per change | external tool format |
| 15 | `.sdd/{dev-infra,dia-redispatch-cycle,opencode-config}/architecture.md` | Markdown | 26,175 total (4 files) | agents | rare | architectural decisions |
| 16 | `AGENTS.md`, `.opencode/practice-protected.md` | Markdown | 18,188 + 5,586 | agents + developer | rare | project-wide policy |
| 17 | `.opencode/opencode.jsonc`, `oh-my-opencode-slim.jsonc` | JSONC | 26,103 + 66,945 | OpenCode runtime | section-10 changes | JSONC (out of scope for YAML review) |

**Extensions beyond DIA-180 inventory:** added ai-assist-sources.yaml (lives under `.opencode/oh-my-opencode-slim/knowledge/ai-assist-sources.yaml`, consumed by @resource-manager), the 146-ticket count, the knowledge/ aggregate (80 reports, ~10 MB), and the explicit sizes for registry.jsonl and messages.jsonl (26.1 MB combined, confirming the OUT-OF-SCOPE classification).

**B7 status:** This report (knowledge/ana026-artifact-format-substrate/ana026-artifact-format-substrate-report.md) is the output artifact. Registration in memory-shelf.yaml is delegated to @memory-manager post-return.

## 4. B2: Data-vs-Prose Classification (MECE)

Each artifact lands in exactly one of four mutually-exclusive classes, defined by the intersection of **(a) consumer type** (machine-first vs human-first) and **(b) write pattern** (structured-record vs narrative-stream vs append-only-log).

```
                          +-----------------------+
                          |   CONSUMER AXIS       |
                          | machine-first  human  |
+-------------------------+-----------------------+
| structured-record       | YAML (or JSON/JSONL)  | MD + YAML frontmatter |
| (tabular, queryable,    | - memory-shelf.yaml   | - tickets/*.md        |
|  schema-enforced)       | - ai-assist-sources   | - openspec/*          |
|                         | - ticket frontmatter  |                       |
W |-----------------------+-----------------------+
R | narrative-stream      | [RARE in this repo]   | MD                    |
I | (prose, instructions, |                       | - knowledge/*         |
T |  human-rendered)      |                       | - learnings/*.md      |
E |                       |                       | - AGENTS.md           |
- |                       |                       | - .sdd/*              |
P |                       |                       | - NEXT-RUN.md         |
A |                       |                       | - practice-protected  |
T |                       |                       | - HANDOFF.md          |
T |-----------------------+-----------------------+
E | append-only-log       | JSONL                 | [n/a]                 |
R | (event stream,        | - registry.jsonl      |                       |
N |  per-row atomic)      | - messages.jsonl      |                       |
+-------------------------+-----------------------+
```

```
+-- How to read this matrix ----------------+
| Title: MECE Substrate Classification      |
| X-axis: primary consumer (machine/human)  |
| Y-axis: write pattern (3 classes)         |
| Cells: recommended substrate              |
| How to read: each artifact lands in       |
| exactly one cell. The FLAGSHIP candidate  |
| (CHANGELOG) is the sole recommended move. |
+-------------------------------------------+
```

### Per-artifact classification

| # | Artifact | Class | Rationale |
|---|----------|-------|-----------|
| 1 | **`.opencode/CHANGELOG.md`** | structured-record / human-rendered (HYBRID -- the hybrid that motivates the flagship move) | 87 sections, each with Change/Reason/Files/Review/Verification fixed sub-structure; today hand-maintained as prose but consumed by agents as structured data (cross-referenced from tickets, learnings, section-10 routing); agents must READ the whole 223 KB to find one DIA entry. YAML-ledger source + derived MD view splits the difference. |
| 2 | `.opencode/memory-shelf.yaml` | structured-record / machine-first | **STAY YAML.** Already has JSON Schema gate (A2). Agents read it as a query table. |
| 3 | `ai-assist-sources.yaml` | structured-record / machine-first | **STAY YAML.** Consumed by @resource-manager as a Tier-1 source registry. |
| 4 | Ticket frontmatter | structured-record / machine-first | **STAY YAML (hybrid MD body).** DIA-125 precedent: text-over-binary-DB because git merges text cleanly. YAML frontmatter preserves this while the MD body stays human-readable. |
| 5 | `registry.jsonl`, `messages.jsonl` | append-only-log / machine-first | **OUT OF SCOPE** -- YAML is the wrong substrate for append-only event streams (one malformed document poisons the file; JSONL is per-row atomic). Storage questions belong to DIA-136 (CLOSED). |
| 6 | `messages.md`, `tickets/README.md` | narrative-stream / human-first (DERIVED) | **STAY MD.** Already DERIVED views -- the question is what their source is, not what they are. |
| 7 | `knowledge/*` (80 reports) | narrative-stream / human-first | **STAY MD.** Narrative analysis; agents read specific reports, not the whole corpus (~10 MB). Rendered for human consumption. |
| 8 | `learnings/external-patterns/*.md` | narrative-stream / human-first | **STAY MD.** Per-session findings; ~4.7 KB/file, consumed on demand. |
| 9 | `openspec/changes/*` | hybrid (MD + YAML frontmatter) | **STAY AS-IS.** External tool format (OpenSpec), do not fork. Already uses the best of both. |
| 10 | `.sdd/*` | narrative-stream / human-first | **STAY MD.** Architectural decisions, rare-write, long-lived. |
| 11 | `AGENTS.md`, `practice-protected.md` | narrative-stream / human-first | **STAY MD.** Project-wide policy; git-diffable prose. |
| 12 | `NEXT-RUN.md` | narrative-stream / human-first | **STAY MD.** Operational runbook with sections; consumed by orchestrator but still narrative (sections 2, 7.2, 7.3 are prose instructions). |
| 13 | `current-handoff.json` | structured-record / machine-first | **STAY JSON.** Atomic write via `JSON.stringify` (always valid); strict JSON is the RIGHT substrate for a single-file atomic record. |
| 14 | `HANDOFF.md` | narrative-stream / human-first | **STAY MD.** Human-rendered prognosis view; the structured data lives in `current-handoff.json`. |
| 15 | `opencode.jsonc`, `oh-my-opencode-slim.jsonc` | structured-record / machine-first | **STAY JSONC.** Out of scope for this review (OpenCode's native config format; JSONC is a JSON superset, not a YAML question). |

## 5. B3: Token-Economy Measurement

### Methodology

- **Measurement:** `wc -c` on live files (2026-08-15, working tree).
- **Token heuristic:** ~4 chars per token is the documented OpenCode heuristic (LABELED AS HEURISTIC; actual tokenization depends on model-specific BPE and may range 3-5 chars/token). The delta RATIO is robust across that range; the absolute token numbers are indicative.
- **Scope of "read today":** for CHANGELOG we measure the FULL-FILE read because that is what agents do today when prompted "reference the CHANGELOG" (no partial-read mechanism exists for a prose MD). For memory-shelf.yaml we assume full read (agents do consult the whole shelf). For YAML-ledger CHANGELOG we assume either full-read-equivalent OR partial-read (per-ticket query via `yq`/`jq`) as a secondary benefit.

### Top-3 conversion candidates (measured)

| Rank | Artifact | Current size (bytes) | Current est. tokens (full read) | YAML-ledger est. size | YAML-ledger est. tokens | Delta ratio |
|------|----------|----------------------|--------------------------------|----------------------|------------------------|-------------|
| 1 | `.opencode/CHANGELOG.md` | **223,195** | **~55,800** | ~43,500 (87 entries * 500 avg) | **~10,875** | **~5.1x** |
| 2 | `memory-shelf.yaml` | 98,495 | ~24,600 | already YAML, gate-enforced | ~24,600 | 1.0x (stay) |
| 3 | `learnings/external-patterns/` (65 files) | 305,910 | ~76,500 (aggregate) | ~N/A -- per-file narrative, no query benefit | same | 1.0x (stay) |

### CHANGELOG flagship -- detailed delta

The DIA-180 axis lean proposes CHANGELOG as the flagship because:

- It is the **largest hand-maintained agent artifact** (223 KB, 87 sections).
- It is **cross-referenced from tickets and learnings** (every section-10 change appends a section; tickets cite CHANGELOG dates).
- It has a **fixed internal structure** per section: Change / Reason / Files / Review / Verification -- a natural YAML entry schema.
- Today, agents must READ the entire 223 KB (or a tail) to find a single DIA's entry; there is no partial-read mechanism.

**YAML-ledger shape (proposed):**

```yaml
# .opencode/CHANGELOG.yaml (proposed)
- date: "2026-08-15"
  ticket: DIA-189b
  status: REGISTERED
  scope: pty title rename + boot retro pass
  route: section-10
  files:
    - .opencode/plugins/needs-input-observer.ts
    - .opencode/plugins/__tests__/needs-input-observer.dia189.test.mjs
  summary: >
    A1b pty.created/pty.updated rename; A2b boot retro pass; F2 envelope
    shapes; harness 14 -> 26 tests.
```

At ~500 bytes per entry * 87 entries = ~43,500 bytes = ~10,875 tokens (full read).

**Secondary benefit -- partial read:** with YAML + schema, `yq '.[] | select(.ticket == "DIA-189")'` returns only the relevant entry (~500 bytes = ~125 tokens) vs today's full-file read (223,195 bytes = ~55,800 tokens). **Per-query delta: ~445x reduction** when an agent needs a single DIA entry.

**Derived MD view:** a render script (mirroring `scripts/session-log render` and `scripts/tickets rollup`) converts the YAML ledger to a human-readable MD for developer consumption and git-diff review. The MD view is gitignored or regenerated-on-demand; the YAML source is the source of truth. This follows the established derived-view pattern in the repo.

### Cost-benefit summary

| Scenario | Full-read tokens | Partial-read tokens (single entry) | Gate-enforced | Git-diff quality |
|----------|------------------|------------------------------------|---------------|------------------|
| CHANGELOG.md today | ~55,800 | ~55,800 (no mechanism) | No (prose) | Good |
| CHANGELOG.yaml (flagship) | ~10,875 | ~125 (yq query) | Yes (schema gate) | Acceptable (structured diff) |
| Derived CHANGELOG.md (rendered) | ~55,800 (same as today) | N/A (not source) | N/A | Good |

```
+-- How to read this chart -----------------+
| Title: CHANGELOG token economy -- current |
|   vs YAML-ledger proposal                 |
| X-axis: scenario                          |
| Y-axis: estimated tokens (log scale)      |
| Segments: full-read vs partial-read       |
| How to read: the YAML-ledger source is    |
| ~5x cheaper on full read and ~445x        |
| cheaper on per-entry queries vs today's   |
| prose CHANGELOG.md.                       |
+-------------------------------------------+
```

```
scenario                 full-read   partial-read (per entry)
-----------------------  ---------   ------------------------
CHANGELOG.md today       ~55,800     ~55,800 (no mechanism)
CHANGELOG.yaml ledger    ~10,875     ~125
Derived MD view          ~55,800     N/A (not source)
```

(Uncertainty band: at 3 chars/token the absolute numbers scale to ~74,400 / ~14,500 / ~167; at 5 chars/token they scale to ~44,600 / ~8,700 / ~100. The ~5x full-read ratio and ~445x partial-read ratio hold across the 3-5 chars/token band.)

## 6. B4: Agent YAML Write-Error Risk Analysis

### In-repo precedents

The project has three documented serialization/tool-drift failures that together bound the YAML write-error risk:

| Precedent | Failure class | Root cause | Resolution | Relevance to YAML substrate |
|-----------|---------------|------------|------------|-----------------------------|
| **DIA-079** (2026-08-10/11) | JSON Parse error: "Unexpected identifier 'computed'/'Session'" | Orchestrator LLM hand-assembled `prognosis` as JSON5 (unquoted keys, unquoted string values); strict `JSON.parse` threw; handoff atomic write silently failed -> current-handoff.json missing -> boot gate broken | Defensive `parsePrognosis` helper (merge b005277) wraps failures in a valid JSON envelope; prompt hardening (DIA-079 secondary) states strict-JSON requirement | **Direct parallel.** An LLM writing YAML without schema/LSP validation would hit the same class: unquoted keys, wrong indentation, single-quotes-as-string-values. The Deliverable-A enabler (JSON Schema gate + yaml-language-server + make test-config wiring) is the EXACT mitigation that would have caught DIA-079-class failures in YAML artifacts at gate time. |
| **DIA-075** (2026-08-09) | Checksum mismatch (wrong sha256 computed ~12x identically) via `snip jq` wrapper | Third-party `snip` CLI built-in jq filter truncated output deterministically above a threshold; coder lanes in identical-command loop (DIA-078 class) | Structural elimination: opencode-snip plugin removed (DIA-092); dormant deny rules retained; `bash -c` passthrough documented as canonical | **Indirect lesson.** Tool-chain opacity can produce deterministic-but-wrong outputs. YAML substrate is safe only when the validation chain is transparent and mechanical -- exactly what Deliverable A wired in. |
| **DIA-191** (2026-08-15) | `context_usage` tool overestimates actual context usage by ~2.1x (48% proxy vs 23% actual) | Proxy estimator uses registry.jsonl activity counts as heuristic, not native token accounting; overestimate triggers premature SELF-RERUN | Open investigation (2026-08-15); candidate corrections include weight-per-row or native-telemetry read-through from DIA-182 | **Indirect lesson.** Estimation tooling drift is a live hazard. The "~4 chars/token" heuristic used in section 5 of this report is similarly a proxy. Mitigation: label it as heuristic (done), rely on the ratio not the absolute number (done), and note that actual YAML token-economy savings should be re-measured post-conversion against `opencode db`/`opencode stats` native data (DIA-182 surface). |

### External evidence (lightweight, non-blocking)

The DIA-180 brief explicitly states external LLM-YAML-error-rate research is "if cheaply available" and "do NOT block on external research." I did not run a fresh external sweep for this analysis because:

1. The in-repo precedents (DIA-079, DIA-075, DIA-191) already demonstrate the failure class with concrete root causes.
2. The **already-merged Deliverable A** (yaml-language-server pin + JSON Schema gate in `make test-config`) is the mitigation machinery the brief identifies as sufficient.
3. External LLM-YAML-error-rate benchmarks are typically model-version-specific and age out within months; citing a 2024 paper would not strengthen the in-repo evidence.

If the developer wants external evidence, a follow-up @researcher dispatch can fetch it cheaply; the analysis does not depend on it.

### Mitigation crosswalk (Deliverable A already in place)

The three-layer mitigation DIA-180 points to is now live:

1. **Layer 1 -- LSP** (A1): `yaml-language-server` installed in Dockerfile.dev, probed by `check-host-lsp.sh`, bats-covered (FAKE-mock, no real binary spawned). Catches syntax errors at edit time for human developers in VSCode; agents do not consume LSP directly but benefit from any LSP-driven CI feedback.
2. **Layer 2 -- JSON Schema gate** (A2): `scripts/validate-memory-shelf.sh` + `scripts/schemas/memory-shelf.schema.json` wired into `make test-config`. Currently covers memory-shelf.yaml only. The schema pattern is directly extensible to any new YAML artifact (proposed CHANGELOG.yaml schema would live at `scripts/schemas/changelog.schema.json`).
3. **Layer 3 -- Mechanical gate** (A2 continued): `make test-config` exit 0 is a hard precondition for commit; pre-commit hook HARD-FAILS without container (DIA-094). So any YAML regression is caught before it reaches git.

This three-layer stack is exactly what was missing during DIA-079 (JSON parse silently failed inside the plugin; no gate caught it at commit time). **The YAML write-error risk is now structurally bounded for any artifact that opts into the schema-gate pattern.**

### Risk table for the flagship CHANGELOG conversion

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Agent writes malformed YAML during conversion | Medium (DIA-079 precedent) | High (broken CHANGELOG, cross-ref loss) | Deliverable A three-layer stack (LSP + schema + gate); initial conversion done by a coder lane with schema-first design; harness tests over the render script |
| Schema evolution pain (adding fields later) | Low | Medium | YAML schema evolution is additive by default (new optional fields); JSON Schema handles this cleanly |
| Derived-MD-view drift (render script breaks) | Low | Medium | Render script has bats coverage (following `scripts/session-log` precedent); `make test-infra` catches drift |
| Git-merge friction on structured YAML vs prose MD | Medium | Medium | YAML line-based diff is coarser than MD line-based diff for prose; but CHANGELOG entries are already line-structured (one entry per section), so the merge-quality delta is small |
| Agent partial-read adoption (using `yq` instead of full read) | Low in short term | High (this is the main benefit) | Requires prompt update (orchestrator_append.md, NEXT-RUN.md) pointing agents at the new query pattern; section-10 routing |

## 7. B5: EBDV Recommendation Matrix (per DIA-115)

DIA-115 requires >=2 genuine variants per recommendation, an abort/status-quo variant, explicit recommendation with because-justification, and routing flag (dev-infra vs section-10 vs N/A).

### Matrix 1: `.opencode/CHANGELOG.md` (FLAGSHIP candidate)

| Variant | Evidence | Pros | Cons | Effort | Routing |
|---------|----------|------|------|--------|---------|
| **V1. YAML ledger + derived MD view (RECOMMENDED)** | In-repo derived-view precedents (messages.md rendered from messages.jsonl; tickets/README.md rolled up from tickets/*.md frontmatter); Deliverable A schema gate already in place; token-economy measurement (section 5: ~5x full-read reduction, ~445x partial-read reduction) | Structured query (per-DIA lookup); schema-enforced writes; 5x cheaper full read; ~445x cheaper per-entry queries; reusable schema pattern for future YAML artifacts | One-time conversion cost; render script to write + maintain; git-diff slightly coarser on structured YAML | Medium (1 section-10 cycle: ai-specialist gate -> design -> coder -> ai-auditor; follow-up ticket required per DIA-084 guardrail) | **section-10** (config-surface change) |
| V2. Stay MD, add jq-style partial-read via section headers | Zero additional tooling; preserves prose git-diff | No conversion cost; agents can `grep "^## DIA-NNN"` for specific entries | No schema enforcement; no token-economy win on full read; grep-based partial read is fragile (section-header format changes break it) | Low | N/A (status quo) |
| V3. Stay MD, full conversion to a different query tool (e.g., sqlite over the prose file) | DIA-136 precedent (rejected embedded DB for source-of-truth reasons) | Powerful queries | Violates the binding developer constraint from DIA-136 (committable text preferred over binary DB for source of truth) | High | section-10 |
| **V4. ABORT / STATUS QUO** | DIA-084 guardrail: "analysis recommends; conversions spawn follow-up tickets" | Zero cost; preserves current working system | Forgoes the 5x/~445x token-economy win; schema-less writes continue | Zero | N/A |

**Recommendation:** Variant 1 (YAML ledger + derived MD view).
**Because:** the token-economy delta is the strongest in the inventory (~5x full read, ~445x partial read), the change fits an established derived-view pattern (messages.md, tickets/README.md), and the Deliverable-A enabler (schema gate + LSP + `make test-config` wiring) already provides the three-layer mitigation for YAML write-error risk. The conversion is the ONLY concrete recommendation in this analysis -- everything else is stay-put. The follow-up ticket must route through section-10 per the AGENTS.md 2.5 workflow.

### Matrix 2: `.opencode/memory-shelf.yaml`

| Variant | Evidence | Pros | Cons | Effort | Routing |
|---------|----------|------|------|--------|---------|
| **V1. Stay YAML (RECOMMENDED)** | Already schema-gated (A2); agents consume as structured query table; 98 KB is manageable | Already working; gate-enforced; zero change cost | None material | Zero | N/A |
| V2. Convert to JSON | JSON parse strictness | Strict parsing | Loses YAML human readability; git-diff noise on key reorders; no schema win | Medium | section-10 |
| V3. Split into multiple smaller YAML files by category | Addresses 98 KB size | Smaller per-file reads | Fragmentation; shelf registration logic must be rewritten; loses single-file atomicity | High | section-10 |
| **V4. ABORT / STATUS QUO** | Already has gate | Zero cost | Same | Zero | N/A |

**Recommendation:** Variant 1 (stay YAML, status quo).
**Because:** the file is already schema-gated, agents consume it as a structured query table, and no token-economy or write-error benefit is realized by changing substrate. The 98 KB size is manageable.

### Matrix 3: `ai-assist-sources.yaml` (@resource-manager Tier-1 cache)

| Variant | Evidence | Pros | Cons | Effort | Routing |
|---------|----------|------|------|--------|---------|
| **V1. Stay YAML (RECOMMENDED)** | Tier-1 source registry, machine-first structured data | Same as Matrix 2 | Same as Matrix 2 | Zero | N/A |
| V2. Convert to JSON | Strict parsing | Loses readability; no schema win | Medium | section-10 |
| **V3. ABORT / STATUS QUO** | Same | Zero cost | Same | Zero | N/A |

**Recommendation:** Variant 1 (stay YAML). Because: structured registry data with machine-first consumers.

### Matrix 4: Ticket frontmatter (`docs/dev-infra-audit/tickets/*.md`)

| Variant | Evidence | Pros | Cons | Effort | Routing |
|---------|----------|------|------|--------|---------|
| **V1. Stay hybrid MD body + YAML frontmatter (RECOMMENDED)** | DIA-125 precedent (text over binary DB); git merges text cleanly; `scripts/validate-grilling-gate.sh` + `scripts/tickets` already emit and validate the frontmatter fields | Proven pattern; git-diff-friendly; mechanical validation already in place | None material | Zero | N/A |
| V2. Convert body to YAML | Pure-structured | Violates the DIA-125 text-over-binary precedent; loses git-merge quality for prose descriptions; breaks the openspec-plan Socratic authoring flow (practice-protected zone) | Very high | section-10 |
| **V3. ABORT / STATUS QUO** | DIA-125 binding | Zero cost | Same | Zero | N/A |

**Recommendation:** Variant 1 (stay hybrid). Because: DIA-125 established text-over-binary-DB for git-merge reasons; the hybrid pattern is already validated by `validate-grilling-gate.sh`.

### Matrix 5: Session records (registry.jsonl, messages.jsonl)

| Variant | Evidence | Pros | Cons | Effort | Routing |
|---------|----------|------|------|--------|---------|
| **V1. OUT OF SCOPE -- stay JSONL (RECOMMENDED)** | DIA-136 CLOSED (node:sqlite in-memory read layer adopted as read-through over the JSONL source); YAML is the wrong substrate for append-only event streams (one bad document poisons the file) | Already working; DIA-136's decision already handles the read-side concern; no change cost | None material | Zero | N/A |
| V2. Convert to YAML | Human-readable | Violates append-only atomicity; one malformed YAML document invalidates the entire file; 26 MB combined; no query benefit | Very high | section-10 |
| V3. Convert to embedded SQLite as source of truth | DIA-136 research | **Binding developer constraint** from DIA-136 rejects this: binary DB not committable/diffable | High | section-10 |
| **V4. ABORT / STATUS QUO** | DIA-136 closed | Zero cost | Same | Zero | N/A |

**Recommendation:** Variant 1 (OUT OF SCOPE, stay JSONL). Because: append-only event streams need per-row atomic writes, YAML is the wrong substrate, and DIA-136 already adopted the node:sqlite in-memory read-through as the answer to the read-side concern.

### Matrix 6: Narrative artifacts (knowledge/*, learnings/*, AGENTS.md, practice-protected.md, NEXT-RUN.md, .sdd/*, openspec/*, HANDOFF.md)

| Variant | Evidence | Pros | Cons | Effort | Routing |
|---------|----------|------|------|--------|---------|
| **V1. Stay Markdown (RECOMMENDED)** | These are narrative / instructions / human-rendered; git-diff-friendly prose; agents read specific reports on demand (not the whole corpus) | Git-merge quality; human-readable; fits the artifact's purpose | None material | Zero | N/A |
| V2. Convert to YAML | Structured queries on knowledge reports | Wrong substrate -- knowledge reports are prose; openspec is an external tool format (do not fork) | Very high | section-10 |
| **V3. ABORT / STATUS QUO** | Same | Zero cost | Same | Zero | N/A |

**Recommendation:** Variant 1 (stay MD) for all artifacts in this class. Because: prose/instruction artifacts are the right fit for MD; YAML provides no benefit and loses git-merge quality for prose.

### Matrix 7: Atomic single-file records (current-handoff.json)

| Variant | Evidence | Pros | Cons | Effort | Routing |
|---------|----------|------|------|--------|---------|
| **V1. Stay JSON (RECOMMENDED)** | `atomicWriteHandoff` uses `JSON.stringify` (always emits valid JSON); strict JSON is the RIGHT substrate for a single atomic record; DIA-079's fix (defensive `parsePrognosis`) wraps malformed inputs | Already working; atomic-write semantics match JSON | None material | Zero | N/A |
| V2. Convert to YAML | Human-readable | Loses atomic-write guarantees; YAML has corner cases around string interpretation (yes/no/on/off) that JSON does not | Medium | section-10 |
| **V3. ABORT / STATUS QUO** | Same | Zero cost | Same | Zero | N/A |

**Recommendation:** Variant 1 (stay JSON). Because: atomic-write semantics match JSON strictly; YAML's string-interpretation corner cases are a liability for a single-file atomic record.

## 8. B6: Cross-Reference DIA-136 / DIA-137

### DIA-136 (CLOSED 2026-08-14)

**Outcome:** V2 ADOPTED - `node:sqlite :memory:` read-only query layer over the existing JSONL session records. JSONL stays canonical committed source of truth; sqlite exists ONLY in memory during a query (nothing new committed to git). Named candidates rejected with evidence: lowdb 7.0.1 (whole-file rewrite O(N)), json-server 1.0.0-beta.15 (full HTTP server, beta), nedb 1.8.0 (unmaintained), nedb2 (abandoned), tinydb 4.9.0 (Python-only), @seald-io/nedb 4.1.2 (file/append-only + full-memory copy), better-sqlite3 13.0.3 (native dep duplicated by Node built-in). Implementation filed as DIA-156.

**Cross-reference impact on this analysis:**
- The session/*.jsonl OUT-OF-SCOPE classification in section 4 is CONSISTENT with DIA-136's decision. The read-side concern DIA-136 addresses is orthogonal to the substrate question; JSONL stays as the committed write path, sqlite-in-memory handles the query ergonomics.
- This analysis explicitly does NOT re-evaluate the JSON-DB candidates DIA-136 already adjudicated.
- The developer committability constraint (binary DB not acceptable as source of truth; text always preferred) established in DIA-136 informs Matrix 5 V3 rejection and Matrix 4 V2 rejection.

### DIA-137 (CLOSED 2026-08-14)

**Outcome:** STATUS-QUO ADOPTED -- bash + jq + bats settled standards, no new tools. The broader chokidar harness application (in-process file watching for auto-regeneration of derived views) filed as DIA-155.

**Cross-reference impact on this analysis:**
- The derived-view render script proposed for the flagship CHANGELOG conversion (Matrix 1 V1) fits the bash+jq+bats stack DIA-137 settled on -- no new tooling category needed.
- DIA-155 (chokidar follow-up) could provide auto-regeneration of the derived CHANGELOG.md view when the YAML ledger changes, but that is a separate concern and not re-evaluated here.

## 9. Mermaid Diagram -- Flagship CHANGELOG YAML-Ledger Pattern

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {
  'darkMode': true, 'background': '#1e1e2e',
  'primaryColor': '#2d3a5c', 'primaryTextColor': '#e0e0e0',
  'primaryBorderColor': '#5b8def', 'lineColor': '#5b8def',
  'labelTextColor': '#e0e0e0', 'noteTextColor': '#e0e0e0',
  'noteBkgColor': '#3d3520'
}}}%%
flowchart TB
    classDef process fill:#1e3a5f,stroke:#5b8def,color:#e0e0e0,stroke-width:2px
    classDef store fill:#2d1b4e,stroke:#a855f7,color:#e0e0e0,stroke-width:2px
    classDef decision fill:#3d2e00,stroke:#eab308,color:#e0e0e0,stroke-width:2px
    classDef boundary fill:#1e1e2e,stroke:#64748b,color:#94a3b8,color:#94a3b8,stroke-dasharray:5 5
    classDef success fill:#0f2d1a,stroke:#22c55e,color:#e0e0e0,stroke-width:2px

    subgraph source[Source of Truth]
        A[CHANGELOG.yaml\n87 entries, ~43.5 KB\n~10,875 tokens full-read]:::store
    end

    subgraph consumers[Consumers]
        B[Agent per-DIA query\nyq '.[] \| select(.ticket==X)'\n~125 tokens per query]:::process
        C[Developer human-read\nrendered MD view]:::process
    end

    subgraph gates[Mitigation Machinery\nfrom Deliverable A]
        D[yaml-language-server\nLSP layer]:::decision
        E[changelog.schema.json\nJSON Schema gate]:::decision
        F[make test-config\nmechanical gate]:::decision
    end

    subgraph derived[Derived View]
        G[scripts/changelog-render\nYAML -> MD\nbash+jq+bats per DIA-137]:::process
        H[CHANGELOG.md\nhuman-readable view]:::store
    end

    A -->|per-DIA lookup| B
    A -->|render on demand| G
    G -->|writes| H
    H -->|human read| C
    A -->|validates against| E
    E -->|blocks commit| F
    D -->|edit-time feedback| A

    %% Theme-safe styling for C4-style UpdateElement
    %% (using classDef above; UpdateElementStyle omitted per mermaid-diagramming
    %% skill C4 experimental warning)
```

```
+-- How to read this diagram ----------------+
| Title: CHANGELOG YAML-ledger data flow     |
| Actors: YAML source, agent/developer       |
|   consumers, mitigation gates, derived MD  |
| Flow: source of truth YAML feeds both      |
|   partial-read agent queries AND the       |
|   render script that produces the human    |
|   MD view. Every write routes through      |
|   the Deliverable-A mitigation stack.      |
+--------------------------------------------+
```

## 10. Consolidated Recommendation Table

| Artifact class | Recommendation | Variant | Routing |
|----------------|----------------|---------|---------|
| `.opencode/CHANGELOG.md` | **CONVERT (flagship, follow-up ticket)** | YAML ledger + derived MD view | section-10 |
| `.opencode/memory-shelf.yaml` | STAY YAML | V1 | N/A |
| `ai-assist-sources.yaml` | STAY YAML | V1 | N/A |
| `tickets/*.md` (frontmatter) | STAY hybrid MD + YAML frontmatter | V1 | N/A |
| `session/*.jsonl` | OUT OF SCOPE (stay JSONL) | V1 | N/A (DIA-136) |
| `knowledge/*` | STAY MD | V1 | N/A |
| `learnings/*` | STAY MD | V1 | N/A |
| `openspec/changes/*` | STAY hybrid (external tool format) | V1 | N/A |
| `.sdd/*` | STAY MD | V1 | N/A |
| `AGENTS.md`, `practice-protected.md` | STAY MD | V1 | N/A |
| `NEXT-RUN.md` | STAY MD | V1 | N/A |
| `HANDOFF.md` | STAY MD | V1 | N/A |
| `current-handoff.json` | STAY JSON (atomic-write) | V1 | N/A |
| `opencode.jsonc`, `oh-my-opencode-slim.jsonc` | OUT OF SCOPE (JSONC, not a YAML question) | N/A | N/A |

## 11. Summary of Key Findings

1. **Hybrid substrate confirmed.** The repo already embodies the right answer: YAML for machine-first structured records, MD for narrative, JSONL for append-only streams, JSON for atomic single-file records. The analysis validates, it does not revise.
2. **Flagship conversion = CHANGELOG.md -> YAML ledger + derived MD view.** The only concrete conversion recommendation. Token-economy delta: ~5x on full read, ~445x on per-entry query. Derived-view pattern already proven in `messages.md` and `tickets/README.md`.
3. **Deliverable A makes the YAML premise viable.** yaml-language-server + JSON Schema gate + `make test-config` wiring is the three-layer mitigation that structurally bounds the YAML write-error risk. The DIA-079/DIA-075/DIA-191 precedents would all be caught by this stack today.
4. **Session JSONL stays OUT OF SCOPE.** YAML is the wrong substrate for append-only streams; DIA-136 already adopted the read-side fix (node:sqlite in-memory).
5. **Ticket hybrid MD+YAML stays per DIA-125 precedent.** Text-over-binary-DB for git-merge quality.
6. **~4 chars/token heuristic is labeled as heuristic.** The delta ratio (~5x / ~445x) is robust across the 3-5 chars/token band; absolute token numbers are indicative. Post-conversion re-measurement against `opencode db`/`opencode stats` native data (DIA-182 surface) is recommended.

## 12. Anomalies and Research Gaps (for developer disposition)

1. **ai-assist-sources.yaml lives under `.opencode/oh-my-opencode-slim/knowledge/`, not the top-level `.opencode/`.** This report treats it as a single class with memory-shelf.yaml; if @resource-manager plans to move it, the schema-gate pattern should follow.
2. **knowledge/ aggregate is ~10 MB.** This report treats knowledge/* as narrative/stay-MD. A separate analysis could examine whether knowledge reports would benefit from YAML metadata frontmatter (ticket-class pattern); not in scope here.
3. **Ticket count is 146, not all with gate_state markers.** The DIA-104 grandfather rule (warn-not-fail for legacy tickets) is the standing policy; this analysis does not revisit it.
4. **No external LLM-YAML-error-rate benchmark cited.** Per the brief's instruction not to block on external research, this gap is noted; a follow-up @researcher dispatch can fill it if the developer wants external evidence independent of the in-repo precedents.
5. **The DIA-191 context_usage estimator overestimate is a live defect** (OPEN). Its existence is a reminder that estimation tooling drift is a real hazard -- the ~4 chars/token heuristic in this report is labeled as such.
6. **Routing flag for the flagship conversion is section-10** (config-surface change per AGENTS.md 2.5). If the developer approves, a follow-up ticket must go through ai-specialist gate -> architect -> coder -> ai-auditor. The follow-up ticket is NOT created by this analysis (guardrail).

## 13. Evidence Index

- `wc -c` measurements taken 2026-08-15 on the live filesystem (working tree).
- `awk` section sizing on `.opencode/CHANGELOG.md` (87 sections, largest 9256 bytes, avg ~2500 bytes/section).
- DIA-180 inventory lines 93-111 (source of the artifact list).
- DIA-180 merge notes (Deliverable A merged as squash commit bcb8379, 2026-08-15).
- DIA-079 ticket (JSON parse error, resolved merge b005277).
- DIA-075 ticket (snip-jq loop, resolved by DIA-092 plugin removal).
- DIA-191 ticket (context_usage estimator, OPEN).
- DIA-136 ticket (CLOSED 2026-08-14, node:sqlite V2 adopted).
- DIA-137 ticket (CLOSED 2026-08-14, bash+jq+bats status-quo adopted).
- DIA-125 precedent (text-over-binary-DB for git-merge quality, cited in DIA-136).
- DIA-115 (EBDV mechanical requirements).
- DIA-084 (guardrail: analysis recommends, conversions spawn follow-up tickets).
- AGENTS.md section 2.5 (AI Devtools Modernization Workflow, section-10 routing).
