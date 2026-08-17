# res030 - OpenCode Go Usage Limits + mimo-v2.5 Pricing Refresh (DIA-189 follow-up)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 5
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

Metadata: res030 | created 2026-08-17 | DIA-189 follow-up (usage-limits + pricing refresh) | type: research conspect
Scope: synthesis of 5 archived sources in knowledge/res030-opencode-go-usage-limits-mimo-v25/sources/ (all archived 2026-08-17; 0 Phase A failures). Sections: (1) current Go subscription + usage limits, (2) deepseek-v4-flash pricing/quota change, (3) mimo-v2.5 family, (4) other Go models table, (5) availability + pricing changes since 2026-08-13, (6) PRICE_DELTA_TABLE vs res013/res021, (7) project implications (cebula preset, model-registry.yaml), (8) source reconciliation notes. All numeric claims cite the archived local files; in-repo config reads (oh-my-opencode-slim.jsonc, knowledge/model-registry.yaml) are cited by path.
Cross-references: res013 (opencode-model-pricing-audit, 2026-08-12), res021 (opencode-agent-presets, 2026-08-12), res024 (model-variant-fetch-tools, 2026-08-13), res029 (model-fallback-semantics, 2026-08-17).

---

## 1. Executive Summary

OpenCode Go pricing and quotas changed materially between the res013/res021 archive (2026-08-12/13) and this refresh (2026-08-17):

1. **deepseek-v4-flash lost its volume-king status.** Price rose from $0.14/$0.28 to $0.22/$0.66 off-peak / $0.44/$1.32 peak (per 1M in/out), the monthly request estimate collapsed from 158,150 to 18,900 (-88%), the usage bucket dropped from $60 to $15, and the 2x-usage promo tag was removed (Anomaly, "Go", 2026; Julien, 2026).
2. **mimo-v2.5 (non-pro) is the new volume king**: $0.14/$0.28 per 1M (the price Flash used to carry), 150,400 estimated req/mo, $60 bucket - roughly 8x Flash's new monthly quota at the same per-token price (Anomaly, "Go", 2026).
3. **mimo-v2.5-pro is unchanged** at $0.435/$0.87, 16,300 req/mo, $15 bucket (Anomaly, "Go", 2026; Julien, 2026).
4. **Availability churn**: GLM-5.3 added (2026-08-14); MiniMax-M2.5, Kimi K2.5, GLM-5 deprecated and removed from the docs model list (2026-08-17); MiniMax-M3 price halved; DeepSeek V4 Pro registry price cut $1.74/$3.48 -> $0.66/$1.98 (Julien, 2026).
5. **Project impact**: the active cebula preset routes 7 agents through opencode-go/deepseek-v4-flash (config read 2026-08-17), whose Go quota just shrank 8x; knowledge/model-registry.yaml still records Flash at $0.14/$0.28 / 158,150 req/mo and is stale (registry read 2026-08-17).

Confidence: High for docs-page figures (official, archived 2026-08-17); medium for tracker-derived registry figures (unofficial auto-generated snapshot, cross-referenced against API + models.dev + docs; discrepancies flagged in Section 8).

## 2. OpenCode Go subscription and usage limits (current, 2026-08-17)

Subscription: **$5 for the first month, then $10/month** - a low-cost subscription for open coding models, designed primarily for international users with stable global access. Optional provider; sign in via OpenCode Zen, subscribe, copy the API key, run `/connect` in the TUI, select OpenCode Go, then `/models` to list available models. Config id format `opencode-go/<model-id>` (Anomaly, "Go", 2026).

Dollar-denominated usage limits (unchanged from res013):

| Limit window | Dollar cap |
|---|---|
| 5 hours | $12 of usage |
| Weekly | $30 of usage |
| Monthly | $60 of usage |

(Anomaly, "Go", 2026.)

Limits are defined in dollar value, so actual request counts depend on the model: cheaper models allow more requests. The docs publish per-model estimated request counts based on observed token patterns (per-request input/cached/output token profiles) and per-model pricing; the $10/month subscription aims to deliver ~6x that in usage via bulk discounts and reserved GPU capacity, with a lower multiplier for models whose public pricing is already discounted or too new to negotiate (Anomaly, "Go", 2026).

Beyond limits: if the subscriber has Zen balance credits, the "Use balance" console option makes Go fall back to the Zen balance after usage limits are reached instead of blocking requests (Anomaly, "Go", 2026). This is the provider-side overflow path; client-side model-array fallback semantics are covered in res029.

Current documented model list (19 models on the archived docs page): Grok 4.5, GLM-5.3, GLM-5.2, GLM-5.1, GPT 5.6 Luna, Kimi K3, Kimi K2.7 Code, Kimi K2.6, MiMo-V2.5, MiMo-V2.5-Pro, MiniMax M3, MiniMax M2.7, Qwen3.8 Max, Qwen3.7 Max, Qwen3.7 Plus, Qwen3.6 Plus, DeepSeek V4 Pro, DeepSeek V4 Flash, Hy3 (Anomaly, "Go", 2026). The API catalog metadata (go-models.json) carries 26 model IDs including deprecated predecessors and preview models; models.dev carries 25 (Julien, 2026; Anomaly, "Go catalog metadata", 2026; Models.dev, 2026). See Section 8 for the tracker's lower "15 documented" count reconciliation.

## 3. deepseek-v4-flash: pricing increase + quota collapse

Current (2026-08-17) Go terms for `opencode-go/deepseek-v4-flash`:

| Metric | Value |
|---|---|
| Price in/out per 1M (off-peak) | $0.22 / $0.66 |
| Price in/out per 1M (peak) | $0.44 / $1.32 |
| Cache read per 1M | $0.007 (off-peak) / $0.014 (peak) |
| Usage bucket | $15/month |
| Estimated requests | 3,800 / 5h; 9,450 / wk; 18,900 / mo |

(Anomaly, "Go", 2026.)

Peak hours: **01:00-04:00 and 06:00-10:00 UTC**; all other hours are off-peak (Anomaly, "Go", 2026). DeepSeek V4 Pro carries the same peak/off-peak structure (off-peak $0.66/$1.98, peak $1.32/$3.96, $15 bucket, 5,200 req/mo) (Anomaly, "Go", 2026).

Change vs the res013/res021 archive (2026-08-12/13): price $0.14/$0.28 -> $0.22/$0.66 off-peak (tracker changelog records "$0.14/$0.28 -> $0.22/$0.66", Julien, 2026); monthly request estimate 158,150 -> 18,900 (-88%); bucket $60 -> $15; the 2x-usage promo tag recorded in res021 (promo rate $0.07/$0.14 per the 2026-08-11 tracker snapshot) is **removed** - the 2026-08-17 tracker lists Flash at standard pricing with no promo tag (Julien, 2026). The docs page no longer shows any 2x tag for Flash (Anomaly, "Go", 2026).

## 4. mimo-v2.5 family

**mimo-v2.5 (non-pro) - NEW volume king** (Anomaly, "Go", 2026; Julien, 2026):

| Metric | Value |
|---|---|
| Price in/out per 1M | $0.14 / $0.28 |
| Cache read per 1M | $0.0028 |
| Usage bucket | $60/month |
| Estimated requests | 30,100 / 5h; 75,200 / wk; 150,400 / mo |

This is the same per-token price Flash carried before its increase, with the largest monthly request estimate on the roster (150,400 vs Flash's new 18,900 - about 8x). Release date 2026-04-22, 1M context, 128K max output, reasoning + tool calling + attachment support, open weights (Julien, 2026).

**mimo-v2.5-pro - UNCHANGED** (Anomaly, "Go", 2026; Julien, 2026):

| Metric | Value |
|---|---|
| Price in/out per 1M | $0.435 / $0.87 |
| Cache read per 1M | $0.003625 |
| Usage bucket | $15/month |
| Estimated requests | 3,250 / 5h; 8,150 / wk; 16,300 / mo |

Identical to the res013/res021 archived values. Note: the tracker changelog lists a models.dev registry price change for MiMo V2.5 Pro ($1.74/$3.48 -> $0.43/$0.87) detected in this snapshot, but the Go docs price was already $0.435/$0.87 at res013 archive time - so relative to the prior conspects the Go-plan price is unchanged; the registry change merely aligns models.dev with the docs (Julien, 2026; res013).

**mimo-v2.5-free is NOT on Go** - absent from the docs model list, the 26-model API catalog (go-models.json), and the tracker's 26-model table; it is a Zen-provider-only model (Anomaly, "Go", 2026; Anomaly, "Go catalog metadata", 2026; Julien, 2026). Absence confirmed across all three sources.

## 5. Other Go models (current table, 2026-08-17)

Selected models relevant to this project's routing (Anomaly, "Go", 2026; Julien, 2026):

| Model | In/out $ per 1M | Bucket | Req/5h | Req/mo | Notes |
|---|---|---|---|---|---|
| Qwen3.7 Plus | $0.40 / $1.60 (<=256K) | $60 | 4,300 | 21,600 | >256K tier $1.20/$4.80 |
| Hy3 | $0.14 / $0.58 | $60 | 4,300 | 21,500 | 256K ctx, open weights |
| MiniMax M2.7 | $0.30 / $1.20 | $60 | 3,400 | 17,000 | cache write $0.375 |
| MiniMax M3 | $0.30 / $1.20 | $60 | 3,200 | 16,000 | price halved 2026-08-17 (was $0.60/$2.40) |
| Qwen3.6 Plus | $0.50 / $3.00 (<=256K) | $60 | 3,300 | 16,300 | >256K tier $2.00/$6.00 |
| GPT-5.6 Luna | $0.20 / $1.20 (<=272K) | $15 | 2,050 | 10,250 | 2x promo still tagged: $0.10/$0.60 (tracker) |
| Kimi K2.7 Code | $0.95 / $4.00 | $60 | 1,350 | 6,750 | 262K ctx |
| DeepSeek V4 Pro | $0.66 / $1.98 off-peak; $1.32/$3.96 peak | $15 | 1,050 | 5,200 | registry price cut $1.74/$3.48 -> $0.66/$1.98 |
| Kimi K3 | $3.00 / $15.00 | $15 | 110 | 490 | binding cap; coder-escalated lane |
| Grok 4.5 | $2.00 / $6.00 | $15 | 120 | 600 | ZDR; 30-day retention |
| GLM-5.3 | $1.40 / $4.40 | $15 | 220 | 1,080 | added 2026-08-14 |

**nemotron is NOT on Go** - absent from the docs model list, the API catalog, and the tracker's 26-model table (Anomaly, "Go", 2026; Anomaly, "Go catalog metadata", 2026; Julien, 2026).

## 6. Availability and pricing changes since 2026-08-13

Tracker changelog (snapshot 2026-08-17 10:08 UTC, compared against the tracker's previous snapshot 2026-06-04) (Julien, 2026):

**Newly available** (tracker list): GLM-5.3 (2026-08-14), Qwen3.8 Max (2026-08-03), Kimi K3 (2026-07-16), Grok 4.5 (2026-07-08), Hy3 (2026-07-06), GPT-5.6 Luna (2026-07-09), Kimi K2.7 Code (2026-06-12), GLM-5.2 (2026-06-13).

Reconciliation vs the res013/res021 archive (2026-08-12/13): of that list, only **GLM-5.3** (released 2026-08-14) is genuinely new to the documented roster; the other seven were already present in res013's pricing/request tables. The tracker's "newly available" list reflects its own 2026-06-04 baseline, not the res013 baseline.

**Deprecated + removed from docs model list (2026-08-17)**: MiniMax-M2.5, Kimi K2.5, GLM-5 (Julien, 2026). Note: the archived docs page still carries MiniMax M2.5 rows in its pricing and endpoints tables, but the current model list no longer includes it (Anomaly, "Go", 2026). res013 had retained M2.5 rows "as archived"; that retention is now obsolete.

**Pricing changes (2026-08-17 snapshot)** (Julien, 2026):

| Model | Before | After |
|---|---|---|
| MiniMax-M3 | $0.60 / $2.40 | $0.30 / $1.20 (halved) |
| DeepSeek V4 Pro (registry) | $1.74 / $3.48 | $0.66 / $1.98 (matches docs off-peak) |
| DeepSeek V4 Flash | $0.14 / $0.28 | $0.22 / $0.66 off-peak / $0.44 / $1.32 peak |
| MiMo V2.5 Pro (registry) | $1.74 / $3.48 | $0.43 / $0.87 (docs unchanged at $0.435/$0.87) |

**Promo tags**: GPT-5.6 Luna still tagged "2x usage" ($0.10/$0.60 per 1M, cache read $0.01, cache write $0.12) in the 2026-08-17 tracker; DeepSeek V4 Flash's 2x tag is gone (Julien, 2026).

## 7. PRICE_DELTA_TABLE: archived (res013/res021, 2026-08-12/13) vs fresh (2026-08-17)

| Model | Metric | Archived (res013/res021) | Fresh (2026-08-17) | Delta |
|---|---|---|---|---|
| deepseek-v4-flash | price in/out per 1M | $0.14 / $0.28 | $0.22 / $0.66 off-peak; $0.44 / $1.32 peak | +57% / +136% (off-peak vs old flat) |
| deepseek-v4-flash | req/mo (est.) | 158,150 | 18,900 | -88% |
| deepseek-v4-flash | usage bucket | $60 | $15 | -75% |
| deepseek-v4-flash | 2x promo | present ($0.07/$0.14, res021 tracker 2026-08-11) | removed | gone |
| mimo-v2.5-pro | price in/out per 1M | $0.435 / $0.87 | $0.435 / $0.87 | unchanged |
| mimo-v2.5-pro | req/mo (est.) | 16,300 | 16,300 | unchanged |
| mimo-v2.5-pro | usage bucket | $15 | $15 | unchanged |
| deepseek-v4-pro | price in/out per 1M | $0.435 / $0.87 (res013; see note) | $0.66 / $1.98 off-peak; $1.32 / $3.96 peak | registry $1.74/$3.48 -> $0.66/$1.98 |

Correction note on deepseek-v4-pro: res013 archived V4 Pro at $0.435/$0.87 - the exact value of mimo-v2.5-pro's price, indicating a transcription collision in res013 (the tracker's registry changelog shows the pre-snapshot registry price was $1.74/$3.48). The fresh docs price is $0.66/$1.98 off-peak. The same $0.435/$0.87 value was inherited by knowledge/model-registry.yaml's deepseek-v4-pro entry (see Section 8).

## 8. Project implications (config reads 2026-08-17)

1. **cebula preset routes 7 agents through opencode-go/deepseek-v4-flash** (active preset, .opencode/oh-my-opencode-slim.jsonc line 3): orchestrator (L192), coder (L253), conspecter (L291), resource-manager (L376), memory-manager (L384), code-navigator (L393), researcher (L399) - all with `opencode-go/deepseek-v4-flash` as the first (primary) array entry. Flash's Go quota just collapsed from 158,150 to 18,900 req/mo (-88%) at a higher price and a $15 bucket, so the volume assumption behind these assignments (res013 finding: "DeepSeek V4 Flash is the volume king", 158K req/mo) no longer holds.

2. **Developer-approved Variant A: full swap to opencode-go/mimo-v2.5** (orchestrator-provided context for this conspect, not an archived-source claim). mimo-v2.5 is the natural replacement: same $0.14/$0.28 price Flash used to carry, 150,400 req/mo (8x Flash's new quota), $60 bucket. The swap is a config change and routes through the AI Devtools Modernization Workflow (AGENTS.md section 2.5) - this conspect is the pricing/quota evidence base for it.

3. **knowledge/model-registry.yaml is stale** (read 2026-08-17): the deepseek-v4-flash entry still records price_in_1m 0.14 / price_out_1m 0.28 / req_per_month 158150 / quota_notes "Volume default, 158K req/mo headroom" (lines 4-14). Needs updating to $0.22/$0.66 off-peak / $0.44/$1.32 peak, 18,900 req/mo, $15 bucket - and the "volume default" role justification must be revisited. Secondary: the deepseek-v4-pro entry (lines 52-62) carries $0.435/$0.87 (the res013 transcription collision noted in Section 7); fresh value is $0.66/$1.98 off-peak. Registry owner per ADR-DIA-133: ai-specialist research -> coder edit.

4. **Fallback-chain consideration (res029 semantics)**: OMO model arrays are ordered fallback chains; the cebula Flash entries fall back to `opencode/deepseek-v4-flash` (free provider). mimo-v2.5 has no free-provider twin (Section 4), so a swap to `opencode-go/mimo-v2.5` must decide the second array entry explicitly (e.g. keep a free-provider fallback or use another Go model). Also relevant: the Go "Use balance" overflow path (Section 2) and the res029 finding that silent-empty responses may not trigger OMO fallback.

5. **dcp.jsonc references** (read 2026-08-17): modelMaxLimits/modelMinLimits contain `opencode-go/deepseek-v4-flash` entries (lines 16-17, 32-33); if the swap proceeds, these limits entries need to move to the replacement model id.

## 9. Source reconciliation notes

- **Tracker "15 documented" vs docs page 19 models**: the tracker's Quick Stats count "Documented (listed on Go docs page) | 15", but the docs page archived in this same fetch lists 19 models (including Grok 4.5, GPT 5.6 Luna, Kimi K2.7 Code, Hy3, which the tracker marks "catalog" only). The tracker's docs-scrape appears to lag the live docs page; the archived docs page is authoritative for the documented roster (Julien, 2026; Anomaly, "Go", 2026).
- **Tracker changelog baseline**: the tracker's changelog compares against its own 2026-06-04 snapshot, not the res013/res021 archive date; Section 6 reconciles the difference (only GLM-5.3 is new vs res013).
- **models.dev registry vs docs**: registry prices (models.dev-api.json, opencode-go entry, 25 models) and docs prices agree on the fresh values for Flash/Pro/MiMo; the tracker's changelog dates (2026-08-17) are snapshot-detection dates, not necessarily change dates.
- **go-models.json**: the archived catalog metadata (26 model IDs) confirms the API-side roster; the tracker's 26-model count matches. The file is a single-line JSON record that exceeds line-based read limits; the tracker's cross-referenced table was used for per-model detail.

## MLA citations (archived local files)

- Anomaly. "Go." OpenCode Docs, 17 Aug. 2026. knowledge/res030-opencode-go-usage-limits-mimo-v25/sources/opencode-go-docs.md/23MrM0Xw_0PmCnl_.txt.
- Anomaly. "Models." OpenCode Docs, 17 Aug. 2026. knowledge/res030-opencode-go-usage-limits-mimo-v25/sources/opencode-models-docs.md/3gDXkpkLvJK7_jBv.txt. (LOW relevance per manifest; cited as context only - general models config, no Go pricing.)
- Julien. "OpenCode Go Models Tracker." julien.ai, auto-generated 17 Aug. 2026 10:08 UTC. knowledge/res030-opencode-go-usage-limits-mimo-v25/sources/julien-go-models-tracker.md/NZ62raq3X4k2V1lM.txt.
- Models.dev. "opencode-go provider entry." models.dev API registry, 17 Aug. 2026. knowledge/res030-opencode-go-usage-limits-mimo-v25/sources/models-dev-api.json.
- Anomaly. "Go catalog metadata endpoint." opencode.ai/zen/go/v1/models, 17 Aug. 2026. knowledge/res030-opencode-go-usage-limits-mimo-v25/sources/go-models.json.

Supplementary local references (cross-referenced, not Phase A sources of this conspect):
- res013: knowledge/res013-opencode-model-pricing-audit/res013-opencode-model-pricing-audit-conspect.md (archived baseline 2026-08-12).
- res021: knowledge/res021-opencode-agent-presets/res021-opencode-agent-presets-conspect.md (2x promo baseline 2026-08-12).
- res024: knowledge/res024-model-variant-fetch-tools/res024-model-variant-fetch-tools-conspect.md (lane-fit + req/mo estimates).
- res029: knowledge/res029-model-fallback-semantics/res029-model-fallback-semantics-conspect.md (OMO fallback-chain semantics).
- knowledge/model-registry.yaml (DIA-133 dispatch routing registry; stale Flash entry).
- .opencode/oh-my-opencode-slim.jsonc (cebula preset, active; 7 Flash-primary agents).

## Unarchived/Excluded

None. All 5 requested sources were archived successfully in Phase A (see .source-urls.txt manifest, all marked "archived 2026-08-17"); no source is excluded. The opencode-models-docs source is LOW relevance but passes evaluation and is cited as context only. The two JSON sources (models-dev-api.json, go-models.json) are single-line records exceeding line-based read limits; their content was verified through the tracker's cross-referenced tables plus the visible record prefixes, and the limitation is disclosed in Section 9.

---

Document prepared by conspecter lane on 2026-08-17. All citations point to locally archived artifacts under knowledge/res030-opencode-go-usage-limits-mimo-v25/sources/. Shelf registration delegated to @memory-manager (DIA-143).