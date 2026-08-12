# Res017: Rung-3 Coder-Escalation Benchmark Evidence (DIA-116)

Date: 2026-08-12
Ticket: DIA-116 (authoritative third-party benchmark evidence for the three coder-escalation candidates kimi-k3 / deepseek-v4-pro / mimo-v2.5-pro, closing the DIA-114 evidence gap by replacing vendor-reported scores with independently reproduced ones)
Author: researcher lane res-1 (2026-08-12) -> conspecter archival (res017)
Scope: synthesis of 21 fresh archived sources in knowledge/res017-rung3-benchmark-evidence/sources/ (22 requested; 1 failure documented in Section 7) plus cross-references to res013 (Go pricing/caps), res014 (Rung0-4 ladder), res015 (MiMo-V2.5-Pro vs DeepSeek-V4-Pro side-by-side, DIA-114), and res016 (coder-escalated model evidence, DIA-111). Sections: (1) context, (2) comparison table with independence flags, (3) per-model evidence with dates and URLs, (4) VERDICT, (5) corrections/notes, (6) confidence assessment, (7) unarchived sources. All claims cite the archived local files (archive-before-claim, DIA-072).

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 21
phase-a-failures: 1
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

## 1. Context

DIA-116 asks for authoritative third-party benchmark evidence for the three coder-escalation candidates (kimi-k3, deepseek-v4-pro, mimo-v2.5-pro) that were provisionally ranked in DIA-114/res015, replacing vendor-reported scores with independently reproduced ones. The specific gap DIA-114 flagged: Kimi K3 had NO independently reproduced SWE-bench Verified score at that time (res015/res016 relied on Vals via cross-reference; the launch-week evidence gap is documented in the archived apidog article of 17 Jul 2026, which explicitly states "what's still missing is a neutral rerun of the coding suites and a classic SWE-bench Verified score" and "wait for the neutral figure").

That neutral figure now exists and is archived: Vals AI independently reproduced Kimi K3 at 93.40% SWE-bench Verified (mini-swe-agent bash-only harness, leaderboard updated 2026-08-08). This conspect conserves that reproduction plus the NIST CAISI independent evaluation of DeepSeek V4 Pro (SWE-bench Verified 74%, Inspect ReAct, 2026-05-01) and the confirmed absence of any independent coding-benchmark reproduction for MiMo-V2.5-Pro (all headline figures trace to Xiaomi vendor sources).

Independence classification used throughout: INDEPENDENT = run by a third party (Vals, Artificial Analysis, NIST CAISI, evals.report-verified community runs) without vendor input; VENDOR = self-reported by the model's own lab; UNVERIFIED = aggregator-transcribed, not reproduced (evals.report status flag); NOT-IN-ARCHIVE = researcher-reported value whose source page is JS-interactive and could not be statically archived (AA per-model tables).

## 2. Comparison table (three candidates, with per-score dates and independence flags)

Pool/harness caveats: SWE-bench Verified scores are NOT directly cross-comparable across trackers. Vals uses a minimal bash-tool-only mini-swe-agent harness (same harness for all models, independent). NIST CAISI uses Inspect's ReAct agent with 500k weighted-token budget and notes its scores "tend to be lower than those of other evaluators, likely due to system prompt, scaffolding, and token budget differences." Vendor figures use each vendor's own harness. AA Intelligence Index v4.1.1 is a composite of 9 evaluations including Terminal-Bench v2.1, SciCode, GDPval-AA v2, tau3-Banking, HLE, GPQA Diamond, CritPt, AA-Omniscience, AA-LCR. Go req/mo and pricing cross-referenced from res013 (kimi-k3, deepseek-v4-pro) and res015 (mimo-v2.5-pro).

| Benchmark | kimi-k3 | deepseek-v4-pro | mimo-v2.5-pro |
|---|---|---|---|
| SWE-bench Verified (independent) | **93.40%** Vals mini-swe-agent, 2026-08-08 [INDEPENDENT] | **74%** NIST CAISI Inspect ReAct, 2026-05-01 [INDEPENDENT] | NONE EXISTS [no independent reproduction found] |
| SWE-bench Verified (vendor/headline) | 93.40% (Vals is the reference; Moonshot publishes no SWE-V headline in the archived card) | 80.6% Max (HF card; evals.report flags **Unverified**, 2026-04-24) | 78.9% (Xiaomi HF card / mimo.xiaomi.com; evals.report status "Verified" = verified-as-published, still vendor-originated, 2026-04-22) |
| AA Intelligence Index (independent composite) | 57.11 (BenchmarkList snapshot, rank 3/464, 2026-07-21) / 60 (AA live comparison page) [INDEPENDENT] | 45 (AA comparison page, max effort) [INDEPENDENT] | 43 (AA comparison page) [INDEPENDENT, composite only] |
| Terminal-Bench 2.1 (Vals harness, benchmarklist leaderboard 2026-08-11) | 80.899% (rank 11, imported from Vals, 2026-07-28) [INDEPENDENT] | 72.1% (rank 20, "DeepSeek V4 Pro Preview", model-card source, 2026-07-31) | 57.303% (rank 38, imported from Vals, 2026-07-28) [INDEPENDENT] |
| Terminal-Bench 2.1 (AA-run, Terminus 2 harness) | 85.0% (component of AA II v4.1.1, Verified, 2026-07-21) [INDEPENDENT] | ~64.8% [NOT-IN-ARCHIVE; AA per-model table JS-interactive] | ~65.2% [NOT-IN-ARCHIVE; AA per-model table JS-interactive] |
| Terminal-Bench 2.1 (vendor harness) | 88.3% (Kimi Code harness, Moonshot launch post / HF card) [VENDOR] | none in archive | none in archive |
| Terminal-Bench 2.0 | not relevant (2.1 supersedes) | 67.9% (evals.report Verified, 2026-04-24) | 68.4% (evals.report Verified, 2026-04-22; vendor-sourced per llmreference) |
| Price per 1M (AA blended) | $2.31 | $0.18 | $0.18 |
| Go pricing / req-mo (res013/res015 cross-ref) | $3.00/$15.00, 490 req/mo | $0.435/$0.87, 17,150 req/mo | $0.435/$0.87, 16,300 req/mo |

Head-to-head deltas from archived independent values: SWE-bench Verified kimi-k3 93.4 vs CAISI 74 = **+19.4 points** (the "~19-20 point lead" on the comparable independent benchmark); AA Intelligence Index kimi-k3 60 vs 45 (deepseek) = +15, vs 43 (mimo) = +17; Terminal-Bench 2.1 (Vals harness) kimi-k3 80.9 vs 72.1 (deepseek) = +8.8, vs 57.3 (mimo) = +23.6. kimi-k3 leads every comparable archived benchmark over both co-candidates.

## 3. Per-model evidence (dates + URLs)

### 3.1 Kimi K3 (Moonshot AI, released 2026-07-16)

- Independent SWE-bench Verified: **93.40%** on Vals, strongest open-weight model, ahead of Claude Opus 4.8 (88.60%) and Grok 4.5 (86.60%); difficulty split 92/95/93/67; leaderboard updated 8/8/2026; 79 models evaluated; leader Claude Opus 5 at 97.00% (https://www.vals.ai/benchmarks/swebench). This is the independent reproduction DIA-114 flagged as missing; it uses the same mini-swe-agent bash-only harness for all models, placing the burden on the model rather than the harness (https://www.swebench.com/verified.html).
- BenchmarkList model profile (66 benchmarks): SWE-bench Verified 93.4% rank 4/72 (Vals source, 2026-07-28, cost/test $0.76); Terminal-Bench 2.1 88.3% rank 3/152 (launch-post source); AA Intelligence Index 57.11 rank 3/464 (Verified, 2026-07-21) with component breakdown: Coding Index 76.24, Agentic Index 50.07, GDPval-AA 1679.21 Elo, Terminal-Bench v2.1 85.0%, SciCode 58.7%, GPQA Diamond 93.5%, HLE 44.3%; ECI 149.76 rank 7/374; price $3 in / $0.30 cache in / $15 out (https://benchmarklist.com/models/moonshotai-kimi-k3/).
- Vendor model card (GitHub MoonshotAI/Kimi-K3): 2.8T total / 104B activated MoE, 16 of 896 experts, 1M context, MXFP4/MXFP8, Kimi K3 License; Terminal-Bench 2.1 88.3 with Kimi Code harness (footnote explicitly states K3's TB 2.1 is Kimi Code-harness while Opus 4.8/Fable 5 are Terminus 2 from AA); DeepSWE 67.5 (67.3 with mini-SWE-agent); ProgramBench 77.8; FrontierSWE 81.2; SWE-Marathon 42.0; Kimi Code Bench 2.0 72.9 (73.7 with Claude Code). VENDOR figures.
- Modelglass profile: SWE-bench Verified 93.4% via mini-swe-agent (Vals leaderboard) vs Terminal-Bench 2.1 88.3% via kimi-code (vendor) — the harness split made explicit; $3.00/$15.00; "no independent data yet" for other dimensions as of 2026-07-23 (https://modelglass.com.au/models/moonshot--kimi-k3).
- OpenLM SWE-bench Verified aggregator: Kimi K3 93.4 (2026-07-16), above Claude Opus 4.8 88.6 and Grok 4.5 86.6 (https://openlm.ai/swe-bench/).
- Launch-week gap documented: apidog (17 Jul 2026) states no independent lab had reproduced K3's standalone coding benchmarks at that date and "Any precise SWE-bench percentage you see for K3 today is citing Moonshot's own runs or estimating"; AA Intelligence Index 57, rank #4 of 189; output speed ~62 tok/s below tier median 72.7; vendor table TB 2.1 88.3 / DeepSWE 67.5 / BrowseComp 91.2 (https://apidog.com/blog/kimi-k3-benchmarks/). This gap is now CLOSED by the Vals 93.40% reproduction archived above.
- AA comparison (kimi-k3 vs deepseek-v4-pro): Intelligence Index 60 vs 45; $2.31 vs $0.18 per 1M; output speed 41.2 vs 70.3 tok/s; TTFT 2.87 vs 1.69s; context 1049k vs 1000k (https://artificialanalysis.ai/models/comparisons/kimi-k3-vs-deepseek-v4-pro).
- AA comparison (kimi-k3 vs mimo-v2.5-pro): Intelligence Index 60 vs 43; $2.31 vs $0.18; 41.2 vs 53.0 tok/s; TTFT 2.87 vs 3.24s (https://artificialanalysis.ai/models/comparisons/kimi-k3-vs-mimo-v2-5-pro).

### 3.2 DeepSeek V4 Pro (DeepSeek, released 2026-04-24)

- Independent SWE-bench Verified: **74%** by NIST CAISI (U.S. government, Center for AI Standards and Innovation), Inspect ReAct agent, 500k weighted-token budget, served on H200/B200; IRT-estimated Elo 800 +/- 28; PortBench 44%; ARC-AGI-2 semi-private 46%; GPQA-Diamond 90%; "most capable PRC AI model evaluated by CAISI to date"; "lags behind the frontier by about 8 months"; footnote: CAISI SWE-V scores tend to be lower than other evaluators due to scaffolding differences; released 2026-05-01 (https://www.nist.gov/news-events/news/2026/05/caisi-evaluation-deepseek-v4-pro).
- Vendor headline: SWE-bench Verified 80.6% (Max mode) on the HF model card; evals.report flags this row **Unverified** (Apr 24, 2026) — i.e., NOT independently reproduced; AA Intelligence Index 51.5 also **Unverified** on evals.report; Terminal-Bench 2.0 67.9% **Verified**; SWE Pro 55.4% Unverified; LiveCodeBench Pro 3206 Codeforces Elo Unverified (https://evals.report/models/deepseek-v4-pro).
- Vendor model card (HF deepseek-ai/DeepSeek-V4-Pro): 1.6T / 49B activated, 1M context, MIT; three reasoning modes; SWE Verified 80.6 (Max) / 79.4 (High) / 73.6 (Non-think); SWE Pro 55.4 (Max); Terminal Bench 2.0 67.9 (Max); GPQA Diamond 90.1 (Max); HLE 37.7 (Max); GDPval-AA 1554 Elo (Max) (https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro).
- AA comparison (deepseek-v4-pro vs mimo-v2.5-pro): Intelligence Index 45 vs 43; both $0.18 per 1M; 70.3 vs 53.0 tok/s; TTFT 1.69 vs 3.24s; both 1000k context; both MIT, both open weights (https://artificialanalysis.ai/models/comparisons/deepseek-v4-pro-vs-mimo-v2-5-pro).

### 3.3 MiMo-V2.5-Pro (Xiaomi, released 2026-04-22)

- **NO independent coding-benchmark reproduction exists.** The headline 78.9% SWE-bench Verified traces entirely to vendor sources: Xiaomi HF model card (https://huggingface.co/XiaomiMiMo/MiMo-V2.5-Pro), the official mimo.xiaomi.com announcement (flagged vendor marketing, provenance trace only), and llmreference (every tracked score sourced to the HF card or mimo.xiaomi.com; SWE-V 78.9 rank 21/81, SWE Pro 57.2 rank 18/42, TB 2.0 68.4).
- evals.report: SWE-bench Verified 78.9% with status "Verified" — this means the figure was verified as matching its published source, NOT that an independent reproduction exists; AA Intelligence Index 53.8 flagged **Unverified**; Terminal-Bench 2.0 68.4% Verified; SWE Pro 57.2% Verified; all dated Apr 22, 2026 (https://evals.report/models/xiaomi-mimo-v2-5-pro).
- Vendor model card: 1.02T / 42B active MoE, hybrid SWA+GA 6:1 attention, 3-layer MTP, 1M context, FP8, MIT; SWE-V 78.9 / SWE Pro 57.2 / TB 2.0 68.4 / GPQA 66.7 (base) in eval-results section; WildClawBench Overall 43 (https://huggingface.co/XiaomiMiMo/MiMo-V2.5-Pro).
- Vendor marketing page (mimo.xiaomi.com, 27 Apr 2026): MiMo Coding Bench 73.7 (in-house suite), ClawEval 64% Pass^3 at ~70K tokens/trajectory (40-60% fewer tokens than Opus 4.6/Gemini 3.1 Pro/GPT-5.4), SysY compiler 233/233 in 4.3h/672 tool calls, 8,192-line video editor in 11.5h/1,868 calls. FLAG: vendor-reported, self-selected; used for provenance only, not as evidence.
- Third-party press (The Decoder, 3 May 2026) relays the same vendor figures (SWE-V 78.9 / SWE Pro 57.2 / TB 2.0 68.4 / MiMo Coding Bench 73.7 / GDPval-AA 1581 Elo / tau3-bench 72.9) — third-party reportage of vendor claims, still vendor-attributed, no independent run (https://the-decoder.com/xiaomis-open-weight-mimo-v2-5-pro-takes-aim-at-claude-opus-with-hours-long-autonomous-coding/).
- AA comparison (kimi-k3 vs mimo): Intelligence Index 43 (independent, composite only — the ONLY independent AA datum for mimo; no AA-run coding-benchmark score exists).
- Terminal-Bench 2.1 (Vals harness, benchmarklist leaderboard): Mimo V2.5 Pro 57.303% rank 38 (imported from Vals, 2026-07-28) — the only independent TB 2.1-style score for mimo in the archive, and it trails both co-candidates (https://benchmarklist.com/benchmarks/vals_terminal_bench_2_1/).
- Pricing cross-ref: $0.435/$0.87, 16,300 req/mo on Go (res015).

## 4. VERDICT

**Keep kimi-k3 as the coder-escalated default.** The DIA-114 evidence gap is closed: Kimi K3 now has an independently reproduced SWE-bench Verified score — 93.40% on Vals (mini-swe-agent bash-only, leaderboard updated 2026-08-08) — making it the ONLY candidate of the three with an independent reproduction of its headline coding benchmark, and the strongest open-weight model on the leaderboard (ahead of Opus 4.8 88.60% and Grok 4.5 86.60%). It also leads the independent AA Intelligence Index (57.11-60 vs 45/43), the AA-run Terminal-Bench 2.1 component (85.0% vs ~64.8/~65.2), the Vals-harness Terminal-Bench 2.1 leaderboard (80.9% vs 72.1%/57.3%), and the vendor TB 2.1 claim (88.3% Kimi Code harness — flagged vendor). The only binding constraint remains the Go cap: 490 req/mo at $3/$15 — kimi-k3 must be used as a sparing escalation tier, not a volume default (cross-ref res013/res016).

**Rung-3 fallback: prefer deepseek-v4-pro over mimo-v2.5-pro (REVERSES the DIA-114 provisional MiMo pick).** Among the two Rung-3 co-candidates, deepseek-v4-pro is the only one with ANY independent coding-benchmark evidence: NIST CAISI measured 74% SWE-bench Verified (Inspect ReAct, 2026-05-01) and an 800 IRT Elo, while the vendor 80.6% figure stays flagged Unverified on evals.report. mimo-v2.5-pro has NO independent coding-benchmark reproduction whatsoever — its 78.9% headline is vendor-reported end to end (Xiaomi model card / mimo.xiaomi.com, confirmed by llmreference and The Decoder provenance), and its only independent AA datum is the composite Intelligence Index (43, below deepseek's 45). On the Vals-harness Terminal-Bench 2.1 leaderboard mimo also trails materially (57.3% vs deepseek 72.1%). Cost is a tie ($0.435/$0.87 both; ~16-17K req/mo both), so the evidence-based ordering is deepseek-v4-pro first, mimo-v2.5-pro second.

**Cap note (unchanged from res016):** kimi-k3 at $2.31/M blended (AA) vs $0.18/M for both co-candidates is roughly 13x more expensive per token; on Go, kimi-k3 is 490 req/mo vs ~16-17K req/mo for the co-candidates. Use kimi-k3 for the hardest escalated tasks, fall back to deepseek-v4-pro when the cap is exhausted or the task is reasoning-heavy (CAISI GPQA 90% / HLE 37.7 vendor).

## 5. Corrections and notes

- **C1 (DIA-116 evidence-gap status): RESOLVED for kimi-k3, PARTIAL for deepseek-v4-pro, OPEN for mimo-v2.5-pro.** The launch-week gap documented in apidog (17 Jul 2026: "wait for the neutral figure") is closed by the Vals 93.40% reproduction (8 Aug 2026). deepseek-v4-pro gained the NIST CAISI independent evaluation (1 May 2026). mimo-v2.5-pro remains without any independent coding benchmark; the DIA-114 "live in-repo benchmark recommended before finalizing" caveat applies most strongly to it. The ana014 Rung-3 live benchmark protocol remains the right final arbiter for the Rung-3 slot.
- **C2 (AA Intelligence Index value variance for mimo):** evals.report transcribes 53.8 (Unverified) for mimo-v2.5-pro while the live AA comparison page shows 43. The AA-run value (43) is authoritative for independent evidence; the 53.8 is an aggregator transcription of a vendor figure.
- **C3 (harness sensitivity on Terminal-Bench 2.1):** kimi-k3's TB 2.1 spans 88.3% (Kimi Code harness, vendor) / 85.0% (AA Terminus 2, independent) / 80.9% (Vals harness, independent) — a 7.4-point spread from harness choice alone, confirming that harness attribution matters more than the raw number (Moonshot footnote: AA runs Terminus 2 for Opus/Fable while K3 used Kimi Code).

## 6. Confidence assessment

- HIGH: kimi-k3 SWE-bench Verified 93.40% (Vals independent, mini-swe-agent same-harness, leaderboard dated 2026-08-08, corroborated by benchmarklist, modelglass, openlm); NIST CAISI 74% for deepseek-v4-pro (U.S. government, methodology published, Inspect ReAct, dated 2026-05-01); AA Intelligence Index values (60/45/43, archived AA comparison pages); vendor-vs-independent TB 2.1 split for kimi-k3 (88.3 vendor / 85.0 AA component / 80.9 Vals, three independent attributions); mimo-v2.5-pro having NO independent coding reproduction (negative result established across evals.report, llmreference, HF card, mimo.xiaomi.com, The Decoder — five sources, all vendor-originated for scores).
- MEDIUM-HIGH: Terminal-Bench 2.1 Vals-harness leaderboard values (benchmarklist 2026-08-11 data; DeepSeek V4 Pro row is "Preview" model-card-sourced rather than a Vals run); evals.report Unverified flags as evidence of non-reproduction (status taxonomy is aggregator-defined).
- MEDIUM: deepseek-v4-pro AA-run Terminal-Bench 2.1 ~64.8% and mimo ~65.2% — NOT statically archived (AA per-model table is JS-interactive); treated as researcher-reported directional values, excluded from the evidence table per archive-before-claim.
- EXCLUDED per DIA-072: no claim from llm-stats.com (unarchived, Section 7); no vendor-marketing figures from mimo.xiaomi.com asserted as evidence (provenance trace only); no AA-run per-model TB 2.1 score asserted for deepseek-v4-pro or mimo-v2.5-pro.

## 7. Unarchived sources

- https://llm-stats.com/benchmarks/terminal-bench-2.1 — NOT ARCHIVED (all methods exhausted). The site served an anti-bot verification wall ("Confirm you're human to keep going") on both fetch attempts (markdown and text extraction; no shell/curl/trafilatura/crawl4ai available in this lane's toolset to escalate). Per DIA-072 policy, no claim from this source is asserted in the conspect body. Impact: none material — Terminal-Bench 2.1 data for all three candidates is covered by benchmarklist-vals-terminal-bench-21.md (Vals-harness rows) and aa-terminalbench-v21.md (AA methodology + top scores). Orchestrator may optionally retry with an alternate URL or accept the gap.
- Researcher-reported AA-run TB 2.1 values for deepseek-v4-pro (~64.8%) and mimo-v2.5-pro (~65.2%): the AA evaluation page's per-model table is JS-interactive and could not be captured statically. These are flagged NOT-IN-ARCHIVE in Section 2 and treated as directional; the archived Vals-harness leaderboard values (72.1% / 57.3%) are used for the evidence table instead.

## MLA citations (archived local files, res017)

- Vals AI. "SWE-bench (Verified)." Vals AI, updated 8 Aug. 2026. knowledge/res017-rung3-benchmark-evidence/sources/vals-ai-swebench.md.
- SWE-bench Team. "SWE-bench Verified." SWE-bench, 2026. knowledge/res017-rung3-benchmark-evidence/sources/swebench-com-verified.md.
- SWE-bench Team. "SWE-bench Analysis (viewer)." SWE-bench, 2026. knowledge/res017-rung3-benchmark-evidence/sources/swebench-com-viewer.md.
- BenchmarkList. "Kimi K3 (Moonshot AI) model profile." BenchmarkList, 2026. knowledge/res017-rung3-benchmark-evidence/sources/benchmarklist-moonshotai-kimi-k3.md.
- Moonshot AI. "Kimi-K3." GitHub, 2026. knowledge/res017-rung3-benchmark-evidence/sources/github-moonshotai-kimi-k3.md.
- OpenLM. "SWE-bench + leaderboard." OpenLM.ai, 2026. knowledge/res017-rung3-benchmark-evidence/sources/openlm-ai-swe-bench.md.
- Modelglass. "Kimi K3 model profile." Modelglass, 2026. knowledge/res017-rung3-benchmark-evidence/sources/modelglass-moonshot-kimi-k3.md.
- DeepSeek-AI. "DeepSeek-V4-Pro." Hugging Face, 26 Apr. 2026. knowledge/res017-rung3-benchmark-evidence/sources/huggingface-deepseek-ai-v4-pro.md.
- National Institute of Standards and Technology. "CAISI Evaluation of DeepSeek V4 Pro." NIST, 1 May 2026. knowledge/res017-rung3-benchmark-evidence/sources/nist-gov-caisi-deepseek-v4-pro.md.
- evals.report. "DeepSeek V4 Pro." evals.report, 2026. knowledge/res017-rung3-benchmark-evidence/sources/evals-report-deepseek-v4-pro.md.
- evals.report. "MiMo-V2.5-Pro." evals.report, 2026. knowledge/res017-rung3-benchmark-evidence/sources/evals-report-xiaomi-mimo-v25-pro.md.
- Xiaomi MiMo Team. "MiMo-V2.5-Pro." Hugging Face, 22 Apr. 2026. knowledge/res017-rung3-benchmark-evidence/sources/huggingface-xiaomimimo-v25-pro.md.
- LLM Reference. "Xiaomi MiMo-V2.5-Pro." LLM Reference, 2026. knowledge/res017-rung3-benchmark-evidence/sources/llmreference-mimo-v25-pro.md.
- Xiaomi MiMo Team. "MiMo-V2.5-Pro (official announcement)." mimo.xiaomi.com, 27 Apr. 2026. knowledge/res017-rung3-benchmark-evidence/sources/mimo-xiaomi-v25-pro.md. (vendor marketing; provenance trace only)
- Artificial Analysis. "Kimi K3 (max) vs. DeepSeek V4 Pro (Reasoning, Max Effort)." Artificial Analysis, 2026. knowledge/res017-rung3-benchmark-evidence/sources/aa-kimi-k3-vs-deepseek-v4-pro.md.
- Artificial Analysis. "Kimi K3 (max) vs. MiMo-V2.5-Pro." Artificial Analysis, 2026. knowledge/res017-rung3-benchmark-evidence/sources/aa-kimi-k3-vs-mimo-v25-pro.md.
- Artificial Analysis. "DeepSeek V4 Pro (Reasoning, Max Effort) vs. MiMo-V2.5-Pro." Artificial Analysis, 2026. knowledge/res017-rung3-benchmark-evidence/sources/aa-deepseek-v4-pro-vs-mimo-v25-pro.md.
- Artificial Analysis. "Terminal-Bench v2.1 Benchmark Leaderboard." Artificial Analysis, 2026. knowledge/res017-rung3-benchmark-evidence/sources/aa-terminalbench-v21.md.
- BenchmarkList. "Terminal-Bench 2.1 leaderboard (Vals data)." BenchmarkList, 11 Aug. 2026. knowledge/res017-rung3-benchmark-evidence/sources/benchmarklist-vals-terminal-bench-21.md.
- Kemper, Jonathan. "Xiaomi's open-weight MiMo-V2.5-Pro takes aim at Claude Opus with hours-long autonomous coding." The Decoder, 3 May 2026. knowledge/res017-rung3-benchmark-evidence/sources/the-decoder-mimo-v25-pro.md.
- Innocent, Ashley. "Kimi K3 Benchmarks: Moonshot's Numbers vs Independent Tests." Apidog, 17 Jul. 2026. knowledge/res017-rung3-benchmark-evidence/sources/apidog-kimi-k3-benchmarks.md.

Cross-referenced (prior conspect archives, not re-downloaded):
- Res013 conspect (Go pricing/caps: kimi-k3 490 req/mo at $3/$15; deepseek-v4-pro 17,150 req/mo at $0.435/$0.87): knowledge/res013-opencode-model-pricing-audit/res013-opencode-model-pricing-audit-conspect.md.
- Res014 conspect (coder escalation ladder Rung0-4, DIA-111): knowledge/res014-model-escalation-routing/res014-model-escalation-routing-conspect.md.
- Res015 conspect (MiMo-V2.5-Pro vs DeepSeek-V4-Pro side-by-side; DIA-114 provisional MiMo Rung-3 pick; mimo 16,300 req/mo at $0.435/$0.87): knowledge/res015-mimo-v25-pro-evaluation/res015-mimo-v25-pro-evaluation-conspect.md.
- Res016 conspect (coder-escalated model evidence; kimi-k3 Vals 93.40% cross-referenced; TB 2.1 88.3 vendor / 85 AA independent; cap-fallback verdict): knowledge/res016-coder-escalated-model-evidence/res016-coder-escalated-model-evidence-conspect.md.
- Ana014 report (Rung-3 live benchmark protocol, DIA-116 companion): knowledge/ana014-rung3-benchmark-protocol/ana014-rung3-benchmark-protocol-report.md.

---
Document prepared by conspecter lane on 2026-08-12. All citations point to locally archived artifacts under knowledge/res017-rung3-benchmark-evidence/sources/ plus cross-references to res013/res014/res015/res016 and ana014.
