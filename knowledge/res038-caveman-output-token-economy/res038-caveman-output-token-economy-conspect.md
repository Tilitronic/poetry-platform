# Caveman Terse-Output Persona for Output-Token Economy - Conspect (res038)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 7
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

Conspect for DIA-260821-8kpc (area: opencode-config, severity: Medium, status: OPEN). Research question: are the real tests, benchmarks, and user reviews of the "caveman" terse-output persona worth adopting for output-token economy in this project? Every external claim is grounded in the 7 locally archived source files under `sources/` (Phase A output, archived 2026-08-21 by @researcher). All 7 provisioned external sources passed the researcher's evaluation (High/Med relevance + High/Med reliability) and are cited in the body. Five additional candidate URLs were consulted only as search snippets and are listed under "Unarchived/Excluded" with reasons; they are never cited in the body. Two project-internal context items (res036 conspect and AGENTS.md) are referenced as on-disk context, not fetched. This conspect feeds the DIA-260821-8kpc adoption decision.

## 1. Verdict (read this first)

Do NOT adopt Caveman as a separate plugin for output-token economy. The terse-output benefit it sells is already delivered by the project's active ponytail ruleset (level: full), and ponytail does it with zero extra input-token injection. The one independent, controlled benchmark (JetBrains) measured only an 8.5% output-token saving on real agentic coding work, not the advertised 65%, and output tokens are the cheap half of this project's bill because cache-hit is the dominant cost lever (res036: ~86% of input is cached, miss/hit ratio ~50x). Adopting Caveman for output economy would add a recurring ~1-1.5k input-token overhead per turn to chase a single-digit-percentage cut on the cheaper token class. Reserve Caveman only for (a) its companion skills (terse commits, one-line reviews) or (b) its INPUT-compress path (caveman-compress, Caveman Proxy), and apply the same prefix-drift caution res036 applied to Headroom before any input-compression is enabled.

## 2. What Caveman is

Caveman is a real, popular skill/plugin (JuliusBrussee/caveman, MIT for the skill, BSL-1.1 for the engine/proxy) that instructs the agent to answer in terse "caveman" fragments, dropping articles, filler, and pleasantries while keeping code, commands, and errors byte-exact (Brussee, "Caveman - README"; Brussee, "Honest Numbers"). It ships in two product forms: (1) the output-style skill that only shrinks what the agent says, and (2) the Caveman Proxy / caveman-compress that shrinks what the agent reads (INPUT) (Brussee, "Caveman - README"). The vendor's own ten-prompt benchmark table claims a 65% mean output-token reduction (range 22-87%), but the vendor's own HONEST-NUMBERS doc admits the output-reduction-vs-default claim is "Not published" (no committed reviewed raw result) and that the skill ADDS ~1-1.5k input tokens per turn (Brussee, "Honest Numbers"; Brussee, "Caveman - README" IMPORTANT callout). Cross-agent install covers 30+ agents including opencode (Dutta; Brussee, "Caveman - README").

## 3. The measured savings: 8.5%, not 65%

The decisive evidence is an independent, paired A/B benchmark run by JetBrains on real agentic coding (Harbor 0.17 sandbox, Claude Code 2.1.200, claude-sonnet-5, SkillsBench 86/87 tasks, 3 runs, ~240 billed trials, ~USD 106). With the skill FORCE-ACTIVATED (the best case, since normal auto-trigger saves less or nothing), output tokens fell 592k to 542k, an 8.5% saving, over 82 clean paired tasks. The advertised 65% belongs to chat-style Q&A, not coding agents, because agentic output is dominated by code, diffs, and tool calls that Caveman deliberately leaves verbatim (JetBrains). The JetBrains write-up is explicit: "Advertised saving: 65%. Measured saving: 8.5%" and "the advertised 65% is off-chart" (JetBrains).

Independent blogger Andrew Ooo reproduces the gap: the vendor 10-prompt suite shows 65% mean (22-87% range), but community reproductions land at 30-50% in normal use, and a one-line "be brief." prompt captures 25-40% while a 6-line community prompt captures 30-55% (Ooo). Better Stack, a vendor-adjacent guide, measured 45% vs baseline and 39% vs "be concise," and notes a single query can be ~10% MORE expensive because the skill's input overhead exceeds the output saved on short turns (Better Stack). The Testing Academy field guide repeats the 75% vendor claim but is lower reliability and adds no independent measurement (Dutta).

## 4. Quality: no detectable degradation at lite/full

On the JetBrains paired run, per-task outcomes were 8 better / 10 worse / 64 tied; sign test p = 0.82 (far from significant). Average task score was 0.326 (baseline) vs 0.311 (skill), a -0.015 gap on a 0-1 scale. Style transfer worked as designed: forced-arm transcripts were unmistakably caveman while code artifacts stayed normal (JetBrains). Andrew Ooo reports lite and full preserve correctness on coding tasks; only ultra occasionally drops edge cases (Ooo). The vendor's HONEST-NUMBERS doc and README agree that lite/full are quality-safe (Brussee, "Honest Numbers"; Brussee, "Caveman - README"). So the quality risk of adopting Caveman for output is low, but the quality risk is also the reason ponytail already exists and already covers it.

## 5. The cost-economics caveat: output tokens are the cheap half

Two independent sources frame the same point. Andrew Ooo states plainly: "Output tokens are the cheap part... typically use 5-10x more input than output. Caveman cuts the smaller half of your bill" (Ooo). Better Stack adds the cache nuance: Caveman is "most useful in interactive chat sessions where prompt caching makes economics favorable... single-shot queries add more input cost than saved output" (Better Stack). This matches the project's own res036 finding: DeepSeek V4 Flash cache hit is $0.0028/1M vs cache miss $0.14/1M (a ~50x ratio), and the Go subscription request is ~86% cached input reads; output tokens are NOT cacheable, so cache-hit is the dominant cost lever (poetry-platform, "DCP vs Headroom - Conspect (res036)"). Cutting output tokens therefore attacks the smaller, non-cacheable, cheaper token class, while Caveman's own ~1-1.5k input-token-per-turn overhead attacks the larger, cacheable, more expensive class (Brussee, "Honest Numbers"). The vendor's own rule of thumb is to "compare provider-billed totals on the same task with and without Caveman. If fixed prompt overhead exceeds output reduction, turn Caveman off" (Brussee, "Honest Numbers").

## 6. Project-internal fit: ponytail already covers the output benefit

The project's AGENTS.md shows PONYTAIL MODE ACTIVE at level: full, which enforces terse output ("Code first. Then at most three short lines... No essays, no feature tours, no design notes") (poetry-platform, "AGENTS.md"). Ponytail delivers the same terse-output discipline Caveman's output skill provides, but with zero extra input-token injection and no separate plugin to install or maintain. Because the project already runs ponytail at full, adopting Caveman's output persona would be redundant: it would add the ~1-1.5k input-token/turn overhead (Brussee, "Honest Numbers") to reproduce a benefit ponytail already supplies for free. This is the same "zero-cache-interaction alternative" logic res036 applied when it kept ponytail and rejected Headroom (poetry-platform, "DCP vs Headroom - Conspect (res036)").

## 7. Where Caveman could still help (and the caution that applies)

Caveman's value is NOT in its output persona but in two other surfaces, both of which the project should treat with the same prefix-drift caution res036 applied to Headroom:

- Companion skills: terse commit messages (/caveman-commit), one-line PR reviews (/caveman-review), and cavecrew subagents that emit fewer tokens. These are output-style conveniences that do not change cache behavior and could be adopted if the team wants them (Brussee, "Caveman - README"; Ooo).
- INPUT-compress path: caveman-compress (~46% input reduction on memory/CLAUDE.md-style files) and the Caveman Proxy (vendor claims 33.2% fewer provider-reported input tokens) (Brussee, "Caveman - README"; Brussee, "Honest Numbers"). This targets the expensive, cacheable token class, which is where real savings live. BUT res036 measured that Headroom's cache-preserving mode DRIFTS the frozen prefix on the opencode-go/DeepSeek path (202,503 to 218,109 bytes, reproduced 3x), turning a large cached region from $0.0028/1M to $0.14/1M and producing a net strongly-negative cost delta (poetry-platform, "DCP vs Headroom - Conspect (res036)"). Any Caveman INPUT-compression integration must be spike-tested for the same prefix-drift before adoption; do not assume byte-exact recovery preserves the provider cache.

## 8. Answer to the research question

Real tests and reviews show Caveman is a genuine, quality-safe terse-output tool, but its measured output-token saving on agentic coding is ~8.5% (JetBrains), not the 65% advertised for chat Q&A, and output tokens are the cheap, non-cacheable half of this project's bill (Ooo; Better Stack; res036). The project already runs ponytail at full, which delivers the same terse-output benefit with no input-token overhead (AGENTS.md). Therefore Caveman is NOT worth adopting as a separate plugin for output-token economy: it is redundant with ponytail and would add recurring input-token cost to chase a single-digit cut on the cheaper token class. Reserve Caveman for companion skills or, pending a prefix-drift spike test, the INPUT-compress path (Brussee, "Honest Numbers"; poetry-platform, "DCP vs Headroom - Conspect (res036)").

## 9. Unarchived / excluded sources

The following candidate URLs were consulted only via search snippets, were NOT archived by @researcher, and are excluded per the Phase A manifest (sources/.source-urls.txt lines 19-24). They are never cited in the body.

- lina-ai-nine.vercel.app: marketing landing bundling "Caveman Mode -65%". Vendor claim only, no methodology. Excluded: redundant with the JetBrains measured rebuttal (8.5% vs 65%).
- dev.co/ai/frameworks/caveman: aggregator/marketing summary repeating vendor claims. Excluded: redundant with archived higher-reliability sources.
- github.com/farhan523/claude-code-lean: related token-optimization toolkit mentioning Caveman. Excluded: tangential to the output-persona question.
- srisatyalokesh.is-a.dev/learn-ai/caveman-reduce-tokens: blog repeating 65-75% vendor claims plus a fictional "March 2026 paper". Excluded: low reliability, unsourced claims.
- himanshu31shr.github.io/portfolio/blog/i-measured-caveman-mode-across-6-repos: single-user anecdote, ~1,900 messages, no controlled A/B, non-reproducible estimates. Excluded: anecdote, not a measured benchmark.

## 10. Works cited (MLA)

1. JetBrains. "Speaking to AI Agents like Cavemen Saves 65% of Tokens. We Test." JetBrains Blog, 6 July 2026, blog.jetbrains.com/ai/2026/07/speak-to-ai-agents-like-cavemen-tosave-tokens/. Accessed 21 Aug. 2026. [archived: sources/jetbrains-blog.html]
2. Brussee, Julius. "Caveman - README." GitHub, github.com/JuliusBrussee/caveman. Accessed 21 Aug. 2026. [archived: sources/caveman-readme.md]
3. Brussee, Julius. "Honest Numbers." GitHub, github.com/JuliusBrussee/caveman/docs/HONEST-NUMBERS.md. Accessed 21 Aug. 2026. [archived: sources/caveman-honest-numbers.md]
4. Better Stack. "Caveman: Reducing LLM Output Tokens by up to 75% with a Prompt Skill." Better Stack Community, betterstack.com/community/guides/ai/caveman-llm/. Accessed 21 Aug. 2026. [archived: sources/betterstack-caveman.html]
5. Ooo, Andrew. "Caveman Review: The Claude Code Skill That Cuts 65% of Tokens." andrew.ooo, 5 May 2026, andrew.ooo/posts/caveman-claude-code-skill-token-savings-review/. Accessed 21 Aug. 2026. [archived: sources/andrew-ooo-review.html]
6. Hakim, MD Azizul. "Brevity Constraints Reverse Performance Hierarchies in Language Models." arXiv, 11 Mar. 2026, arxiv.org/abs/2604.00025. Accessed 21 Aug. 2026. [archived: sources/arxiv-2604.00025.html]
7. Dutta, Pramod. "Caveman Mode: Cut AI Agent Tokens 75% (Claude Code, Copilot, Codex)." The Testing Academy, app.thetestingacademy.com/masterclass/caveman. Accessed 21 Aug. 2026. [archived: sources/testingacademy-caveman.html]
8. poetry-platform. "DCP vs Headroom - Conspect (res036)." Project-internal conspect, 2026, knowledge/res036-dcp-vs-headroom/res036-dcp-vs-headroom-conspect.md. Accessed 21 Aug. 2026.
9. poetry-platform. "AGENTS.md - Poetry Platform Engineering Standards (PONYTAIL MODE ACTIVE level: full)." Project-internal config, 2026.

## 11. Claim-to-source mapping (key claims)

- "Caveman is a real skill/plugin; output-style skill + INPUT-compress proxy; MIT skill / BSL-1.1 engine; 30+ agents including opencode" -> Brussee, "Caveman - README" (cite 2); Dutta (cite 7)
- "Vendor claims 65% mean output reduction (22-87% range); HONEST-NUMBERS admits output-reduction-vs-default is Not published; skill ADDS ~1-1.5k input tokens/turn; caveman-compress ~46% INPUT" -> Brussee, "Caveman - README" (cite 2); Brussee, "Honest Numbers" (cite 3)
- "Independent JetBrains A/B: 8.5% measured output saving (592k to 542k) on 82 paired agentic tasks with skill FORCED on; advertised 65% is chat-Q&A scoped" -> JetBrains (cite 1)
- "No detectable quality degradation at lite/full: 8 better / 10 worse / 64 tied; sign test p = 0.82; avg score 0.326 vs 0.311" -> JetBrains (cite 1); Ooo (cite 5); Brussee, "Honest Numbers" (cite 3)
- "Output tokens are the cheap, non-cacheable half; typically 5-10x more input than output; single-shot queries can be ~10% more expensive" -> Ooo (cite 5); Better Stack (cite 4)
- "Cache-hit is the dominant cost lever: DeepSeek miss/hit ~50x; Go request ~86% cached input reads; output not cacheable" -> poetry-platform, res036 (cite 8)
- "Project already runs ponytail level: full (terse output, no extra input injection); redundant with Caveman output persona" -> poetry-platform, AGENTS.md (cite 9); poetry-platform, res036 (cite 8)
- "Reserve Caveman for companion skills or INPUT-compress path; apply same prefix-drift caution as Headroom (measured 202,503 to 218,109 byte drift, 3x, net strongly negative)" -> Brussee, "Caveman - README" (cite 2); poetry-platform, res036 (cite 8)
- "Verdict: do NOT adopt Caveman as a separate plugin for output economy" -> synthesis of JetBrains (cite 1), Ooo (cite 5), Brussee, "Honest Numbers" (cite 3), poetry-platform, res036 (cite 8), poetry-platform, AGENTS.md (cite 9)
