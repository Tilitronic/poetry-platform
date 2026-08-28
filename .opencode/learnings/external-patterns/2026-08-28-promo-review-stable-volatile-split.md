# Learnings: promo-review skill - stable vs volatile split (DIA-260828-qtsi)
Date: 2026-08-28
Source: ai-specialist gate ses_fb7ed8294ffeTMXVmlTLxwLXTf, res041/res030/researcher DIA-260828-qtsi

## Findings
- BENCHMARKS/PARAMS are STABLE (Intelligence Index, Coding Index, GPQA, context, licensing). Cached on memory shelf (knowledge/res041-opencode-go-promo-benchmarks). Cache never deprecated, reuse - do not re-fetch. Muse Spark 1.2 Contributor 56.8/72.2/90.4 1.05M; Hy3 42.2/58.8/89.7 262K; MiMo V2.5 38.0/56.8/84.9 1M. Muse is best intelligence + cheapest input ($0.10) but excluded for privacy.
- PROMOS/USAGE-LIMITS/PRICING are VOLATILE (6x general, Hy3-specific 8x, -98% MiMo, 2x GLM-5.3-Flash, caps $12/5h $30/wk $60/mo, expiry dates). Must fetch LIVE every review from opencode.ai/go (landing, NOT just docs/go) + julien.cloud tracker + commandcode.ai/models. Previous fetch of docs/go alone missed all promo tiers.
- Hy3 x8 promo CONFIRMED live (opencode.ai/go "Hy3 8x usage" + julien.cloud "Hy3 (8x usage) 2026-07-06 | active" -> effective $0.02/$0.07). Inverts promo preset premise: worker->mimo-v2.5 ($0.14/$0.28) is now MORE expensive than promo-Hy3; do NOT activate promo preset as-is under 8x.
- Muse Spark excluded NOT for benchmarks (it is cheapest + highest intelligence) but for privacy (Meta Contributor trains on prompts/completions, 100 RPM vs 3000, region-limited) -> active:false, pending privacy review (ana036 R7). Skill must explicitly compare and explain exclusion + admission path for non-sensitive traffic.
- Persistence rule: stable -> shelf (never deprecated); volatile -> live fetch, never cached as durable truth; if written to promo-registry.json timestamp with fetched_at + 7-day stale.

## Implication for skill
Update .opencode/skills/promo-review/SKILL.md to encode stable-vs-volatile split, landing-page+tracker fetch with promo-multiplier capture, >2x ROUTING-INVERSION threshold, manual newest conspect pick, timestamp promo-registry.json only, and explicit Muse Spark comparison section.
