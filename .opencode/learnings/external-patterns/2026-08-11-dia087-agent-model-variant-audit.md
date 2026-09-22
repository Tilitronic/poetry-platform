# DIA-087 agent model variant audit - per-lane allocation optimization (2026-08-11)

- **Date:** 2026-08-11
- **Source:** DIA-087 audit (filed 2026-08-10, batch brief 2026-08-11) - docs lane + ai-auditor findings 8+9; implementation commits bcd4df0 (R1/R2/R3/R6) + dcc7260 (R4) + 2fb3f48 (ai-auditor findings 8+9 fix); S10-P6 registration by code-executor lane.
- **Status:** IMPLEMENTED - model allocation corrected across .opencode config and the opencode-go preset; stale pricing corrected and snapshot semantics documented; make test-config exit 0 (224 known WARNs).
- **Outcome note:** every agent audited; evidence-linked recommendations R1-R6; R5 queued (MiMo evaluation), all others applied. Ticket DIA-087 CLOSED 2026-08-11.

## Ticket

- **DIA-087** (Medium, CLOSED) - "audit picked models and model variants for current agents - is the assignment optimal?".
- **Related:** DIA-078 (V4-Flash beats V4-Pro on agentic benchmarks), DIA-062/DIA-064 (flash vs pro regressions), DIA-055 (model tiering).

## Findings and recommendations (evidence-linked)

- **R1 - 4 gpt-5-mini primaries -> deepseek-v4-flash.** conspecter / resource-manager / memory-manager / code-navigator primaries (github-copilot/gpt-5-mini) replaced with opencode-go/deepseek-v4-flash in the cebula preset. Rule: **model tiering by lane complexity** - these are volume/mechanical lanes (synthesis, curation, persistence, fast code search); a cheap, fast, order-following model is optimal (DIA-062/064 history: flash > pro for these lanes).
- **R2 - architector -> gemini-3.1-pro-preview.** architector primary changed opencode-go/qwen3.7-max -> github-copilot/gemini-3.1-pro-preview (fallback big-pickle retained). Rule: **creative/ambiguous lanes get the strongest capable model** - architecture and strategy benefit from top-tier reasoning.
- **R3 - opencode-go preset coder + 5 agents -> deepseek-v4-flash.** coder, resource-manager, conspecter, memory-manager, code-navigator, researcher moved from deepseek-v4-pro to deepseek-v4-flash. Rule: **model tiering by lane complexity** - clear order-following lanes (coder, mechanical docs) do not need pro; V4-Flash beats V4-Pro on agentic benchmarks (DIA-078).
- **R4 - stale V4 Pro pricing corrected.** ai-assist-sources.yaml stored $1.74/$3.48 -> corrected to $0.435/$0.87 (web-verified 2026-08-08, official DeepSeek pricing). Rule: **web-fresh pricing** - volatile pricing must be fetched live from Tier 2 URLs, never trusted from stale local copies.
- **R5 - queued.** MiMo evaluation deferred (not enough evidence at audit time). No action taken.
- **R6 - inline resource-manager model override removed.** opencode.jsonc:350 inline "model": "opencode-go/deepseek-v4-flash" removed (the opencode-go preset already declares the same model). Rule: **single source of truth** - one canonical model declaration per agent; inline overrides create drift surface.

## Fix (implemented 2026-08-11)

- **bcd4df0** - R1/R2/R3/R6: cebula preset 4 primaries -> v4-flash; architector -> gemini-3.1-pro-preview; opencode-go preset coder+5 -> v4-flash; opencode.jsonc:350 inline override removed.
- **dcc7260** - R4: stale V4 Pro pricing $1.74/$3.48 -> $0.435/$0.87 in ai-assist-sources.yaml (web-verified 2026-08-08).
- **2fb3f48** - ai-auditor findings 8+9: code_navigator role mapping corrected to "DS V4 Flash (Go)" in model_selection_guidelines; header pricing-storage contradiction clarified (authoritative pricing NEVER stored; inline prices are reference-only snapshots); strong_sides snapshot note added.

## Outcome

- Implemented + validated: make test-config exit 0 (224 known WARNs); husky pre-commit ran live (no --no-verify); ASCII-only (DIA-079).
- S10-P6 registration complete 2026-08-11: CHANGELOG entry added + this learnings registration + ticket CLOSED.

## Reusable lesson

Model allocation is a per-lane cost/quality optimization, not a one-size-fits-all choice: tier by lane complexity (mechanical/volume lanes -> cheap fast models; creative/ambiguous lanes -> strongest capable model), keep volatile pricing web-fresh instead of trusting stale local copies, and keep exactly one canonical model declaration per agent (inline overrides are drift surface). Audit findings must be evidence-linked (benchmarks, prior regression history) and every recommendation routed through the S10 workflow before application.

## Tags

DIA-087, DIA-078, DIA-062, DIA-064, model-allocation, model-tiering, deepseek-v4-flash, gpt-5-mini, gemini-3.1-pro-preview, pricing, single-source-of-truth, web-fresh-pricing, ai-auditor, opencode-go-preset
