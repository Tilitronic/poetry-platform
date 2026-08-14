# DIA-135 - research-pipeline optimization: order corruption + double source fetch + binary persistence decision

<!-- UPDATE 2026-08-13 (DEVELOPER REFINEMENTS ROUND 2 - FOUR ADDITIONAL
     REQUIREMENTS): the developer extended DIA-135 with four refinements
     that reshape the reordered pipeline. D5 RESEARCHER-DOWNLOADS-INTO-SOURCES:
     the RESEARCHER lane (not the conspecter) must download every source into
     knowledge/<resid>-<topic>/sources/ using AI-optimized fetch tools
     (trafilatura markdown extraction / crawl4ai headless / curl with
     browser-UA / registry JSON API - the 3-tier fallback chain currently
     used by conspecter Phase A moves to the researcher). The researcher owns
     Phase A source capture; this structurally eliminates the double-fetch
     defect D2 (no second trafilatura pass by a conspecter). D6 SOURCE QUALITY
     EVALUATION: the researcher MUST evaluate each source for RELEVANCE (does
     it answer the research question) and RELIABILITY (authority, recency,
     independence, vendor-vs-independent) before archiving, and record a
     per-source relevance/reliability rating (e.g. High/Med/Low each) in the
     sources/.source-urls.txt manifest (or an adjacent per-source rating
     line); the conspect must only cite sources that pass the evaluation,
     with excluded sources listed under Unarchived/Excluded with reason.
     D7 CONSPECTER MINIMAL TOOLSET: the conspecter becomes a PURE SYNTHESIS
     lane - it must NOT download or fetch from the network at all; its tools
     shrink to: read sources/ + knowledge/*, write the conspect +
     .source-urls.txt already populated by researcher, register in
     memory-shelf. Remove curl/trafilatura/crwl/playwright from conspecter
     permissions (it only reads what the researcher archived and writes the
     conspect). This is a §10 permission change (agent config). D8
     MODEL-VARIANT OPTIMIZATION ASSESSMENT: before finalizing the pipeline,
     assess whether the models and model variants assigned to researcher,
     conspecter (and related pipeline lanes) are the most optimized choice -
     using the archived evidence (res013/res016/res017 pricing+benchmarks,
     res022 EBDV format, DIA-133 registry design) produce an evidence-backed
     variant comparison (>=2 variants per lane, Tier-1/Tier-2 evidence,
     recommendation, abort/status-quo) for researcher and conspecter lane
      models; change only with developer approval via §10. All four
      refinements are §10-routable (agent permissions + model config). -->

<!-- UPDATE 2026-08-13 (ROUND 3 - RESEARCH + ANALYSIS CYCLE COMPLETE): the
     D8 model-variant assessment and D5 fetch-tool research are DONE and
     archived. Artifacts: res024 (knowledge/res024-model-variant-fetch-tools/
     res024-model-variant-fetch-tools-conspect.md, 21/21 sources archived,
     0 failures) and ana018 (knowledge/ana018-research-lane-optimization/
     ana018-research-lane-optimization-report.md, EBDV matrix + 8 numbered
     conclusions). ai-specialist section-10 gate recommendation: researcher
     R2 (keep deepseek-v4-flash, temp 0.7->0.3, gain bash allow-list
     curl/wget/trafilatura/crwl + edit knowledge/*) and conspecter C2 (keep
     deepseek-v4-flash, add variant low + temp 0.1, lose all bash post-D7).
     CHANGE PENDING DEVELOPER APPROVAL via section-10 - no config edits made. -->

<!-- UPDATE 2026-08-14 (IMPLEMENTED - section-10 coder lane, restart-verify
     pending): all 8 ana018 conclusions + arc-1 design IMPLEMENTED and
     validated (test-config exit 0, drift gate 3 presets x 8 markers 0 gaps,
     test-shell 286 bats 0 failures, node --check clean, prettier clean).
     Changes: research-pipeline SKILL.md reordered (ID pre-allocation ->
     researcher-owns-Phase-A -> binary KEEP/DELETE -> pure-synthesis conspect
     -> analysis gate); OMO agent configs across all 3 presets (researcher
     temp 0.7->0.3 + Phase A prompt block with 3-tier chain + D6 quality
     manifest; conspecter variant low + temp 0.1 + pure-synthesis prompt;
     free preset researcher model aligned to opencode/deepseek-v4-flash;
     ANALYSIS GATE rule in all 3 orchestrator prompts); opencode.jsonc
     permissions (researcher bash allow-list curl/wget/trafilatura/crwl +
     edit knowledge/* deny-first; conspecter bash flat deny + memory-shelf
     edit allow per D7); delegation-observer.ts analysis-pending.json gate
     mirroring persistence-pending.json; model-registry ESTIMATE labels per
     C8. Status stays OPEN - closure is a separate lane (ai-auditor Phase 6
     + disposition). No CHANGELOG entry (closure-lane responsibility). -->

---

id: DIA-135
title: "research-pipeline optimization: order corruption + double source fetch + binary persistence decision"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
discovered: 2026-08-13
source: fix-lane
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Developer-raised process defect (2026-08-13) in the research-pipeline
workflow (research-pipeline skill, DIA-057/DIA-058 gate). Three concrete
defects + one strictness gap:

D1 ORDER CORRUPTION: the conspect artifact exists to make ANALYSIS
efficient (a synthesis an analyzer consumes instead of raw findings), but
the pipeline runs analysis BEFORE the conspect exists. Observed:
ana-2/ana-3/ana-4 (DIA-113/098/102) consumed raw researcher findings;
res021/res022 conspects were created in parallel/after. Desired order:
research -> archive sources -> conspect -> verify -> analysis (analysis
consumes the conspect).

D2 DOUBLE SOURCE FETCH: the researcher fetches every URL (webfetch) to
write findings; the conspecter Phase A then re-downloads every URL via
trafilatura/crawl4ai (3-tier chain). Observed duplication: res021 13
URLs, res022 10 URLs - every source fetched twice, wasted tokens + time.

D3 DECISION FRAMING: the persistence decision was presented as 'persist
vs skip', which the developer reads as 'do nothing vs do the research
flow once more'. Required framing: binary KEEP (archive + register
conspect) vs DELETE (discard artifacts; findings remain only in the
ticket). No re-do-the-flow option.

D4 STRICTNESS: nothing mechanically prevents analysis from being
dispatched before a conspect is verified. Need a gate analogous to the
research-persistence gate: analysis dispatch is BLOCKED until conspect
artifacts are verified (or developer explicitly skips analysis).

### Developer refinements (round 2, 2026-08-13)

Four additional requirements reshape the reordered pipeline:

D5 RESEARCHER-DOWNLOADS-INTO-SOURCES: the RESEARCHER lane (not the
conspecter) must download every source into knowledge/<resid>-<topic>/
sources/ using AI-optimized fetch tools (trafilatura markdown extraction /
crawl4ai headless / curl with browser-UA / registry JSON API - the 3-tier
fallback chain currently used by conspecter Phase A moves to the
researcher). The researcher owns Phase A source capture; this structurally
eliminates the double-fetch defect D2 (no second trafilatura pass by a
conspecter).

D6 SOURCE QUALITY EVALUATION: the researcher MUST evaluate each source for
RELEVANCE (does it answer the research question) and RELIABILITY
(authority, recency, independence, vendor-vs-independent) before archiving,
and record a per-source relevance/reliability rating (e.g. High/Med/Low
each) in the sources/.source-urls.txt manifest (or an adjacent per-source
rating line); the conspect must only cite sources that pass the evaluation,
with excluded sources listed under Unarchived/Excluded with reason.

D7 CONSPECTER MINIMAL TOOLSET: the conspecter becomes a PURE SYNTHESIS lane

- it must NOT download or fetch from the network at all; its tools shrink
  to: read sources/ + knowledge/\*, write the conspect + .source-urls.txt
  already populated by researcher, register in memory-shelf. Remove
  curl/trafilatura/crwl/playwright from conspecter permissions (it only reads
  what the researcher archived and writes the conspect). This is a section-10
  permission change (agent config).

D8 MODEL-VARIANT OPTIMIZATION ASSESSMENT: before finalizing the pipeline,
assess whether the models and model variants assigned to researcher,
conspecter (and related pipeline lanes) are the most optimized choice -
using the archived evidence (res013/res016/res017 pricing+benchmarks,
res022 EBDV format, DIA-133 registry design) produce an evidence-backed
variant comparison (>=2 variants per lane, Tier-1/Tier-2 evidence,
recommendation, abort/status-quo) for researcher and conspecter lane
models; change only with developer approval via section-10.
Current assignment (as of 2026-08-13, active preset `cebula`):
researcher = opencode-go/deepseek-v4-flash (variant low, temperature 0.7,
read-only: edit/bash/task deny); conspecter = [github-copilot/gpt-5-mini,
opencode-go/deepseek-v4-flash, opencode/deepseek-v4-flash] (bash
curl/wget/trafilatura/crwl allow, edit knowledge/\* + memory-shelf.yaml).
Other presets: opencode-go -> researcher deepseek-v4-flash low / conspecter
deepseek-v4-flash; free -> researcher opencode/deepseek-v4-pro variant low.

All four refinements are section-10-routable (agent permissions + model
config).

### Research + analysis cycle (round 3, 2026-08-13)

The D8 model-variant assessment and D5 fetch-tool research ran the full
research pipeline (researcher + ai-specialist section-10 gate + conspecter +
analyzer). Artifacts:

- Conspect: `knowledge/res024-model-variant-fetch-tools/res024-model-variant-fetch-tools-conspect.md` (21/21 sources archived, 0 failures; registered in memory shelf)
- Analysis: `knowledge/ana018-research-lane-optimization/ana018-research-lane-optimization-report.md` (EBDV matrix, registered in memory shelf)

Numbered conclusions (verbatim from ana018, evidence tiers as marked):

1. KEEP deepseek-v4-flash for the researcher lane (R2). Evidence: T1 (res024 sec 4.1, res013). Flash is the highest-volume cheapest Go model ($0.14/$0.28, ~158K estimated req/mo) with 1M context; retrieval is cost-dominant, not reasoning-dominant. Lower temperature from 0.7 to 0.3 for determinism. Section-10 flag: YES.
2. GRANT the researcher bash allow-list (curl, wget, trafilatura, crwl) plus edit knowledge/\*. Evidence: T1 (res024 sec 5.2, res019 DIA-126 live verification). The allow-list is exactly what D5 needs and matches the battle-tested conspecter pattern. Section-10 flag: YES.
3. KEEP deepseek-v4-flash for the conspecter lane (C2) with variant "low" and temperature 0.1. Evidence: T1 (res024 sec 4.2 + sec 6; empirical baseline: 12 conspects in shelf all produced correctly on flash). Sibling artifact-producer pattern (coder/reviewer/memory-manager all temp 0.1) confirms. Section-10 flag: YES.
4. REVOKE conspecter bash post-D7. Evidence: T1 (res024 sec 6, D7 design). Source archival moves to researcher; conspecter becomes synthesis-only. Guard gate "if sources/ is empty do NOT proceed" already enforces ordering. Section-10 flag: YES.
5. REJECT upgrading conspecter to deepseek-v4-pro or qwen3.7-plus. Evidence: T1 (res013, res016, res024). Reasoning uplift is wasted on a citation-formatting task; no model-family conflict exists here; cost increases 2.9x-3.1x for zero context gain; burns Copilot credits shared with coder-escalated/reviewer/ai-auditor (C3) or opens a second billing surface (gpt-5-mini not on Go). Section-10 flag: N/A (rejection, not a change).
6. Adopt the 3-tier fetch chain by URL class for D5. Evidence: T1 (res024 sec 5, res008). Tier 1 npm JSON API for registry pages; Tier 2 trafilatura (direct or after curl+browser-UA) for static docs; Tier 3 crwl headless ONLY as last-resort fallback. Section-10 flag: N/A (tool design, not config).
7. Flag DIA-129 crwl-fragility risk as a hard constraint on D5. crwl must NEVER be the first attempt; a crwl failure is a signal to skip the URL and mark it in the conspect's Works Cited per DIA-072. Cache crwl outputs per-URL-hash within a session to avoid repeat Chromium launches. Section-10 flag: N/A (operational constraint).
8. Label all req/mo figures in the model registry as ESTIMATES. Evidence: T1 (res024 sec 3.3 -- no provider publishes a literal requests-per-month quota; the Go doc numbers are derived from dollar caps + documented token patterns). Any quota-guard built on res023 must carry this label. Section-10 flag: N/A (registry convention).

NEXT STEP (section-10): developer approves/rejects conclusions 1-8 -> @architector design -> @coder implement -> validate -> @ai-auditor. DEFERRED 2026-08-13 by developer decision: queue for the orchestrator's open-tickets sweep in the next session. Ticket stays OPEN; no config edits made.

## Verification

- [x] Current pipeline order documented (research -> decision -> conspect -> verify -> analysis) with the order-corruption evidence (ana-2/3/4 consumed raw findings; res021/res022 created after/in-parallel).
- [x] Double-fetch quantified (res021 13 URLs, res022 10 URLs fetched twice) + redesign proposed that eliminates re-download (e.g. researcher archives sources during research and conspecter reuses; or researcher returns fetched content; or shared fetch cache).
- [x] Binary persistence decision framing specified (KEEP vs DELETE; no re-do-the-flow option) - applied to the research-pipeline skill Phase 2.
- [x] Mechanical gate designed: analysis dispatch blocked until conspect verified (analogous to persistence-pending.json gate; e.g. analysis-pending.json or an extension of the existing gate).
- [x] Pipeline reorder: research -> archive -> conspect -> verify -> analysis, with analysis consuming the conspect.
- [x] Section-10 routing: the research-pipeline skill change + any delegation-observer/plugin gate change must route through the section-10 chain (ai-specialist gate -> developer decide -> design -> coder -> validate -> ai-auditor). Flag which parts are skill (section-10 YES), which are agent-prompt (YES), which are dev-infra script (NO).
- [x] D5: researcher downloads all sources into sources/ via AI-optimized tools (trafilatura/crawl4ai/curl/registry-JSON) - single fetch, no conspecter re-download (double-fetch eliminated, quantified)
- [x] D6: researcher records per-source relevance + reliability rating in .source-urls.txt manifest; conspect cites only passing sources; excluded sources listed with reason
- [x] D7: conspecter toolset reduced to read sources/ + knowledge/\* + write conspect + memory-shelf (no curl/trafilatura/crwl/playwright) - §10 permission change applied + verified
- [x] D8: model-variant optimization assessment delivered for researcher + conspecter lanes (EBDV format per res022, >=2 variants per lane, evidence-tiered, developer-approved via §10)

## Fix

> IMPLEMENTED 2026-08-14 (section-10 coder lane, branch omo-slim-changes).
> Committed as b6ddc8e - see commit message. All 8 ana018
> conclusions applied exactly; arc-1 design implemented file-by-file below.
> Status stays OPEN: closure is a separate lane (ai-auditor Phase 6
> independent review + developer disposition). Restart-verify pending:
> config changes take effect on next OpenCode run; functional smoke test
> (researcher Phase A dispatch + conspecter pure-synthesis dispatch) belongs
> to the closure lane.

### D1 ORDER CORRUPTION - pipeline reordered (skill + prompts)

- `.opencode/skills/research-pipeline/SKILL.md` rewritten to the 5-phase
  order: Phase 1 ID pre-allocation (L13), Phase 2 Research + Phase A Source
  Capture owned by researcher (L16), Phase 3 binary persistence decision
  (L34), Phase 4 pure-synthesis conspect (L48), Phase 5 Analysis Gate (L60).
  Analysis now consumes the conspect, never raw findings.

### D2 DOUBLE SOURCE FETCH - structurally eliminated (D5)

- The researcher owns Phase A source capture: single fetch into
  `knowledge/<resid>-<topic>/sources/`; the conspecter never re-downloads.
  `.opencode/skills/research-pipeline/SKILL.md` L16-33;
  `.opencode/oh-my-opencode-slim.jsonc` researcher orchestratorPrompt
  PHASE A block at L187 (opencode-go), L411 (cebula), L592 (free).

### D3 DECISION FRAMING - binary KEEP vs DELETE

- `.opencode/skills/research-pipeline/SKILL.md` L34-47: developer decides
  KEEP (archive + register conspect) or DELETE (discard artifacts; findings
  remain only in the ticket). No re-do-the-flow option.

### D4 STRICTNESS - mechanical analysis gate

- Plugin: `.opencode/plugins/delegation-observer.ts` L1991-2044 adds the
  ANALYSIS GATE detector mirroring the persistence-pending mechanism: a
  COMPLETED conspecter task with a conspect-indicating result drops
  `.opencode/session/analysis-pending.json`
  `{ session_id, agent, detected_at, status: "pending_verification" }`
  (same write path mkdirSync+writeFileSync, same TUI-safe ctx.client.app.log,
  same fail-soft console.warn).
- Prompts: ANALYSIS GATE rule added to the orchestrator prompt in all 3
  presets - `.opencode/oh-my-opencode-slim.jsonc` L26 (opencode-go), L209
  (cebula), L433 (free): analysis dispatch BLOCKED while the file exists;
  verify conspect artifacts via read, edit JSON to `{ "status": "verified" }`
  to clear; developer skip via `status: "skipped"`.
- Skill: `.opencode/skills/research-pipeline/SKILL.md` L60-66 documents the
  gate procedure.

### D5 RESEARCHER-DOWNLOADS-INTO-SOURCES

- Permissions: `.opencode/opencode.jsonc` L360-379 - researcher gains bash
  allow-list `{ "*": "deny", "curl *", "wget *", "trafilatura *", "crwl *" }`
  (deny-first per DIA-126 findLast pattern) and edit
  `{ "*": "deny", "knowledge/*": "allow" }`; task stays deny.
- Prompts: 3-tier chain by URL class in the researcher PHASE A block (Tier 1
  npm registry JSON API; Tier 2 trafilatura direct or after curl+browser-UA;
  Tier 3 crwl headless LAST-RESORT ONLY - crwl never first attempt, crwl
  failure = skip URL + mark per DIA-072, crwl outputs cached per-URL-hash).

### D6 SOURCE QUALITY EVALUATION

- Researcher must rate each source RELEVANCE + RELIABILITY (High/Med/Low
  each) and record ratings in `sources/.source-urls.txt`; conspect cites
  only passing sources; excluded sources listed with reason. Prompts L187/
  L411/L592 step 3-5; skill L22-25; conspecter prompt L608 step 2 enforces
  "cite ONLY sources that pass the researcher's evaluation (D6)".

### D7 CONSPECTER MINIMAL TOOLSET (pure synthesis)

- Permissions: `.opencode/opencode.jsonc` L406-424 - bash flat `"deny"`
  (curl/wget/trafilatura/crwl allow-list removed), webfetch stays deny,
  task stays deny; edit map gains `.opencode/memory-shelf.yaml: allow` so the
  conspecter can register its own artifact (D7 register-in-memory-shelf is a
  mechanical enabler restored per historical precedent 753e374).
- Prompt: `.opencode/oh-my-opencode-slim.jsonc` L608 - conspecter prompt is
  now single-phase PURE SYNTHESIS: reads only sources/, no network fetch of
  any kind, writes MLA-cited conspect, registers in memory-shelf under
  shelf.conspects, guard gate "if sources/ is empty or missing, do NOT
  proceed".

### D8 MODEL-VARIANT OPTIMIZATION (C1/C3, free-preset alignment)

- C1: researcher temperature 0.7 -> 0.3 in all 3 presets
  (`.opencode/oh-my-opencode-slim.jsonc` L177 / L401 / L583).
- C3: conspecter variant "low" + temperature 0.1 in all 3 presets
  (L132-136 opencode-go, L290-294 cebula, L509-513 free).
- Free preset: researcher model `opencode/deepseek-v4-pro` ->
  `opencode/deepseek-v4-flash` (L580) - developer-approved alignment per C1.

### C8 REGISTRY CONVENTION

- `knowledge/model-registry.yaml` L8/L20/L32/L44/L56/L68/L80: every
  `req_per_month` value carries the inline comment
  `# ESTIMATE (per res024 sec 3.3)`.

### Validation evidence (all gates exit 0)

- `make test-config`: exit 0 - drift gate
  `check-orchestrator-prompt-drift: 3 preset(s) checked, 8 markers each,
0 gaps`; validate-decision-variants 104/104; agent-name cross-ref, output
  contracts, reviewer sections, handoff, ticket-gate, tool-coverage audit
  (20 agents, 0 gaps), JSONC syntax all pass.
- `make test-shell`: exit 0 - 286 bats, 0 failures.
- `node --experimental-strip-types --check delegation-observer.ts`: clean.
- `npx --no-install prettier --check` on all 6 edited files: clean.
- DIA-105 formatter hook, DIA-123 session_boot, DIA-120 isSafeTaskBatch,
  DIA-098 stall/watchdog untouched (plugin change is additive in the
  tool.execute.after task() hook, after the persistence-pending block).

## Re-verify

> To be filled at re-verify time.
