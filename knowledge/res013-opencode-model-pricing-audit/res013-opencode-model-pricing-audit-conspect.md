Res013: OpenCode Model Pricing Audit (DIA-108)

Date: 2026-08-12
Ticket: DIA-108 (model-assignment audit)
Author: ai-specialist research -> conspecter archival
Scope: synthesis of 7 archived sources in knowledge/res013-opencode-model-pricing-audit/sources/. Sections: (1) OpenCode Go pricing/limits, (2) GitHub Copilot model pricing, (3) SWE-bench Verified scores, (4) GPQA Diamond scores, (5) variant/mode notes, (6) key findings. All numeric claims cite the archived local files.

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 7
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

1. OpenCode Go pricing and usage limits

Summary: OpenCode Go is a flat subscription - $5 for the first month, then $10/month - covering 18 curated open coding models with dollar-denominated usage limits: $12 per 5 hours, $30 per week, $60 per month. Request counts are estimates derived from per-request token patterns and per-model pricing; the 6x usage multiplier applies to most models (bulk discount + reserved GPU capacity passed to subscribers), with a lower multiplier for models whose public pricing is already discounted or too new to negotiate (Anomaly, "Go", 2026).

Subscription: $5 first month, then $10/month. Only one member per workspace can subscribe. Optional provider; config id format opencode-go/<model-id>.

Global limits (dollar value): $12 per 5 hours; $30 per week; $60 per month. Beyond limits: optional fallback to Zen balance via "Use balance" console option, or continue on free models.

Pricing per 1M tokens and monthly usage included (dash = no cache write cost):

| Model | Input $/1M | Output $/1M | Cached read $/1M | Cached write $/1M | Included usage $/mo |
|---|---|---|---|---|---|
| Grok 4.5 | $2.00 | $6.00 | $0.30 | - | $15 |
| GPT 5.6 Luna (<=272K tokens) | $0.20 | $1.20 | $0.02 | $0.25 | $15 |
| GPT 5.6 Luna (>272K tokens) | $0.40 | $1.80 | $0.04 | $0.50 | $15 |
| GLM-5.2 | $1.40 | $4.40 | $0.26 | - | $60 |
| GLM-5.1 | $1.40 | $4.40 | $0.26 | - | $60 |
| Kimi K3 | $3.00 | $15.00 | $0.30 | - | $15 |
| Kimi K2.7 Code | $0.95 | $4.00 | $0.19 | - | $60 |
| Kimi K2.6 | $0.95 | $4.00 | $0.16 | - | $60 |
| MiMo V2.5 | $0.14 | $0.28 | $0.0028 | - | $60 |
| MiMo V2.5 Pro | $0.435 | $0.87 | $0.003625 | - | $15 |
| MiniMax M3 | $0.30 | $1.20 | $0.06 | - | $60 |
| MiniMax M2.7 | $0.30 | $1.20 | $0.06 | $0.375 | $60 |
| MiniMax M2.5 | $0.30 | $1.20 | $0.06 | $0.375 | $60 |
| Qwen3.8 Max | $2.00 | $6.00 | $0.25 | $2.50 | $15 |
| Qwen3.7 Max | $2.50 | $7.50 | $0.50 | $3.125 | $60 |
| Qwen3.7 Plus (<=256K tokens) | $0.40 | $1.60 | $0.04 | $0.50 | $60 |
| Qwen3.7 Plus (>256K tokens) | $1.20 | $4.80 | $0.12 | $1.50 | $60 |
| Qwen3.6 Plus (<=256K tokens) | $0.50 | $3.00 | $0.05 | $0.625 | $60 |
| Qwen3.6 Plus (>256K tokens) | $2.00 | $6.00 | $0.20 | $2.50 | $60 |
| DeepSeek V4 Pro | $0.435 | $0.87 | $0.003625 | - | $15 |
| DeepSeek V4 Flash | $0.14 | $0.28 | $0.0028 | - | $60 |
| Hy3 | $0.14 | $0.58 | $0.035 | - | $60 |

Estimated request counts per model (typical Go usage patterns; token-profile assumptions documented in source):

| Model | Req/5h | Req/wk | Req/mo |
|---|---|---|---|
| Grok 4.5 | 120 | 300 | 600 |
| GPT 5.6 Luna | 2,050 | 5,100 | 10,250 |
| GLM-5.2 | 880 | 2,150 | 4,300 |
| GLM-5.1 | 880 | 2,150 | 4,300 |
| Kimi K3 | 110 | 250 | 490 |
| Kimi K2.7 Code | 1,350 | 3,380 | 6,750 |
| Kimi K2.6 | 1,150 | 2,880 | 5,750 |
| MiMo-V2.5 | 30,100 | 75,200 | 150,400 |
| MiMo-V2.5-Pro | 3,250 | 8,150 | 16,300 |
| MiniMax M3 | 3,200 | 8,000 | 16,000 |
| MiniMax M2.7 | 3,400 | 8,500 | 17,000 |
| Qwen3.8 Max | 160 | 400 | 810 |
| Qwen3.7 Max | 340 | 840 | 1,690 |
| Qwen3.7 Plus | 4,300 | 10,800 | 21,600 |
| Qwen3.6 Plus | 3,300 | 8,200 | 16,300 |
| DeepSeek V4 Pro | 3,450 | 8,550 | 17,150 |
| DeepSeek V4 Flash | 31,650 | 79,050 | 158,150 |
| Hy3 | 4,300 | 10,750 | 21,500 |

Note: MiniMax M2.5 appears in the pricing table but is not in the request-count table or the current model list (list carries MiniMax M2.7 and MiniMax M3); the M2.5 rows are retained as archived.

Confidence: High (all figures directly transcribed from archived opencode-go-pricing.md).

2. GitHub Copilot model pricing

Summary: Copilot billing is token-based: input, output, and cached tokens are priced per model, then converted to AI credits at 1 credit = $0.01 USD. Individual plans include monthly credit allowances: Copilot Pro $10/mo (1,000 base + 500 flex = 1,500 credits), Copilot Pro+ $39/mo (3,900 + 3,100 = 7,000), Copilot Max $100/mo (10,000 + 10,000 = 20,000). Code completions and next-edit suggestions are not billed in credits and remain unlimited on paid plans (GitHub, "Usage-based billing for individuals", 2026). A 10% discount on model costs applies to paid-plan users while using auto model selection in Chat, CLI, app, or cloud agent.

Pricing per 1M tokens (GitHub, "Models and pricing for GitHub Copilot", 2026). Derived credits-per-100K-tokens column added (1 credit = $0.01; credits per 100K = price per 1M / 0.1, marked derived):

OpenAI (cache write cost only for GPT-5.6 Sol/Terra/Luna; others no cache write):

| Model | Tier | Input $ | Cached $ | Cache write $ | Output $ | Credits/100K in (derived) | Credits/100K out (derived) |
|---|---|---|---|---|---|---|---|
| GPT-5 mini | Default | $0.25 | $0.025 | - | $2.00 | 2.5 | 20 |
| GPT-5.3-Codex | Default | $1.75 | $0.175 | - | $14.00 | 17.5 | 140 |
| GPT-5.4 | Default <=272K | $2.50 | $0.25 | - | $15.00 | 25 | 150 |
| GPT-5.4 | Long ctx >272K | $5.00 | $0.50 | - | $22.50 | 50 | 225 |
| GPT-5.4 mini | Default | $0.75 | $0.075 | - | $4.50 | 7.5 | 45 |
| GPT-5.4 nano | Default | $0.20 | $0.02 | - | $1.25 | 2 | 12.5 |
| GPT-5.5 | Default <=272K | $5.00 | $0.50 | - | $30.00 | 50 | 300 |
| GPT-5.5 | Long ctx >272K | $10.00 | $1.00 | - | $45.00 | 100 | 450 |
| GPT-5.6 Luna | Default <=200K | $0.20 | $0.02 | $0.25 | $1.20 | 2 | 12 |
| GPT-5.6 Luna | Long ctx >200K | $0.40 | $0.04 | $0.50 | $1.80 | 4 | 18 |
| GPT-5.6 Sol | Default <=272K | $5.00 | $0.50 | $6.25 | $30.00 | 50 | 300 |
| GPT-5.6 Sol | Long ctx >272K | $10.00 | $1.00 | $12.50 | $45.00 | 100 | 450 |
| GPT-5.6 Terra | Default <=272K | $2.00 | $0.20 | $2.50 | $12.00 | 20 | 120 |
| GPT-5.6 Terra | Long ctx >272K | $4.00 | $0.40 | $5.00 | $18.00 | 40 | 180 |

Anthropic (all include cache write cost):

| Model | Input $ | Cached $ | Cache write $ | Output $ | Credits/100K in (derived) | Credits/100K out (derived) |
|---|---|---|---|---|---|---|
| Claude Haiku 4.5 | $1.00 | $0.10 | $1.25 | $5.00 | 10 | 50 |
| Claude Sonnet 4 | $3.00 | $0.30 | $3.75 | $15.00 | 30 | 150 |
| Claude Sonnet 4.5 | $3.00 | $0.30 | $3.75 | $15.00 | 30 | 150 |
| Claude Sonnet 4.6 | $3.00 | $0.30 | $3.75 | $15.00 | 30 | 150 |
| Claude Opus 4.5 | $5.00 | $0.50 | $6.25 | $25.00 | 50 | 250 |
| Claude Opus 4.6 | $5.00 | $0.50 | $6.25 | $25.00 | 50 | 250 |
| Claude Opus 4.7 | $5.00 | $0.50 | $6.25 | $25.00 | 50 | 250 |
| Claude Opus 4.8 | $5.00 | $0.50 | $6.25 | $25.00 | 50 | 250 |
| Claude Opus 5 | $5.00 | $0.50 | $6.25 | $25.00 | 50 | 250 |
| Claude Sonnet 5 (promo through 2026-08-31) | $2.00 | $0.20 | $2.50 | $10.00 | 20 | 100 |
| Claude Opus 4.8 fast mode (preview) | $10.00 | $1.00 | $12.50 | $50.00 | 100 | 500 |
| Claude Fable 5 | $10.00 | $1.00 | $12.50 | $50.00 | 100 | 500 |

Google:

| Model | Tier | Input $ | Cached $ | Output $ | Credits/100K in (derived) | Credits/100K out (derived) |
|---|---|---|---|---|---|---|
| Gemini 3.1 Pro (public preview) | Default <=200K | $2.00 | $0.20 | $12.00 | 20 | 120 |
| Gemini 3.1 Pro (public preview) | Long ctx >200K | $4.00 | $0.40 | $18.00 | 40 | 180 |
| Gemini 3.5 Flash | Default | $1.50 | $0.15 | $9.00 | 15 | 90 |
| Gemini 3.6 Flash | Default | $1.50 | $0.15 | $7.50 | 15 | 75 |

Fine-tuned (GitHub): Raptor mini - in $0.25, cached $0.025, out $2.00.

Microsoft: MAI-Code-1-Flash - in $0.75, cached $0.075, out $4.50; MAI-Code-1.1-Flash - in $0.20, cached $0.02, out $1.20.

xAI:

| Model | Tier | Input $ | Cached $ | Output $ | Credits/100K in (derived) | Credits/100K out (derived) |
|---|---|---|---|---|---|---|
| Grok 4.5 | Default <=200K | $2.00 | $0.50 | $6.00 | 20 | 60 |
| Grok 4.5 | Long ctx >200K | $4.00 | $1.00 | $12.00 | 40 | 120 |

Moonshot AI:

| Model | Input $ | Cached $ | Output $ | Credits/100K in (derived) | Credits/100K out (derived) |
|---|---|---|---|---|---|
| Kimi K2.7 Code | $0.95 | $0.19 | $4.00 | 9.5 | 40 |
| Kimi K3 | $3.00 | $0.30 | $15.00 | 30 | 150 |

Note: Copilot code review is billed in both AI credits (token consumption; model auto-selected and not disclosed) and GitHub Actions minutes.

Confidence: High (tables transcribed from archived copilot-models-pricing.md and copilot-usage-billing.md; credits-per-100K column is derived arithmetic, flagged as derived).

3. SWE-bench Verified scores

Summary: Two independent trackers archived. BenchLM (63 models, data verified 2026-08-11) reports Claude Opus 5 at 96% leading; Vals AI (79 models, updated 2026-08-08, mini-swe-agent bash-only harness) reports Claude Opus 5 at 97.00% and names Kimi K3 (93.40%) the strongest open-weight model. Pools and harnesses differ, so scores are not directly cross-comparable; both sources state the benchmark is near saturation at the top.

Scores relevant to the audited model set (both archived sources):

| Model | Score | Pool | Context |
|---|---|---|---|
| Claude Opus 5 | 96% (BenchLM) / 97.00% (Vals) | 63 (BenchLM) / 79 (Vals) | BenchLM aggregation; Vals bash-only mini-swe-agent |
| Kimi K3 | 93.40% (Vals) | 79 | Strongest open-weight per Vals; bash-only harness; not in BenchLM top-63 |
| Grok 4.5 | 86.60% (Vals) | 79 | Vals bash-only harness |
| Claude Sonnet 5 | 85.2% (BenchLM) | 63 | BenchLM aggregation |
| GPT-5.3 Codex | 85% (BenchLM) | 63 | BenchLM aggregation |
| MiniMax M3 | 80.5% (BenchLM) | 63 | BenchLM aggregation, open weight |
| DeepSeek V4 Pro (Max) | 80.6% (BenchLM) | 63 | BenchLM aggregation, open weight |
| Kimi K2.6 | 80.2% (BenchLM) | 63 | BenchLM aggregation, open weight |
| DeepSeek V4 Flash (Max) | 79% (BenchLM) | 63 | BenchLM aggregation, closed |
| GPT-5.6 Luna | no overall in either archive; Vals difficulty split 96% (<15 min), 92% (15m-1h), 86% (1-4 hr), 67% (>4 hr) | 79 | Vals bash-only harness |
| DeepSeek V4 Flash (plain) | 73.7% (BenchLM) / difficulty split 91/87/90/67% (Vals, "DeepSeek V4 Flash 0731") | 63 / 79 | BenchLM aggregation; Vals bash-only harness |
| DeepSeek V4 Pro (plain) | 73.6% (BenchLM) | 63 | BenchLM aggregation, open weight |
| Kimi K2.7 Code | in Vals list, no overall % in archive | 79 | Vals bash-only harness |
| GLM-5.2 | in Vals list, no overall % in archive; difficulty split 88/82/67/67% | 79 | Vals bash-only harness |

Benchmark facts: SWE-bench Verified is a human-validated 500-instance subset of SWE-bench, created with OpenAI; each instance is a real GitHub issue requiring a code patch validated by unit tests (SWE-bench Team, 2026). Vals uses a minimal bash-tool-only agent harness (mini-swe-agent) with provider-default config except max token limit set to highest; BenchLM reports a freshness note (annual cadence, "refreshing") and 63-model coverage.

Confidence: High for transcribed scores; the differing pools/harnesses (63 vs 79 models) mean cross-source comparison requires care.

4. GPQA Diamond scores

GPQA Diamond scores are NOT present in any of the 7 archived sources (all three benchmark sources cover SWE-bench Verified only; the two OpenCode pages and two GitHub billing pages contain no GPQA data). Any GPQA Diamond figures used elsewhere in the DIA-108 audit are cached-from-shelf values, not independently verified against this archive. Per DIA-072 policy, no GPQA claim is asserted in this conspect.

Confidence: N/A (no archived grounding).

5. Variant and mode notes per model

Summary: OpenCode supports per-model option configuration and built-in variants. Anthropic built-ins: high (high thinking budget, default) and max (maximum thinking budget). OpenAI built-ins vary by model, roughly: none, minimal, low, medium, high, xhigh reasoning effort. Google built-ins: low and high (effort/token budget). Agent config overrides global options; custom variants can extend or disable built-ins, and a variant_cycle keybind switches between them (Anomaly, "Models", 2026).

Observed mode/variant labels in the archived benchmark sources:
- DeepSeek V4 Pro (Max) 80.6% and DeepSeek V4 Pro (High) 79.4% (BenchLM) - named modes of the same base model, differing in effort; plain DeepSeek V4 Pro 73.6% (BenchLM).
- DeepSeek V4 Flash (Max) 79% and DeepSeek V4 Flash (High) 78.6% (BenchLM); plain DeepSeek V4 Flash 73.7% (BenchLM); Vals evaluates "DeepSeek V4 Flash 0731" (date-stamped snapshot).
- Vals difficulty table names reasoning/thinking modes explicitly: Claude Opus 4.6 (Thinking), Claude Opus 4.5 (Thinking), Claude Sonnet 4.5 (Thinking), Claude Haiku 4.5 (Thinking), Grok 4.20 (Reasoning), Grok 4 Fast (Reasoning), Grok 4.1 Fast (Reasoning), DeepSeek V3.2 (Thinking), Kimi K2 Thinking, GPT 5.4 (xhigh) - indicating effort-level sensitivity on SWE-bench.
- OpenCode Go exposes no per-model variant knobs in the archived Go page; variant configuration is a client-side OpenCode config concern (opencode-models.md).

Confidence: High for archived variant lists; effort-level sensitivity is descriptive, not quantified in the archives beyond the score deltas above.

6. Key findings

- Kimi K3 is the best SWE-bench performer among OpenCode Go models: 93.40% on SWE-bench Verified (Vals, strongest open-weight model) with a Go cap of 490 requests/month (110/5h, 250/wk) and Go pricing $3.00/$15.00 per 1M in/out (Anomaly, "Go", 2026; Vals AI, 2026). The tight cap (lowest of the 18 Go models) reflects the $15/mo usage bucket and $3/$15 pricing; Kimi K3 is also the highest-priced input of the Go set alongside Grok 4.5.
- Grok 4.5 scores 86.60% (Vals) with a 600 req/mo Go cap (120/5h, 300/wk), pricing $2.00/$6.00 (Go) and $2.00/$6.00 per 1M in/out on Copilot (default tier <=200K; $0.50 cached; long-context tier >200K at $4.00/$12.00). Note: Grok 4.5 in Go uses ZDR (no stateful Responses API).
- GPT 5.6 Luna is the new cheap lightweight: $0.20/$1.20 per 1M in/out (Go and Copilot identical), with cache write $0.25/$0.50 and 2/12 credits per 100K in/out on Copilot; Go cap 10,250 req/mo; Vals difficulty split 96/92/86/67% (no overall score in the archive).
- DeepSeek V4 Flash is the volume king: 158,150 req/mo Go cap (31,650/5h) at $0.14/$0.28 per 1M - the cheapest model in both Go and the audit set. Plain score 73.7% (BenchLM); Max mode 79%, High mode 78.6%. Vals "DeepSeek V4 Flash 0731" difficulty split 91/87/90/67%. ZDR agreement current through 2026-08-31.
- MiniMax M3 reaches 80.5% (BenchLM, open weight) at $0.30/$1.20 Go pricing with 16,000 req/mo cap; also present in the Vals 79-model list (no overall in archive).
- Copilot credit economics: Copilot Pro = 1,500 credits/mo ($10); a frontier output at $25/1M (Claude Opus family) burns 250 credits per 100K output tokens, i.e. 16.7% of the monthly Pro allowance per 100K output tokens. Cheaper lanes: GPT-5 mini 20 credits/100K out, GPT-5.6 Luna 12, MAI-Code-1.1-Flash 12, Kimi K2.7 Code 40, GPT-5.4 nano 12.5.
- Budget tension from the audit: OpenCode Go ($60/mo cap) vs Copilot Pro (1,500 credits = $15/mo) - Go remains the volume workhorse for the audit's 8:1 target ratio, with Copilot reserved for the models unavailable on Go.

IMPORTANT AVAILABILITY CAVEAT (developer disposition, DIA-108): the Claude Sonnet 5 recommendation (Copilot $2/$10 promo pricing through 2026-08-31; 85.2% SWE-bench Verified per BenchLM; Vals difficulty split 84/77/76/67%) was REJECTED by the developer because Claude Sonnet 5 is NOT in their actual Copilot Pro subscription model list. Pricing-page availability does not imply subscription availability: a model listed in the Copilot pricing reference may not be exposed to a given plan/seat, and auto model selection may substitute other models. Rule recorded for this audit: validate model availability against the actual subscription's model list BEFORE recommending; a pricing-table entry alone is insufficient evidence. Claude Sonnet 5 is therefore NOT presented as an actionable recommendation in this conspect.

Excluded claims per DIA-072: every numeric claim in this conspect traces to one of the 7 archived local files. GPQA Diamond figures are deliberately excluded (no archived grounding; see Section 4).

Concluding guidance:
- For volume delegation on OpenCode Go: DeepSeek V4 Flash (cheapest, 158K req/mo) or GPT 5.6 Luna (cheap lightweight) - with Kimi K3 reserved for high-difficulty tasks where its 93.4% justifies the 490 req/mo cap.
- For Copilot-backed lanes: pick from models confirmed present in the actual subscription (e.g. GPT-5.6 Luna, Kimi K2.7 Code, Grok 4.5 if offered); re-verify availability per plan before each recommendation, per the caveat above.
- Cross-source score comparisons must state pool and harness (BenchLM 63-model aggregation vs Vals 79-model bash-only mini-swe-agent).

MLA citations (archived local files):
- Anomaly. "Go." OpenCode Docs, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/opencode-go-pricing.md.
- Anomaly. "Models." OpenCode Docs, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/opencode-models.md.
- GitHub. "Models and pricing for GitHub Copilot." GitHub Docs, 2026. knowledge/res013-opencode-model-pricing-audit/sources/copilot-models-pricing.md.
- GitHub. "Usage-based billing for individuals." GitHub Docs, 2026. knowledge/res013-opencode-model-pricing-audit/sources/copilot-usage-billing.md.
- BenchLM. "SWE-bench Verified Leaderboard (August 2026): Top Scores." BenchLM.ai, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/swebench-benchlm.md.
- Vals AI. "SWE-bench Verified." Vals AI, 8 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/swebench-vals.md.
- SWE-bench Team. "SWE-bench Verified." SWE-bench, 10 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/swebench-official.md.
- Jimenez, Carlos E., et al. "SWE-bench: Can Language Models Resolve Real-world Github Issues?" arXiv preprint arXiv:2310.06770, 2024. Cited within swebench-official.md.

Unarchived sources:
None. All 7 requested sources were archived successfully in Phase A (see phase_a_report.txt). No source is marked [source not archived - excluded per DIA-072 policy]; that marker would apply only to a URL that exhausted all archival methods.

---
Document prepared by conspecter lane on 2026-08-12. All citations point to locally archived artifacts under knowledge/res013-opencode-model-pricing-audit/sources/.
