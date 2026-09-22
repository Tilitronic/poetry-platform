# Learnings: Muse Spark admission - privacy cleared (DIA-260828-qtsi)
Date: 2026-08-28
Source: ai-specialist gate ses_fb70fab10ffeLXW8rVCdflmmed, res041, ana036, developer statement

## Findings
- Muse Spark 1.2 Contributor $0.10/$0.20 Intel 56.8 Coding 72.2 GPQA 90.4 1.05M context 226600 req/mo - cheapest + highest intelligence of promo trio, NOT worse than Hy3 ($0.14/$0.58 42.2) or MiMo V2.5 ($0.14/$0.28 38.0).
- Previously excluded only for privacy: Meta Contributor trains on prompts/completions, 100 RPM vs 3000, region-limited -> active:false ana036 R7.
- Developer cleared privacy: no sensitive traffic, no reason to exclude.
- RPM not binding: 100 RPM = 144k/day vs workload 120 dispatches/day max (ana036).
- Recommendation: set model-registry.yaml active:true lane=[coder,reviewer,analyzer,researcher,conspecter,openspec-plan] fallback=[hy3,mimo-v2.5], admit to BOTH cebula-hy3 (active) and promo presets, Hy3 as fallback for burst.

## Implication
Update model-registry.yaml and oh-my-opencode-slim.jsonc presets + scripts/promo-preset-apply ROUTING per gate. Admit Muse Spark as primary for coder/reviewer/analyzer/researcher/conspecter/openspec-plan.
