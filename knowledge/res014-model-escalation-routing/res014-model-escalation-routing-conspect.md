# Res014: Model Escalation Routing for Coder and Analyzer Agents (DIA-111)

Date: 2026-08-12
Ticket: DIA-111 (model escalation routing for coder and analyzer agents, research-first)
Author: ai--2 escalation research (session 13, 2026-08-11 22:52-22:54Z) -> conspecter archival (res014)
Scope: synthesis of 8 archived sources in knowledge/res014-model-escalation-routing/sources/ plus cross-referenced benchmark/pricing data from knowledge/res013-opencode-model-pricing-audit/ (7 sources, DIA-108, archived 2026-08-12 - reused, not duplicated, per DIA-111 requirement 1). Sections: (1) research summary and escalation approaches, (2) six routing patterns, (3) benchmark table for the six candidate models, (4) coder escalation ladder Rung0-4 design, (5) analyzer-to-Luna escalation design, (6) MiMo-V2.5-Pro vs DeepSeek-V4-Pro comparison, (7) confidence assessment. All claims cite the archived local files.

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 8
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

## 1. Research summary: escalation approaches for agentic coding workflows

DIA-111 asks for an escalation ladder so the coder agent escalates to stronger models on complex tasks / advanced problem fixes, and the analyzer escalates to GPT-5.6 Luna when it "doesn't understand the problem" - all research-first, before any config change. The developer-provided reference flow: Qwen3.7 Plus (architecture) / DeepSeek V4 Flash (implementation) handle the user task; Codex performs the review; on problems the task escalates to DeepSeek V4 Pro or MiMo V2.5 Pro, then re-review, then DONE; the analyzer escalates to GPT-5.6 Luna for expert analysis, then routes back to Qwen3.7 Plus (DIA-111 ticket, 2026).

The archived research establishes a consistent design vocabulary for escalation routing:

- **Cascades are the baseline but insufficient.** Cost-aware inference treats failure as a cascade decision - try a cheap model first, defer hard cases to a stronger one. In coding, however, execution feedback can make further cheap-model recovery worthwhile, so the post-failure decision is better framed as recovery routing over heterogeneous actions: reflect (repair using the error trace, cheap), replan (solve from scratch, cheap), or escalate (defer to a stronger model) (He et al., "CodeRescue", 2026; ARCHER repo, 2026). Cheap recovery and escalation exhibit complementary success patterns; a learned router with a Conformal Risk Control (CRC) calibration layer beat always-escalate solve rate while using 35% of its mean recovery cost in the main GPT-5.4-nano/GPT-5.4 setting (0.717 solve @ $2.56m vs binary cascade 0.636 @ $2.56m; CRC argmax 0.817 @ $5.51m) (ARCHER, 2026).
- **Escalate on evidence, not habit.** A codified effort-and-escalation policy written into the instruction file (CLAUDE.md / AGENTS.md) makes the cheap path the default and escalates only on a named trigger - e.g., after N failed verification runs (tests, lint, types), or when a cheap model's partial trajectory shows it thrashing (AgentPatterns, 2026). The escalate-on-evidence half is grounded in the SWE-Router result that conditioning model choice on observed failure is provably never worse than a fixed a-priori choice, and strictly better when the cheap attempt is informative (Son et al., 2026).
- **Trajectory-conditioned temporal routing.** SWE-Router lets a cheap weak model run K exploratory turns, then a learned value head reads the partial trajectory and predicts whether the cheap model will solve the task; if the prediction clears a cost-adjusted threshold the cheap model continues, otherwise the strong model restarts from the original prompt (never from the weak model's reasoning, which biases it toward the weak model's mistakes). Bayes-optimality theorem: conditioning on the partial trajectory never harms routing (Son et al., 2026). Route-AUC 0.780 (+15.3 pp) with deepseek-v3.2 as the weak model on SWE-bench Verified.
- **Information deficit, not reasoning, is the router bottleneck.** Agent-as-a-Router (ACRouter) diagnoses LLM-as-a-router failure as information deficit: adding per-dimension performance statistics to a vanilla LLM router yields +15.3% relative gain. ACRouter formalizes routing as a Context-Action-Feedback loop with an Orchestrator, a Verifier (sandbox execution), and a Memory (embedding-keyed vector store, cosine kNN), evaluated by cumulative regret on CodeRouterBench (~10K tasks, 8 frontier LLMs). It attains the lowest ID regret (205.5) and the only strong OOD generalization (62.50 AvgPerf vs Always-Opus 57.14); static learners collapse on OOD (8.93-21.43%, below Random 31.25%) (Zhou et al., 2026).
- **Production reliability taxonomy.** Agent failure is a taxonomy, not a single retry pattern: transient (retry-with-backoff), persistent (circuit breaker), quality (validation gates + quality-aware fallback), partial (partial-success protocol with idempotency), unrecoverable (human-in-the-loop escalation with a fixed schema: question, recommendation, evidence, smallest decision, deadline, acknowledgment loop), and cost/rate-limit pressure (graceful degradation fallback chain) (Shah, 2026). The structured human-in-the-loop escalation event is the template for the analyzer escalation design.

Confidence: High for the archived sources (8/8 archived with full content; one paper withdrawn - see Section 7). The routing-pattern taxonomy and ladder design are synthesized from the archived sources plus the DIA-111 ticket's developer-provided reference flow.

## 2. Six routing patterns (from the archived research)

| # | Pattern | Source | Mechanism |
|---|---|---|---|
| 1 | LLM classifier routing | NVIDIA NeMo Switchyard (2026) | An LLM judge selects a candidate model and maintains session affinity with it across later turns; fits headless/domain-specific systems (coding, math, healthcare) |
| 2 | Stage router | NVIDIA NeMo Switchyard (2026) | Examines recent tool activity per turn: severe errors / repeated unproductive work / prolonged exploration push toward the capable model; steady writes and edits (especially after tests pass) favor the efficient model; inconclusive signals consult an LLM judge |
| 3 | Escalation router | NVIDIA NeMo Switchyard (2026) | Starts each conversation with a lower-cost model; an LLM judge monitors progress turn by turn and moves the session to a more capable model on sustained difficulty (repeated errors, loops, drift). LangChain benchmark: 74% cost reduction vs frontier-only baseline sending 7% of calls to frontier at ~6-point accuracy tradeoff; Cognition/Devin: 50.6% at $3.11 mean cost, within 2.8 points of Opus 5 at ~28% lower cost |
| 4 | Recovery routing (reflect / replan / escalate) | CodeRescue (He et al., 2026); ARCHER repo | Post-failure three-action router over (problem statement, execution verdict, stderr) + CRC budget calibration; complementary success patterns for cheap recovery vs escalation |
| 5 | Trajectory-conditioned temporal routing | SWE-Router (Son et al., 2026) | Cheap model runs K exploratory turns; value head on partial trajectory decides continue-vs-escalate; escalation restarts from the original prompt |
| 6 | C-A-F loop routing with memory | Agent-as-a-Router / ACRouter (Zhou et al., 2026) | Context-Action-Feedback loop: Orchestrator + Verifier + Memory accumulate execution-grounded experience; contextual-bandit formulation with cumulative regret |

Supporting patterns: codified effort+escalation policy in the instruction file (AgentPatterns, 2026 - "default cheap, spend on proof"; high-effort trap: continuous max scored 53.9% vs 63.6% uniform-high on Terminal Bench 2.0); structured human-in-the-loop escalation with schema + deadline + acknowledgment loop (Shah, 2026); unified (agent, tier) ladder with plan-time selection, cross-agent escalation, availability fallback, and deterministic reset (nax ADR-025, 2026).

Confidence: High (patterns 1-3 from NeMo Switchyard archived post; 4 from CodeRescue/ARCHER; 5 from SWE-Router; 6 from Agent-as-a-Router; supporting from AgentPatterns, Shah, nax ADR-025).

## 3. Benchmark table for the six candidate models

Cross-referenced from res013 (7 archived sources; scores and pricing not re-archived here - DIA-111 requirement 1 "reuse res013, do not duplicate"). Pool/harness caveats: BenchLM = 63-model aggregation; Vals = 79-model bash-only mini-swe-agent harness; scores are not directly cross-comparable across the two trackers (res013, 2026).

| Model | SWE-bench Verified | Context | Go pricing $/1M (in/out) | Go req/mo | Role in DIA-111 flow |
|---|---|---|---|---|---|
| deepseek-v4-flash | 73.7% plain / 79% Max / 78.6% High (BenchLM); Vals "0731" split 91/87/90/67 | BenchLM 63 / Vals 79 | $0.14 / $0.28 | 158,150 | Rung 0 implementation default (volume king, cheapest) |
| qwen3.7-plus | no SWE-bench score in archive (pricing only) | - | $0.40 / $1.60 (<=256K); $1.20/$4.80 (>256K) | 21,600 | Architecture lane primary + analyzer primary (route-back target) |
| gpt-5.3-codex | 85% (BenchLM) | BenchLM 63 | Copilot $1.75 / $14.00 (17.5/140 credits per 100K) | n/a (Copilot credits) | Reviewer (Codex performs the review) |
| gpt-5.6-luna | no overall in either archive; Vals difficulty split 96% (<15m), 92% (15m-1h), 86% (1-4h), 67% (>4h) | Vals 79 | $0.20 / $1.20 (<=200K); $0.40/$1.80 (>200K); cache write $0.25/$0.50 | 10,250 | Analyzer escalation target (cheap lightweight) |
| deepseek-v4-pro | 73.6% plain / 80.6% Max / 79.4% High (BenchLM) | BenchLM 63 | $0.435 / $0.87 | 17,150 | Escalation rung (coder ladder) |
| mimo-v2.5-pro | no SWE-bench score in archive | - | $0.435 / $0.87 | 16,300 | Escalation rung (coder ladder) - benchmark gap, see Section 6 |

Notes: (a) effort-level sensitivity is documented - DeepSeek V4 Pro (Max) 80.6% vs plain 73.6%; DeepSeek V4 Flash (Max) 79% vs plain 73.7% (res013, 2026). (b) qwen3.7-plus and mimo-v2.5-pro have NO SWE-bench score in the archived res013 sources; per DIA-072 policy no score is asserted for them here. (c) all pricing/request-count figures are direct transcriptions from res013's archived opencode-go-pricing.md and copilot-models-pricing.md.

Confidence: High for transcribed figures (res013 archive); benchmark gap flagged for qwen3.7-plus and mimo-v2.5-pro.

## 4. Coder escalation ladder - Rung0-4 design

Design grounded in the DIA-111 developer reference flow (Qwen3.7 Plus architecture / DeepSeek V4 Flash implementation / Codex review / escalate to DeepSeek V4 Pro or MiMo V2.5 Pro / re-review / DONE) and the archived routing patterns (nax ADR-025 unified ladder, AgentPatterns codified escalation, NeMo escalation router, SWE-Router trajectory conditioning).

| Rung | Model | Trigger | Mechanism |
|---|---|---|---|
| Rung 0 (default) | deepseek-v4-flash | - | Implementation default: cheap, 158K req/mo, 73.7% plain / 79% Max SWE-bench. "Default cheap, spend on proof" (AgentPatterns, 2026) |
| Rung 1 (recovery) | deepseek-v4-flash | Failed verification run #1 (test/lint/type failure); reviewer finding (Minor) | Reflect/replan with execution feedback before escalation (CodeRescue/ARCHER, 2026); escalation is NOT the first response to a transient failure (Shah, 2026) |
| Rung 2 (first escalation) | deepseek-v4-flash -> qwen3.7-plus | Failed verification run #2; reviewer "problems" signal; complexity heuristic high | Codified trigger "escalate after 2 failed verification runs" (AgentPatterns, 2026); architecture-strength reasoning lane (Qwen3.7 Plus 21,600 req/mo) |
| Rung 3 (strong escalation) | deepseek-v4-pro OR mimo-v2.5-pro | Repeated failure after Rung 2; reviewer findings severity Critical; sustained difficulty / trajectory thrash (SWE-Router) | Advance rung index, cross agents where the ladder does (nax ADR-025, 2026); NeMo escalation-router pattern: LLM judge moves session on sustained difficulty (2026). Identical Go pricing ($0.435/$0.87) - choice is capability/availability-driven (Section 6) |
| Rung 4 (re-review + done) | return to reviewer (gpt-5.3-codex) | Rung 3 produced a patch | Re-review, then DONE (DIA-111 ticket flow); availability fallback sidesteps an unreachable rung without consuming an escalation step (nax ADR-025, 2026) |

Fallback order: if a rung's model is unavailable (e.g., Go cap hit), sidestep to the next reachable rung without consuming an escalation step (nax ADR-025, 2026); graceful-degradation chain as last resort (Shah, 2026).

Re-entry conditions: after any escalation the patch returns to review (Rung 4); if review still fails, re-enter at the rung that produced the strongest evidence (deterministic reset per nax ADR-025 resetMode semantics - "initial" restores origin rung, "last" keeps the escalated rung).

Confidence: Medium-High. The rung models and trigger thresholds follow the DIA-111 ticket flow and archived patterns; exact threshold values (e.g., "2 failed runs") come from AgentPatterns' example policy block and are proposed defaults to validate on the project's own tasks (AgentPatterns: "tune the tiers to what your own self-test proves").

## 5. Analyzer escalation design ("we don't understand the problem" -> GPT-5.6 Luna)

Design grounded in the DIA-111 ticket flow (analyzer escalates to GPT-5.6 Luna for expert analysis, then routes back to Qwen3.7 Plus) and the structured-escalation pattern (Shah, 2026) and C-A-F loop (Zhou et al., 2026).

- Trigger: analyzer emits an "I don't understand the problem" signal - low-confidence classification, unrecognized domain, or an escalation event with a fixed schema (the question, the analyzer's recommendation, the evidence gathered, the smallest decision needed) (Shah, 2026).
- Escalation step: route the analysis request to gpt-5.6-luna (cheap lightweight: $0.20/$1.20 per 1M, 10,250 req/mo; Vals difficulty split 96/92/86/67 - strongest relative showing on quick-turn tasks). This is an escalation-router pattern: LLM judge detects sustained difficulty and moves the session to a more capable model (NeMo Switchyard, 2026).
- Expert analysis returns: the Luna analysis becomes a tool result the primary analyzer consumes - the workflow resumes deterministically from the checkpoint that was waiting on it (Shah, 2026).
- Routing back: after the analysis returns, the task routes BACK to the primary analyzer model (qwen3.7-plus) for synthesis and continued work - never continues on the escalated model (DIA-111 ticket flow; nax ADR-025 PRD-wins + origin tracking semantics).
- Guardrails: escalation carries an evidence packet, not a bare prompt; the route-back is deterministic (write-once origin tracking, nax ADR-025, 2026); re-entry cap to prevent escalation loops (attempts reset semantics).

Confidence: Medium-High. Flow follows the DIA-111 ticket verbatim; the structured-escalation schema and route-back mechanics are grounded in Shah (2026) and nax ADR-025 (2026).

## 6. MiMo-V2.5-Pro vs DeepSeek-V4-Pro comparison

Both are the two Rung-3 escalation candidates for the coder ladder (DIA-111 ticket flow). Comparison from res013 archived data (pricing) and the DIA-111 research:

| Dimension | DeepSeek V4 Pro | MiMo-V2.5-Pro | Verdict |
|---|---|---|---|
| Go price $/1M in/out | $0.435 / $0.87 | $0.435 / $0.87 | Identical (both in the $15/mo Go bucket) |
| Go cached read | $0.003625 | $0.003625 | Identical |
| Go included usage | $15/mo | $15/mo | Identical |
| Go req/mo (est.) | 17,150 | 16,300 | Near-identical volume headroom |
| SWE-bench Verified | 73.6% plain / 80.6% Max / 79.4% High (BenchLM) | NO SCORE in the res013 archive | DeepSeek V4 Pro has verified benchmark evidence; MiMo-V2.5-Pro has a benchmark gap |
| Effort-mode sensitivity | Documented (plain vs Max: +7.0 pp) | Not in archive | DeepSeek V4 Pro shows meaningful Max-mode headroom |
| Availability | On Go model list | On Go model list | Both available |

Key finding: on price and volume the two models are functionally interchangeable escalation candidates; the decisive difference is evidence. DeepSeek V4 Pro has archived SWE-bench scores (73.6-80.6% depending on mode); MiMo-V2.5-Pro has NO benchmark score in the res013 archive - per DIA-072 policy no score is asserted, and this is the open evaluation tracked by DIA-087 R5 ("MiMo V2.5 Pro evaluation research for escalation role"). The tie-breaker for Rung 3 selection should therefore be: run the project's own side-by-side on representative hard tasks before defaulting (AgentPatterns: "published benchmarks do not predict your codebase's outcomes"), or default to DeepSeek V4 Pro until MiMo-V2.5-Pro has verified scores.

Confidence: High for pricing/volume (res013 transcription); benchmark-gap statement is an absence-of-evidence claim, flagged per DIA-072.

## 7. Confidence assessment

- High: all 8 escalation-routing sources archived with full content in Phase A (8/8, 0 failures - see phase_a_report.txt); benchmark/pricing table transcribed from the 7-source res013 archive.
- Medium-High: ladder Rung0-4 and analyzer-Luna designs - grounded in the DIA-111 ticket flow + archived patterns, but exact trigger thresholds (2 failed runs, etc.) are proposed defaults to be validated on project tasks.
- CAVEAT (withdrawn source): CodeRescue (arXiv:2607.19338) was WITHDRAWN on 2026-07-30 at the request of ByteDance (manuscript submitted before completing the company's internal review/approval process). Its abstract and results were preserved in the researcher's 2026-08-11 compilation and cross-checked against the live ARCHER repository README (same authors, same numbers, results table verified); CodeRescue-specific numeric claims are flagged as withdrawn-source in this conspect.
- Excluded claims per DIA-072: no SWE-bench score is asserted for qwen3.7-plus or mimo-v2.5-pro (absent from the res013 archive); no GPQA or other-benchmark claims are made (not in the archive).

## MLA citations (archived local files)

- AgentPatterns. "Codified Effort and Escalation Policy in the Instruction File." AgentPatterns.ai, reviewed 3 Jul. 2026. knowledge/res014-model-escalation-routing/sources/agentpatterns-codified-escalation.md.
- He, Qijia, et al. "CodeRescue: Budget-Calibrated Recovery Routing for Coding Agents." arXiv:2607.19338 [cs.AI], 21 Jul. 2026 (withdrawn 30 Jul. 2026). knowledge/res014-model-escalation-routing/sources/code-rescue-recovery-routing.md.
- Qijia-He. "ARCHER: Adaptive Recovery routing with Conformal-risk calibration for coding agents." GitHub, 2026 (formerly agent-budget-control). knowledge/res014-model-escalation-routing/sources/archer-recovery-router.md.
- Shah, Tanay. "Four Production Reliability Patterns for AI Agents (Beyond Retry-With-Backoff)." Tanay Shah Blog, 26 Apr. 2026. knowledge/res014-model-escalation-routing/sources/tanay-shah-reliability-patterns.md.
- Son, Seongho, et al. "SWE-Router: Routing in Multi-turn Agentic Software Engineering Tasks." arXiv:2607.00053 [cs.SE], 30 Jun. 2026. knowledge/res014-model-escalation-routing/sources/swe-router-temporal-routing.md.
- Varshney, Tanay, et al. "Route AI Agents Across Models with NVIDIA NeMo Switchyard." NVIDIA Technical Blog, 11 Aug. 2026. knowledge/res014-model-escalation-routing/sources/nemo-switchyard-routing.md.
- Zhou, Pengfei, et al. "Agent-as-a-Router: Agentic Model Routing for Coding Tasks." arXiv:2606.22902 [cs.AI], 26 Jun. 2026. knowledge/res014-model-escalation-routing/sources/agent-as-a-router-caf-loop.md.
- Khoo, William. "ADR-025: Agent Routing via Plan-Time Selection and Cross-Agent Escalation." nathapp-io/nax, 12 Jun. 2026. knowledge/res014-model-escalation-routing/sources/nax-adr025-escalation-ladder.md.

Cross-referenced (res013 archive, DIA-108, not duplicated):
- Anomaly. "Go." OpenCode Docs, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/opencode-go-pricing.md.
- Anomaly. "Models." OpenCode Docs, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/opencode-models.md.
- GitHub. "Models and pricing for GitHub Copilot." GitHub Docs, 2026. knowledge/res013-opencode-model-pricing-audit/sources/copilot-models-pricing.md.
- BenchLM. "SWE-bench Verified Leaderboard (August 2026): Top Scores." BenchLM.ai, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/swebench-benchlm.md.
- Vals AI. "SWE-bench Verified." Vals AI, 8 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/swebench-vals.md.
- SWE-bench Team. "SWE-bench Verified." SWE-bench, 10 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/swebench-official.md.
- GitHub. "Usage-based billing for individuals." GitHub Docs, 2026. knowledge/res013-opencode-model-pricing-audit/sources/copilot-usage-billing.md.

Unarchived sources: none. All 8 requested escalation-routing sources were archived successfully in Phase A. One source status note: CodeRescue arXiv full text is no longer distributed (withdrawn) - the abs-page abstract and the companion ARCHER repo cover its content; the URL https://arxiv.org/html/2607.19338 returns 404 and was substituted with the abs page in archival. No source is marked [source not archived - excluded per DIA-072 policy].

---
Document prepared by conspecter lane on 2026-08-12. All citations point to locally archived artifacts under knowledge/res014-model-escalation-routing/sources/ and knowledge/res013-opencode-model-pricing-audit/sources/.
