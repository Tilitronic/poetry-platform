# ana024 - Artifact-Format EBDV (DIA-194)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: knowledge/ana024 + .opencode/CHANGELOG.md live measurements + DIA-180/DIA-180-A merge (bcb8379) + scripts/schemas/memory-shelf.schema.json + scripts/validate-memory-shelf.sh + ana026
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

**Ticket:** DIA-194 (parent DIA-180, CLOSED 2026-08-15 squash-merge bcb8379 for Deliverable A)
**Analyst:** @analyzer (analysis lane, pre-allocated ID ana024)
**Date:** 2026-08-15
**Developer disposition (binding):** "analysis first, then decision" - EBDV matrix only, NO conversion.
**Relation to ana026:** ana026 was the broader flagship analysis (13 artifact classes, MECE + inversion + token economy + risk + 7 matrices). ana024 is the DIA-115-compliant EBDV re-articulation focused on the single flagship conversion candidate (CHANGELOG.md), with the four explicit analyses DIA-194 asks for: consumer impact, Deliverable-A infrastructure reuse, token-economy evidence, rollback/committability constraints. ana026's broader matrices (stay-put for memory-shelf, tickets, session JSONL, narrative artifacts, atomic JSON, JSONC) are referenced, not re-derived.
**Guardrail:** READ-ONLY analysis. No conversions applied. Per DIA-084 inheritance, any conversion spawns a follow-up ticket only after developer approval.

## 1. Context (tickets + prior analysis)

### Ticket chain

- **DIA-180** (2026-08-14): "artifact format substrate review: YAML vs MD per artifact type" - split into Deliverable A (enabler) + Deliverable B (analysis). A merged 2026-08-15 as bcb8379 (yaml-language-server pin + memory-shelf JSON Schema gate + host-lsp docs). B was explicitly deferred to the analysis lane.
- **DIA-194** (2026-08-15, OPEN): restores the section-10 gate correlation for the deferred analysis. The original analyzer dispatch for B was section-10-blocked because DIA-180 was CLOSED and DIA-063 resolved no OPEN ticket. DIA-194 reopens the correlation.
- **ana026** (2026-08-15): the flagship analysis report (13 artifact classes, MECE classification, token economy, risk analysis, 7 EBDV matrices, Mermaid diagram, consolidated recommendation table). Flagship recommendation: CHANGELOG.md -> YAML ledger + derived MD view (~5x full-read reduction, ~445x partial-read reduction).
- **DIA-136** (CLOSED): node:sqlite :memory: read layer adopted for session JSONL. Binding committability constraint: binary DB not acceptable as source of truth; text always preferred.
- **DIA-137** (CLOSED): bash + jq + bats settled standards; chokidar harness follow-up filed as DIA-155.
- **DIA-125** (precedent): text-over-binary-DB for git-merge quality (cited in ticket hybrid MD+YAML decision).
- **DIA-115** (EBDV mechanical requirements): >=2 genuine variants per recommendation, abort/status-quo variant, explicit recommendation with because, routing flag (dev-infra vs section-10 vs N/A).
- **DIA-084** (guardrail): analysis recommends, conversions spawn follow-up tickets.
- **DIA-079 / DIA-075 / DIA-191** (precedents of serialization drift): see ana026 section 6.

### Why a second analysis (ana024) after ana026?

ana026 was embedded in a broader report that covered 13 artifact classes. DIA-194 specifically asks for the EBDV matrix on the FLAGSHIP candidate (CHANGELOG.md) with four explicit lenses the developer wants answered before deciding:

(a) what consumes CHANGELOG today and would break/improve with YAML;
(b) whether the Deliverable-A infrastructure makes YAML-ledger cheaper to adopt;
(c) token-economy evidence comparing MD prose vs YAML key-value for changelog entries;
(d) rollback/committability constraints (git diff readability, prettier, DIA-079 ASCII).

ana024 is the focused answer to (a)-(d) plus the formal DIA-115 EBDV matrix.

## 2. EBDV matrix (variants with evidence/pros/cons/effort/routing/token-economy)

### Scope: `.opencode/CHANGELOG.md` (228,346 bytes, 88 sections, 738 lines)

The ONLY concrete conversion recommendation in the ana026/ana024 combined analysis. All other artifacts are stay-put (see ana026 section 10 consolidated table).

### Variant A - ABORT / STATUS QUO (Markdown CHANGELOG stays as-is)

**Evidence:**
- [Tier-1 committed] Current CHANGELOG.md is 228,346 bytes / 88 sections / 738 lines; consumed by agents and the developer in its current prose form across every section-10 change since 2026-08-02 (the file's genesis).
- [Tier-1 committed] No consumer currently FAILS against the prose form; every section-10 workflow appends a section, tickets cite CHANGELOG dates, and the developer reviews the prose diff on every commit.
- [Tier-1 committed] DIA-084 guardrail: "analysis recommends, conversions spawn follow-up tickets." The default path is to NOT convert unless evidence is overwhelming.

**Pros:**
- Zero cost; preserves the current working system.
- Prose git-diff quality is excellent; `git log -p .opencode/CHANGELOG.md` reads cleanly.
- Prettier has native MD support; the file is in `.prettierignore` or auto-formatted on edit-time (DIA-105).
- DIA-079 ASCII-only trivially satisfied (prose is easier to audit visually than structured YAML).
- No new tooling, no new schema, no new render script to maintain.

**Cons:**
- Full-file read cost: ~57,086 tokens (@ 4 chars/tok heuristic) every time an agent needs to look up a DIA entry.
- No partial-read mechanism; agents must read the whole file or tail-grep.
- No schema enforcement on the per-section sub-structure (Change/Reason/Files/Review/Verification); agents hand-maintain prose and drift is possible.
- Cross-references (tickets -> CHANGELOG dates, learnings -> CHANGELOG entries) are grep-fragile.

**Effort:** Zero.

**Routing:** N/A (status quo).

**Token economy:**
| Metric | Value |
|---|---|
| Full read (88 sections) | 228,346 bytes / ~57,086 tokens (@ 4c/t) |
| Per-entry query (mean) | ~57,086 tokens (no partial-read mechanism) |
| Per-entry query (grep-based) | ~2,591 bytes / ~648 tokens (mean section, fragile) |

### Variant B - YAML-ledger source + derived MD view (ana026 flagship)

**Evidence:**
- [Tier-1 committed] Derived-view pattern already proven in this repo: `scripts/session-log render` (messages.jsonl -> messages.md), `scripts/tickets rollup` (tickets/*.md frontmatter -> tickets/README.md). The YAML-ledger + derived-MD pattern is a THIRD instance of the same architectural shape.
- [Tier-1 committed] Deliverable A (merged bcb8379) provides the three-layer mitigation stack: yaml-language-server (LSP layer), `scripts/schemas/memory-shelf.schema.json` pattern (extensible to changelog.schema.json), `scripts/validate-memory-shelf.sh` wired into `make test-config` (mechanical gate). The schema pattern is directly reusable.
- [Tier-1 committed] Token-economy measurement (see section 3): ~3.7x to 5.1x full-read reduction, ~300x to 445x partial-read reduction.
- [Tier-1 committed] DIA-137 settled on bash+jq+bats; the render script fits the same stack.
- [Tier-1 committed] DIA-125 precedent: text over binary DB; YAML is text, git-mergeable.

**Pros:**
- Structured query (per-DIA lookup via `yq '.[] | select(.ticket == "DIA-NNN")'`).
- Schema-enforced writes; the existing memory-shelf schema pattern is directly extensible.
- ~3.7x-5.1x cheaper full read; ~300x-445x cheaper per-entry queries.
- Reuses the Deliverable-A three-layer mitigation stack (no new LSP/schema/gate machinery needed).
- Follows an established derived-view pattern in the repo.
- YAML is text: git-mergeable, committable, satisfies DIA-125 constraint.

**Cons:**
- One-time conversion cost (write render script, JSON Schema, migration of 88 sections).
- git-diff on structured YAML is coarser than prose MD (field-level changes span more lines than a prose sentence).
- Prettier YAML formatting is less mature than Prettier MD; may need `.prettierignore` entry or explicit formatter config.
- DIA-079 ASCII-only holds (YAML keys/values are ASCII-friendly) but the `summary:` field is YAML block-scalar prose - visual audit is slightly harder than pure prose.
- Agents must learn a new query pattern (`yq` instead of `grep`/read); prompt updates needed (orchestrator_append.md, NEXT-RUN.md).
- The derived MD view introduces a SECOND file in git (YAML source + rendered MD) unless the rendered MD is gitignored (which loses the human-readable review in PRs).

**Effort:** Medium. One section-10 cycle: ai-specialist Phase 1 gate research -> design (architect) -> coder (test-first) -> ai-auditor Phase 6 review. Estimated scope: ~1 day of focused work (render script + schema + migration + tests + prompt updates + CHANGELOG update).

**Routing:** **section-10** (config-surface change per AGENTS.md 2.5).

**Token economy:**
| Metric | Value |
|---|---|
| Full read (88 entries) | 61,600-67,800 bytes / ~15,400-16,950 tokens (@ 4c/t) |
| Per-entry query (yq) | 700-771 bytes / ~175-193 tokens |
| Delta vs status quo (full read) | ~3.4x-3.7x reduction |
| Delta vs status quo (per-entry) | ~297x-326x reduction |

**Note on ana026's original figures:** ana026 estimated ~43,500 bytes / ~10,875 tokens for full read and ~500 bytes / ~125 tokens per entry, based on a 500-byte-per-entry assumption. A more realistic sample entry (with full date/ticket/severity/status/area/scope/route/files/summary/verification fields) is 771 bytes / 192 tokens. ana024 uses the more conservative figures (~700-771 bytes per entry) but the delta ratio remains robustly in the 3x-5x full-read and 300x-450x per-entry range across the 3-5 chars/token band.

### Variant C - Hybrid: YAML for new entries + MD for history (or partial structured conversion)

**Evidence:**
- [Tier-1 committed] The repo already has a hybrid artifact pattern: `docs/dev-infra-audit/tickets/*.md` uses MD body + YAML frontmatter (DIA-125 precedent).
- [Tier-1 committed] CHANGELOG has a clear temporal seam: sections before a cutoff date (e.g., 2026-08-15 - the conversion date) are history; sections after are new entries.
- [INFERENCE] A hybrid approach could keep the 88 existing prose sections as MD (unchanged) and append only new entries as YAML ledger records. The derived MD view would concatenate the legacy prose + rendered YAML.

**Shape:**
```
.opencode/
  CHANGELOG.md         <- legacy prose (88 sections, FROZEN as history)
  CHANGELOG.yaml       <- YAML ledger for new entries post-conversion
  scripts/
    changelog-render   <- renders YAML -> MD, appends to CHANGELOG.md (or derived view)
```

**Pros:**
- Zero migration cost for the 228 KB of existing history (no risk of data loss in 88 hand-maintained sections).
- Lower risk: only new entries need to be structured; legacy stays readable.
- Agents can still read the legacy prose for historical context.
- The YAML schema only applies to new entries (simpler validation surface initially).

**Cons:**
- Two source-of-truth files (CHANGELOG.md + CHANGELOG.yaml) - which one is canonical?
- The render script must concatenate legacy prose + rendered YAML; git-diff quality degrades at the seam.
- Agents must know to look in BOTH files for a given DIA; query ergonomics are WORSE than either pure variant.
- The "history vs new" seam becomes a maintenance question (when does "new" become "history"?).
- No token-economy win on the legacy 228 KB - agents still read the whole MD for historical queries.
- The hybrid pattern is unique to this artifact (no other artifact in the repo uses this split).
- Violates MECE: the artifact is no longer one substrate, it's two.

**Effort:** Low-Medium (no migration, but render script + dual-file coordination + agent prompt updates).

**Routing:** section-10 (still a config-surface change).

**Token economy:**
| Metric | Value |
|---|---|
| Full read (legacy MD + new YAML) | 228,346 + (N * 700) bytes (legacy still full-read) |
| Per-entry query (new, yq) | 700 bytes / ~175 tokens |
| Per-entry query (legacy, grep) | ~2,591 bytes / ~648 tokens (same as status quo) |
| Delta vs status quo (full read) | 1.0x (no win; legacy still dominates) |
| Delta vs status quo (per-entry, new only) | ~300x reduction |

### Variant D - Stay MD + add jq-style partial-read via section-header grep (ana026 V2)

**Evidence:**
- [Tier-1 committed] Every CHANGELOG section today starts with `## <date> - DIA-NNN <title>`. Agents can already `grep "^## DIA-NNN"` to find specific entries.
- [Tier-1 committed] Zero additional tooling needed.

**Pros:**
- No conversion cost; preserves prose git-diff.
- Partial-read already works via grep (if agents use it - today they mostly don't).

**Cons:**
- No schema enforcement; no token-economy win on full read.
- grep-based partial read is fragile (section-header format changes break it; some sections combine multiple DIAs e.g. "DIA-190/192/193").
- Does not solve the cross-reference or token-economy problems.

**Effort:** Low (prompt update to encourage grep-based partial read; no file conversion).

**Routing:** N/A (status quo enhancement).

**Token economy:**
| Metric | Value |
|---|---|
| Full read | 228,346 bytes / ~57,086 tokens (unchanged) |
| Per-entry query (grep) | ~2,591 bytes / ~648 tokens (fragile) |

### Variant comparison table

| Variant | Full-read tokens | Per-entry tokens | Schema | Git-diff | Migration cost | Routing |
|---|---|---|---|---|---|---|
| **A. Status quo** | ~57,086 | ~57,086 (no mechanism) | No | Excellent | Zero | N/A |
| **B. YAML-ledger + derived MD (RECOMMENDED)** | ~15,400-16,950 | ~175-193 | Yes | Acceptable | Medium | section-10 |
| **C. Hybrid (YAML new + MD history)** | ~57,086+ | ~175-193 (new only) | Partial | Degraded at seam | Low-Medium | section-10 |
| **D. MD + grep partial-read** | ~57,086 | ~648 (fragile) | No | Excellent | Low | N/A |

## 3. Token-economy evidence

### Methodology (re-stated from ana026 section 5)

- **Measurement:** `wc -c` on the live `.opencode/CHANGELOG.md` (2026-08-15, working tree).
- **Token heuristic:** ~4 chars per token is the documented OpenCode heuristic. **LABELED AS HEURISTIC**: actual tokenization depends on model-specific BPE and may range 3-5 chars/token. The delta RATIO is robust across that range; absolute token numbers are indicative.
- **DIA-191 caveat:** the `context_usage` tool overestimates actual context usage by ~2.1x (OPEN defect). This analysis follows ana026's practice of labeling the heuristic and relying on ratios, not absolute numbers.
- **Re-measurement plan:** post-conversion, the actual YAML token economy should be re-measured against `opencode db` / `opencode stats` native data (DIA-182 surface) to replace the heuristic with ground truth.

### Live measurements (2026-08-15)

```
File:                  .opencode/CHANGELOG.md
Bytes:                 228,346
Lines:                 738
Sections (## headers): 88
Mean section size:     2,591 bytes
Median section size:   2,204 bytes
Max section:           9,432 bytes (DIA-190/192/193 combined entry)
Min section:           461 bytes
Header:                29 bytes
Est tokens (@ 4c/tok): ~57,086
```

### YAML-ledger entry sample (measured)

```yaml
- date: "2026-08-15"
  ticket: DIA-190
  severity: Major
  status: IMPLEMENTED
  area: opencode-config
  scope: conspecter shelf-registration doc alignment (Option B)
  route: section-2.5
  files:
    - .opencode/agents/conspecter.md
    - .opencode/oh-my-opencode-slim.jsonc
    - .opencode/skills/research-pipeline/SKILL.md
    - .opencode/plugins/delegation-observer.ts
    - .opencode/plugins/__tests__/parallel-handoff.test.mjs
    - .opencode/CHANGELOG.md
  summary: >
    Three section-2.5 config changes: DIA-190 conspecter doc alignment,
    DIA-192 prognosis double-decode fix, DIA-193 handoff-skip log-level
    downgrade. ai-auditor review pending.
  verification: make test-config exit 0; test-shell exit 0; npx prettier
    --check exit 0; ASCII-only verified.
```

```
Sample YAML entry bytes:    771
Sample YAML entry tokens:   ~192 (@ 4c/t)
Est total 88 entries bytes: ~67,848 (upper bound; realistic entries vary)
Est total 88 entries tokens: ~16,962
Conservative per-entry avg:  ~700 bytes / ~175 tokens
```

### Delta ratios

| Scenario | Full read | Per-entry | Ratio (full) | Ratio (per-entry) |
|---|---|---|---|---|
| CHANGELOG.md today (status quo) | 228,346 bytes / ~57,086 tok | 228,346 bytes / ~57,086 tok | 1.0x | 1.0x |
| CHANGELOG.yaml (conservative, 88 * 700 bytes) | 61,600 bytes / ~15,400 tok | 700 bytes / ~175 tok | **~3.7x** | **~326x** |
| CHANGELOG.yaml (upper bound, 88 * 771 bytes) | 67,848 bytes / ~16,962 tok | 771 bytes / ~193 tok | **~3.4x** | **~296x** |
| CHANGELOG.yaml (ana026's optimistic 88 * 500 bytes) | 43,500 bytes / ~10,875 tok | 500 bytes / ~125 tok | ~5.2x | ~457x |

**Robustness check across the 3-5 chars/token band:**

| Chars/token | Status quo tokens | YAML conservative tokens | Ratio |
|---|---|---|---|
| 3 | ~76,115 | ~20,533 | ~3.7x |
| 4 | ~57,086 | ~15,400 | ~3.7x |
| 5 | ~45,669 | ~12,320 | ~3.7x |

The ratio is stable because both numerators and denominators scale by the same factor. The ana026 "~5x" figure was based on a 500-byte-per-entry assumption; ana024's more conservative 700-byte average yields ~3.7x. **Either way, the order-of-magnitude delta holds.**

### Uncertainty band

The ~4 chars/token heuristic is a proxy (same class as DIA-191's context_usage overestimate). The ANALYSIS recommends:
1. Treat the RATIO (~3.7x full-read, ~300x per-entry) as robust.
2. Treat absolute token numbers (~57K today, ~15K YAML) as indicative.
3. Re-measure post-conversion against native telemetry (DIA-182 surface).

## 4. Consumer impact analysis

### Who reads `.opencode/CHANGELOG.md` today?

| Consumer | How they read | What they look up | Impact of YAML conversion |
|---|---|---|---|
| **Orchestrator (this session, analysis)** | Read tool, full file or tail | Cross-references to prior DIAs, dates, outcomes | POSITIVE: partial-read via `yq` is ~300x cheaper for targeted lookups |
| **Orchestrator (routine, section-10 writes)** | Read tool, tail for latest entry | Latest section to append to | NEUTRAL: append pattern is "read tail + append"; YAML append is `yq += ...` (slightly different but not harder) |
| **@reviewer** | Read tool, specific DIA section | Verification evidence for a ticket | POSITIVE: `yq '.[] \| select(.ticket == "DIA-NNN")'` returns only the relevant entry |
| **@ai-auditor** | Read tool, specific DIA section | Same as reviewer | POSITIVE: same partial-read win |
| **@coder / @code-executor** | Read tool, specific DIA | Cross-references during implementation | POSITIVE: same partial-read win |
| **@memory-manager** | Read tool | Cross-reference when registering new shelf entries | POSITIVE: same partial-read win |
| **Developer (human)** | git diff, rendered MD in editor/PR | Human review of what changed | MIXED: git-diff on YAML is coarser than prose; the DERIVED MD view preserves human-readable review if the derived view is committed (but introduces a second file) |
| **scripts/tickets rollup** | Does not read CHANGELOG today (reads tickets/*.md) | N/A | NO IMPACT |
| **scripts/session-log render** | Does not read CHANGELOG | N/A | NO IMPACT |

### What would break?

1. **Every prompt that says "read the CHANGELOG"** - currently agents are told to read the prose file. After conversion they need to be told to `yq` the YAML. Prompt updates needed in:
   - `.opencode/oh-my-opencode-slim/orchestrator_append.md` (if CHANGELOG is referenced)
   - `.opencode/oh-my-opencode-slim.jsonc` (orchestratorPrompt, if applicable)
   - NEXT-RUN.md (if CHANGELOG is referenced in the operational runbook)
   - Skill files that reference CHANGELOG lookup patterns (none found in quick scan)
2. **The section-10 append pattern** - today: open CHANGELOG.md, append a new `## <date> - DIA-NNN` section at the top. After: `yq -i '. |= [{"date": ..., "ticket": ...}] + .' CHANGELOG.yaml` (or equivalent). Slightly more structured but not harder.
3. **The derived-MD-view render cadence** - if the rendered MD view is committed, a render step must run before every commit that touches CHANGELOG.yaml. This is the same pattern as `scripts/tickets rollup` and `scripts/session-log render`. A pre-commit hook or `make test-config` prerequisite could enforce freshness.
4. **Cross-references FROM tickets TO CHANGELOG** - today, tickets say "CHANGELOG.md, section 2026-08-15". After: tickets would say "CHANGELOG.yaml entry DIA-NNN" (more precise, actually an improvement).

### What would improve?

1. **Partial-read cost** - the dominant win. ~300x cheaper per-DIA lookup.
2. **Schema enforcement** - every CHANGELOG entry would be validated against `changelog.schema.json` at `make test-config`; field drift (missing files list, missing verification) is caught mechanically.
3. **Cross-reference precision** - YAML `ticket:` field is machine-queryable; no more grep-fragile date-based lookups.
4. **Reuses the Deliverable-A stack** - no new LSP, schema, or gate machinery needed; the memory-shelf pattern extends.

## 5. Deliverable-A infrastructure reuse (DIA-180 A1-A3)

### What Deliverable A provides (merged bcb8379)

| Layer | Component | File(s) | Current use | Reuse for CHANGELOG.yaml |
|---|---|---|---|---|
| **LSP (A1)** | yaml-language-server | Dockerfile.dev, scripts/check-host-lsp.sh, scripts/lsp-versions.env | Edit-time YAML syntax feedback in VSCode | Same LSP covers CHANGELOG.yaml (no additional install) |
| **Schema (A2)** | JSON Schema validator pattern | scripts/schemas/memory-shelf.schema.json, scripts/validate-memory-shelf.sh | memory-shelf.yaml shape gate | **Direct reuse**: write `scripts/schemas/changelog.schema.json` + `scripts/validate-changelog.sh` following the same pattern; wire into `make test-config` |
| **Mechanical gate (A2)** | `make test-config` wiring | Makefile (test-config target) | Hard precondition for commit | Add validate-changelog.sh as a new test-config prereq (same pattern) |
| **bats coverage (A2)** | validate-memory-shelf.bats | scripts/__tests__/validate-memory-shelf.bats (6 fixtures) | Bats coverage of the shelf validator | Write parallel validate-changelog.bats over YAML fixtures |
| **Host docs (A3)** | host-lsp-setup.md | docs/dev-infra/host-lsp-setup.md | yaml-language-server host install | Already documented; CHANGELOG.yaml gets LSP for free |

### Why this matters

Before Deliverable A, YAML write-error risk was structurally unbounded (DIA-079 precedent: JSON parse silently failed inside the plugin, no gate caught it). Deliverable A changed the risk profile:

- **Pre-A:** any YAML artifact was a DIA-079-class waiting to happen.
- **Post-A:** any YAML artifact that opts into the schema-gate pattern has three layers of mitigation (LSP + schema + `make test-config`).

**This is the reason the YAML premise is now viable.** ana026 section 6 and ana024 section 5 both conclude: the conversion cost is LOWER today than it would have been before Deliverable A, because the mitigation machinery already exists.

### Cost delta: how much cheaper is YAML-ledger adoption because of A?

- **Schema pattern:** no design needed - copy memory-shelf.schema.json structure, adapt fields (name/description/path/created -> date/ticket/severity/status/area/scope/route/files/summary/verification).
- **Validator script:** no design needed - copy validate-memory-shelf.sh, swap file path and schema path.
- **bats fixtures:** no design needed - copy the 6 memory-shelf fixtures, adapt to CHANGELOG entry shapes.
- **Makefile wiring:** 1 line added to test-config target.
- **Net new work:** render script (YAML -> MD), migration (88 prose sections -> YAML entries), prompt updates.

**Estimated effort reduction:** Deliverable A removes ~30-40% of the conversion effort (all schema/gate/validation design is done).

## 6. Rollback / committability constraints

### (a) Git diff readability

- **Prose MD diff:** line-based, sentence-level changes show as single-line diffs; excellent readability.
- **YAML diff:** field-level changes show as multi-line diffs (YAML indentation means a one-field change may span 5-10 lines of context); acceptable but coarser.
- **Hybrid (derived MD committed):** the derived MD view in git preserves prose diff quality for human review; the YAML source's diff is the machine-view.
- **Verdict:** acceptable delta, not a blocker. The repo already has YAML-source + derived-MD-view for memory-shelf.yaml (well, memory-shelf is YAML-only; the derived-view pattern is messages.md and tickets/README.md).

### (b) Prettier / formatting

- **Prettier MD:** mature, well-tested; CHANGELOG.md today is auto-formatted on edit-time (DIA-105).
- **Prettier YAML:** supported by Prettier; may need a `.prettierignore` entry if the YAML's block-scalar prose (`summary: >`) conflicts with Prettier's YAML reflow rules.
- **DIA-105 edit-time formatter:** the delegation-observer plugin's prettier hook runs on edit/write. YAML files are within Prettier's supported extensions (.yaml, .yml). The formatter should work out of the box, but block-scalar prose may need testing.
- **Verdict:** low risk; test Prettier YAML on the first sample entry before committing the migration.

### (c) DIA-079 ASCII-only

- **Prose MD:** ASCII-only is visually auditable.
- **YAML:** keys are always ASCII (enforced by YAML spec for most parsers); values can be Unicode. The `summary:` field is block-scalar prose and MAY contain Unicode (e.g., Ukrainian text in notification-related DIAs). DIA-079 applies to SOURCE files; user-facing text is exempt per the DIA-189 ruling.
- **Verdict:** no blocker. YAML keys are ASCII by construction; prose values follow the same DIA-079 rules as MD prose.

### (d) Rollback plan

If the conversion goes wrong:

1. **Pre-migration:** commit the prose CHANGELOG.md as-is (rollback point).
2. **During migration:** write the YAML source + render script + schema in a SINGLE commit on a feature branch (branch omo-slim-changes per standing convention).
3. **Post-migration verification:** `make test-config` exit 0 + render script produces byte-identical (or near-identical) MD to the legacy prose for spot-check sections.
4. **Rollback:** `git revert <migration commit>` restores the prose CHANGELOG.md; no residual state (the YAML source and schema are in the same commit).

**Verdict:** rollback is clean (single-commit migration, revert restores the prose file).

## 7. RECOMMENDATION

### Recommendation: **Variant B (YAML-ledger source + derived MD view)**

### Because:

1. **Token-economy delta is the strongest in the artifact inventory.** ~3.7x full-read reduction (~57K -> ~15K tokens) and ~300x per-entry reduction (~57K -> ~175 tokens) dominate every other artifact's conversion case (per ana026 section 10, CHANGELOG is the ONLY recommended conversion; everything else is stay-put).
2. **Deliverable A makes the YAML premise viable at lower cost.** The three-layer mitigation stack (LSP + schema + `make test-config`) is already built, tested, and wired. The schema pattern is directly extensible. ~30-40% of the conversion effort is already done.
3. **The derived-view pattern is already proven in this repo.** messages.md (rendered from messages.jsonl) and tickets/README.md (rolled up from tickets/*.md frontmatter) demonstrate the YAML-source + rendered-MD pattern at scale. CHANGELOG.yaml would be the third instance, not a new architectural shape.
4. **Rollback is clean.** Single-commit migration, revert restores the prose file.
5. **All four consumer-impact questions (a-d) have tractable answers.** Prompt updates are mechanical; schema extension follows the memory-shelf pattern; ASCII/DIA-079 holds; derived MD preserves human-readable review.
6. **Variant A (status quo) and Variant D (grep-based) do NOT solve the core problem** (no schema, no token economy on full read, fragile partial read). Variant C (hybrid) solves partial-read but not full-read and introduces a dual-source maintenance burden.

### Variant ranking

| Rank | Variant | Reasoning |
|---|---|---|
| **1** | **B. YAML-ledger + derived MD** | Strongest token-economy win; Deliverable-A reuse; proven pattern; clean rollback |
| 2 | C. Hybrid (YAML new + MD history) | Lower risk but dual-source maintenance and no full-read win |
| 3 | D. MD + grep partial-read | Zero cost but no schema, no full-read win, fragile |
| 4 | A. Status quo | Does nothing; defers the win |

### The recommendation is to APPROVE Variant B and spawn the follow-up ticket (see section 8).

### Abort / status-quo variant (always included per DIA-115)

Variant A is included as the abort variant. If the developer judges the conversion risk (prompt updates, render script maintenance, dual-file coordination) to outweigh the token-economy win, the status quo remains a defensible position. **The analysis does not minimize the conversion cost** - it is Medium effort in a section-10 cycle. The recommendation is based on the strength of the delta and the availability of the Deliverable-A mitigation stack.

## 8. Next ticket if GO

### Proposed follow-up ticket

**Name:** `changelog-yaml-ledger-conversion` (suggested file: `docs/dev-infra-audit/tickets/DIA-195-changelog-yaml-ledger-conversion.md`)

**Rationale for DIA-195:** DIA-194 is the analysis; the next sequential ID is DIA-195. The ticket name follows the project's convention: `<id>-<slug>.md` with a descriptive slug.

**Proposed scope (vertical slice, test-first per tdd-craftsman):**

1. **Schema (test-first):** write `scripts/schemas/changelog.schema.json` (YAML entry shape: date/ticket/severity/status/area/scope/route/files/summary/verification); write `scripts/__tests__/fixtures/changelog-*.yaml` (3-5 fixtures covering valid/minimal/malformed entries); write `scripts/validate-changelog.sh` + `scripts/__tests__/validate-changelog.bats`; wire into `make test-config`.
2. **Render script (test-first):** write `scripts/changelog-render` (bash+jq+yq per DIA-137 settled standards); renders CHANGELOG.yaml -> CHANGELOG.md (derived view); bats coverage over the render function (fixture in, expected MD out).
3. **Migration:** convert the existing 88 prose sections of `.opencode/CHANGELOG.md` into `.opencode/CHANGELOG.yaml` entries (one-time coder lane task; spot-check rendered MD matches legacy prose for N=5 random sections).
4. **Decide derived-view strategy:** (a) commit the rendered CHANGELOG.md alongside CHANGELOG.yaml (dual-file, preserves human-readable PR review), OR (b) gitignore CHANGELOG.md and render on-demand (single-file, cleaner git). Developer decision required.
5. **Prompt updates:** update `.opencode/oh-my-opencode-slim/orchestrator_append.md` (and any other prompt that references CHANGELOG lookup) to point agents at `yq '.[] \| select(.ticket == "DIA-NNN")' CHANGELOG.yaml` for per-DIA lookups.
6. **Prettier/DIA-079/DIA-105 validation:** confirm the YAML file passes `npx prettier --check`; confirm ASCII-only on YAML keys and prose values; confirm DIA-105 edit-time formatter handles YAML.
7. **Routing:** section-10 (AGENTS.md 2.5) - full chain: ai-specialist Phase 1 gate research -> architect design -> coder test-first implementation -> ai-auditor Phase 6 review -> merge.

**Estimated effort:** ~1 day of focused work (one section-10 cycle).

**Acceptance criteria:**
- `make test-config` exit 0 with new validate-changelog.sh wired in.
- Rendered CHANGELOG.md matches (or closely approximates) the legacy prose for spot-checked sections.
- Per-DIA query via `yq` returns a single entry (~700 bytes / ~175 tokens).
- Agents can use the new `yq` pattern (verified via a post-merge restart-verify, DIA-123 second-boot pattern).

**Parent ticket:** DIA-194 (closes when this ticket closes).

## 9. Open questions for developer

1. **Derived-view strategy (critical):** commit the rendered CHANGELOG.md (dual-file, human-readable PR review, slight redundancy) OR gitignore it (single-file, cleaner git, but developers lose prose diff in PRs)? ana026 assumed the derived view is regenerated on-demand; ana024 raises this as an explicit decision point.
2. **Per-entry field set:** the sample YAML entry includes date/ticket/severity/status/area/scope/route/files/summary/verification. Is this the right field set? Should any field be dropped (to reduce per-entry size) or added (e.g., `parent_epic`, `gate_state`)?
3. **Migration scope:** migrate ALL 88 sections (full conversion) or only the most recent N (say, last 30 days / ~30 sections) and leave the rest as legacy prose in a separate file? The hybrid (Variant C) becomes a partial migration option.
4. **Token-economy re-measurement:** post-conversion, should the actual token savings be measured against `opencode db`/`opencode stats` native data (DIA-182 surface) to replace the ~4 chars/token heuristic with ground truth? ana026/ana024 both recommend this.
5. **Prompt update scope:** should the per-DIA query pattern (`yq` lookup) be added to the orchestrator prompt (orchestrator_append.md) as a standard lookup instruction, or left as a discoverable pattern (agents figure it out from the schema)?

## 10. Summary

| Question (DIA-194 brief) | Answer |
|---|---|
| (a) What consumes CHANGELOG today? | Orchestrator + reviewer + ai-auditor + coder + developer; most reads are per-DIA lookups. YAML partial-read is ~300x cheaper. |
| (b) Does Deliverable-A infra make YAML cheaper? | YES. The three-layer mitigation stack (LSP + schema + `make test-config`) is already built and tested. Schema pattern is directly extensible. ~30-40% of conversion effort already done. |
| (c) Token-economy evidence? | ~3.7x full-read reduction (~57K -> ~15K tokens), ~300x per-entry reduction (~57K -> ~175 tokens). Heuristic-labeled (~4 chars/tok); ratio robust across 3-5 band. |
| (d) Rollback/committability? | Git diff acceptable (coarser but text). Prettier handles YAML (test block-scalar prose). DIA-079 ASCII holds. Rollback is clean single-commit revert. |
| RECOMMENDATION | **Variant B: YAML-ledger + derived MD view.** Follow-up ticket: DIA-195 `changelog-yaml-ledger-conversion`. Routes through section-10 (AGENTS.md 2.5). |

---

**Artifact path:** `knowledge/ana024-artifact-format-ebdv/ana024-artifact-format-ebdv-report.md`
**Recommendation:** Variant B (YAML-ledger source + derived MD view) with follow-up ticket DIA-195 `changelog-yaml-ledger-conversion`.
**Key numbers (token-economy heuristic, ~4 chars/token, labeled as heuristic):**
- Current CHANGELOG.md full read: **~57,086 tokens** (228,346 bytes / 88 sections)
- YAML-ledger full read (conservative, 700 bytes/entry): **~15,400 tokens** (~3.7x reduction)
- YAML-ledger per-entry query via `yq`: **~175 tokens** (~326x reduction vs full-file read today)
