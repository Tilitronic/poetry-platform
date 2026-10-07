# Res015: MiMo-V2.5-Pro Evaluation - Agentic Coding Capability and Rung-3 Escalation Evidence (DIA-114)

Date: 2026-08-12
Ticket: DIA-114 (evaluate MiMo-V2.5-Pro agentic coding capability, DIA-087 R5 follow-up, OPEN)
Author: res-2 research lane (session ses_00b0ca6e2ffeqUeK54NxtnYk9x, 2026-08-12) -> conspecter archival (res015)
Scope: synthesis of 32 archived sources in knowledge/res015-mimo-v25-pro-evaluation/sources/ (DIA-114). Sections: (1) research summary, (2) model identity and lineage table, (3) benchmark table with per-score source attribution and vendor-reported flags, (4) agentic-framework integration, (5) OpenCode/Go provider evidence, (6) MiMo-V2.5-Pro vs DeepSeek-V4-Pro comparison for the Rung-3 escalation decision, (7) confidence assessment, (8) unarchived sources. Cross-references res013 (Go pricing audit, DIA-108) and res014 (model escalation routing, DIA-111). All claims cite the archived local files.

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 32
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

## 1. Research summary

DIA-114 closes the benchmark gap tracked by DIA-087 R5: MiMo-V2.5-Pro availability and pricing were known (res013), but no archived capability evidence existed to justify picking it over deepseek-v4-pro at Rung 3 of the coder escalation ladder (DIA-111 / res014). This research archives 32 sources spanning Xiaomi official channels, OpenCode/Go provider docs, benchmark aggregators, press, hands-on tutorials, and community configs, and fills that gap.

Key findings:

- **MiMo-V2.5-Pro is Xiaomi's flagship open-source agentic coding model**, released 2026-04-22 (Xiaomi blog dated 2026-04-27): 1.02T total / 42B active sparse MoE, hybrid attention (SWA+GA 6:1, 128-token window), 3-layer MTP, 1M-token context (Base 256K), FP8 (E4M3), MIT license, knowledge cutoff May 2025 (Wikipedia; Xiaomi; HF model card).
- **The benchmark gap is now filled**: SWE-bench Verified 78.9%, SWE-bench Pro 57.2%, Terminal-Bench 2.0 68.4%, ClawEval 63.8%, GDPVal-AA Elo 1581, MiMo Coding Bench 73.7% (vs Claude Opus 4.6 at 77.1) - with per-score source attribution in Section 3. All headline coding scores are **vendor-reported** (Xiaomi model card / aggregators transcribing Xiaomi), not independently reproduced - the same caveat applies to DeepSeek V4 Pro's 80.6% (benchr).
- **Agentic usage is broadly confirmed**: Xiaomi explicitly welcomes integration into Claude Code, OpenCode, and Kilo; OpenHands/SWE-agent/Cline/Aider work via the OpenAI-compatible tool_calls API; OpenCode handles MiMo's reasoning_content correctly while several other scaffolds (Cursor, Roo Code, Codex, Copilot CLI, TRAE) fail on it (DataCamp).
- **OpenCode/Go integration is first-class**: mimo-v2.5-pro is on the official Go provider list at $0.435/$0.87 with a 16,300 req/mo cap; Xiaomi maintains an official OpenCode integration doc; Xiaomi's own MiMo Code is an OpenCode fork.
- **Rung-3 verdict**: MiMo-V2.5-Pro is the better default for the coder escalation ladder (comparable-or-better agentic coding scores, superior token efficiency, explicit OpenCode-native integration), with DeepSeek V4 Pro remaining reasonable when pure reasoning/knowledge or a marginally higher headline SWE-bench number matters more. Both headline SWE numbers are vendor-reported; a live in-repo benchmark is recommended before finalizing Rung 3.

Confidence: High (identity/specs/lineage; Go availability+cap); Medium-High (SWE-bench 78.9 / Pro 57.2 / Terminal-Bench 68.4 - consistent across aggregators but Xiaomi-reported); High for the DeepSeek 80.6 figure as DeepSeek-official but vendor-reported (benchr caveat); Medium (reasoning_content caveat; MiMo Code harness gain self-reported).

## 2. Model identity and lineage

MiMo-V2.5-Pro is a 1.02T-total / 42B-active sparse Mixture-of-Experts model with hybrid attention (Sliding Window Attention + Global Attention interleaved at 6:1, 128-token window), a 3-layer Multi-Token Prediction (MTP) module, a 1M-token context window (Base variant 256K), FP8 (E4M3) precision, MIT license, and knowledge cutoff May 2025 (Wikipedia 2026; Xiaomi 2026; HF model card 2026). Post-training: SFT + large-scale agentic RL + Multi-Teacher On-Policy Distillation (MOPD). Xiaomi explicitly describes "harness awareness": the model uses its harness environment's affordances, manages its own memory, and shapes its context toward the final objective (Xiaomi 2026; MarkTechPost 2026). The model can sustain complex long-horizon tasks spanning more than a thousand tool calls (Xiaomi 2026). Demonstrated real-world workloads include a SysY compiler in Rust (233/233 tests, 672 tool calls, 4.3 hours), a desktop video editor (8,192 LOC, 1,868 tool calls, 11.5 hours), and an analog FVF-LDO design via ngspice closed-loop simulation (Xiaomi 2026; The Decoder 2026; MarkTechPost 2026).

Lineage table (from Wikipedia 2026; Xiaomi release pages; mimo.mi.com docs):

| Model | Release date | Params (total / active) | Context | License | Codename / notes |
|---|---|---|---|---|---|
| MiMo-7B | 2025-04-30 | 7B / 7B | - | MIT | First MiMo model; reasoning-focused |
| MiMo-V2-Flash | 2025-12-16 (Wikipedia: 17 Dec) | 309B / 15B | 256K | MIT | Hybrid attention 5:1; MOPD introduced; SGLang Day-0 |
| MiMo-V2-Pro | 2026-03-18 | >1T / 42B | 1M | Proprietary | Codename Hunter Alpha (OpenRouter); hybrid 7:1 |
| MiMo-V2-Omni | 2026-03-18 | unknown | 256K | Proprietary | Codename Healer Alpha; text/vision/speech |
| MiMo-V2-TTS | 2026-03-18 | unknown | - | Proprietary | Speech synthesis; no public weights |
| MiMo-V2.5 (omni) | 2026-04-22 | 310B / 15B | 1M | MIT | Native full-modal; 48T tokens; open-sourced |
| **MiMo-V2.5-Pro** | **2026-04-22** | **1.02T / 42B** | **1M (Base 256K)** | **MIT** | Flagship; 27T tokens; harness-aware |

Additional lineage notes: MiMo-V2.5-ASR released 2026-06-02 (open weights, 5.73% WER on Open ASR Leaderboard); MiMo-V2.5-TTS family API-only (The Decoder 2026; mimo.mi.com docs 2026). The V2 series was deprecated 2026-06-30 with migration to V2.5 (mimo.mi.com docs). MiMo Code, Xiaomi's OpenCode fork, was open-sourced June 2026 (V0.1.0, MIT) with a compose/spec-driven workflow and a free "MiMo Auto" channel (VentureBeat 2026-06-11; GitHub MiMo-Code 2026).

## 3. Benchmark table

Per-score source attribution. "Verified" on evals.report/llm-registry/neura means the aggregator transcribed the score from a published source (predominantly Xiaomi); it does NOT mean independent reproduction. Flag: [vendor-reported] = score originates from Xiaomi's model card/release; [independent] = score from a third-party run.

| Benchmark | MiMo-V2.5-Pro | Source(s) | Flag |
|---|---|---|---|
| SWE-bench Verified | 78.9% | HF hub eval results; evals.report (Verified, Apr 22); llm-registry (78.9/100); neura (78.9) | vendor-reported (Xiaomi) |
| SWE-bench Pro | 57.2% | HF hub eval results; evals.report (Verified); llm-registry (57.2); neura (57.2); Spheron (~57.2) | vendor-reported (Xiaomi) |
| SWE-bench AgentLess (base) | 35.7% (3-shot) | HF model card base-eval table | vendor-reported (Xiaomi) |
| Terminal-Bench 2.0 | 68.4% | evals.report (Verified); llm-registry (68.4); The Decoder (68.4) | vendor-reported (Xiaomi) |
| ClawEval | 63.8% | Xiaomi blog (64% Pass^3); MarkTechPost (63.8); VentureBeat (63.8); HF hub claw-eval multi_turn 63.2 | vendor-reported (Xiaomi); ~70K tokens/trajectory |
| GDPVal-AA | Elo 1581 | The Decoder (1581); evals.report (1571); llm-registry (HLE-Full 48.0% as separate row) | vendor-reported (Xiaomi); slight aggregator variance 1571-1581 |
| MiMo Coding Bench | 73.7% | Xiaomi blog; The Decoder (73.7 vs Claude Opus 4.6 77.1, Gemini 3.1 Pro 67.8) | vendor-reported (in-house suite) |
| tau3-bench | 72.9% | Xiaomi (via MarkTechPost 72.9); The Decoder (72.9) | vendor-reported (Xiaomi) |
| GPQA-Diamond | 86.6% verified / 66.7% base | evals.report (86.6 Verified); HF card base 66.7 (5-shot); llm-registry (66.7); neura (66.7) | vendor-reported (Xiaomi); verified number is agentic-eval setting |
| Humanity's Last Exam | 33.8% evals / 48.0% Xiaomi w/tools | evals.report (33.8); llm-registry HLE-Full (48.0% no tools); Xiaomi w/tools via HF DeepSeek comparison table context | vendor-reported (Xiaomi); weaker reasoning vs frontier |
| SciCode | 50.2% | evals.report (Unverified status) | vendor-reported/unverified |
| WebDev Arena / Design Arena | Elo 1471 / 1325 | evals.report (Verified) | vendor-reported (Xiaomi) |
| OSWorld | NO SCORE FOUND | - | not in archive; gap retained |
| Long-context GraphWalks | 0.37 BFS / 0.62 Parents at 1M | HF model card; The Decoder | vendor-reported; V2-Pro collapses to 0.00 at 1M |

Notes: (a) evals.report statuses "Verified"/"Official" refer to whether the aggregator verified the source, not independent reproduction; the underlying numbers are Xiaomi's published scores. (b) The MiMo-V2.5 (omni) variant scores on BenchLM: SWE-bench Pro 56.1%, Terminal-Bench 2.0 65.8%, Claw-Eval 62.3% (BenchLM, verified rows) - provided for comparison, not the Pro model. (c) MiMo-V2.5-Pro pricing on Xiaomi API: $1.00/$3.00 per 1M up to 256K, $2.00/$6.00 above (VentureBeat 2026-04-27); Xiaomi's own API pricing is separate from OpenCode Go pricing (Section 5).

Confidence: Medium-High for the headline scores (consistent across 3+ independent aggregators, all tracing to Xiaomi); High for architectural specs (multiple official sources); the OSWorld absence is an absence-of-evidence claim flagged per DIA-072.

## 4. Agentic-framework integration

MiMo-V2.5-Pro is broadly deployed as a coding-agent backend (High confidence).

- **Xiaomi's own positioning**: "We welcome developers worldwide to integrate MiMo-V2.5 series into scaffolds such as Claude Code, OpenCode, and Kilo" (Xiaomi 2026). MiMo Coding Bench evaluates models within agentic frameworks such as Claude Code (Xiaomi 2026; MarkTechPost 2026). Xiaomi's Agent Ecosystem Co-construction Initiative cooperated with OpenCode, Hermes Agent, and KiloCode (mimo.mi.com news 2026).
- **OpenAI-compatible tool calling**: MiMo-V2.5-Pro follows the OpenAI function-calling schema; OpenHands, SWE-agent, Cline, and Aider work via the OpenAI tool_calls API pointed at a vLLM/SGLang server (Spheron 2026). SGLang/vLLM deployment flags: `--reasoning-parser mimo --tool-call-parser mimo` (HF model card).
- **MiMo Code (Xiaomi's OpenCode fork)**: a terminal-native agent built as a fork of OpenCode, MIT-licensed, with persistent memory (SQLite FTS5), compose workflows, and a free MiMo Auto channel. Self-reported harness gain: same MiMo-V2.5-Pro model in both harnesses, MiMo Code scored 62% SWE-bench Pro vs 57% Claude Code, and 73% Terminal-Bench 2 vs 68% - roughly 5 points each attributable to the harness (VentureBeat 2026-06-11; GitHub MiMo-Code 2026). Human double-blind A/B: 576 developers, 474 repos, 1,213 pairs; above 65% win rate past 200 steps (VentureBeat 2026-06-11; self-reported).
- **reasoning_content caveat (Medium confidence)**: MiMo fails with Cursor, Roo Code, Codex, Copilot CLI, and TRAE in multi-turn tool-call conversations because those frameworks mishandle `reasoning_content`; OpenCode handles it correctly (DataCamp 2026; Xiaomi's own OpenCode doc warns the Anthropic protocol returns 400 when the assistant message with tool calls is missing reasoning_content). This is the documented reason OpenCode is the recommended tool in the DataCamp guide.
- **awesome-mimo-agent** collects setup guides for using MiMo in Cursor, Cline, Zed, etc. (GitHub MiMo-Code README 2026).

## 5. OpenCode / Go provider evidence

- **First-class Go provider model (High confidence)**: mimo-v2.5-pro is on the official OpenCode Go model list alongside DeepSeek V4 Pro, tag `mimo-v2.5-pro`, endpoint `https://opencode.ai/zen/go/v1/chat/completions`, AI SDK package `@ai-sdk/openai-compatible` (opencode.ai/docs/go; dev.opencode.ai/docs/go). Config id format: `opencode-go/<model-id>` (opencode.ai/docs/go).
- **Pricing and limits (matches res013)**: $0.435 / $0.87 per 1M input/output, cached read $0.003625, $15/mo usage bucket, estimated 16,300 req/mo (3,250 per 5h / 8,150 per week); MiMo-V2.5 (non-Pro) $0.14/$0.28 at 150,400 req/mo; DeepSeek V4 Pro identical $0.435/$0.87 but 17,150 req/mo (opencode.ai/docs/go; dev.opencode.ai/docs/go).
- **Context on Go**: 1M context / 131,072 max output in the Xiaomi official OpenCode config example (mimo.mi.com/docs/en-US/tokenplan/integration/opencode). Data retention 0 days, no training use on Go (opencode.ai/docs/go).
- **Xiaomi official OpenCode integration doc** (mimo.mi.com 2026-07-16): opencode.json config via `@ai-sdk/openai-compatible` provider with models mimo-v2.5-pro (1048576 context / 131072 output) and mimo-v2.5; Token Plan base URLs for CN (token-plan-cn.xiaomimimo.com), SGP (token-plan-sgp), EU/AMS (token-plan-ams); pay-as-you-go base URL api.xiaomimimo.com/v1.
- **Community configs (GitHub, archived)**: gajae-code assigns `critic: opencode-go/mimo-v2.5-pro` in its opencodego profile (and xiaomi/mimo-v2.5-pro across mimo-eco/medium/pro profiles); fmflurry/settings-opencode uses opencode-go/mimo-v2.5-pro as conductor and planner; OmniRoute ships a `mimo-pro` profile (`opencode-go/mimo-v2.5-pro`, thinking) and `mimo` profile (`opencode-go/mimo-v2.5`); CodeWhale registry includes xiaomi/mimo-v2.5-pro with OpenRouter aliases; LobeChat model bank has mimo-v2.5-pro enabled (family mimo, 1M context, knowledge cutoff 2024-12, reasoning via enableReasoning); gpt4free maps mimo-v2.5-pro across Airforce/LMArena/OpenRouter/Pollinations/Puter. cc-switch (claudeProviderPresets.ts) archived but the specific MiMo preset line was not visible in the captured excerpt (partial verification; see Section 7).
- **Deployment**: MIT weights self-hostable via SGLang/vLLM; 8x H200 (1,128GB) minimum single-node, H100 not viable for FP8 weights (~1,020GB), 16x H200 for 1M context (Spheron 2026; HF model card).

## 6. MiMo-V2.5-Pro vs DeepSeek-V4-Pro (Rung-3 decision)

Both are the Rung-3 escalation candidates for the coder ladder (DIA-111 / res014). Identical Go pricing and near-identical caps (res013; opencode.ai/docs/go). Capability comparison from this archive:

| Dimension | DeepSeek V4 Pro | MiMo-V2.5-Pro | Verdict |
|---|---|---|---|
| Go price $/1M in/out | $0.435 / $0.87 | $0.435 / $0.87 | Identical (opencode.ai/docs/go) |
| Go cached read | $0.003625 | $0.003625 | Identical |
| Go req/mo (est.) | 17,150 | 16,300 | Near-identical headroom |
| Context | 1M (384K max output) | 1M (Base 256K) | Both 1M |
| Params (total / active) | 1.6T / 49B | 1.02T / 42B | DS larger; both sparse MoE |
| SWE-bench Verified | 80.6% (Max) / 73.6% plain / 79.4% High | 78.9% | DS edges headline (VENDOR-REPORTED both) |
| SWE-bench Pro | 55.4% (Max) / 52.1% plain | 57.2% | MiMo edges |
| Terminal-Bench 2.0 | 67.9% (Max) / 59.1% plain | 68.4% | MiMo edges |
| GPQA-Diamond | 90.1% (Max) / 72.9% plain | 86.6% verified / 66.7% base | DS edges (reasoning) |
| HLE | 32.4-37.7% (Max) / 48.2% w/tools | 33.8-48.0% w/tools | Similar reasoning ceiling |
| GDPVal-AA | Elo 1554 (Max) | Elo 1581 | MiMo edges |
| Token efficiency | Not benchmarked on ClawEval in archive | ~70K tokens/traj, 40-60% fewer than Opus 4.6/Gemini 3.1 Pro/GPT-5.4 | MiMo materially cheaper per real agent trajectory |
| OpenCode/harness optimization | Not documented | Explicit: harness-aware training, own OpenCode fork (MiMo Code), ~5pt harness gain vs Claude Code (self-reported) | MiMo |
| License | MIT | MIT | Both open weights |

Assessment: effectively tied on SWE-bench Verified (78.9 vs 80.6 headline - the gap narrows to parity against DS plain/High modes 73.6-79.4); MiMo edges on agentic-terminal and tool-heavy evals (Terminal-Bench 68.4 vs 67.9, SWE-bench Pro 57.2 vs 55.4, GDPVal-AA 1581 vs 1554) while DeepSeek edges on pure reasoning/knowledge (GPQA-Diamond 90.1 vs 86.6). MiMo's decisive advantages for the coder lane: 40-60% fewer tokens per trajectory (cheaper real-world agent loops) and explicit OpenCode-native integration (including Xiaomi's own OpenCode fork). **Recommended default for Rung 3: mimo-v2.5-pro**; keep deepseek-v4-pro as the alternative when reasoning-heavy or marginally-higher-headline-SWE work dominates.

CRITICAL CAVEAT: both headline SWE numbers are VENDOR-REPORTED (Xiaomi and DeepSeek model cards respectively; benchr explicitly flags DS 80.6 as "not yet reproduced"; no independent reproduction of MiMo 78.9 found in this archive). Treat as directionally strong, not settled. Recommend a live in-repo benchmark (project-side-by-side) before finalizing Rung 3 (benchr 2026; res014 Section 6 tie-breaker guidance).

## 7. Confidence assessment

- High: model identity/specs/lineage (Wikipedia + Xiaomi official + HF card, mutually consistent); Go availability, pricing, cap (official OpenCode docs, cross-checked against res013); DeepSeek V4 Pro benchmark figures as DeepSeek-official (HF card + evals.report).
- Medium-High: MiMo SWE-bench Verified 78.9 / Pro 57.2 / Terminal-Bench 2.0 68.4 - consistent across 3+ aggregators (evals.report, llm-registry, neura) but all trace to Xiaomi-reported numbers.
- Medium: reasoning_content compatibility caveat (single hands-on primary source, DataCamp, corroborated by Xiaomi's own OpenCode doc warning); MiMo Code harness-gain claims (5pt) - VentureBeat-transmitted Xiaomi self-reported numbers, no third-party reproduction.
- PARTIAL verification: cc-switch claudeProviderPresets.ts archived (200 OK) but the specific mimo-v2.5-pro preset line was not visible in the captured excerpt (file truncated at 859/1459 lines; full file retained in webfetch tool-output). The broader claim (community tooling ships mimo-v2.5-pro presets) is nonetheless supported by the five other archived community sources (gajae-code, fmflurry, OmniRoute, CodeWhale, lobehub, gpt4free).
- Excluded claims per DIA-072: no OSWorld score is asserted (none found in the archive); no independent-reproduction claim is made for any vendor-reported score.

## 8. Unarchived sources

None. All 32 requested URLs were archived successfully in Phase A (32/32, 0 hard failures - see phase_a_report.txt). Method notes: (a) 2 VentureBeat URLs returned persistent HTTP 429 (rate limited) across multiple webfetch retries and were archived via Exa web-search retrieval of the full published article text (documented in each file header) - content archived, method substituted per DIA-072; (b) 4 large GitHub source files (gajae-code, CodeWhale, cc-switch, gpt4free) had captured excerpts truncated by the fetch tool; the full file contents are retained in webfetch tool-output, and the MiMo-relevant lines were verified via grep on those saved outputs before being cited (cc-switch partial - see Section 7). No source is marked [source not archived - excluded per DIA-072 policy].

## MLA citations (archived local files)

- "Xiaomi MiMo-V2.5-Pro." Xiaomi MiMo Blog, 27 Apr. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/xiaomi-mimo-v25pro-official.md.
- "Xiaomi MiMo-V2.5." Xiaomi MiMo Blog, 22 Apr. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/xiaomi-mimo-v25-omni.md.
- Xiaomi MiMo Team. "MiMo-V2.5-Pro." Hugging Face model card, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/huggingface-mimo-v25pro-model-card.md.
- Xiaomi. "Model Release." MiMo Docs, update log, 2 Jun. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/mimo-docs-updates-model.md.
- Xiaomi. "OpenCode Configuration." MiMo Docs, 16 Jul. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/mimo-docs-opencode-integration.md.
- Xiaomi. "Xiaomi MiMo-V2.5 series open-sourced & Orbit 100 trillion token plan launched." MiMo Docs News, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/mimo-docs-v25-open-sourced.md.
- XiaomiMiMo. "MiMo-Code." GitHub, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/github-mimo-code.md.
- "Xiaomi MiMo-V2-Pro." Xiaomi MiMo Blog, 18 Mar. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/xiaomi-mimo-v2pro-lineage.md.
- "Introducing MiMo-V2-Flash." Xiaomi MiMo Blog, 16 Dec. 2025. knowledge/res015-mimo-v25-pro-evaluation/sources/xiaomi-mimo-v2flash-lineage.md.
- "Xiaomi MiMo." Wikipedia, 11 Aug. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/wikipedia-xiaomi-mimo.md.
- Anomaly. "Go." OpenCode Docs, 12 Aug. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/opencode-docs-go.md.
- Anomaly. "Go." OpenCode Dev Docs, 12 Aug. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/opencode-dev-docs-go.md.
- evals.report. "MiMo-V2.5-Pro benchmark scores." inductive.ml, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/evals-report-mimo-v25pro.md.
- LLM Registry. "MiMo V2.5-Pro." llm-registry.com, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/llm-registry-mimo-v25pro.md.
- Neura Market. "MiMo-V2.5-Pro Benchmark Scores & Rankings." neura.market, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/neura-market-mimo-v25pro.md.
- BenchLM. "MiMo-V2.5 Benchmarks & Speed (August 2026)." BenchLM.ai, 11 Aug. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/benchlm-mimo-v25.md.
- evals.report. "DeepSeek V4 Pro benchmark scores." inductive.ml, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/evals-report-deepseek-v4pro.md.
- DeepSeek-AI. "DeepSeek-V4-Pro." Hugging Face model card, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/huggingface-deepseek-v4pro.md.
- benchr. "DeepSeek-V4, reviewed." benchr.org, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/benchr-deepseek-review.md.
- Franzen, Carl. "Open source Xiaomi MiMo-V2.5 and V2.5-Pro are among the most efficient (and affordable) at agentic 'claw' tasks." VentureBeat, 27 Apr. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/venturebeat-mimo-v25-efficient.md.
- Franzen, Carl. "Xiaomi's new open source, agentic AI coding harness MiMo Code beats Claude Code at ultra-long, 200+ step tasks." VentureBeat, 11 Jun. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/venturebeat-mimo-code-harness.md.
- Razzaq, Asif. "Xiaomi Releases MiMo-V2.5-Pro and MiMo-V2.5: Matching Frontier Model Benchmarks at Significantly Lower Token Cost." MarkTechPost, 22 Apr. 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/marktechpost-mimo-v25-release.md.
- Kemper, Jonathan. "Xiaomi's open-weight MiMo-V2.5-Pro takes aim at Claude Opus with hours-long autonomous coding." The Decoder, 3 May 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/the-decoder-mimo-v25pro-opus.md.
- Awan, Abid Ali. "Vibe Coding with Xiaomi MiMo-V2.5-Pro: A Hands-On Tutorial." DataCamp, 19 May 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/datacamp-vibe-coding-mimo.md.
- Spheron Network. "Deploy MiMo-V2.5-Pro on GPU Cloud." Spheron Blog, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/spheron-deploy-mimo-v25pro.md.
- Yeachan-Heo. "model-profiles.ts." gajae-code, GitHub, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/github-gajae-code-model-profiles.md.
- fmflurry. "opencode-models.zsh." settings-opencode, GitHub, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/github-fmflurry-opencode-models.md.
- Hmbown. "lib.rs." CodeWhale, GitHub, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/github-codewhale-agent-lib.md.
- LobeHub. "xiaomimimo.ts." lobehub model-bank, GitHub, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/github-lobehub-xiaomimimo.md.
- diegosouzapw. "CODEX-CLI-CONFIGURATION.md." OmniRoute, GitHub, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/github-omniroute-codex-config.md.
- farion1231. "claudeProviderPresets.ts." cc-switch, GitHub, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/github-cc-switch-claude-presets.md.
- xtekky. "any_model_map.py." gpt4free, GitHub, 2026. knowledge/res015-mimo-v25-pro-evaluation/sources/github-gpt4free-model-map.md.

Cross-referenced (res013 archive, DIA-108; res014 archive, DIA-111 - not re-archived here):
- Anomaly. "Go." OpenCode Docs, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/opencode-go-pricing.md.
- BenchLM. "SWE-bench Verified Leaderboard (August 2026): Top Scores." BenchLM.ai, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/swebench-benchlm.md.
- Vals AI. "SWE-bench Verified." Vals AI, 8 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/swebench-vals.md.
- Res014 conspect (escalation ladder Rung0-4 design, DIA-111): knowledge/res014-model-escalation-routing/res014-model-escalation-routing-conspect.md.

---
Document prepared by conspecter lane on 2026-08-12. All citations point to locally archived artifacts under knowledge/res015-mimo-v25-pro-evaluation/sources/ plus cross-references to res013/res014 archives.
