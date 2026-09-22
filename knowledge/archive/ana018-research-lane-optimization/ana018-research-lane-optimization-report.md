# ana018 -- Research-Lane Optimization (Model/Variant + Fetch-Tool Design)

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: recommendation
evidence-source: knowledge/res024-model-variant-fetch-tools + knowledge/res013 + knowledge/res016 + knowledge/res017 + in-conversation ai-specialist gate (2026-08-13)
confidence: High
shelf-registration: .opencode/memory-shelf.yaml (shelf.analyses)
-->

**Ticket:** DIA-135 (OPEN)
**Author:** @analyzer
**Date:** 2026-08-13
**Methods applied:** EBDV (res022), MECE model-lane decomposition, 3-tier URL-class
fetch chain, cost/quota cross-check, model-family diversity audit, conflict
resolution between specialist recommendation and researcher lane-fit finding.
**Scope:** Synthesize the DIA-135 research conspect (res024) and the
ai-specialist section-10 gate variants into an evidence-backed recommendation
for the researcher and conspecter lanes of the research-pipeline. Produce
numbered conclusions the ticket can quote verbatim.
**Constraint:** ASCII-only output (DIA-079). No edits to config or
implementation. The ai-specialist gate variants are consumed from the
in-conversation input (not archived); all other evidence is Tier-1 shelf.

---

## 1. Executive Summary

- Both lanes (researcher + conspecter) KEEP deepseek-v4-flash as the default
  model. Flash is the highest-volume cheapest model on OpenCode Go
  ($0.14/$0.28, ~158K estimated req/mo) and its 1M context covers both
  volume retrieval and long MLA-cited synthesis. No model upgrade is
  cost-justified.
- Researcher R2: KEEP flash, temperature 0.7 -> 0.3, GAIN bash allow-list
  (curl, wget, trafilatura, crwl) + edit knowledge/*. Section-10-flagged.
- Conspecter C2: KEEP flash, add variant "low" + temperature 0.1, LOSE all
  bash post-D7 (synthesis-only). Section-10-flagged.
- Fetch-tool design: 3-tier chain by URL class -- npm JSON API for registry
  pages, trafilatura for static docs, crwl headless only as last-resort
  fallback. DIA-129 crwl-fragility risk flagged; cache-miss penalty
  documented.
- The researcher's independent lane-fit finding (deepseek-v4-pro or
  qwen3.7-plus as conspecter primary) is EXPLICITLY REJECTED in favor of
  specialist C2 (keep-flash + low variant + temp 0.1): the synthesis task is
  citation-formatting, not reasoning; flash 1M context is sufficient; C2
  aligns with the sibling artifact-producer pattern (coder/reviewer/
  memory-manager all temp 0.1).
- Cost/cross-lane check: the recommended pair stays on a single model family
  (DeepSeek flash), preserves 158K+70K=228K req/mo headroom within the
  $60/mo Go tier, and leaves the Copilot credits intact for coder-escalated
  (kimi-k3) + reviewer (gpt-5.3-codex) + ai-auditor (gpt-5.3-codex).

---

## 2. EBDV Matrices

Format follows res022 (EBDV). Per-variant: title, change-description,
evidence-sources (T1 = Tier-1 shelf; T2 = Tier-2 web-fresh URL+date),
pros/cons, effort, section-10-flag, Y-statement.

### 2.1 Researcher Lane Variants (R1 / R2 / R3)

| Variant | Title | Section-10 flag |
|---|---|---|
| R1 | Status-quo / abort (no change) | NO |
| R2 (REC) | KEEP flash + temp 0.7->0.3 + bash allow-list (curl/wget/trafilatura/crwl) + edit knowledge/* | YES |
| R3 | SWAP to qwen3.7-plus + temp 0.3 + same allow-lists | YES |

**R1 -- Status-quo / abort:**
- Change-description: no model, variant, temp, or permission change.
- Evidence-sources: T1 res024 sec 4.1 (lane-fit finding).
- Pros: zero change risk.
- Cons: (a) incompatible with D5 -- researcher needs bash for
  trafilatura/curl/crwl and edit for knowledge/*; (b) current temp 0.7
  is above the best-practices balanced ceiling of 0.5 (res022);
  (c) no fallback model is defined.
- Effort: none.

**R2 -- KEEP flash + temp 0.3 + bash allow-list + edit knowledge/* (RECOMMENDED):**
- Change-description: lower temperature from 0.7 to 0.3; GRANT bash
  allow-list (curl, wget, trafilatura, crwl); GRANT edit knowledge/*.
- Evidence-sources: T1 res024 sec 4.1 + sec 6; T1 res019 (DIA-126 live
  verification of the bash allow-list pattern).
- Pros: (a) matches the conspecter's battle-tested bash pattern from
  DIA-126; (b) lowest cost at $0.14/$0.28; (c) ~158K estimated req/mo
  volume headroom; (d) 1M ctx comfortably covers multi-source fetches;
  (e) allow-list already observed working live in this archival run
  (res024 sec 6).
- Cons: (a) the 4-tool allow-list must be kept in sync with D5;
  (b) bash adds a small risk of runaway curl loops (mitigated by the
  4-tool fixed list).
- Effort: low (one config block edit + 4 allow-list entries).

**R3 -- SWAP to qwen3.7-plus:**
- Change-description: replace flash with qwen3.7-plus; temp 0.7->0.3;
  same bash allow-list + edit knowledge/*.
- Evidence-sources: T1 res013 (qwen pricing), T1 res016 (qwen agentic
  rank), T1 res024 sec 3.1 (pricing table).
- Pros: (a) stronger reasoning (SWE-V 77.7%, GPQA 90.3%) for source-
  quality ratings; (b) multimodal (text + image) input.
- Cons: (a) 2.9x input cost ($0.40 vs $0.14 per M); (b) weak agentic
  rank (#107/129 per res016); (c) reasoning uplift is wasted on a
  retrieval-dominant lane; (d) above 256K the price jumps to $1.20/$4.80.
- Effort: low (config block swap).

**Recommendation R2 (abort R1 + R3):**
- Y-statement: "We keep deepseek-v4-flash for the researcher lane with
  temperature lowered to 0.3 and a 4-tool bash allow-list, because
  flash is the highest-volume cheapest Go model and the lane is
  retrieval-dominant, so that the retrieval-lane cost stays at $0.14/M
  input and the lane retains the 158K estimated req/mo headroom needed
  for multi-source archival runs."

**Recommendation R2 (abort R1 + R3):**
- Y-statement: "We keep deepseek-v4-flash for the researcher lane with
  temperature lowered to 0.3 and a 4-tool bash allow-list, because
  flash is the highest-volume cheapest Go model and the lane is
  retrieval-dominant, so that the retrieval-lane cost stays at $0.14/M
  input and the lane retains the 158K estimated req/mo headroom needed
  for multi-source archival runs."
- Effort: low (one model config block edit + 4 allow-list entries).

### 2.2 Conspecter Lane Variants (C1 / C2 / C3)

| Variant | Title | Section-10 flag |
|---|---|---|
| C1 | KEEP flash + remove bash (D7 minimal toolset) | YES |
| C2 (REC) | KEEP flash + variant "low" + temp 0.1 + remove bash | YES |
| C3 | SWAP primary to gpt-5-mini + flash fallback | YES |

**C1 -- KEEP flash, remove bash (minimal toolset):**
- Change-description: remove bash (allow-list -> deny); no variant or
  temperature change.
- Evidence-sources: T1 res024 sec 6.
- Pros: (a) D7 minimal toolset achieved; (b) source archival cleanly
  separated from synthesis.
- Cons: (a) no explicit variant or temperature set, so conspecter is
  less deterministic than its sibling artifact-producers (coder,
  reviewer, memory-manager all temp 0.1).
- Effort: low (permission edit only).

**C2 -- KEEP flash + variant "low" + temp 0.1 + remove bash (RECOMMENDED):**
- Change-description: add variant "low" (reasoning-effort low); set
  temperature 0.1; remove bash (allow-list -> deny).
- Evidence-sources: T1 res024 sec 6; T1 res013 (flash pricing);
  empirical baseline: 12 conspects in shelf (res013-res024) all
  produced correctly on flash with correct MLA citations.
- Pros: (a) matches sibling artifact-producer pattern (coder/reviewer/
  memory-manager all temp 0.1); (b) deterministic citation formatting
  via temp 0.1; (c) 1M ctx swallows full source set (res016: 25 srcs,
  res017: 21 srcs, res019: 10 srcs); (d) lowest Go price; (e) guard
  gate "if sources/ is empty do NOT proceed" already enforces ordering.
- Cons: (a) depends on researcher running first (mitigated by the guard
  gate, already in place).
- Effort: low (variant + temp + permission surface edit).

**C3 -- SWAP primary to gpt-5-mini + flash fallback:**
- Change-description: primary model becomes gpt-5-mini (Copilot
  credits); flash becomes fallback.
- Evidence-sources: T1 res013 (gpt-5-mini pricing), T1 res024 sec 3.1
  (pricing table).
- Pros: (a) OpenAI reasoning edge for citation formatting.
- Cons: (a) burns 1500/mo Copilot credits SHARED with coder-escalated
  (kimi-k3), reviewer (gpt-5.3-codex), and ai-auditor (gpt-5.3-codex);
  (b) SWE-V ~60% < flash 73.7%; (c) NOT on Go (opens a second billing
  surface); (d) no model-family conflict exists here to solve (unlike
  coder/reviewer where diversification was the point).
- Effort: medium (config block swap + fallback chain edit).

**Recommendation C2 (abort C1 + C3):**
- Y-statement: "We keep deepseek-v4-flash for the conspecter lane with
  explicit variant 'low' and temperature 0.1 and remove bash, because
  the synthesis task is citation-formatting (not reasoning), the 1M
  context is sufficient for typical conspect source sets, the temp-0.1
  pattern matches the sibling artifact-producer lanes, and the model-
  family conflict that justified coder/reviewer model swaps does not
  exist here."

**Recommendation C2 (abort C1 + C3):**
- Y-statement: "We keep deepseek-v4-flash for the conspecter lane with
  explicit variant 'low' and temperature 0.1 and remove bash, because
  the synthesis task is citation-formatting (not reasoning), the 1M
  context is sufficient for typical conspect source sets, the temp-0.1
  pattern matches the sibling artifact-producer lanes, and the model-
  family conflict that justified coder/reviewer model swaps does not
  exist here."
- Effort: low (one config block edit: variant + temperature + permission
  surface).

---

## 3. Cross-Check: Lane-Fit vs. Specialist Recommendation

### 3.1 The conflict to resolve

The conspect's section 4 lane-fit analysis observes that flash remains the
default for both lanes (sec 4.1, 4.2). A separate independent lane-fit
pass (researcher reasoning) noted that the conspecter lane could
theoretically benefit from deeper reasoning models -- deepseek-v4-pro
(GPQA 90.1, SWE-V 80.6, res017) or qwen3.7-plus (SWE-V 77.7, res016).
The specialist gate recommends C2 (keep-flash + low variant), not an
upgrade. The conflict: "why not upgrade conspecter to a stronger reasoner
for better MLA citation accuracy?"

### 3.2 Resolution -- C2 wins on four evidence-backed grounds

1. **Task decomposition:** the conspecter's job is synthesis + citation
   formatting. The citation accuracy problem is FORMAT adherence, not
   REASONING depth. Temperature 0.1 (C2) reduces format variance more
   effectively than a stronger reasoner at temperature 0.7. Evidence:
   the sibling artifact-producer lanes (coder/reviewer/memory-manager)
   all use temp 0.1.
2. **Context, not reasoning, is the binding constraint:** res024 section
   4.2 documents that conspecter input volume is driven by dozens of
   archived sources (res016: 25, res017: 21, res019: 10), each 30-1,100
   lines. 1M context on flash comfortably swallows this. Upgrading to
   qwen3.7-plus would jump input cost from $0.14 to $0.40/M (+2.9x) for
   zero context gain (both 1M).
3. **No model-family conflict exists here:** coder and reviewer use
   different model families (DeepSeek flash vs GPT-5.3 Codex) precisely
   to diversify failure modes on IMPLEMENTATION tasks where a single
   family's blind spot could corrupt code. The conspecter writes
   MARKDOWN, not code. The diversification benefit is zero; the cost
   (Copilot credits, res013) is real.
4. **Empirical confirmation:** the existing conspecter (flash, no
   explicit variant/temp) has produced res013-res024 in the shelf -- 12
   conspects with 6-25 archived sources each, all with correct MLA
   citations and zero evidence of reasoning failure. The empirical
   baseline is healthy.

### 3.3 Cross-lane cost check

```
+------------------+------------------+--------------------+---------------------+
| Lane             | Model            | Est. req/mo (Go)   | Credit surface      |
+------------------+------------------+--------------------+---------------------+
| coder (default)  | deepseek-v4-flash| ~158K              | Go $60/mo           |
| researcher (R2)  | deepseek-v4-flash| ~70K (half shared) | Go $60/mo (shared)  |
| conspecter (C2)  | deepseek-v4-flash| shared w/ researcher| Go $60/mo (shared) |
| coder-escalated  | kimi-k3          | 490 (binding cap)  | Go $15/mo           |
| reviewer         | gpt-5.3-codex    | n/a                | Copilot 1500/mo     |
| ai-auditor       | gpt-5.3-codex    | n/a                | Copilot 1500/mo (shared)|
| analyzer         | qwen3.7-plus     | moderate           | Go $60/mo           |
| analyzer-esc.    | gpt-5.6-luna     | low                | Go nano tier        |
+------------------+------------------+--------------------+---------------------+
```

- Researcher + conspecter share a single Go $60/mo surface (DeepSeek flash).
- Copilot credits remain intact for coder-escalated + reviewer + ai-auditor.
- No lane-family duplication (coder=DeepSeek, reviewer=Codex, analyzer=
  Qwen, coder-esc=Kimi, analyzer-esc=Luna, researcher+conspecter=DeepSeek
  flash). Diversification across 5 families on 7 lanes.

---

## 4. Fetch-Tool Design (D5 -- Researcher-Owns-Source-Capture)

### 4.1 Recommended 3-tier chain by URL class

```
+-----------------------------+------------+-------------------+------------------+
| URL class                   | Tier 1     | Tier 2            | Tier 3 (fallback)|
+-----------------------------+------------+-------------------+------------------+
| npm registry / npmjs.com/*  | npm JSON   | trafilatura on    | crwl headless    |
|                             | API        | resolved package  |                  |
|                             | (readme +  | page              |                  |
|                             | dist-tags) |                   |                  |
+-----------------------------+------------+-------------------+------------------+
| Static docs (readthedocs,   | trafilatura| curl + browser-UA | crwl headless    |
| aclanthology, docs.github,  | direct     | + trafilatura     |                  |
| opencode.ai, api-docs.deep- |            |                   |                  |
| seek, developers.openai)    |            |                   |                  |
+-----------------------------+------------+-------------------+------------------+
| JS-heavy platform pages     | trafilatura| curl + browser-UA | crwl headless    |
| (platform.openai.com,       | (partial:  | + trafilatura     | (needed for full |
| platform.kimi.ai, open-     | desc/price |                   | tables; DIA-129  |
| router.ai cards, npmjs.com  | but not    |                   | risk)            |
| SPA)                        | tables)    |                   |                  |
+-----------------------------+------------+-------------------+------------------+
| GitHub blob pages           | raw.github-| trafilatura on    | crwl             |
|                             | usercontent| HTML github pages |                  |
|                             | .com raw   |                   |                  |
|                             | markdown   |                   |                  |
+-----------------------------+------------+-------------------+------------------+
```

### 4.2 Tool roles

- **trafilatura**: best static extractor; official benchmark F-score 0.920
  (2026-08-04, 990 documents, res024 sec 5.1). Beats magic-html, justext,
  news-please, readability-lxml, resiliparse, goose3, boilerpy3, newspaper4k.
  Peer-reviewed (Barbaresi ACL 2021). LIMITATION: JS/SPA pages yield empty
  output.
- **npm JSON API**: `GET https://registry.npmjs.org/{package}` returns the
  packument with readme + dist-tags (res024 #19). First tier for npm URLs
  because npmjs.com pages are JS-heavy SPA.
- **curl + browser-UA**: transport-only, not extraction. Pair with
  trafilatura; confirmed to retrieve raw HTML from platform.openai.com but
  still yields 0 bytes through trafilatura when the target page is
  server-rendered JS.
- **crwl (crawl4ai CLI)**: `crwl <url> -o markdown`. The ONLY tier that
  succeeded on platform.openai.com (1,137-line capture vs 0 bytes from
  trafilatura). Use as last-resort fallback.

### 4.3 DIA-129 risk + caching note for crwl

- **DIA-129 crwl-fragility**: crwl depends on headless Chromium. Known
  failure mode: chromium launch failure under resource pressure (documented
  in res019). In the research-pipeline this means:
  - crwl must NEVER be the first attempt on any URL class.
  - A crwl failure should be logged as "crwl unavailable" and the URL
    skipped with a clear warning in the conspect's Works Cited (so the
    conspecter can mark the source as "partial capture" or exclude per
    DIA-072).
  - No automatic retry loop -- a failed crwl attempt is a hard signal to
    move on.
- **Caching note**: crwl captures are expensive (Chromium). If the same
  URL is fetched repeatedly within a session (e.g., re-reading during
  synthesis), cache the markdown output to a temp path keyed by URL hash
  and reuse it. The cache directory should be under .opencode/session/
  or /tmp/opencode/ (not committed), and cleared on session end.

---

## 5. Conspecter Minimal-Toolset Design (D7)

### 5.1 Permission surface: before vs. after

```
+-------------------+---------------------------+---------------------------+
| Permission key    | BEFORE (status-quo)       | AFTER (D7 / C2)           |
+-------------------+---------------------------+---------------------------+
| edit              | knowledge/* + memory-shelf| knowledge/* + memory-shelf|
|                   | (artifact-producer)       | (artifact-producer,       |
|                   |                           |  UNCHANGED)               |
+-------------------+---------------------------+---------------------------+
| bash              | curl, wget, trafilatura,  | deny                      |
|                   | crwl (allow-list)         | (source archival moves to |
|                   |                           |  researcher; conspecter   |
|                   |                           |  becomes synthesis-only)  |
+-------------------+---------------------------+---------------------------+
| read              | knowledge/* + project     | UNCHANGED                 |
|                   | tree (already sufficient) |                           |
+-------------------+---------------------------+---------------------------+
| task              | deny                      | UNCHANGED                 |
+-------------------+---------------------------+---------------------------+
```

### 5.2 Model config deltas (C2)

```
+------------------+---------------------------+---------------------------+
| Field            | BEFORE                    | AFTER (C2)                |
+------------------+---------------------------+---------------------------+
| model            | opencode-go/deepseek-v4-  | UNCHANGED                 |
|                  | flash                     |                           |
+------------------+---------------------------+---------------------------+
| variant          | (not set)                 | "low"                     |
|                  |                           | (reasoning-effort low)    |
+------------------+---------------------------+---------------------------+
| temperature      | (not set, defaults to     | 0.1                       |
|                  | provider default)         | (deterministic citation   |
|                  |                           |  formatting)              |
+------------------+---------------------------+---------------------------+
```

### 5.3 Section-10 flags

All four changes are section-10-flagged (AI-tooling config):
- Researcher: temperature edit + bash allow-list grant + edit grant
- Conspecter: variant add + temperature edit + bash revoke
- Implementation path: @ai-specialist Phase 1 gate (read-only research),
  then @coder under @architector design, then @ai-auditor independent
  review.

---

## 6. Conclusions

The ticket (DIA-135) may quote these verbatim. Each carries its evidence
tier and section-10 flag.

1. **KEEP deepseek-v4-flash for the researcher lane (R2).** Evidence: T1
   (res024 sec 4.1, res013). Flash is the highest-volume cheapest Go
   model ($0.14/$0.28, ~158K estimated req/mo) with 1M context; retrieval
   is cost-dominant, not reasoning-dominant. Lower temperature from 0.7 to
   0.3 for determinism. **Section-10 flag: YES.**

2. **GRANT the researcher bash allow-list (curl, wget, trafilatura, crwl)
   plus edit knowledge/*.** Evidence: T1 (res024 sec 5.2, res019 DIA-126
   live verification). The allow-list is exactly what D5 needs and matches
   the battle-tested conspecter pattern. **Section-10 flag: YES.**

3. **KEEP deepseek-v4-flash for the conspecter lane (C2) with variant
   "low" and temperature 0.1.** Evidence: T1 (res024 sec 4.2 + sec 6;
   empirical baseline: 12 conspects in shelf all produced correctly on
   flash). Sibling artifact-producer pattern (coder/reviewer/memory-manager
   all temp 0.1) confirms. **Section-10 flag: YES.**

4. **REVOKE conspecter bash post-D7.** Evidence: T1 (res024 sec 6, D7
   design). Source archival moves to researcher; conspecter becomes
   synthesis-only. Guard gate "if sources/ is empty do NOT proceed"
   already enforces ordering. **Section-10 flag: YES.**

5. **REJECT upgrading conspecter to deepseek-v4-pro or qwen3.7-plus.**
   Evidence: T1 (res013, res016, res024). Reasoning uplift is wasted on
   a citation-formatting task; no model-family conflict exists here; cost
   increases 2.9x-3.1x for zero context gain; burns Copilot credits
   shared with coder-escalated/reviewer/ai-auditor (C3) or opens a second
   billing surface (gpt-5-mini not on Go). **Section-10 flag: N/A
   (rejection, not a change).**

6. **Adopt the 3-tier fetch chain by URL class for D5.** Evidence: T1
   (res024 sec 5, res008). Tier 1 npm JSON API for registry pages;
   Tier 2 trafilatura (direct or after curl+browser-UA) for static docs;
   Tier 3 crwl headless ONLY as last-resort fallback. **Section-10 flag:
   N/A (tool design, not config).**

7. **Flag DIA-129 crwl-fragility risk as a hard constraint on D5.** crwl
   must NEVER be the first attempt; a crwl failure is a signal to skip
   the URL and mark it in the conspect's Works Cited per DIA-072. Cache
   crwl outputs per-URL-hash within a session to avoid repeat Chromium
   launches. **Section-10 flag: N/A (operational constraint).**

8. **Label all req/mo figures in the model registry as ESTIMATES.**
   Evidence: T1 (res024 sec 3.3 -- no provider publishes a literal
   requests-per-month quota; the Go doc numbers are derived from dollar
   caps + documented token patterns). Any quota-guard built on res023
   must carry this label. **Section-10 flag: N/A (registry convention).**

---

## Appendix A. Evidence Provenance

- **Tier-1 shelf sources (archived, committed):**
  - res024 -- DIA-135 research conspect (21 sources, 0 failures)
  - res013 -- OpenCode model pricing audit (DIA-108)
  - res016 -- Coder-escalated model evidence (DIA-111)
  - res017 -- Rung-3 benchmark evidence (DIA-116)
  - res019 -- OMO-slim version-gate (DIA-126 live verification)
  - res008 -- Source-archival fallbacks (DIA-072)
  - res022 -- EBDV format (DIA-115)
  - res023 -- Dispatch routing registry (DIA-133)
- **Tier-2 (in-conversation, not archived):**
  - ai-specialist section-10 gate variants (R1/R2/R3 + C1/C2/C3),
    supplied with the DIA-135 research request, 2026-08-13.
- **Excluded per DIA-072:** JS-rendered benchmark tables on OpenRouter
  model cards; Kimi platform price/limit tables.
