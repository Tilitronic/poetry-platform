# OpenCode Go Promo Benchmarks: 6x Multiplier, Cheapest-Model Comparison, and the Muse Spark Privacy Tradeoff

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 10
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## Source Capture Note

All ten sources were archived by @researcher via webfetch extraction (the prescribed trafilatura/curl/crwl chain could not persist files from the bash sandbox). Content is a faithful extraction of substantive page data (pricing tables, benchmark scores, promo terms), not raw HTML. The researcher rated all ten sources as passing (Relevance High/Med, Reliability High/Med); no source was excluded (see "Unarchived/Excluded" below).

## 1. OpenCode Go Promo Structure (the 6x Multiplier) and Usage Caps

OpenCode Go is a low-cost $10/month subscription that grants API-key access to popular open coding models, billed as a provider under the `opencode-go/<model-id>` id format. The headline promo is a **6x usage proportion**: subscribers pay $10/month and OpenCode aims to deliver roughly 6x that in usage value, i.e. about $60/month of model usage (OpenCode, "OpenCode Go"). The mechanism is described as passing through bulk discounts and reserved GPU capacity negotiated with model hosts; for models where no discount was negotiated, the included-usage value is lower ($15 or $30 instead of $60), and the docs explicitly note subscribers "still get a little more than if you paid the model providers directly" (OpenCode, "OpenCode Go").

Hard usage caps (in dollars of usage, not tokens) are:

- 5-hour limit: $12
- Weekly limit: $30
- Monthly limit: $60 (OpenCode, "OpenCode Go")

On hitting a cap, the subscriber "can continue using the free models" (OpenCode, "OpenCode Go"). Subscription is limited to one member per workspace (OpenCode, "OpenCode Go").

## 2. Cheapest-Model Comparison: Muse Spark 1.2 Contributor vs Hy3 vs MiMo V2.5

The three lowest-priced models in the Go catalog are Muse Spark 1.2 Contributor, Tencent Hy3, and Xiaomi MiMo V2.5. All three carry a $60/month included-usage cap under the 6x proportion (OpenCode, "OpenCode Go"; Command Code, "Models").

| Model | Input $/1M | Output $/1M | Cache read $/1M | Context | Intelligence Index | Coding Index | GPQA Diamond |
|---|---|---|---|---|---|---|---|
| Muse Spark 1.2 Contributor | 0.10 | 0.20 | 0.002 | 1.05M | 56.8 | 72.2 | 90.4 |
| Tencent Hy3 | 0.14 | 0.58 | 0.035 | 262K | 42.2 | 58.8 | 89.7 |
| MiMo V2.5 | 0.14 | 0.28 | 0.0028 | 1M | 38.0 | 56.8 | 84.9 |

Sources: pricing and context from the OpenCode Go catalog and vendor/aggregator pages (OpenCode, "OpenCode Go"; Command Code, "Muse Spark 1.2 Contributor"; Command Code, "Tencent Hy3"; Command Code, "MiMo V2.5"); benchmark indices from the Artificial Analysis independent lab (Artificial Analysis, "Muse Spark 1.2"; Artificial Analysis, "Hy3"; Artificial Analysis, "MiMo-V2.5").

### 2.1 Pricing read

- Cheapest input among the trio: Muse Spark 1.2 Contributor at $0.10 (Command Code, "Models").
- Cheapest output: MiMo V2.5 at $0.28, beating Hy3 ($0.58) and Muse Spark ($0.20); note Muse Spark's lower output price is offset by its training-on-data condition (see Section 4) (Command Code, "Models").
- Hy3 carries by far the highest output price ($0.58) despite only a mid Intelligence score (Command Code, "Tencent Hy3").

### 2.2 Context windows

- Muse Spark 1.2 Contributor: ~1.05M tokens (Command Code, "Muse Spark 1.2 Contributor"); Artificial Analysis lists 1M (Artificial Analysis, "Muse Spark 1.2").
- Hy3: 262K tokens (Command Code, "Tencent Hy3"); Artificial Analysis lists 256k (Artificial Analysis, "Hy3") — the smallest context of the three.
- MiMo V2.5: 1M tokens (Command Code, "MiMo V2.5"; Artificial Analysis, "MiMo-V2.5").

### 2.3 Benchmark scores

Independent Artificial Analysis Intelligence Index (v4.1.1, 9-eval standard):

- Muse Spark 1.2 (xhigh): **57** (#17/187 overall) (Artificial Analysis, "Muse Spark 1.2"). The Contributor variant is reported at 56.8 by the aggregator (Command Code, "Muse Spark 1.2 Contributor").
- Hy3: **42** (#17/110 open-weight class) (Artificial Analysis, "Hy3"); aggregator 42.2 (Command Code, "Tencent Hy3").
- MiMo V2.5: **38** (#27/110 open-weight class) (Artificial Analysis, "MiMo-V2.5"); aggregator 38.0 (Command Code, "MiMo V2.5").

Coding and reasoning sub-scores (Artificial Analysis, relayed via aggregator):

- Muse Spark 1.2 Contributor: Coding 72.2 (#14/48), Terminal-Bench 80.1, Long-context reasoning 83.3, SciCode 56.4, GPQA Diamond 90.4 (Command Code, "Muse Spark 1.2 Contributor").
- Hy3: Coding 58.8 (#32/48), Terminal-Bench 64.4, Long-context reasoning 74.7, SciCode 47.6, GPQA Diamond 89.7 (Command Code, "Tencent Hy3").
- MiMo V2.5: Coding 56.8 (#35/48), Terminal-Bench 63.7, Long-context reasoning 68.3, SciCode 43.1, GPQA Diamond 84.9 (Command Code, "MiMo V2.5").

### 2.4 Capability and licensing notes

- Muse Spark 1.2 Contributor: proprietary (Meta), multimodal input (text/image/speech/video -> text), reasoning-capable, released Aug 5, 2026 (Artificial Analysis, "Muse Spark 1.2"; Command Code, "Muse Spark 1.2 Contributor").
- Hy3: open weights (Apache 2.0), 299B total / 21B active MoE, text-only, reasoning-capable, released July 6, 2026 (Artificial Analysis, "Hy3"; Command Code, "Tencent Hy3").
- MiMo V2.5: open weights (MIT), 310B total / 15B active MoE, text+image input, reasoning-capable, released April 22, 2026 (Artificial Analysis, "MiMo-V2.5"; Command Code, "MiMo V2.5").

## 3. Promo Tags and Expiry

Within the Go catalog, the deepest explicit discounts are attached to the MiMo line:

- MiMo V2.5: **-98% off** list, applied automatically at billing (no code/toggle); list vs promo: input $0.80 -> $0.14, output $4.00 -> $0.28, cache $0.16 -> $0.0028 (Command Code, "MiMo V2.5").
- MiMo V2.5 Pro: **-99% off** (input $2.00 -> $0.435, output $6.00 -> $0.87) (Command Code, "Models").

The Muse Spark 1.2 Contributor tier is itself the discount mechanism (~95% off the standard $1.25/$4.25 rate), not a time-limited promo code; it is described as "limited regions" on Go and "free, limited time" on the Zen free tier (OpenCode, "OpenCode Go"; OpenCode, "OpenCode Zen"; Command Code, "Muse Spark 1.2 Contributor").

Explicit expiry dates found in the captured docs:

- GPT 5.6 Sol: 50% discount through **September 18, 2026** (Zen-side; supplementary) (OpenCode, "OpenCode Zen").
- Gemini 3.7 Flash: -50% off through **December 31, 2026** (Command Code, "Models").
- MiniMax M3: -50% off (no explicit expiry captured) (Command Code, "Models").
- DeepSeek V4 Flash: off-peak half-price window (peak 01:00-04:00 and 06:00-10:00 UTC Mon-Fri) rather than a dated promo (OpenCode, "OpenCode Go"; Command Code, "Models").

The Go **6x multiplier itself carries no stated expiry** in the captured documentation (OpenCode, "OpenCode Go"). The Zen free-tier models (MiMo-V2.5 Free, Hy3 Free, Muse Spark 1.2 Contributor Free, Nemotron Free, Big Pickle) are flagged "limited time" / trial, with the Contributor and Nemotron free tiers training on data (OpenCode, "OpenCode Zen").

## 4. Privacy Tradeoff for Muse Spark (Training on Data)

The Muse Spark 1.2 Contributor tier is the only one of the three target models that trades price for data rights. Meta's official vendor page states the Contributor tier offers "heavily discounted token pricing in exchange for permission to use your prompts and completions to train future Meta models"; by contrast the Standard tier explicitly states "Your prompts/completions are NOT used to train Meta models" (Meta, "Meta Model API"). OpenCode's Go docs confirm Muse Spark 1.2 Contributor "trains on your prompts/completions," while Hy3, MiMo V2.5, and the other open models are "Not used" for training with 0-day retention (OpenCode, "OpenCode Go").

Operational consequences of the Contributor tier:

- **Rate limits are tighter**: Contributor tier is 100 RPM / 3,000,000 TPM per team vs Standard 3,000 RPM / 4,000,000 TPM (Meta, "Meta Model API").
- **Geographic restriction**: availability limited to Meta-permitted regions; the Go catalog adds a $60/mo included-usage cap on top of Meta's rates (Meta, "Meta Model API"; OpenCode, "OpenCode Go").
- **Zen free variant**: Muse Spark 1.2 Contributor Free on Zen is also flagged as training on data (OpenCode, "OpenCode Zen").

Net assessment: Muse Spark 1.2 Contributor is the cheapest input ($0.10) and the highest-Intelligence (56.8) of the three, with the largest context (1M+), but the training-on-data condition and tighter rate limits make it suitable for prototyping/testing where data sensitivity is acceptable, not for confidential production traffic. Hy3 and MiMo V2.5 preserve data privacy (no training, 0-day retention) at the cost of higher output price (Hy3) or lower Intelligence (MiMo V2.5) (OpenCode, "OpenCode Go"; Meta, "Meta Model API"; Command Code, "Models").

## Works Cited

Artificial Analysis. "Hy3." *Artificial Analysis*, artificialanalysis.ai/models/hy3.

Artificial Analysis. "MiMo-V2.5." *Artificial Analysis*, artificialanalysis.ai/models/mimo-v2-5-0424.

Artificial Analysis. "Muse Spark 1.2 (xhigh)." *Artificial Analysis*, artificialanalysis.ai/models/muse-spark-1-2.

Command Code. "Mimo V2.5." *Command Code*, commandcode.ai/models/mimo-v2-5.

Command Code. "Models." *Command Code*, commandcode.ai/models.

Command Code. "Muse Spark 1.2 Contributor." *Command Code*, commandcode.ai/models/muse-spark-1-2-contributor.

Command Code. "Tencent Hy3." *Command Code*, commandcode.ai/models/tencent-hy3.

Meta. "Meta Model API — Muse Spark Pricing & Rate Limits." *Meta Developer*, dev.meta.ai/docs/pricing-rate-limits.

OpenCode. "OpenCode Go." *OpenCode*, 28 Aug. 2026, opencode.ai/docs/go/.

OpenCode. "OpenCode Zen." *OpenCode*, 28 Aug. 2026, opencode.ai/docs/zen/.

## Unarchived/Excluded

None. The researcher's Phase A manifest records all 10 archived sources as passing evaluation (Relevance High/Med, Reliability High/Med) and lists no exclusions. First-party Tencent Hunyuan and Xiaomi MiMo model-card pages were not separately archived; the Artificial Analysis and Command Code pages already cite the vendor ids (`tencent/hy3-paid`, `xiaomi/mimo-v2-5`) and vendor homepages, satisfying the vendor-page requirement by proxy (per researcher manifest note).
