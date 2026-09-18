# Research Conspect: Context Thresholds, Auto-Compaction, and Session Handoff Strategy for Orchestrator Model Choices

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 14
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## 1. Scope and Synthesis Question

This conspect synthesizes archived research on four interlocking problems for an
orchestrator-led agent system: (a) the mechanistic basis of context degradation
("context rot"), (b) auto-compaction trigger thresholds and mechanics across
coding agents, (c) session-handoff strategy as a complement or alternative to
compaction, and (d) orchestrator model-choice implications (reasoning versus
loop-driving capability, and the Chinese-model context-window landscape). The
audience is an advisory audit of how to set context thresholds, when to compact
versus hand off, and which model profiles fit the orchestrator role.

## 2. Mechanistic Basis: Context Rot and Attention Dilution

The core finding is that a large context window is not equivalent to reliable
long-term memory. Liu et al. demonstrate that LLM performance degrades
significantly when relevant information sits in the middle of a long context,
with a pronounced primacy/recency bias; a 1M-token window "does NOT equal 1M
tokens of perfect memory" (Liu et al., "Lost in the Middle"). This is the
mechanistic underpinning of "context rot."

Anthropic defines context rot as performance degradation as context grows
because "attention spreads across more tokens and older/irrelevant content
distracts," and notes the model "is at its least intelligent point when
compacting" because compaction fires precisely when rot is worst (Anthropic,
"Session Management"). Towards Data Science splits rot into intrinsic (attention
dilution, maps to Lost-in-the-Middle) and content rot (stale/contradictory
accumulation), and cites Letta's Recovery-Bench: agents given the full history
of failed attempts performed worse than clean-start agents, because rotten
context actively drags down recovery (Towards Data Science). The governance
thesis: the model has no internal brake and cannot see its own rot; correction
must come from outside the window, via a human or an orchestrator (Towards Data
Science).

## 3. Auto-Compaction Thresholds Across Agents

Thresholds vary enormously by agent. The showdown table reports: Gemini CLI
~50%; Roo ~86-92%; Claude Code ~89% (contextWindow - min(maxOutput, 20k) -
13k); Codex CLI ~90% (hard ceiling, configurable downward only); Pi ~92%;
OpenCode ~96-99%; OpenHands event-based (100 events) (Vaughan). The practitioner
pattern library states the research community identified 85-90% as the optimal
auto-compaction threshold, with 95% (common in implementations) "often too
late" because the summarizer then runs on rotted context and may itself overflow
(AgentNative).

OpenCode's official mechanics: the preflight trigger fires when estimated tokens
exceed context_limit minus max(requested_output, buffer); default config is
auto:true, keep.tokens:15000, buffer:20000; on overflow it compacts and retries
once even if auto:false (OpenCode, "Compaction"; OpenCode, "Configuration").
Codex's open-source analysis confirms a 90% clamp (context_window * 9/10),
hard-capped since v0.100.0, with the most recent ~20,000 user tokens preserved
(Saffron). Justin3go's deep-dive quantifies that in a 15.4k-token debugging
session, tool results were 81% of tokens, concluding "the best context
management isn't about endlessly expanding memory capacity, but learning to
forget with precision" (Justin3go).

## 4. Compaction Mechanics and Failure Modes

Three distinct compaction architectures appear:

- Codex CLI: single-layer handoff summary; preserves all user messages
  verbatim, deletes assistant replies plus tool results; "all-or-nothing" -
  missed detail is gone (Justin3go; Saffron).
- Claude Code: three-tier "precision forgetting" - tool-result trimming (zero
  LLM cost) then cache-friendly tail trimming then a 9-section LLM summary as
  last resort; auto-rereads up to 5 recently edited files post-compact
  (Justin3go).
- OpenCode: prune-first (mark hidden, preserve most recent 40k tokens, protect
  last 2 user turns) then a 5-heading LLM summary; auto-replays the last user
  message (Justin3go; OpenCode, "Compaction").

Failure modes cataloged by the pattern library: (01) summary-induced amnesia
loops (agent re-attempts a ruled-out approach); (02) lost stop signals
(JetBrains measured up to 15% longer trajectories because acceptance criteria
got summarized away - keep acceptance criteria in a verbatim head zone); (03)
summarizing the un-summarizable (system prompts, tool schemas, exact identifiers
must survive byte-for-byte); (04) panic-threshold compaction at 95% runs the
summarizer on rotted context (AgentNative). Relevance AI's production framing
adds two-phase observational memory: raw history compacted into "observations"
at 30% of window, observations refined at 50%, plus real-time tool-output
compaction above 4,000 tokens to prevent single-turn overflow (Relevance AI).

## 5. Session Handoff Strategy

Handoff is the strategic alternative to relying on a bloated window. Anthropic's
decision table: continue same task; /rewind when down wrong path; /compact
<hint> mid-task when bloated; /clear for a genuinely new task (zero rot, you
control carry-forward); subagents for output you will not need again (Anthropic,
"Session Management"; Anthropic, "Best Practices"). The rule of thumb: "when you
start a new task, you should also start a new session" (Anthropic, "Session
Management"). Towards Data Science's decision tree: new unrelated task -> /clear;
next phase of related work, session healthy -> hand off state; limit reached
mid-task, healthy -> /compact; session turned -> snapshot and clear (Towards
Data Science).

Community practice (r/ClaudeAI, attributable handles) converges on externalizing
state to files so clearing is non-destructive: jake_that_dude keeps a
fixed-structure HANDOFF.md updated at ~40% context then /clears; Peerless-Paragon
uses hooks to warn/save handoff.md above 50% and cautions against auto-clearing
mid-task; return_of_valensky keeps state in spec/plan/tasks docs so clearing
between phases is safe; Input-X tunes a pre-auto-compact hook to steer what
carries forward (Reddit). The recurring pattern: externalize state (HANDOFF.md,
git, docs) so compaction or clearing is recoverable. Note: two OSS handoff
plugins (who96/claude-code-context-handoff; adamnfineco/opencode-self-compact)
were listed in the manifest but NOT archived - see Excluded.

## 6. Orchestrator Model Choices

The orchestrator role splits into two capabilities: reasoning about code (best
done by a strong single-shot model) and driving a multi-step agentic loop (needs
convergence discipline). Measured on a DeepSeek Flash-type worker
(deepseek-v4-flash-free via OpenCode zen): "strong reasoner, weak agentic-loop
driver" - it reasons well in one shot but over-explores and forgets to finish
when left on a loose task (15 steps / 182k tokens, never called done); reasoning
tokens are NOT controllable (zen ignores reasoning.enabled=false, measured
increase); only the final answer reaches the orchestrator's context
(yesterdayyousaidtmrw). The measured fix: a tight orchestrator prompt (named
files plus output_schema) cut prompt tokens 182k -> 38k and forced convergence.
Anti-drift is enforced in code, not prompts: read-only presets, forced
convergence signal, output-schema gate, per-step checkpointing, and context
compaction when the transcript nears the window (yesterdayyousaidtmrw).
Implication: delegate bounded reading/grinding down to a cheap model; keep
judgment plus live context at the orchestrator top.

Chinese-model context landscape (verified primary plus indicative vendor data):
DeepSeek-V3 reaches 128K via YaRN, with strong needle-in-a-haystack up to 128K
(Liu et al., "DeepSeek-V3 Technical Report"). Compiled 2026 window sizes: Qwen
3.6/3.7 up to 1M; Kimi K2.5 256K / K2 claimed 2M; GLM 128K; MiniMax M2.5 262K /
M3 1M (aisa.one, via chinese-models-context). Caveat: no source provides
vendor-specific compaction/handoff behavior for Chinese models beyond context
size; claims that "1M-context agents can actually use [context] without
degradation past 200K" are UNVERIFIED promotional statements and are excluded
from factual claims (chinese-models-context). "GPT TerraHigh-type
orchestrators": no source was found for a model literally named TerraHigh;
treated as GPT-family reasoning/orchestrator models (GPT-5.x / Codex) - no
GPT-vendor-specific compaction facts are asserted without a cited source
(chinese-models-context).

## 7. Advisory Audit Conclusions

1. Set the auto-compaction threshold in the 85-90% band, not 95%+. OpenCode's
   near-100% default is the riskiest end; consider a lower, configurable
   threshold for exploratory/long sessions (AgentNative; Vaughan).
2. Treat compaction as lossy and one-shot-risky. Preserve acceptance criteria,
   system prompts, tool schemas, and exact identifiers in a verbatim "head
   zone" that survives summarization (AgentNative; Justin3go).
3. Prefer structured handoff over indefinite session extension. After 3+
   compactions, spawn a fresh session with a HANDOFF.md or spec state rather
   than compounding information loss (Vaughan; Reddit; Towards Data Science).
4. Externalize state to files (HANDOFF.md, git, docs) so /clear and /compact
   are non-destructive and recoverable (Reddit; Towards Data Science).
5. For the orchestrator model, separate reasoning from loop-driving: use a
   strong single-shot reasoner for bounded reads, but enforce convergence via
   code-level guards (output schema, forced done signal, checkpointing), not
   prompts alone (yesterdayyousaidtmrw).
6. Do not assume a 1M window removes the need for handoff/compaction; attention
   dilution (Lost-in-the-Middle) and content rot persist at scale (Liu et al.;
   Anthropic; Towards Data Science).

## Works Cited

AgentNative. "Context Compaction Pattern for Long-Running Agents." AgentNative,
  2026, https://www.agentnative.dev/patterns/context-compaction-pattern-for-long-running-agents.

Anthropic. "Claude Code Best Practices." Anthropic Docs,
  https://code.claude.com/docs/en/best-practices.

Anthropic. "Using Claude Code Session Management and the 1M Context Window."
  Anthropic, https://claude.com/blog/using-claude-code-session-management-and-1m-context.

aisa.one. "Chinese LLM Context-Window Guide." aisa.one,
  https://aisa.one/docs/guides/chinese-llms. (indicative vendor data; not independently verified)

Justin3go. "Context Compaction in Codex CLI, Claude Code, and OpenCode."
  Justin3go, 9 Apr. 2026,
  https://justin3go.com/en/posts/2026/04/09-context-compaction-in-codex-claude-code-and-opencode.

Liu, Aixin, et al. "DeepSeek-V3 Technical Report." arXiv, 2024, arXiv:2412.19437.

Liu, Nelson F., et al. "Lost in the Middle: How Language Models Use Long
  Contexts." Transactions of the Association for Computational Linguistics,
  vol. 12, 2024, pp. 157-73. arXiv:2307.03172.

OpenCode. "Compaction." OpenCode Documentation,
  https://opencode.ai/v2/docs/compaction.

OpenCode. "Configuration." OpenCode Documentation,
  https://opencode.ai/v2/docs/config.

Relevance AI. "Adaptive Context Management for Production AI Agents." Relevance
  AI, https://relevanceai.com/blog/adaptive-context-management-for-production-ai-agents.

Saffron, Sam. "Codex CLI Compression/Compaction: Prompts and Full Analysis."
  GitHub Gist,
  https://gist.github.com/sam-saffron-jarvis/30403c1bc5682bf9f69fa00933aad815.

Towards Data Science. "Governed Context: Managing Context Rot in Claude Code."
  Towards Data Science,
  https://towardsdatascience.com/governed-context-managing-context-rot-in-claude-code/.

Vaughan, Daniel. "Context Compaction Showdown: Thresholds across Coding Agents."
  Codex, 10 Apr. 2026,
  https://codex.danielvaughan.com/2026/04/10/context-compaction-showdown-coding-agents.

yesterdayyousaidtmrw. "DeepSeek Flash-Type Orchestrator Worker Behavior."
  Orchestrator-MCP,
  https://raw.githubusercontent.com/yesterdayyousaidtmrw/orchestrator-mcp/master/docs/deepseek-behavior.md.

## Excluded / Unarchived Sources

### A. Deliberately excluded by researcher (manifest NOT ARCHIVED section)

- https://www.morphllm.com/context-compaction - vendor; overlapping with
  agentnative/JetBrains cites; redundant.
- https://www.osvaldorestrepo.dev/blog/claude-code-context-limits - practitioner;
  "15-minute rule", atomic sessions; redundant with TowardsDataScience/Reddit.
- https://www.morphllm.com/claude-code-reddit - curated Reddit roundup; secondary
  aggregation, lower independence.
- https://codex.danielvaughan.com/2026/04/20/codex-cli-context-window-budget-token-management-large-codebases
  - overlaps showdown/deep-dive; reviewed via snippet only.
- https://www.explainx.ai/blog/enable-1m-token-context-window-codex-cli-gpt-5-6-sol-august-2026
  - GPT-5.6 Sol 1M config; single-model how-to, not generalizable; Inference only.
- "GPT TerraHigh-type orchestrators" - NO source found for a model literally
  named "TerraHigh"; treated as GPT-family reasoning/orchestrator models
  (GPT-5.x / Codex); no vendor-specific facts asserted without a cited source.

### B. Manifest-listed but not present as an archived file (Phase A capture gap; not synthesized)

These URLs appear in the researcher's manifest with ratings but have no
corresponding `.md` file in `sources/`. They were not available for synthesis.
Listed for transparency; none are cited in the body.

- https://code.claude.com/docs/en/model-config (context sizes, not handoff thresholds directly)
- https://codex.danielvaughan.com/2026/04/14/context-compaction-deep-dive-codex-cli-claude-code-opencode
- https://codex.danielvaughan.com/2026/03/31/codex-cli-context-compaction-architecture/
- https://upd.dev/openai/codex/issues/19116 (Codex CLI freeze near threshold; single-reporter anecdotal)
- https://www.reddit.com/r/ClaudeAI/comments/1pprkzw/the_context_rot_problem_nobody_talks_about_why (community anecdotal)
- https://neuraltrust.ai/blog/context-window-optimization (vendor blog)
- https://getunblocked.com/blog/context-rot-claude-code (single-source strong claim, unverified)
- https://github.com/who96/claude-code-context-handoff (OSS plugin, niche)
- https://github.com/adamnfineco/opencode-self-compact (OSS plugin, niche)
- https://deepwiki.com/sst/opencode/2.4-context-management-and-compaction (secondary wiki)

### C. Flagged-but-archived content excluded from factual claims

- Within chinese-models-context.md, the nextfuture.io.vn claim that "1M-context
  agents can actually use [context] without degradation past 200K" is marked
  UNVERIFIED promotional (Inference) in the source and is NOT used as a factual
  basis in this conspect.
