Res014: OpenCode Agent Presets (Models / Temperature / Reasoning Effort) for the OpenCode Go + Copilot Workflow

Date: 2026-08-12
Scope: synthesis of 19 archived sources in knowledge/res021-opencode-agent-presets/sources/ plus the res013 local archive referenced as supplementary. Sections: (1) DeepSeek V4 Flash specs/modes/effort mapping, (2) GPT 5.6 Luna specs/role split/benchmarks, (3) OpenCode Go promo (2x usage tags, request budgets), (4) GitHub Copilot billing/BYOK/ACP and Copilot-only models, (5) temperature best practices per role, (6) reasoning-effort best practices, (7) recommended preset delta table (RECOMMENDATION NOT APPLIED), (8) gap vs res013. All numeric claims cite the archived local files.

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 19
phase-a-failures: 0
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

CORRECTION (2026-08-12, ai-specialist audit):

Finding (verified against live DeepSeek API docs 2026-08-12): the original
temperature discussion implied temperature is inert only on "non-thinking"
Flash lanes and that other lanes retain live temperature knobs. That is wrong.
DeepSeek thinking mode is ENABLED BY DEFAULT at effort high; the OpenCode
`variant: medium/low` settings are effort levels, NOT thinking toggles; and no
lane in .opencode/oh-my-opencode-slim.jsonc sets `thinking.type: disabled`
(only `enabled` blocks exist). Therefore `temperature`, `top_p`,
`presence_penalty` and `frequency_penalty` are INERT on ALL DeepSeek V4 Flash
lanes -- coder, researcher, memory-manager, code-navigator, resource-manager
and conspecter included -- so every temperature value configured on those lanes
is cosmetic. Additionally, DeepSeek `reasoning_effort` accepts only
`low/high/xhigh/max` (NO "medium" level).

Amendments applied: Section 1 summary + temperature guidance, Section 5
applicability note, Section 6 DeepSeek effort vocabulary, Section 7 temps-row
rationale. The "no temperature changes needed" verdict (audit P4) is UNCHANGED
-- it is strengthened: altering cosmetic temperatures would have no effect.
Grounding: DeepSeek, "Thinking Mode" (archived deepseek-thinking-mode.md);
config read 2026-08-12.

1. DeepSeek V4 Flash: specs, reasoning modes, effort mapping, temperature guidance, agentic scores

Summary: DeepSeek-V4-Flash is a 284B-parameter Mixture-of-Experts model with 13B activated parameters (arXiv paper; the Hugging Face card lists 304B total params, which includes the attached DSpark speculative-decoding module). It supports a 1M-token context and up to 384,000 output tokens, with three reasoning modes (Non-think / Think High / Think Max). Temperature is inert in thinking mode, which is ENABLED BY DEFAULT at effort high (DeepSeek, "Thinking Mode", 2026); since no lane in this repo's config disables thinking, all temperature settings on DeepSeek V4 Flash lanes are cosmetic (see CORRECTION note above). DeepSeek's official temperature=0.0 guidance applies only to non-thinking mode, which no current lane exercises. On agentic benchmarks the 0731 release outperforms V4-Pro-Preview and is broadly competitive with the strongest proprietary models (DeepSeek-AI, "DeepSeek-V4-Flash-0731", 2026).

Specs:
- Architecture: DeepSeekMoE, 284B total / 13B activated (DeepSeek-AI, "DeepSeek-V4", 2026); HF card lists 304B total params incl. speculative module (DeepSeek-AI, "DeepSeek-V4-Flash-0731", 2026).
- Context: 1M tokens; max output 384K tokens (Chat-Deep.ai snapshot, 2026; Julien, 2026).
- Hybrid attention (CSA + HCA), Manifold-Constrained Hyper-Connections, Muon optimizer; in 1M-token context Flash uses ~10% of the single-token FLOPs and 7% of the KV cache of DeepSeek-V3.2 (DeepSeek-AI, "DeepSeek-V4", 2026).
- Release: DeepSeek-V4-Flash-0731 is the official API release behind the `deepseek-v4-flash` request ID, public beta since 2026-07-31; Responses API support is Flash-only; ZDR agreement valid through 2026-08-31 (Chat-Deep.ai, 2026; Anomaly, "Go", 2026).

Reasoning modes (Non-think / Think High / Think Max):
- The paper trains distinct specialist models per effort mode with different length penalties and context windows (8K / 128K / 384K for Non-think / High / Max in the evaluation setup), demarcated by <think> and </think> tokens; the Think Max mode prepends an explicit "reasoning effort: absolute maximum" system instruction (DeepSeek-AI, "DeepSeek-V4", 2026).
- Max mode outperforms High mode on the most challenging tasks; Flash-Max matches Pro-Max on several agent benchmarks but trails on complex high-difficulty tasks; Flash-Max attains reasoning comparable to GPT-5.2 / Gemini-3.0-Pro (DeepSeek-AI, "DeepSeek-V4", 2026).

reasoning_effort mapping (requested -> actual on Flash):
- `low/high/xhigh/max` maps to `low/high/high/max` on deepseek-v4-flash, and to `high/high/max/max` on deepseek-v4-pro (DeepSeek, "Thinking Mode", 2026; Chat-Deep.ai, 2026). The official table does not list `medium`; thinking mode is enabled by default with default effort `high` (DeepSeek, "Thinking Mode", 2026). The HF model card states `reasoning_effort` supports three levels: `low`, `high`, `max` (DeepSeek-AI, "DeepSeek-V4-Flash-0731", 2026).

Temperature guidance:
- Thinking mode does not support `temperature`, `top_p`, `presence_penalty`, or `frequency_penalty` -- setting them triggers no error but has no effect (DeepSeek, "Thinking Mode", 2026; Chat-Deep.ai, 2026).
- Thinking mode is ENABLED BY DEFAULT with default effort `high` (DeepSeek, "Thinking Mode", 2026). The OpenCode `variant: medium/low` settings in this repo's config are effort levels, NOT thinking toggles, and no lane sets `thinking.type: disabled` (config read 2026-08-12). Consequence (CORRECTION 2026-08-12): `temperature` is INERT on ALL DeepSeek V4 Flash lanes -- coder (0.1), researcher (0.7), memory-manager (0.1), and every other Flash-configured lane -- all such values are cosmetic.
- Non-thinking mode (only reachable by explicitly disabling thinking): DeepSeek's official temperature guide recommends `temperature=0.0` for coding and math; use higher temperature only for brainstorming architecture options, naming, or alternative implementations (Chat-Deep.ai, 2026). No current lane exercises this path.
- Agentic benchmark evaluation uses `temperature = 1.0, top_p = 0.95` with `max` reasoning effort (DeepSeek-AI, "DeepSeek-V4-Flash-0731", 2026); local serving guidance recommends temperature 1.0, top_p 0.95 for agentic scenarios and top_p 1.0 otherwise, with 384K max output for high/max effort (same source). These are evaluation/local-serving conventions for the model, not live knobs in this repo's lanes.

Agentic benchmark scores (DeepSeek-V4-Flash-0731, evaluated with DeepSeek Harness minimal mode, max effort, temp 1.0 / top_p 0.95):

| Benchmark | Flash-0731 | Flash (Preview) | V4-Pro (Preview) | GLM-5.2 | Opus-4.8 |
|---|---|---|---|---|---|
| Terminal Bench 2.1 | 82.7 | 61.8 | 72.1 | 81.0 | 85.0 |
| NL2Repo | 54.2 | 39.4 | 38.5 | 48.9 | 69.7 |
| Cybergym | 76.7 | 38.7 | 52.7 | - | 83.1 |
| DeepSWE | 54.4 | 7.3 | 12.8 | 46.2 | 58.0 |
| Toolathlon-Verified | 70.3 | 49.7 | 55.9 | 59.9 | 76.2 |
| Agents' Last Exam | 25.2 | 15.8 | 16.5 | 23.8 | 25.7 |
| AutomationBench Public | 25.1 | 10.8 | 12.8 | 12.9 | 27.2 |
| DSBench-FullStack (internal) | 68.7 | 37.0 | 41.8 | 61.8 | 71.6 |
| DSBench-Hard (internal) | 59.6 | 25.8 | 31.1 | 54.5 | 71.7 |

(DeepSeek-AI, "DeepSeek-V4-Flash-0731", 2026.)

Paper-reported agent results (Flash-Max / Flash-High rows in Table 7): SWE Verified (Resolved) 80.6 / 80.2; Terminal Bench 2.0 (Acc) 68.5 / 66.7; SWE Pro 54.2 / 58.6; BrowseComp (Pass@1) 85.9 / 83.2; HLE w/ tools 51.6 / 54.0; the paper notes Flash underperforms Pro on coding tasks, particularly Terminal Bench 2.0 (DeepSeek-AI, "DeepSeek-V4", 2026).

Confidence: High (all figures directly transcribed from archived deepseek-v4-flash-0731.md and arxiv-2606-19348.md).

2. GPT 5.6 Luna: nano-class tier, specs, reasoning.effort, role split, coding agent score, pricing

Summary: GPT-5.6 Luna is OpenAI's most cost-efficient GPT-5.6 model, roughly corresponding to the nano tier of earlier GPT-5 families. It has a 1,050,000-token context window (922,000 max input) and 128,000 max output tokens, supports reasoning.effort from none through max (default medium), and is available on OpenCode Go as well as via the OpenAI API and Copilot (OpenAI, "GPT-5.6 Luna", 2026).

Specs (OpenAI, "GPT-5.6 Luna", 2026):
- Model ID `gpt-5.6-luna`; input text+image, output text; knowledge cutoff Feb 16, 2026; reasoning token support.
- Context window 1,050,000; max input 922,000; max output 128,000.
- reasoning.effort supported values: none, low, medium (default), high, xhigh, max.
- Endpoints: Chat Completions + Responses supported; Batch supported; Realtime/Assistants/Fine-tuning/Embeddings not supported.
- Features: streaming, structured_outputs, function_calling, file_search, image_input, web_search, prompt_caching; tools incl. web_search, file_search, image_generation, code_interpreter, hosted_shell, apply_patch, skills, computer_use, mcp, tool_search.
- Rate limits (default tier): Tier 1 500 RPM / 500K TPM up to Tier 5 30,000 RPM / 180M TPM.

Pricing (OpenAI API reference, after the 2026-07-30 -80% price reduction noted in the announcement): input $0.2 / 1M, cached input $0.02 / 1M, output $1.2 / 1M; >272K input tokens priced at 2x input and 1.5x output for the full request; cache writes 1.25x uncached input (OpenAI, "GPT-5.6 Luna", 2026). Go pricing identical: $0.20/$1.20 (<=272K) and $0.40/$1.80 (>272K) (Anomaly, "Go", 2026).

Recommended role split (synthesised from archived OpenAI sources): the announcement frames the family as "efficient by default, maximum performance on demand" and positions Luna as the fastest/most affordable tier, with customer evidence that routine and well-specified implementation work runs on Terra/Luna without quality loss (Notion: agents running GPT-5.5 "perform just as well on Terra for half the cost and 16% fewer tokens"; Cognition: Luna combines "strong coding-agent performance with very strong cost efficiency") (OpenAI, "GPT-5.6", 2026). The reasoning guide adds: "gpt-5.6-luna for the lowest cost and latency" and maps `low` effort to "execution-oriented coding" and `medium` to "agentic coding" (OpenAI, "Reasoning models", 2026). The practical split -- frontier models (Sol/Terra) for planning and hard architecture, Luna for well-specified changes and test generation -- is a synthesis of these archived statements plus the coding-effort research in Section 6, not a verbatim OpenAI sentence; treat as derived guidance.

Coding Agent Index (Artificial Analysis Coding Agent Index v1.1): GPT-5.6 Luna 74.6, vs Sol 80 (SOTA), Terra 77.4, GPT-5.5 76.4, Claude Fable 5 77.2, Claude Opus 4.8 72.5, Gemini 3.1 Pro Preview 42.7; "Luna outperforms Opus 4.8... in roughly one-third of the time, with about half as many output tokens, and at approximately one-quarter the estimated cost" (OpenAI, "GPT-5.6", 2026). SWE-Bench Pro: Luna 62.7%; DeepSWE v1.1: Luna 67.2%; Terminal-Bench 2.1: Luna 84.7% (same source).

Confidence: High (transcribed from archived openai-gpt-5-6.md and openai-gpt-5-6-luna.md; the role-split paragraph is flagged as synthesis).

3. OpenCode Go: promo tags, request budgets, dollar limits, config id format

Summary: OpenCode Go is a $5-first-month then $10/month flat subscription covering 18 curated coding models with dollar-denominated limits ($12/5h, $30/wk, $60/mo). The official docs page (fetched 2026-08-12) still lists standard per-1M pricing, while the community tracker (snapshot 2026-08-11) records a 2x-usage promo for DeepSeek V4 Flash and GPT 5.6 Luna with halved effective rates (Anomaly, "Go", 2026; Julien, 2026).

2x usage promo (from the unofficial tracker, which cross-references the live `/zen/go/v1/models` endpoint + models.dev + official docs):
- DeepSeek V4 Flash tagged "2x usage": pricing changed 2026-08-11 from $0.14/$0.28 to $0.07/$0.14 per 1M in/out (cache read $0.0014); context 1M, max output 384,000 (Julien, 2026). The official docs page still shows $0.14/$0.28 -- the promo rate is visible on the API metadata/models.dev side; treat the docs-page figure as the conservative reference (Anomaly, "Go", 2026).
- GPT-5.6 Luna tagged "2x usage": $0.10/$0.60 per 1M in/out (cache read $0.01, cache write $0.12); context 1M, max output 128,000 (Julien, 2026). Official docs page shows $0.20/$1.20 (<=272K) / $0.40/$1.80 (>272K) (Anomaly, "Go", 2026).
- The standard (non-promo) model set gets ~6x usage via bulk discounts and reserved GPU capacity; new or already-discounted models carry a lower multiplier -- which is the framing under which Flash and Luna now carry the explicit 2x tag (Anomaly, "Go", 2026).

Request budgets (official docs estimates based on typical Go usage patterns; dollar caps $12/5h, $30/wk, $60/mo):
- DeepSeek V4 Flash: 31,650 req/5h, 79,050 req/wk, 158,150 req/mo -- $60/month usage bucket (Anomaly, "Go", 2026). This is the highest-volume model on the roster; the tracker lists the same figures (Julien, 2026; Dragos, 2026).
- GPT 5.6 Luna: 2,050 req/5h, 5,100 req/wk, 10,250 req/mo -- $15/month usage bucket (Anomaly, "Go", 2026). Models on the $15 tier: Grok 4.5, GPT 5.6 Luna, Kimi K3, Qwen3.8 Max, MiMo-V2.5-Pro, DeepSeek V4 Pro (Anomaly, "Go", 2026; Dragos, 2026).

Config id format: `opencode-go/<model-id>` in the OpenCode config -- e.g. `opencode-go/kimi-k3`, `opencode-go/deepseek-v4-flash`, `opencode-go/gpt-5.6-luna` (Anomaly, "Go", 2026). Endpoint for Luna is the Responses API (`https://opencode.ai/zen/go/v1/responses`, `@ai-sdk/openai`); Flash uses chat completions (`.../v1/chat/completions`, `@ai-sdk/openai-compatible`) (Anomaly, "Go", 2026). Usage beyond limits falls back to the Zen balance via the "Use balance" option, or continues on free models (Anomaly, "Go", 2026).

Privacy note: Grok 4.5 and GPT 5.6 Luna retain logs 30 days; all other Go models 0 days; no model training (Anomaly, "Go", 2026). Bitdoze flags: "If you ship proprietary code, avoid those two or scrub the prompts" (Dragos, 2026).

Confidence: High for docs-page figures; the 2x-usage promo figures come from the tracker and should be re-verified against the live endpoint before relying on them (flagged).

4. GitHub Copilot: credit billing, Copilot-only models, CLI BYOK + ACP

Credit billing (supplementary reference to the res013 local archive; the res014 fetch of the Copilot CLI pages confirms the mechanism):
- Copilot CLI consumes "AI credits based on the number of tokens processed", varying by model (GitHub, "About GitHub Copilot CLI", 2026).
- 1 credit = $0.01 USD; individual plans include monthly credit allowances: Copilot Pro $10/mo = 1,500 credits (1,000 base + 500 flex); per-1M token pricing for all Copilot models archived in res013 (GitHub, "Usage-based billing for individuals", 2026, as archived in knowledge/res013-opencode-model-pricing-audit/sources/copilot-usage-billing.md).

Models on Copilot but NOT on OpenCode Go (cross-reference of the archived Copilot supported-models list vs the Go 18-model roster):
- Copilot-supported OpenAI models absent from Go: GPT-5 mini, GPT-5.3-Codex, GPT-5.4 / mini / nano, GPT-5.5, GPT-5.6 Sol, GPT-5.6 Terra (GitHub, "Supported AI models in Copilot", 2026; Anomaly, "Go", 2026).
- Copilot-supported Anthropic models absent from Go: Claude Fable 5, Haiku 4.5, Sonnet 4.5, Sonnet 4.6, Sonnet 5, Opus 4.5-4.8, Opus 5 (same two sources).
- Copilot-supported Google models absent from Go: Gemini 3.1 Pro (public preview), Gemini 3.5 Flash, Gemini 3.6 Flash (same two sources).
- Also Copilot-only: MAI-Code-1-Flash, MAI-Code-1.1-Flash (Microsoft), Raptor mini (fine-tuned GPT-5 mini) (GitHub, "Supported AI models in Copilot", 2026).
- Correction note vs the task brief: Grok 4.5 was listed in the brief as "not on Go", but the archived Go docs list Grok 4.5 as a member of the 18-model roster (Anomaly, "Go", 2026). Per the res013 DIA-108 rule, availability claims were validated against the actual roster lists before being asserted. Models present on BOTH Copilot and Go: GPT-5.6 Luna, Grok 4.5, Kimi K2.7 Code, Kimi K3.
- Res013 availability caveat applies: pricing-page/model-list availability does not imply availability on a specific plan/seat; validate against the actual subscription's model list before recommending (Anomaly, res013 disposition, 2026).

CLI BYOK (bring-your-own-key): Copilot CLI can be configured to use your own model provider instead of GitHub-hosted models -- OpenAI-compatible endpoints (incl. Ollama and vLLM), Azure OpenAI, or Anthropic -- via environment variables (base URL, provider type `openai`/`azure`/`anthropic`, API key, model). Requirements: models MUST support tool calling (function calling) and streaming, else Copilot CLI errors; for best results a context window of at least 128k tokens (GitHub, "Use your own model provider", 2026). This is the path for routing Copilot CLI to OpenCode Go models.

CLI ACP: ACP (the Agent Client Protocol) is an open standard for interacting with AI agents; it allows using Copilot CLI as an agent in any third-party tools, IDEs, or automation systems that support the protocol. Copilot CLI has interactive (ask/execute + plan mode) and programmatic interfaces (GitHub, "About GitHub Copilot CLI", 2026).

Confidence: High (transcribed from archived copilot-supported-models.md, copilot-cli-byok.md, copilot-cli-acp.md; credit figures from the res013 archive).

5. Temperature best practices per role

Summary: the archived sources converge on a per-role temperature ladder: lowest for code and review (deterministic), low-mid for spec/architecture (precision), and mid for research (exploration). Empirical grounding: an exhaustive 14,742-segment code-generation study found optimal performance with temperature below 0.5, top_p below 0.75, frequency penalty above -1 and below 1.5, presence penalty above -1 (Arora et al., 2024).

| Role | Temperature range | Grounding |
|---|---|---|
| Code generation / implementation | 0.0 - 0.3 | Glanzz: "use temperature 0.0 to 0.3 for code generation", start at 0.2; Cursor reportedly defaults to 0.0; GPT-4 optimal at 0.1/top-p 0.9. DeepSeek official guidance: 0.0 for coding and math. ClaudeGuide: temp=0 for code generation; 0.2 in the production code-agent setting. |
| Code review | 0.0 - 0.2 | Glanzz: "0.0-0.2 for general review"; Anthropic recommends temperature closer to 0.0 for analytical tasks. |
| Security review | 0.0 - 0.1 | Glanzz: "0.0-0.1 for security where false negatives are expensive". |
| Architecture / ADR / diagrams | 0.2 - 0.4 | Glanzz: ADRs 0.2-0.4 (top-p 0.3-0.5); architecture docs 0.2-0.4; Mermaid/PlantUML diagram generation 0.2-0.4 (syntax errors break output). |
| Spec / technical documentation | 0.1 - 0.3 | Glanzz: documentation generation 0.1-0.3 (Predibase docstring generator uses 0.1); READMEs where prose matters 0.3-0.5. |
| Research / balanced analysis | 0.5 - 0.7 | ClaudeGuide: 0.5-0.7 for technical writing, summaries, balanced agentic decisions; Glanzz: trade-off discussions 0.4-0.6 (with presence penalty 0.3-0.6), design-pattern comparisons 0.3-0.6, brainstorming novel approaches 0.7-0.9. |
| Test generation | 0.0 (standard), 0.2-0.4 (edge-case discovery, 5-10 candidates then filter) | Glanzz. |

Caveats from the sources: temperature 0.0 is near-deterministic but not perfect (~0.1% variability; use seed or majority vote for absolute determinism); tune temperature OR top_p, never both simultaneously; production should run lower temperatures (0.2-0.5) than development; reasoning models break the classical paradigm -- OpenAI o-series lock temperature at 1.0 and Google Gemini 3 is optimized for 1.0 with warnings against lower values (Glanzz, 2025; ClaudeGuide, 2026). Model-specific optimization matters: GPT-4 and Mistral have nearly opposite optimal settings (Glanzz, 2025).

DeepSeek-lane applicability note (CORRECTION 2026-08-12): the per-role temperature bands above are vendor-agnostic guidance for models that honour temperature (OpenAI/Anthropic/Google API models, and DeepSeek in explicitly non-thinking mode). They do NOT apply as live knobs to this repo's DeepSeek V4 Flash lanes: thinking mode is enabled by default at effort high and no lane disables it, so temperature is inert there (DeepSeek, "Thinking Mode", 2026). The bands remain relevant to the OpenAI/Anthropic-model lanes (e.g. reviewer qwen3.7-plus, ai-auditor gpt-5.3-codex) and to any future lane that explicitly disables DeepSeek thinking.

Confidence: High (multiple independent sources agree; ranges flagged as guidance, not universal optima).

6. Reasoning effort best practices

Summary: the archived sources agree that reasoning effort should be matched to task structure, not difficulty, and that medium -- not high -- is the default sweet spot for coding; high is reserved for architecture, debugging, and security work; cost and latency scale steeply with effort.

- Medium beats high on code: on Expert-SWE-style benchmarks medium lands ~71-73% pass rate while high regresses by 3-5 points (over-thinking, gold-plating, second-guessing correct approaches); "default to medium for code and escalate to high only when medium visibly struggles, not as a reflex" (Bartley Editions, 2026). T-Minus: "medium effort: typical feature work and interactive coding sessions. This is the recommended default for most day-to-day coding" (T-Minus AI, 2026).
- Effort-to-task-structure matching: planning/analysis (architecture decisions, root-causing a subtle bug, design tradeoffs) rewards high; mechanical execution (applying an agreed change, formatting, boilerplate from a clear spec) wants minimal/low; verification/review sits at medium (Bartley Editions, 2026). OpenAI's effort table: none = latency-critical no-reasoning tasks; low = tool-use/planning/search/execution-oriented coding; medium = agentic coding, research, long-horizon delegation (default); high = hard reasoning, complex debugging, agentic coding; xhigh = security and code review, deep research (OpenAI, "Reasoning models", 2026).
- High for architecture/debug/security: high (or xhigh) for intermittent race conditions in async queues, circular dependencies across modules, non-trivial refactors, and security audits (T-Minus AI, 2026); xhigh explicitly recommended for "security and code review" (OpenAI, "Reasoning models", 2026).
- Cost/latency structure: fee inflation ~4-17x between lowest and highest tiers; time-to-first-token up 5-60x; thinking tokens bill at output-token rate (a 4,000-token thinking run before a 500-token answer costs ~9x the bare answer) (Bartley Editions, 2026; T-Minus AI, 2026).
- Escalate on evidence, not "just in case": start at the model's default (medium for GPT-5.5/GPT-5.6; high for DeepSeek thinking mode), raise only when the answer is measurably wrong or shallow (T-Minus AI, 2026; OpenAI, "Reasoning models", 2026; DeepSeek, "Thinking Mode", 2026).
- DeepSeek-specific: thinking mode on by default at effort high; requested low/high/xhigh/max maps to low/high/high/max on Flash (xhigh is collapsed to high) and high/high/max/max on Pro; max is the mode where Flash-Max approaches Pro-Max on agent benchmarks (DeepSeek, "Thinking Mode", 2026; DeepSeek-AI, "DeepSeek-V4", 2026). DeepSeek's `reasoning_effort` vocabulary has NO `medium` level -- the accepted requested values are `low/high/xhigh/max` only (DeepSeek, "Thinking Mode", 2026; Chat-Deep.ai, 2026), so any "medium" effort reference in this conspect applies to OpenAI-style models (Luna/qwen), never to a DeepSeek lane.
- Model choice vs effort: routing picks the model (capability ceiling); effort tunes deliberation within it. "Raise effort when the model was lazy; switch models when it was ignorant" (Bartley Editions, 2026, citing the lazy-vs-ignorant framing).

Confidence: High (four independent sources converge; benchmark deltas cited per source).

7. Recommended preset delta table (RECOMMENDATION -- NOT APPLIED)

Current state of the default `opencode-go` preset in .opencode/oh-my-opencode-slim.jsonc (read 2026-08-12; unchanged by this conspect):

| Agent | Current model | Variant | Temperature | reasoningEffort option |
|---|---|---|---|---|
| coder | opencode-go/deepseek-v4-flash | medium | 0.1 | not set (DeepSeek default high in thinking mode) |
| designer | opencode-go/kimi-k2.7-code | medium | not set | not set |
| reviewer | opencode-go/qwen3.7-plus | medium | 0.1 | not set |

Recommended delta (grounded in Sections 1-6; proposed to the developer 2026-08-12, **declined -- NOT applied**):

| Agent | Delta | Rationale (archived grounding) |
|---|---|---|
| coder | += Luna secondary: `["opencode-go/deepseek-v4-flash", "opencode-go/gpt-5.6-luna"]` | Luna is the cheapest OpenAI reasoning model on Go ($0.20/$1.20 or 2x-promo $0.10/$0.60) with a 74.6 Coding Agent Index (above Opus 4.8) and low effort suited to well-specified implementation; a fallback preserves volume (Flash 158K req/mo vs Luna 10.25K req/mo at the $15 tier) (Anomaly, "Go", 2026; OpenAI, "GPT-5.6", 2026; OpenAI, "GPT-5.6 Luna", 2026). |
| designer | += Luna fallback: `["opencode-go/kimi-k2.7-code", "opencode-go/gpt-5.6-luna"]` | Luna is the strongest archived option for structured, specification-following generation (frontend/code-shaped output) per the OpenAI family benchmarks; fallback only, so Kimi K2.7 Code remains primary (OpenAI, "GPT-5.6", 2026). |
| reviewer | reasoningEffort = medium (explicit `options.reasoningEffort: "medium"`) | Medium is the verified sweet spot for review/verification work; high regresses on code-like tasks by 3-5 points; an explicit setting prevents drift to a harsher default (Bartley Editions, 2026; T-Minus AI, 2026). |
| temps | UNCHANGED (coder 0.1, reviewer 0.1; designer none) | Verdict (audit P4) stands; rationale corrected 2026-08-12 (ai-specialist audit). Coder runs DeepSeek V4 Flash with thinking mode default-on, so its 0.1 temperature is INERT (cosmetic) -- changing it would have no effect, and none is warranted. Reviewer 0.1 (qwen3.7-plus) and any OpenAI/Anthropic-lane temperatures sit inside the archived per-role bands: code 0.0-0.3, review 0.0-0.2, architecture 0.2-0.4 (Glanzz, 2025). No change warranted. |

Status: RECOMMENDATION ONLY. The developer declined to apply it on 2026-08-12; no configuration file was modified by this conspect. If the developer later approves, the change routes through @coder (implementation) per AGENTS.md workflow; this conspect is the reference for the delta.

Confidence: High for the current-state transcription (read directly from the config); the delta itself is a recommendation with archived grounding, pending developer disposition.

8. Gap vs res013

res013 (opencode-model-pricing-audit, 2026-08-12) covers pricing and usage limits only: OpenCode Go subscription economics, per-1M pricing tables, Copilot credit economics, and SWE-bench Verified scores. It does NOT cover: (a) model temperature guidance, (b) reasoning-effort semantics and per-model effort mapping, (c) model role-split recommendations for agent presets, or (d) preset configuration deltas. res014 fills that gap: it adds the DeepSeek V4 Flash and GPT 5.6 Luna capability/mode detail behind the models res013 priced, the temperature and reasoning-effort guidance per agent role, the 2x-usage promo tracking, and the (declined) preset delta recommendation. res014 relies on res013's local archive for Copilot credit mechanics (1 credit = $0.01, Pro 1,500 credits/mo) and inherits the res013 DIA-108 availability-validation rule.

MLA citations (archived local files, knowledge/res021-opencode-agent-presets/sources/):
- DeepSeek-AI. "DeepSeek-V4-Flash-0731." Hugging Face model card, 2026. deepseek-v4-flash-0731.md.
- DeepSeek-AI. "DeepSeek-V4: Towards Highly Efficient Million-Token Context Intelligence." arXiv:2606.19348v1 [cs.CL], 26 Apr. 2026. arxiv-2606-19348.md.
- DeepSeek. "Thinking Mode." DeepSeek API Docs, 2026. deepseek-thinking-mode.md.
- Chat-Deep.ai. "DeepSeek for Coding: V4 Models, API, FIM & Agents." Chat-Deep.ai, official sources verified 5 Aug. 2026. deepseek-for-coding.md.
- OpenAI. "GPT-5.6: Frontier intelligence that scales with your ambition." OpenAI, 9 Jul. 2026 (pricing update 30 Jul. 2026). openai-gpt-5-6.md.
- OpenAI. "GPT-5.6 Luna." OpenAI API Docs (developers.openai.com), 2026. openai-gpt-5-6-luna.md.
- OpenAI. "Reasoning models." OpenAI API Docs (developers.openai.com), 2026. openai-reasoning-guide.md.
- Anomaly. "Go." OpenCode Docs, last updated 12 Aug. 2026. opencode-go-docs.md.
- Anomaly. "Go." OpenCode Docs (dev mirror), last updated 12 Aug. 2026. opencode-go-docs-dev.md.
- Julien. "OpenCode Go Models." julien.cloud, auto-generated 11 Aug. 2026 22:08 UTC. opencode-go-models-julien.md.
- Dragos. "Get DeepSeek V4 Flash, GPT 5.6 Luna, Qwen 3.8 Max and Kimi K3 for Cheap: OpenCode Go vs ClinePass." Bitdoze, 3 Aug. 2026. opencode-go-vs-clinepass.md.
- GitHub. "Supported AI models in Copilot." GitHub Docs, 2026. copilot-supported-models.md.
- GitHub. "Use your own model provider (BYOK) with Copilot CLI." GitHub Docs, 2026. copilot-cli-byok.md.
- GitHub. "About GitHub Copilot CLI." GitHub Docs, 2026. copilot-cli-acp.md.
- Arora, Chetan, et al. "Optimizing Large Language Model Hyperparameters for Code Generation." arXiv:2408.10577v1 [cs.SE], 20 Aug. 2024. arxiv-2408-10577.md.
- ClaudeGuide.io. "Claude API Sampling: Temperature, Top-P, Top-K, Stop (2026)." ClaudeGuide.io, 22 May 2026. claude-sampling-parameters.md.
- Glanzz. "Stop using temperature 1.0 for code generation: Advanced LLM sampling parameters guide every developer needs." Medium, 23 Dec. 2025. temperature-1-0-glanzz.md.
- Bartley Editions. "Reasoning Effort." Encyclopedia of Agentic Coding Patterns, aipatternbook.com, 2026. reasoning-effort-patternbook.md.
- T-Minus AI Editorial. "Reasoning Effort, Explained: Why 'Always Use Max' Is Costing You." T-Minus AI, 15 Jun. 2026. choose-reasoning-effort-tminus.md.

Supplementary local references (res013 archive, cited for Copilot credit mechanics):
- GitHub. "Usage-based billing for individuals." GitHub Docs, 2026. knowledge/res013-opencode-model-pricing-audit/sources/copilot-usage-billing.md.
- Anomaly. "Go." OpenCode Docs, 11 Aug. 2026. knowledge/res013-opencode-model-pricing-audit/sources/opencode-go-pricing.md.

Unarchived sources:
None. All 19 requested sources were archived successfully in Phase A (see phase_a_report.txt). No source is marked [source not archived - excluded per DIA-072 policy]. Two claims from the task brief were corrected against the archives rather than excluded: (a) Grok 4.5 IS on the Go roster (Section 4 correction note), and (b) the OpenAI "role split" recommendation is presented as synthesised guidance with grounding citations, not as a verbatim archived quote.

---
Document prepared by conspecter lane on 2026-08-12; amended 2026-08-12 (ai-specialist audit correction: DeepSeek thinking mode is default-on at effort high, so temperature is inert on all DeepSeek V4 Flash lanes; see CORRECTION note). All citations point to locally archived artifacts under knowledge/res021-opencode-agent-presets/sources/ (plus two res013 files referenced as supplementary).
