# Res016: Coder-Escalated Model Evidence - Kimi K3, GPT-5.6 Luna, Qwen3.7 (DIA-111 Session 15)

Date: 2026-08-12
Ticket: DIA-111 (model escalation routing for coder and analyzer agents; Session 15 researcher findings, PERSISTENCE_RECOMMENDED: true, developer-approved persistence as conspect)
Author: researcher lane Session 15 (DIA-111 evidence) -> conspecter archival (res016)
Scope: synthesis of 25 fresh archived sources in knowledge/res016-coder-escalated-model-evidence/sources/ plus 5 cross-references to res013 (Go pricing/caps), res014 (coder ladder Rung0-4), and res015 (Go model list, MiMo-V2.5-Pro vs DeepSeek-V4-Pro side-by-side). Sections: (1) context, (2) comparison table, (3) per-model evidence with dates and URLs, (4) VERDICT, (5) corrections C1/C2, (6) confidence assessment, (7) unarchived sources. All claims cite the archived local files (archive-before-claim, DIA-072).

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 25
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

## 1. Context

DIA-111 Session 15 research returned findings on the models eligible for the coder-escalated lane with PERSISTENCE_RECOMMENDED: true; the developer approved persistence as a conspect. This conspect archives the fresh evidence and synthesizes a capability/pricing comparison for five candidate models (kimi-k3, gpt-5.6-luna, qwen3.7-max, qwen3.7-plus, deepseek-v4-pro) against the coder escalation ladder design from res014 (Rung0-4: deepseek-v4-flash default -> recovery -> qwen3.7-plus -> deepseek-v4-pro OR mimo-v2.5-pro -> re-review) and the analyzer-to-Luna escalation design.

Two evidence corrections were required by the Session 15 findings and are confirmed against the fresh archive (see Section 5): C1 — there is no model named "qwen3.7-pro"; the real Qwen3.7 family names are qwen3.7-max (closed text-only flagship) and qwen3.7-plus (multimodal balanced variant). C2 — gpt-5.6-luna is agentic-capable (full tool use, reasoning effort up to max) but is weak as a multi-agent SUBAGENT (rejected by Codex's native subagent path; community converged on top-level-thread deployment).

## 2. Comparison table (five candidates)

Pool/harness caveats: scores are NOT directly cross-comparable across trackers — Vals uses a minimal bash-tool-only mini-swe-agent harness (independent, same harness for all models); Moonshot/OpenAI/Alibaba tables are vendor-reported with each vendor's own harness; AA Coding Agent Index pairs models with agentic harnesses. BenchLM aggregates with its own weighting. All pricing/req-mo figures are from the official Go model list (opencode.ai/docs/go, archived fresh here and cross-referenced to res013).

| Model | SWE-bench Verified | Terminal-Bench | SWE-bench Pro | AA Coding Agent Index | Go pricing $/1M in/out | Go req/mo |
|---|---|---|---|---|---|---|
| kimi-k3 | 93.40% (Vals, independent, bash-only harness) | 88.3% TB 2.1 (vendor, Kimi Code); 85% TB 2.1 (AA independent); 80.9% TB 2.1 hosted (Vals) | not in archive (DeepSWE 67.5 vendor) | AA Coding index 76.24 (via GoldieBench); no AA Coding Agent Index v1.1 row archived | $3.00 / $15.00 (cached $0.30) | 490 |
| gpt-5.6-luna | no overall SWE-V in archive; Vals difficulty split 96/92/86/67 | 84.7% TB 2.1 (OpenAI official); 82.5% (danielvaughan citing BuildFastWithAI) | 62.7% (OpenAI official) | 74.6 (OpenAI official table); 75 (AA article) | $0.20 / $1.20 (<=272K); $0.40/$1.80 (>272K); cache write $0.25/$0.50 | 10,250 |
| qwen3.7-max | 80.4% (Alibaba vendor) | 69.7% TB 2.0 (Alibaba vendor, Terminus harness) | 60.6% (Alibaba vendor) | not in archive | $2.50 / $7.50 (cached $0.50) | 1,690 |
| qwen3.7-plus | 77.7% (BenchLM, Alibaba launch source) | 70.3% TB 2.0 (BenchLM, Alibaba launch source) | 57.6% (BenchLM, Alibaba launch source) | not in archive | $0.40 / $1.60 (<=256K); $1.20/$4.80 (>256K) | 21,600 |
| deepseek-v4-pro | 73.6% plain / 80.6% Max / 79.4% High (res013 BenchLM; cross-ref) | 67.9% TB 2.0 Max (Alibaba Qwen blog comparison; cross-ref context) | 55.4% Max (res015; cross-ref) | not in archive | $0.435 / $0.87 (cached $0.003625) | 17,150 |

Notes: (a) Kimi K3 is the ONLY candidate with an independent SWE-bench Verified score (Vals 93.40%, same-harness bash-only); the other candidates' SWE-V figures are vendor-reported (Alibaba/OpenAI/DeepSeek) or aggregator-transcribed (BenchLM). (b) gpt-5.6-luna has no overall SWE-V in the archive; its Vals difficulty split (96% <15min, 92% 15m-1h, 86% 1-4h, 67% >4h) shows its strongest relative showing on quick-turn tasks. (c) qwen3.7-max req/mo is low (1,690) at $2.50/$7.50 — it is the most expensive candidate per request on Go. (d) kimi-k3 req/mo is the lowest of the five (490) at $3/$15 — the Go cap is the binding constraint for kimi-k3 adoption. (e) BenchLM category ranks (2026-08-11 data): kimi-k3 Agentic #5 of 129 (74.2), Coding #5 of 135 (77.7), overall #5 of 218 (80.5); gpt-5.6-luna Agentic #35 of 129 (54.6), Coding #6 of 135 (72.6), overall #26 of 218 (66.8); qwen3.7-plus Agentic #107 of 129 (38.8), Coding #31 of 135 (57.6), overall #31 of 218 (65.8). Luna's Agentic rank is its weakest category — see Section 5 C2.

## 3. Per-model evidence (dates + URLs)

### 3.1 Kimi K3 (Moonshot AI, released 2026-07-16/17)

- Identity: 2.8T-parameter MoE (16 of 896 experts active; corrected from launch-day 2.5T estimate), Kimi Delta Attention + Attention Residuals, Stable LatentMoE, native multimodal (text+image, MoonViT-V2), 1M-token context, MXFP4 weights / MXFP8 activations, Kimi K3 License (open weights). Always-on thinking with reasoning_effort low/high/max (default max); trained in preserved-thinking-history mode — the complete assistant message including reasoning_content must be passed back (github.com/MoonshotAI/Kimi-K3; kimi.com/blog/kimi-k3).
- Independent SWE-bench Verified: **93.40%** on Vals, strongest open-weight model, ahead of Claude Opus 4.8 (88.60%) and Grok 4.5 (86.60%); difficulty split 92/95/93/67 (https://www.vals.ai/benchmarks/swebench).
- Vendor coding table (reasoning max, Kimi Code harness unless noted): DeepSWE 67.5 (67.3 with mini-SWE-agent), ProgramBench 77.8 (raw pass rate), Terminal-Bench 2.1 88.3 (85% independently on AA's own harness), FrontierSWE 81.2, SWE-Marathon 42.0, Kimi Code Bench 2.0 72.9 (73.7 with Claude Code) (github.com/MoonshotAI/Kimi-K3; nxcode.io guide; emergent.sh).
- Independent indices (AA, July 23 2026 snapshot): Intelligence Index 57 (fourth overall, FIRST among open-weight models); AA Coding 76.24, Agentic 50.07; LMArena Frontend Code Arena #1 debut (Elo 1679, 17-place jump over K2.6); AA-Briefcase Elo 1548 (#2 behind Fable 5) but $10.57/task and 56.4 min/task (slow, verbose: 35 tok/s vs ~78 median; 130M output tokens vs 63M median; $0.94 per Intelligence Index task) (emergent.sh; goldiebench.com; together.ai).
- Fireworks routing data: K3 selected for 72-96% of tasks by an oracle router, up to 50x cheaper on long agentic loops; K3 vs Fable 5 near-tied on SWE tasks (92.4% vs 92.6%) (emergent.sh).
- Hallucination tradeoff: AA-Omniscience accuracy 46% / non-hallucination 49% (hallucinates on ~51% of uncertain questions; mid-pack among frontier) (emergent.sh).
- BenchLM (2026-08-11): overall 80.5/100 #5 of 218; Agentic 74.2 #5 of 129; Coding 77.7 #5 of 135; Multimodal 87.9 #3 of 35 (benchlm.ai/models/kimi-3). Note: the Session 15 brief cited "Agentic #4, Coding #5 of 133"; the archived page (data 2026-08-11) shows Agentic #5 of 129 / Coding #5 of 135 — rank/cohort drift between researcher session and archival date; the archived page is authoritative.
- Go availability: model id kimi-k3, endpoint opencode.ai/zen/go/v1/chat/completions, $3.00/$15.00 (cached $0.30), 490 req/mo, 0-day retention, not used for training (opencode.ai/docs/go). Moonshot's own OpenCode integration: `opencode auth login` -> Kimi For Coding; models k3 / k3-256k / kimi-for-coding / kimi-for-coding-highspeed; `/variants` maps Default->high, low, high, max (kimi.com/code/docs/en/third-party-tools/opencode; platform.kimi.ai/docs/guide/open-code).

### 3.2 GPT-5.6 Luna (OpenAI, released 2026-07-09; 80% price cut 2026-07-30)

- Identity: most cost-efficient tier of GPT-5.6 family (Sol flagship, Terra balanced, Luna fastest/cheapest); "roughly corresponds to the nano model tier used in earlier GPT-5 families"; 1,050,000 context, 922,000 max input, 128,000 max output, knowledge cutoff Feb 16, 2026; reasoning.effort none/low/medium(default)/high/xhigh/max; supports tool use (web_search, file_search, code_interpreter, hosted_shell, apply_patch, skills, computer_use, mcp, tool_search), structured outputs, prompt caching (developers.openai.com/api/docs/models/gpt-5.6-luna).
- Coding (OpenAI official table): AA Coding Agent Index 74.6; SWE-Bench Pro 62.7%; DeepSWE v1.1 67.2%; Terminal-Bench 2.1 84.7%; "Luna outperforms Opus 4.8 [on the Coding Agent Index] in roughly one-third of the time, about half the output tokens, at approximately one-quarter the estimated cost" (openai.com/index/gpt-5-6).
- Vals SWE-bench difficulty split: 96/92/86/67 (https://www.vals.ai/benchmarks/swebench).
- Independent (AA): Intelligence Index 51 (max) at $0.21/task (~80% less than Sol's $1.04); AA Coding Agent Index 75; on the Intelligence-vs-Cost Pareto frontier ahead of Terra; matches/exceeds GLM-5.2 and Gemini 3.5 Flash at lower cost; "very verbose" (130M output tokens vs 61M median), 182.5 tok/s but ~136s time-to-first-token at max effort (artificialanalysis.ai/articles/gpt-5-6-has-landed; orcarouter.ai).
- BenchLM (2026-08-11): overall 66.8/100 #26 of 218; Coding 72.6 #6 of 135 (strong); Agentic 54.6 #35 of 129 (weak — its weakest category); Knowledge 81.2 #12 of 56; API pricing $0.2/$1.2, cached $0.02 (benchlm.ai/models/gpt-5-6-luna).
- PRICE CUT and positioning (2026-07-30): Luna price cut 80% ($1/$6 -> $0.20/$1.20); "fastest and most affordable model"; "high-volume work at very high levels of quality... can use tools and complete multi-step workflows"; official workflow example: "use Sol to resolve uncertainty and define the plan, then use Luna to implement well-specified changes, write and run tests, and evaluate the results"; "Luna delivers performance comparable to models that were frontier-class a year ago at roughly 6 cents on the dollar per task" (openai.com/index/advancing-the-price-performance-frontier-with-gpt-5-6/).
- Routing lane (Codex ecosystem): Luna sweet spot = "Well-specified fixes, transformation, classification, volume work"; Sol = ambiguous/unfamiliar/architecture; Terra = everyday implementation; migration map gpt-5.4-mini -> gpt-5.6-luna; profile-based routing (scout/architect/ci) with reasoning-effort as an independent dial (codex.danielvaughan.com/2026/08/05/...; github.com/luckeyfaraday/codex-router: Luna = "tightly scoped, repetitive, high-throughput work").
- SUBAGENT WEAKNESS (CRITICAL): Codex's native subagent system does not accept Luna ("Luna not permitted as a subagent" — hard block); stock model catalog marks Luna as v1 (not v2 multi-agent protocol); the community converged on giving Luna Max its OWN top-level thread, not a slot in the subagent graph, accepting context isolation as the price; the "luna_worker" pattern went viral then was retracted and rewired within a week (orcarouter.ai/blog/gpt-5-6-luna-max-codex-playbook).

### 3.3 Qwen3.7-Max (Alibaba, released 2026-05-20/21)

- Identity: closed-source (API-only), TEXT-ONLY flagship of the Qwen3.7 series; 1M context; agent-era foundation model; preserves thinking (preserve_thinking recommended for agentic tasks); 35-hour autonomous ceiling, 1,000+ sequential tool calls (alibabacloud.com/blog/qwen3-7-the-agent-frontier_603154; aimodelsnavi.com/en/blog/qwen3-7-max-deep-dive; apidog.com).
- Benchmarks (vendor, Alibaba): SWE-Verified 80.4 (on par with Opus-4.6 Max 80.8 and DS-V4-Pro Max 80.6); SWE-Pro 60.6; Terminal-Bench 2.0-Terminus 69.7 (beats DS-V4-Pro Max 67.9); MCP-Mark 60.8; MCP-Atlas 76.4; SkillsBench 59.2 (evaluated VIA OPENCODE on 78 tasks); Kernel Bench L3 1.98x median speedup / 96% win rate; GPQA Diamond 92.4; HLE 41.4 (alibabacloud.com).
- Autonomous experiment: 35-hour kernel optimization on unseen T-Head ZW-M890 PPUs: 1,158 tool calls, 432 kernel evaluations, 10.0x geometric-mean speedup (vs GLM 5.1 7.3x, Kimi K2.6 5.0x, DeepSeek V4 Pro 3.3x, Qwen3.6-Plus 1.1x) (alibabacloud.com; aimodelsnavi.com).
- BenchLM: overall 92/100 #3 of 117; Coding 92.2 #4; Reasoning 96.4; Agentic 87.7 (aimodelsnavi.com, citing BenchLM).
- AA comparison: Intelligence Index 47 (Max) vs 39 (Plus); output speed 205 tok/s (Max) vs 56 (Plus); both proprietary (artificialanalysis.ai/models/comparisons/qwen3-7-plus-vs-qwen3-7-max).
- Go availability: qwen3.7-max, endpoint opencode.ai/zen/go/v1/messages (@ai-sdk/anthropic), $2.50/$7.50 (cached $0.50), 1,690 req/mo (opencode.ai/docs/go).

### 3.4 Qwen3.7-Plus (Alibaba, released 2026-06-01/03)

- Identity: closed-source (API-only) multimodal balanced variant ("Max with eyes"): text+image+video input, GUI grounding (ScreenSpot Pro 79.0), same 1M context and 35-hour ceiling; NOT open weights (breaks Qwen's open-source habit) (apidog.com; dev.to).
- Benchmarks (BenchLM, Alibaba launch source): SWE-bench Verified 77.7%; SWE-bench Pro 57.6%; Terminal-Bench 2.0 70.3%; LiveCodeBench 89.6%; MCP-Atlas 73.2; OSWorld-Verified 73.3; overall 65.8/100 #31 of 218; Agentic #107 of 129 (38.8 — notably weak); Coding #31 of 135; Multilingual #3 of 13 (benchlm.ai/models/qwen3-7-plus).
- Vendor vs text flagship: slightly trails Max on text (LM Arena #15 vs #13 text, #12 vs #10 coding); ties/beats on vision tasks; real-task ofox test: Plus reads screenshots (5/5 debug quality vs Max 2/5), Max ~7-15% faster on pure text (dev.to).
- Go availability: qwen3.7-plus, $0.40/$1.60 (<=256K) / $1.20/$4.80 (>256K), 21,600 req/mo (opencode.ai/docs/go). Note: dev.to reports $2.50/$7.50 for Plus on Bailian (source conflict on list price); Go pricing is authoritative for this conspect.

### 3.5 DeepSeek V4 Pro (cross-reference, not re-archived)

- Cross-referenced from res013 (SWE-bench Verified 73.6% plain / 80.6% Max / 79.4% High, BenchLM) and res015 (SWE-bench Pro 55.4% Max, Terminal-Bench 2.0 67.9% Max, GPQA-Diamond 90.1% Max; DeepSeek-official vendor-reported figures) and the Qwen blog comparison (TB 2.0 67.9). Go: $0.435/$0.87, 17,150 req/mo (opencode.ai/docs/go).
- Baseline escalation candidate at Rung 3 (res014 ladder); no fresh archival in res016 (per the cross-reference instruction).

## 4. VERDICT

**kimi-k3 is recommended as the coder-escalated default model** — it is the only candidate in the comparison with an INDEPENDENT, same-harness SWE-bench Verified score (Vals 93.40%, best open-weight model, ahead of Claude Opus 4.8 and Grok 4.5), and it leads on the agentic-coding evidence overall (TB 2.1 88.3% vendor / 85% independent, DeepSWE 67.5, FrontierSWE 81.2, AA Intelligence 57 first open-weight, LMArena Frontend #1). It fits the escalated-coder lane (Rung 2+ in the res014 ladder, replacing or preceding qwen3.7-plus as the strong-reasoning escalation) because hard, multi-file, long-horizon work is exactly where its economics favor it ($0.94 per hard task despite high verbosity; up to 50x cheaper on long agentic loops per Fireworks). The binding constraint is the Go cap: 490 req/mo at $3/$15 — kimi-k3 must be used as a SPARING escalation tier, not a volume default.

**Cap-fallback: deepseek-v4-pro (and/or mimo-v2.5-pro per res015) when the kimi-k3 Go cap is exhausted or the task is reasoning-heavy.** deepseek-v4-pro (17,150 req/mo, $0.435/$0.87) retains a vendor-reported SWE-bench Verified 80.6% (Max) and GPQA-Diamond 90.1% reasoning edge (res015); mimo-v2.5-pro (16,300 req/mo, identical pricing) is the res015-recommended Rung-3 default with a benchmark gap caveat. kimi-k3, deepseek-v4-pro, and mimo-v2.5-pro together form the strong-escalation tier, with availability sidestep per the res014 ladder fallback semantics (nax ADR-025).

**gpt-5.6-luna is recommended for the ANALYZER-escalated lane, with the subagent-weakness caveat (C2).** Luna is agentic-capable (full tool use, reasoning to max, 1M context) and is a genuine Pareto-frontier cost play (Intelligence Index 51 at $0.21/task; AA Coding Agent Index 75; official "well-specified changes" lane: plan with Sol, implement well-specified changes + tests + evaluation with Luna). BUT: it is weak as a multi-agent SUBAGENT — Codex's native subagent path rejects it (v1 catalog filter, not post-trained for v2 multi-agent protocol), and the community converged on top-level-thread deployment with a five-question handoff packet. For the analyzer lane (a single escalated expert-analysis step, not a subagent graph), Luna fits: cheap, fast on quick-turn tasks (Vals 96% <15min), strong at classification/transformation/volume. For any design that would place Luna INSIDE a multi-agent hierarchy as a subordinate, the evidence says: give it its own thread or do not use it.

**qwen3.7-max / qwen3.7-plus are NOT recommended for the coder-escalated lane.** qwen3.7-max (80.4 SWE-V vendor, 1,690 req/mo at $2.50/$7.50) is the most expensive-per-request candidate with the lowest Go cap, closed-source, and its SWE-V figure is vendor-reported; qwen3.7-plus (77.7 SWE-V BenchLM, 21,600 req/mo) has a notably weak Agentic rank (#107 of 129) that undercuts its value as an agentic escalation tier. Both remain viable as architecture-lane/primary models per the res014 design (qwen3.7-plus: architecture-strength reasoning at 21,600 req/mo) but are not escalation-strength evidence.

## 5. Corrections (C1, C2)

- **C1: "qwen3.7-pro" does not exist.** The Session 15 evidence needed correction on the Qwen3.7 family. The official Go model list (opencode.ai/docs/go, archived fresh) contains qwen3.7-max and qwen3.7-plus (and qwen3.8-max) — NO qwen3.7-pro. The real names: qwen3.7-max (closed, text-only flagship, $2.50/$7.50, 1,690 req/mo) and qwen3.7-plus (closed, multimodal balanced, $0.40/$1.60 <=256K, 21,600 req/mo). Confirmed across four independent sources (opencode.ai/docs/go; alibabacloud.com; aimodelsnavi.com; apidog.com). HIGH confidence.
- **C2: gpt-5.6-luna is agentic-capable but subagent-weak.** Luna supports the full tool-use surface, reasoning effort up to max, structured outputs, and multi-step workflows (developers.openai.com; openai.com) — the agentic-CAPABLE half. But it is weak as a multi-agent SUBAGENT: Codex's native subagent system does not accept Luna ("Luna not permitted as a subagent"); the stock model catalog marks it v1 rather than v2; the practitioner consensus is top-level-thread deployment with an explicit handoff packet; BenchLM independently ranks Luna Agentic #35 of 129 (54.6) — its weakest category (orcarouter.ai; benchlm.ai/models/gpt-5-6-luna). This supports the analyzer-escalation design (single expert step) while ruling out Luna-inside-a-subagent-graph designs. HIGH confidence (multi-source, including a practitioner retract-and-rewire episode documented with dates).

## 6. Confidence assessment

- HIGH: Go availability, pricing, and req/mo for all five models (official opencode.ai/docs/go archived fresh, cross-checked against res013/res015); Kimi K3 Vals SWE-bench 93.40% (independent, same-harness); Luna pricing/positioning and the 80% price cut (OpenAI official pages); corrections C1 and C2 (multiple mutually-consistent sources); BenchLM ranks (archived pages, 2026-08-11 data).
- MEDIUM-HIGH: Kimi K3 vendor coding table (Moonshot-reported, mixed harnesses — the harness caveat is explicitly documented by NxCode and Emergent; AA independent readings: Intelligence 57, TB 2.1 85%); Luna AA Coding Agent Index 75 vs OpenAI's 74.6 (aggregator variance, same index).
- MEDIUM: Qwen3.7-Max SWE-V 80.4 and all Alibaba vendor figures (vendor-reported, single source); Kimi K3 hallucination rate (AA-Omniscience non-hallucination 49%; material for production use); kimi-k3 BenchLM rank drift vs Session 15 brief (#4 vs #5 Agentic) — archived page authoritative.
- EXCLUDED per DIA-072: no SWE-bench Verified overall score is asserted for gpt-5.6-luna (none in archive); no AA Coding Agent Index row is asserted for kimi-k3/qwen models (not archived); no independent reproduction is claimed for any vendor-reported score.

## 7. Unarchived sources

None. All 25 requested fresh URLs were archived successfully in Phase A (25/25, 0 failures; see .source-urls.txt for per-URL archival mapping). Five cross-references recorded without re-download (res013 opencode-go-pricing.md + swebench-vals.md; res014 coder ladder Rung0-4; res015 opencode-docs-go.md + MiMo-vs-DeepSeek side-by-side). No source is marked [source not archived - excluded per DIA-072 policy].

## MLA citations (archived local files, res016)

- Anomaly. "Go." OpenCode Docs, 12 Aug. 2026. knowledge/res016-coder-escalated-model-evidence/sources/opencode-docs-go.md.
- Vals AI. "SWE-bench (Verified)." Vals AI, 2026. knowledge/res016-coder-escalated-model-evidence/sources/vals-swebench.md.
- Moonshot AI. "Kimi-K3." GitHub, 2026. knowledge/res016-coder-escalated-model-evidence/sources/github-kimi-k3.md.
- "Kimi K3 benchmarks: the full breakdown." Emergent, 2026. knowledge/res016-coder-escalated-model-evidence/sources/emergent-kimi-k3-benchmark.md.
- "Kimi K3 Benchmarks Explained: A Coding-Agent Evaluation Guide (2026)." NxCode, 2026. knowledge/res016-coder-escalated-model-evidence/sources/nxcode-kimi-k3-guide.md.
- "Kimi K3 guide: benchmarks, pricing, and how to use it." Together AI, 2026. knowledge/res016-coder-escalated-model-evidence/sources/together-kimi-k3-guide.md.
- "Kimi K3." GoldieBench, 2026. knowledge/res016-coder-escalated-model-evidence/sources/goldiebench-kimik3.md.
- BenchLM. "Kimi K3 model profile (Moonshot AI)." BenchLM.ai, 11 Aug. 2026. knowledge/res016-coder-escalated-model-evidence/sources/benchlm-kimi-3.md.
- Moonshot AI. "Using Kimi in OpenCode." Kimi Code Docs, 2026. knowledge/res016-coder-escalated-model-evidence/sources/kimi-docs-opencode.md.
- Moonshot AI. "Connect OpenCode to the Kimi Open Platform." Kimi Open Platform Docs, 2026. knowledge/res016-coder-escalated-model-evidence/sources/kimi-platform-opencode.md.
- OpenAI. "GPT-5.6 Luna." OpenAI API Reference, 2026. knowledge/res016-coder-escalated-model-evidence/sources/openai-dev-gpt-5-6-luna.md.
- OpenAI. "Introducing GPT-5.6." OpenAI, 9 Jul. 2026. knowledge/res016-coder-escalated-model-evidence/sources/openai-gpt-5-6.md.
- "GPT-5.6 has landed." Artificial Analysis, 2026. knowledge/res016-coder-escalated-model-evidence/sources/aa-gpt-5-6-landed.md.
- "GPT-5.6 benchmarks: Sol, Terra, and Luna tested." GoML, 2026. knowledge/res016-coder-escalated-model-evidence/sources/goml-gpt-5-6-benchmarks.md.
- BenchLM. "GPT-5.6 Luna model profile (OpenAI)." BenchLM.ai, 11 Aug. 2026. knowledge/res016-coder-escalated-model-evidence/sources/benchlm-gpt-5-6-luna.md.
- OpenAI. "Advancing the price-performance frontier with GPT-5.6." OpenAI, 30 Jul. 2026. knowledge/res016-coder-escalated-model-evidence/sources/openai-price-performance-luna.md.
- Vaughan, Daniel. "GPT-5.6 model migration for Codex CLI: Luna, Terra, Sol." codex.danielvaughan.com, 5 Aug. 2026. knowledge/res016-coder-escalated-model-evidence/sources/codex-danielvaughan-gpt-5-6-routing.md.
- luckeyfaraday. "codex-router." GitHub, 2026. knowledge/res016-coder-escalated-model-evidence/sources/github-codex-router.md.
- "The GPT-5.6 Luna Max Codex playbook." OrcaRouter, 2026. knowledge/res016-coder-escalated-model-evidence/sources/orcarouter-luna-max-playbook.md.
- Qwen Team. "Qwen3.7: The Agent Frontier." Alibaba Cloud Community, May 2026. knowledge/res016-coder-escalated-model-evidence/sources/alibabacloud-qwen3-7-agent-frontier.md.
- "Qwen3.7-Max Deep Dive." AIModelsNavi, 2026. knowledge/res016-coder-escalated-model-evidence/sources/aimodelsnavi-qwen3-7-max.md.
- BenchLM. "Qwen3.7 Plus model profile (Alibaba)." BenchLM.ai, 11 Aug. 2026. knowledge/res016-coder-escalated-model-evidence/sources/benchlm-qwen3-7-plus.md.
- "Qwen 3.7 Plus: the multimodal budget sibling of Qwen3.7-Max." Apidog, 2026. knowledge/res016-coder-escalated-model-evidence/sources/apidog-qwen-3-7-plus.md.
- Fox, Owen. "Qwen 3.7 Plus vs Qwen 3.7 Max in 2026." DEV Community, 2026. knowledge/res016-coder-escalated-model-evidence/sources/devto-qwen37-plus-vs-max.md.
- Artificial Analysis. "Qwen3.7 Plus vs Qwen3.7 Max." Artificial Analysis, 2026. knowledge/res016-coder-escalated-model-evidence/sources/aa-qwen37-plus-vs-max.md.

Cross-referenced (prior conspect archives, not re-downloaded):
- Anomaly. "Go." OpenCode Docs, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/opencode-go-pricing.md.
- Vals AI. "SWE-bench Verified." Vals AI, 8 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/swebench-vals.md.
- Res014 conspect (coder escalation ladder Rung0-4, DIA-111): knowledge/res014-model-escalation-routing/res014-model-escalation-routing-conspect.md.
- Anomaly. "Go." OpenCode Docs, 12 Aug. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/opencode-docs-go.md.
- Res015 conspect (MiMo-V2.5-Pro vs DeepSeek-V4-Pro side-by-side): knowledge/res015-mimo-v25-pro-evaluation/res015-mimo-v25-pro-evaluation-conspect.md.

---
Document prepared by conspecter lane on 2026-08-12. All citations point to locally archived artifacts under knowledge/res016-coder-escalated-model-evidence/sources/ plus cross-references to res013/res014/res015 archives.
