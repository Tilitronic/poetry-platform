# DIA-135 Research-Pipeline Optimization: Model/Variant Selection for Researcher + Conspecter Lanes, and AI-Optimized Source-Fetch Tools (res024)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 21
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

Metadata: res024 | created 2026-08-13 | DIA-135 (OPEN) | type: research conspect
Scope: model/variant optimization for the researcher and conspecter lanes of the
research-pipeline (D5: model routing; D8: AI-optimized source-fetch tooling).
Cross-references: res008 (DIA-072 archival fallbacks), res013 (Go pricing audit),
res014 (escalation routing), res016/017 (kimi-k3 / deepseek-v4-pro evidence),
res019 (DIA-126 archival, crwl/DIA-129), res022 (EBDV format), res023 (registry design).

---

## 1. Executive Summary

This conspect grounds the DIA-135 research-pipeline optimization in 21 freshly
archived sources (0 failures; one source required the crawl4ai headless tier).
Four findings:

1. Per-model pricing/context for the five pipeline candidates, plus the DeepSeek
   API concurrency limits (flash 2500, pro 500). No literal requests-per-month
   quota is published anywhere: OpenCode Go caps usage in DOLLARS ($12/5h,
   $30/wk, $60/mo) and publishes only ESTIMATED request counts per model;
   DeepSeek publishes concurrency; OpenAI publishes RPM/TPM/tiered spend;
   Moonshot publishes rate-limit concepts only.
2. Lane-fit: deepseek-v4-flash remains the correct default for BOTH researcher
   (volume retrieval at $0.14/$0.28, ~158K estimated req/mo) and conspecter
   (1M context for long MLA-cited synthesis at the lowest Go price).
3. Fetch-tool comparison: trafilatura is the best static extractor (current
   official benchmark F-score 0.920, 2026-08-04; historically up to 0.925
   precision) but returns nothing on JS/SPA pages; crawl4ai (crwl) is the only
   JS-capable tier but is heavyweight (headless Chromium); curl+browser-UA is
   transport-only; the npm registry JSON API exposes readme-as-JSON for npm
   pages. Recommended 3-tier chain by URL class is given in section 5.
4. The ai-specialist gate EBDV recommendation: researcher R2 (keep
   deepseek-v4-flash, temp 0.7 -> 0.3, gain bash allow-list
   curl/wget/trafilatura/crwl + edit knowledge/*) and conspecter C2 (keep
   deepseek-v4-flash, add variant "low" + temp 0.1, lose all bash post-D7).
   Evidence that R2's bash allow-list is already in effect was observed live in
   this archival run (the bash permission surface matched exactly).

## 2. Source Manifest (21 archived, 0 failed)

Archival tiers used: T2 trafilatura direct; T3 curl + browser-UA + trafilatura;
T4 crawl4ai headless (crwl); JSON raw fetch for GitHub-hosted markdown.

| # | Slug | Source | Relevance | Reliability | Tier |
|---|---|---|---|---|---|
| 1 | openrouter-deepseek-v4-flash | OpenRouter model card | High (identity, ctx, OR price) | Medium (JS benchmark tables not captured) | T2 |
| 2 | openrouter-deepseek-v4-pro | OpenRouter model card | High (identity, ctx, OR price) | Medium (JS benchmark tables not captured) | T2 |
| 3 | openrouter-gpt-5-mini | OpenRouter model card | High (identity, ctx, cutoff) | Medium (JS benchmark tables not captured) | T2 |
| 4 | openrouter-qwen3.7-plus | OpenRouter model card | High (identity, modalities, OR price) | Medium (JS benchmark tables not captured) | T2 |
| 5 | openrouter-kimi-k3 | OpenRouter model card | High (identity, ctx, OR price) | Medium (JS benchmark tables not captured) | T2 |
| 6 | deepseek-api-docs | DeepSeek official API docs | High (model IDs, OpenAI/Anthropic compat) | High (vendor primary) | T2 |
| 7 | deepseek-rate-limit | DeepSeek official rate-limit page | High (concurrency 500/2500, 429 semantics) | High (vendor primary) | T2 |
| 8 | openai-dev-gpt-5-mini | OpenAI developer model card | High (pricing, ctx, rate tiers) | High (vendor primary) | T2 |
| 9 | openai-dev-rate-limits | OpenAI developer rate-limit guide | High (RPM/RPD/TPM/TPD, usage tiers) | High (vendor primary) | T2 |
| 10 | openai-platform-rate-limits | OpenAI platform rate-limit guide | High (same family as #9; headers detail) | Medium (crwl capture is navigation-heavy) | T4 |
| 11 | kimi-platform-chat-k3 | Moonshot platform pricing page | Medium (description + reasoning fields; price table JS-rendered, missing) | Medium (partial capture) | T2 |
| 12 | kimi-platform-limits | Moonshot platform limits page | High (concurrency/RPM/TPM/TPD concepts, $1 min recharge) | Medium (no per-model numbers in archive) | T2 |
| 13 | openrouter-docs-limits | OpenRouter limits docs | High (credit limits, 429/402, no monthly quota) | High (vendor primary) | T2 |
| 14 | trafilatura-docs | Trafilatura project docs | High (features, output formats) | High (project primary) | T2 |
| 15 | trafilatura-evaluation | Trafilatura official benchmark | High (F-score table, 2026-08-04 + history) | High (project primary, reproducible) | T2 |
| 16 | aclanthology-trafilatura-paper | Barbaresi ACL 2021 system demo | High (peer-reviewed benchmark claim) | High (peer-reviewed; citation record captured) | T2 |
| 17 | crawl4ai-docs | Crawl4AI project docs | Medium (capabilities; marketing-heavy) | Medium | T2 |
| 18 | crawl4ai-cli-docs | Crawl4AI CLI reference | High (crwl invocation, output formats) | High (project primary) | T2 |
| 19 | npm-registry-api-docs | npm Public Registry API spec | High (packument/readme-as-JSON endpoints) | High (project primary) | JSON raw |
| 20 | opencode-go-docs | OpenCode Go subscription docs | High (Go pricing, dollar caps, req estimates, endpoints) | High (vendor primary) | T2 |
| 21 | github-copilot-models-pricing | GitHub Copilot billing reference | High (per-1M pricing incl. GPT-5 mini, Kimi K3) | High (vendor primary) | T2 |

## 3. (a) Model Pricing/Context Table, Concurrency Limits, and the No-Quota Finding

### 3.1 Per-model pricing and context (the five DIA-135 candidates)

Primary pricing authority for the pipeline lanes is OpenCode Go (the subscription
the project actually uses); OpenRouter/OpenAI/GitHub list prices are shown for
cross-check. All prices are USD per 1M tokens.

| Model | Go input/output | Go cached read | Go usage tier | OpenRouter price | Context | Notes |
|---|---|---|---|---|---|---|
| deepseek-v4-flash | $0.14 / $0.28 | $0.0028 | $60/mo | $0.0679 / $0.168 | 1M | 284B total / 13B active MoE, hybrid attention; reasoning high/xhigh; released 2026-04-24 |
| deepseek-v4-pro | $0.435 / $0.87 | $0.003625 | $15/mo | $0.4225 / $0.845 | 1M | 1.6T total / 49B active MoE; reasoning high/xhigh; released 2026-04-24 |
| gpt-5-mini | NOT on Go | - | - | $0.25 / $2.00 | 400K (128K max output) | OpenAI $0.25/$2.00; GitHub Copilot $0.25/$0.025/$2.00; cutoff May 2024; released 2025-08-07; successor to o4-mini |
| qwen3.7-plus | $0.40 / $1.60 (<=256K); $1.20 / $4.80 (>256K) | $0.04 / $0.12 | $60/mo | $0.32 / $1.28 | 1M | multimodal text+image input, text output; GUI/mobile-app agent capability; released 2026-06-03 |
| kimi-k3 | $3.00 / $15.00 | $0.30 | $15/mo | $2.40 / $12.00 | 1M | 2.8T open-weight; GitHub Copilot $3.00/$0.30/$15.00; reasoning_effort low/high/max; released 2026-07-16 |

Sources: #20 (Go prices, tiers, cached read), #1/#2/#3/#4/#5 (OpenRouter prices,
context, release dates, parameter counts), #8 (GPT-5 mini OpenAI price/context/
output), #21 (GPT-5 mini and Kimi K3 GitHub Copilot prices), #11 (Kimi K3
reasoning_effort and context-caching fields).

### 3.2 Concurrency limits (DeepSeek API)

Source #7 is the ONLY archive that publishes a hard per-model concurrency number:

- deepseek-v4-flash: concurrency limit 2500 per account
- deepseek-v4-pro: concurrency limit 500 per account
- Account-level regardless of API key; requests above limit receive HTTP 429;
  capacity expansion is free on request; per-user_id isolation optional.

These are DeepSeek-hosted API concurrency caps, distinct from OpenCode Go's
dollar-valued usage caps (the Go subscription routes through OpenCode Zen).

### 3.3 Finding: no literal req/month quota is published anywhere

Across all 21 archives, no provider publishes a hard requests-per-month quota
for these models:

- OpenCode Go (#20): caps are DOLLAR-valued -- $12 per 5 hours, $30 per week,
  $60 per month. The per-model request counts in the Go docs table (e.g.,
  DeepSeek V4 Flash 31,650 per 5h / 79,050 per week / 158,150 per month; Kimi
  K3 110/250/490) are EXPLICITLY labeled "estimated request count based on
  typical Go usage patterns", i.e. estimates, not quotas. The 6x multiplier
  rationale is documented ($10/mo buys ~$60 of usage).
- DeepSeek API (#7): publishes concurrency (500/2500), not monthly request
  quotas.
- OpenAI (#8, #9, #10): publishes RPM, RPD, TPM, TPD per usage tier
  (Tier 1 500 RPM / 500K TPM up to Tier 5 30,000 RPM / 180M TPM) plus a
  monthly DOLLAR usage limit per organization ($100 to $200,000 per month).
  No requests/month quota.
- Moonshot (#11, #12): publishes rate-limit CONCEPTS (concurrency, RPM, TPM,
  TPD) and a $1 minimum recharge, but no per-model numbers in the archived
  pages (tables are JS-rendered).
- OpenRouter (#13): publishes credit limits and per-key limits, free-variant
  per-minute/per-day limits, and DDoS protection; no monthly request quota.

Implication for the DIA-135 quota-guard design (res023): any "req/mo cap"
implemented in the model registry must be labeled ESTIMATE and derived from
the Go dollar caps + documented token patterns, not from a published quota.

## 4. (b) Lane-Fit Analysis: researcher vs conspecter

### 4.1 Researcher lane (volume retrieval)

Profile: high request volume, short prompts, many small fetches and lookups,
tolerance for lower reasoning depth, cost-sensitive. Go estimates (#20):
DeepSeek V4 Flash ~158,150 req/mo at $0.14/$0.28 with 1M context -- the
highest-volume cheapest model on Go. Concurrency 2500 (#7) removes any
headroom concern for bursty retrieval.

Fit verdict: deepseek-v4-flash is the right researcher default. Its 1M context
accommodates reading multiple archived sources per turn; its price makes
high-volume retrieval affordable within the $60/mo Go tier. No model upgrade
is justified for the researcher lane: qwen3.7-plus is 2.9x the input price for
marginal retrieval benefit, and kimi-k3 is 21x the input price with a binding
490 req/mo estimate (#20).

### 4.2 Conspecter lane (long-context MLA-cited synthesis)

Profile: moderate request volume, LONG inputs (reads many archived source files
per conspect), heavy output writing, needs reliable instruction following and
citation accuracy. Context is the binding constraint: conspects cite dozens of
sources (res023: 6-25+ sources per conspect), and trafilatura-extracted pages
run 30-1,100 lines each.

Fit verdict: deepseek-v4-flash also fits the conspecter lane: 1M context
swallows the full source set of typical conspects (res016: 25 sources;
res017: 21 sources; res019: 10 sources), and the $0.14/$0.28 price keeps
synthesis cheap. The "low reasoning" variant + temp 0.1 (C2, section 6)
targets deterministic citation formatting rather than deeper reasoning.
Escalation, if ever needed, follows the res014/res017 ladder (flash ->
qwen3.7-plus -> deepseek-v4-pro / kimi-k3), but no archived evidence in this
conspect's source set shows the researcher/conspecter lanes hitting Go caps
at current volume.

## 5. (c) Fetch-Tool Comparison and Recommended 3-Tier Chain by URL Class

### 5.1 Tool comparison

trafilatura (static extraction, fails JS):
- Current official benchmark (2026-08-04, 990 documents, 2,951 text + 2,966
  boilerplate segments): trafilatura 2.2.0 standard F-score 0.920 (precision
  0.906 / recall 0.943 / accuracy 0.917); recall mode F 0.918; precision mode
  F 0.920 (#15). Historical peak precision 0.925 (trafilatura 0.8.2 fast,
  2021-06-07) and 0.924 (trafilatura 0.6.0, 2020-11-06) (#15).
- Best static open-source extractor in the current table: beats magic-html
  0.889, justext 0.862, news-please 0.836, readability-lxml 0.826,
  resiliparse 0.811, goose3 0.810, boilerpy3 0.807, newspaper4k 0.801 (#15).
- Peer-reviewed claim: "The tool performs significantly better than other
  open-source solutions in this evaluation and in external benchmarks"
  (Barbaresi 2021, ACL demo, #16).
- LIMITATION confirmed live in this archival run: JS/SPA pages yield empty or
  partial output. OpenRouter model cards (#1-#5) returned description + price
  but NOT the JS-rendered benchmark tables; platform.openai.com (#10) returned
  0 bytes through trafilatura on both direct fetch and curl+UA raw HTML.

crawl4ai / crwl (only JS/SPA-capable tier, heavyweight):
- Headless-browser crawler; CLI `crwl <url> -o markdown` / `-O <path>` (#18);
  output formats: all/json/markdown/markdown-fit; supports YAML browser config,
  CSS/LLM extraction, BM25/pruning filters, Q&A, --bypass-cache (#18).
- It is the ONLY tier that succeeded on platform.openai.com (#10): a 1,137-line
  capture with the full rate-limits article (vs 0 bytes from trafilatura).
- Cost: heavyweight (Chromium); known failure mode documented in res019
  (DIA-129 chromium launch failure). Use as the last resort tier only.

curl + browser-UA (transport only):
- Fetches raw HTML with a browser User-Agent; confirmed working for
  platform.openai.com (Astro server-rendered HTML retrieved), but the
  retrieved HTML still yielded 0 extracted bytes through trafilatura (#10).
  It is transport, not extraction; pair it with trafilatura or crwl.

npm registry JSON API (readme-as-JSON for npm pages):
- `GET https://registry.npmjs.org/{package}` returns the packument whose
  `readme` field is the full text of the latest version README; `dist-tags`
  gives the latest version; `GET /{package}/{version}` and
  `GET /-/v1/search` (with author:/maintainer:/scope:/keywords: qualifiers)
  round out the surface (#19).
- Purpose in the pipeline: npm package pages on npmjs.com are JS-heavy; the
  JSON API returns the README as structured JSON without any HTML extraction,
  making it the right FIRST tier for npm URLs (matches res008/DIA-072 and the
  res019 npmjs SPA archival failures).

### 5.2 Recommended 3-tier chain by URL class (for the pipeline tooling)

- npm URLs (registry.npmjs.org, npmjs.com/package/*): Tier 1 npm JSON API
  (readme + dist-tags), Tier 2 trafilatura on the resolved package page,
  Tier 3 crwl.
- Static docs (readthedocs, aclanthology, docs.github.com, opencode.ai,
  docs.crawl4ai.com, api-docs.deepseek.com, developers.openai.com): Tier 1
  trafilatura direct; Tier 2 curl + browser-UA + trafilatura; Tier 3 crwl.
- JS-heavy platform pages (platform.openai.com, platform.kimi.ai,
  openrouter.ai model cards, npmjs.com): Tier 1 trafilatura (captures partial
  content: description/price but not tables); Tier 2 curl + browser-UA +
  trafilatura; Tier 3 crwl headless (needed for full tables; DIA-129 risk).
- GitHub blob pages: fetch raw.githubusercontent.com markdown directly
  (used for #19), then trafilatura for HTML github pages.

Live confirmation: this conspect's own archival run exercised the chain --
T2 succeeded on 19 sources, JSON raw on 1, T4 (crwl) on 1. curl+UA+trafilatura
(T3) was attempted and failed on #10, demonstrating the chain's fallback order
works end-to-end.

## 6. (d) EBDV-Style Recommendation Summary (ai-specialist gate, DIA-135)

Recommendation format follows res022 (EBDV); presented as decision input, not
as an implemented change. The parameter values (temperature, variant) are
ai-specialist recommendations supplied with the DIA-135 research request; the
model/pricing/tool facts they rest on are archived in this conspect.

Variant R2 -- researcher lane:
- Model: KEEP deepseek-v4-flash (default; evidence: sections 3.1, 4.1).
- Temperature: 0.7 -> 0.3 (lower determinism for retrieval/summarization).
- Permissions: GAIN bash allow-list `curl`, `wget`, `trafilatura`, `crwl`
  and edit `knowledge/*` (evidence: section 5 tool chain; the current
  environment already reflects this allow-list -- observed live in this run).
- Status-quo alternative: keep temp 0.7 with no tool expansion (rejected:
  higher variance in retrieval output, no source-archival capability).

Variant C2 -- conspecter lane:
- Model: KEEP deepseek-v4-flash (evidence: sections 3.1, 4.2; 1M context at
  lowest Go price).
- Add variant "low" (reasoning-effort low) + temperature 0.1 for
  deterministic MLA citation formatting.
- Permissions: LOSE all bash post-D7 (source archival moves to the researcher
  lane or a dedicated fetcher; conspecter becomes synthesis-only, reading
  already-archived sources).
- Status-quo alternative: keep conspecter bash (rejected only if the
  researcher lane reliably archives before conspecter dispatch; the guard gate
  "if sources/ is empty do NOT proceed" already enforces ordering).

## 7. Unarchived / Excluded (DIA-072)

No source URL failed to archive (phase-a-failures: 0); all 21 URLs in
.source-urls.txt were archived with content > 100 bytes. However, the
following CONTENT is missing from otherwise-archived sources and is EXCLUDED
from claims above per DIA-072 Archive-Before-Claim:

- JS-rendered benchmark tables on all five OpenRouter model cards (#1-#5):
  description, price, context, and release date were captured; benchmark
  score tables and traffic/throughput charts were not. No benchmark claim
  (e.g., SWE-bench scores) is made from these cards; such numbers remain
  cross-referenced from res016/res017 archives instead.
- Kimi platform chat-k3 price table (#11): JS-rendered; only the model
  description and capability fields were captured. Kimi K3 pricing in this
  conspect is sourced from #20 (Go) and #21 (GitHub Copilot), not from #11.
- Kimi platform per-model limits (#12): rate-limit concepts archived; no
  per-model numeric values (JS-rendered). Any Kimi quota figure would be
  excluded; none is claimed here.
- platform.openai.com (#10) archive contains navigation boilerplate; the
  substantive rate-limits article is present (verified by content search),
  and claims made from it are limited to the tier table and header fields
  actually present in the archive.
- Trafilatura paper full text (#16): the ACL page provided the citation
  record + abstract; the full paper PDF was not archived. The "significantly
  better" claim is quoted from the archived abstract; detailed paper
  benchmark tables were not re-archived (the official evaluation page #15
  carries the benchmark instead).

## 8. Works Cited (MLA)

Barbaresi, Adrien. "Evaluation." Trafilatura Documentation, 2026,
trafilatura.readthedocs.io/en/latest/evaluation.html. Accessed 13 Aug. 2026.

---. "Trafilatura: A Web Scraping Library and Command-Line Tool for Text
Discovery and Extraction." Proceedings of the 59th Annual Meeting of the ACL
and the 11th International Joint Conference on Natural Language Processing:
System Demonstrations, Association for Computational Linguistics, Aug. 2021,
pp. 122-131, aclanthology.org/2021.acl-demo.15/. Accessed 13 Aug. 2026.

---. "Trafilatura: A Python Package & Command-Line Tool to Gather Text on the
Web." Trafilatura Documentation, 2026, trafilatura.readthedocs.io/en/latest/.
Accessed 13 Aug. 2026.

Crawl4AI. "Crawl4AI: Open-Source LLM-Friendly Web Crawler & Scraper."
Crawl4AI Documentation, 2026, docs.crawl4ai.com/. Accessed 13 Aug. 2026.

---. "Crawl4AI CLI Guide." Crawl4AI Documentation, 2026,
docs.crawl4ai.com/core/cli/. Accessed 13 Aug. 2026.

DeepSeek. "Rate Limit & Isolation." DeepSeek API Docs, 2026,
api-docs.deepseek.com/quick_start/rate_limit. Accessed 13 Aug. 2026.

---. "Your First API Call." DeepSeek API Docs, 2026,
api-docs.deepseek.com/. Accessed 13 Aug. 2026.

GitHub. "How Model Pricing Works." GitHub Docs: Copilot Billing Reference,
2026, docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing.
Accessed 13 Aug. 2026.

Moonshot AI. "Limits." Kimi Open Platform Docs, 2026,
platform.kimi.ai/docs/pricing/limits. Accessed 13 Aug. 2026.

---. "Product Pricing: Chat K3." Kimi Open Platform Docs, 2026,
platform.kimi.ai/docs/pricing/chat-k3. Accessed 13 Aug. 2026.

npm. "Public Registry API." npm/registry, GitHub, 2026,
github.com/npm/registry/blob/main/docs/REGISTRY-API.md. Accessed 13 Aug. 2026.

OpenAI. "GPT-5 mini." OpenAI Developers API Docs, 2026,
developers.openai.com/api/docs/models/gpt-5-mini. Accessed 13 Aug. 2026.

---. "Rate Limits." OpenAI Developers API Docs, 2026,
developers.openai.com/api/docs/guides/rate-limits. Accessed 13 Aug. 2026.

---. "Rate Limits." OpenAI Platform Docs, 2026,
platform.openai.com/docs/guides/rate-limits. Accessed 13 Aug. 2026.

OpenCode. "Go." OpenCode Docs, 2026, opencode.ai/docs/go/. Accessed
13 Aug. 2026.

OpenRouter. "Checking Your Limits." OpenRouter Docs, 2026,
openrouter.ai/docs/limits. Accessed 13 Aug. 2026.

---. "DeepSeek V4 Flash." OpenRouter, 2026,
openrouter.ai/deepseek/deepseek-v4-flash. Accessed 13 Aug. 2026.

---. "DeepSeek V4 Pro." OpenRouter, 2026,
openrouter.ai/deepseek/deepseek-v4-pro. Accessed 13 Aug. 2026.

---. "GPT-5 Mini." OpenRouter, 2026, openrouter.ai/openai/gpt-5-mini.
Accessed 13 Aug. 2026.

---. "Kimi K3." OpenRouter, 2026, openrouter.ai/moonshotai/kimi-k3. Accessed
13 Aug. 2026.

---. "Qwen3.7-Plus." OpenRouter, 2026, openrouter.ai/qwen/qwen3.7-plus.
Accessed 13 Aug. 2026.
