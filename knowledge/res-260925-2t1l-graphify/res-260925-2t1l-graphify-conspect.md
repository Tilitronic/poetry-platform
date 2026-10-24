# Conspect: Graphify - Multi-Modal Knowledge Graph Builder for AI Agents

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 12
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## License Discrepancy (Unresolved)

**WARNING: License conflict across sources.** The repository's `LICENSE` file on the default branch (`v8`) contains the full text of the Apache License 2.0 (GitHub API metadata confirms `spdx_id: Apache-2.0`; the license-file.txt is verbatim Apache 2.0) [1][2]. The project's official website (graphify.net) states the project is "released under the permissive MIT license" [6]. The InfoQ editorial article describes Graphify as "released under the dual MIT and Apache-2.0 licenses" [7]. No source resolves which is authoritative. This matters for adoption: Apache-2.0 and MIT have different patent and attribution clauses; enterprise legal teams reviewing compliance need clarity before deploying in commercial pipelines. The conflict is flagged by the website's own archived page as a known discrepancy [6].

## Project Identity

| Field | Value |
|---|---|
| Canonical repository | `Graphify-Labs/graphify` |
| Organization | Graphify-Labs |
| Primary language | Python |
| Default branch | `v8` |
| Created | 2026-04-03 |
| Last push (at capture) | 2026-09-25 |
| Stars | 121,438 |
| Forks | 11,703 |
| Open issues | 1,472 |
| Contributors | 77 (per Augment article) |
| Maintainer | Safi Shamsi |
| Release cadence | Roughly one release per day [8] |
| PyPI package name | `graphifyy` (note: double-y spelling) [8] |

Source: GitHub API JSON [1]; contributor count and release cadence from Augment article [8]; maintainer named in graphify.net source [6].

## Mechanism: Three-Pass Pipeline

Graphify processes files in three sequential passes before constructing a unified graph [3][4].

### Pass 1 -- Code Structure (Local, No LLM, Zero Cost)

Tree-sitter parses code files and extracts classes, functions, imports, call graphs, and inline comments. 25 languages are supported (28 tree-sitter grammars per the Augment article, suggesting the count grew between documentation snapshots) [3][8]. SQL files receive special treatment: tables, views, foreign keys, and JOIN relationships are extracted deterministically. This pass runs entirely locally with no LLM involvement and incurs zero API cost [3]. Code files are not sent to the LLM semantic extractor; if the corpus contains only code, Pass 3 is skipped entirely [3].

### Pass 2 -- Video and Audio (Local, No LLM, Cached)

Audio and video files are transcribed with faster-whisper, a local whisper implementation. The transcription prompt is seeded with the top god nodes (most-connected concepts) from the code graph built in Pass 1. Transcripts are cached by content hash; re-runs skip unchanged files [3].

### Pass 3 -- Docs, Papers, Images (LLM Subagents, Costs Tokens)

Claude runs in parallel over markdown, PDFs, images, and transcripts. Each subagent reads a batch of files and outputs a JSON fragment containing nodes, edges, and group relationships. Fragments are merged into a single graph. Optional converters handle Office files (`.docx`, `.xlsx`) and Google Workspace shortcuts (opt-in via `--google-workspace`) [3].

### Graph Construction

After all three passes, the graph is built using NetworkX [3][6]:

- **Merge**: All JSON fragments are merged into a single graph.
- **Community detection**: Leiden algorithm groups nodes by edge density. No separate embedding step or vector database is used; the semantic similarity edges extracted by Claude influence community shape directly [3].
- **God nodes**: Identified by betweenness centrality -- the most-connected concepts that anchor the graph [3].
- **Confidence tagging**: Every relationship carries one of three labels:
  - `EXTRACTED` -- found directly in source (e.g., function call, import); confidence 1.0.
  - `INFERRED` -- reasonable inference from Claude, with a discrete confidence score: 0.95 (near-certain), 0.85 (strong evidence), 0.75 (reasonable), 0.65 (weak), 0.55 (speculative).
  - `AMBIGUOUS` -- flagged for manual review [3].

### Emitted Artifacts

- `graph.html` -- interactive visualization
- `graph.json` -- NetworkX node-link format (the primary machine-readable output)
- `GRAPH_REPORT.md` -- human-readable summary
- Optional exports: Obsidian vault, wiki format, SVG, GraphML, Neo4j [3]

## Integration

### MCP Server

Graphify ships as an MCP (Model Context Protocol) server with two transport modes [3][8]:

- **stdio** -- local process, used by default.
- **Streamable HTTP** -- network transport added in v0.8.35, enabling teams to share a single graph server [8].

### CLI Commands

- `graphify install --platform <name>` -- writes platform-specific configuration
- `graphify query "what connects auth to the database?"` -- natural-language graph queries from the terminal
- `graphify path "UserService" "DatabasePool"` -- path queries between nodes
- `graphify prs --triage` -- ranks PR review queue by graph impact
- `graphify prs --conflicts` -- flags PRs touching overlapping graph communities [8]

### Git Hooks and Team Workflow

A post-commit hook rebuilds the AST graph after each commit. A custom git merge driver union-merges `graph.json` so parallel commits never produce conflict markers. The `graphify-out/` directory is committed to the repo [8].

### OpenCode Integration

`graphify install --platform opencode` writes two artifacts [8]:
1. An `AGENTS.md` (or appends to existing) with graphify skill instructions.
2. A `.opencode/plugins/graphify.js` plugin that hooks `tool.execute.before` to hint the agent to consult the built graph before making tool calls.

The broader install supports 20+ platforms including Claude Code, Cursor, Codex, Gemini CLI, Kilo Code, Aider, Amp, Kiro, Devin CLI, Copilot CLI, and CodeBuddy [8].

## Adoption Failure (Community Findings)

The most decision-relevant finding across the archived sources is that **agents do not reliably use the built graph**. Multiple independent community reports converge on this:

1. **0% adoption in a controlled benchmark.** A user on r/ClaudeCode benchmarked both Graphify CLI (suggestion hooks) and Graphify MCP (registered MCP server) against the Medusa e-commerce repo (1,571 TypeScript files, 3,863-node graph) across 5 code-audit tasks using Claude Sonnet 4.5. Result: Claude "completely ignored the 3,863-node graph and raw-dogged the codebase using grep and Read" -- a 0% graph adoption rate. By contrast, a forced-retrieval tool (GrapeRoot MCP) hit 100% adoption [10].

2. **Agents never querying the graph.** A separate r/ClaudeCode user reported installing graphify, adding the skill, and installing instructions to CLAUDE.md with a hook to hint Claude Code to consult the graph. "I have never seen the agents actually query the built graph even once. Instead, they always can get what they want with using my ripgrep and piping output to head or tail" [9].

3. **"Hairball" graphs.** A user with a 57K-star repo reported the first run produced a 6,825-node graph where 44% of nodes were not code (markdown, JSON config, test files), clusters had no names (just numbered blobs from Leiden without API-key labeling), and 66% of nodes were dead-end leaves, rendering as "one gray ball of yarn." The fix was using `--code-only` for the tree-sitter pass and a separate docs pass with labeled clusters [11].

4. **Silent staleness.** Community reports note that graphs go silently stale after code edits. Without the post-commit hook running, the graph falls out of sync with the codebase [9].

5. **Project's own caveat.** The official documentation acknowledges: a corpus that already fits in one context window may not need a graph at all [3]. Token reduction scales with corpus size -- at 6 files the reduction is approximately 1x; the graph value is structural clarity, not compression [3].

These are independent community findings, not vendor-reported metrics.

## Benchmarks (All First-Party)

All benchmark figures below are **first-party / self-reported** by Graphify Labs. No independent replication was found in the archived sources. The Medium/TowardsAI analysis explicitly notes: "No external benchmark comparing Graphify's graph queries against a raw-file or RAG baseline on a common test set has been independently reproduced" [12].

### LOCOMO (n=300) -- Conversational QA

| Metric | graphify | Best competitor | Source context |
|---|---|---|---|
| recall@10 | 0.497 | BM25 0.362, mem0 0.048 | Best recall of any system tested |
| QA accuracy | 45.3% | supermemory 49.7% (11x ingest cost) | Within 4.4 points of supermemory |
| Ingest cost | ~$1.40 | supermemory $15.67 | ~11x cheaper than supermemory [4][5] |

### LongMemEval-S (n=50) -- Long-Horizon Memory

| Metric | graphify | Dense RAG | Other |
|---|---|---|---|
| QA accuracy | 76% | 76% (tie) | hybrid RRF 74%, mem0 70% |
| recall@10 | 0.844 | 0.848 | Hybrid RRF 0.822, mem0 0.344 [4] |

### ERPNext Code Intelligence (n=6 graded questions)

Key-fact coverage lifts from 70.8% (grep/read baseline) to 82.0% with one graphify tool, averaging ~140K tokens per query session [4][12].

### Token Reduction (First-Party, Small Corpus)

| Corpus | Files | Reduction |
|---|---|---|
| Karpathy repos + papers + images | 52 | 71.5x |
| graphify source + Transformer paper | 4 | 5.4x |
| httpx (synthetic Python) | 6 | ~1x [3] |

### Harness Details

- Single model: Kimi K2.6 via Moonshot (all LLM roles) [4].
- Blind-judge validation: judge blind-validated against a second independent judge at 90.6% agreement, Cohen's kappa 0.81 (substantial agreement) [4].
- Temporal sweep: 689 weekly ERPNext AST checkpoints from 2011-2026, built deterministically with no LLM [4].

### Maintainer Caveat on Benchmarks

The maintainer acknowledged in GitHub Discussion #1677 that supermemory beats graphify on raw LOCOMO QA (49.7% vs 45.3%), and that the recall comparison is "not fully apples-to-apples" because supermemory's self-host forces its own embedder. An experimental multi-hop consolidation pass (prototype, not production) edged supermemory at 1/20th ingest cost [5].

## Limitations

Based on the archived sources:

1. **LLM API key requirement for non-code inputs.** Pass 3 (docs, PDFs, images) requires a configured LLM API key. Only code parsing and audio transcription are fully local [3][6].
2. **Adoption risk.** Agents do not reliably use the built graph even when hooks and AGENTS.md nudges are in place. This is the single most significant practical barrier [9][10].
3. **Overkill on small repos.** A corpus that fits in one context window may not benefit from a graph. Token reduction at 6 files is approximately 1x [3].
4. **Graph bloat without `--code-only`.** Without the code-only flag, 44%+ of nodes may be non-code, and 66% may be dead-end leaves, producing an unreadable "hairball" [11].
5. **Staleness / update lag.** Graphs go silently stale after edits unless the post-commit hook is active [9].
6. **Setup weight.** Multiple sources cite installation friction as an adoption barrier [7][11].
7. **Per-invocation LLM cost.** Every non-code extraction call costs tokens; the graph build is free but queries and re-extractions are not [4][12].
8. **Open-issue count.** 1,472 open issues on a project created April 2026 (approximately 5 months old at capture) suggests a large backlog relative to project age [1].

## Privacy

The two processing paths have different privacy profiles [3][6]:

**Fully local (no data leaves the machine):**
- Code parsing (tree-sitter AST)
- Audio/video transcription (faster-whisper)

**Requires outbound network call to a configured LLM API:**
- Docs, PDFs, images, transcripts (Pass 3 semantic extraction)

**Default provider priority order** (from graphify.net): the documentation states a configured AI model API key is used for Pass 3, with Claude as the primary provider (Pass 3 subagents are described as "Claude subagents" in the how-it-works docs) [3]. The benchmarks run on Kimi K2.6 via Moonshot, but that is the benchmark harness configuration, not the default [4].

**Fully local escape hatches:**
- `--code-only` flag: skips Pass 3 entirely; no API key needed for code-only corpora [3][8].
- Ollama backend: supported as an alternative provider, enabling fully local operation for Pass 3 [6].

**No-telemetry claim:** graphify.net states "no telemetry, no usage tracking" [6]. This claim is from the vendor website; no independent audit was found in the archived sources.

## Competitive Positioning

### Where Graphify Competes

- **Cross-modal span.** The three-pass pipeline handles code, docs, PDFs, images, audio, and video in a single tool -- no other indexed source describes a competitor matching this breadth [3][8].
- **Leiden clustering without embeddings.** Community detection uses graph structure directly, avoiding the embedding step and vector database overhead [3].
- **God nodes.** Betweenness centrality identifies the most-connected concepts, providing a natural entry point for agents navigating the graph [3].
- **PR impact triage.** `graphify prs --triage` and `--conflicts` rank review queues by graph community overlap -- a feature not described for competing tools [8].
- **Cost efficiency.** Zero LLM cost for graph construction; 11x cheaper ingest than supermemory on LOCOMO; higher accuracy per dollar than supermemory on LOCOMO QA [4][5].

### Where Graphify Loses

- **Setup weight.** Multiple sources cite installation friction; the tool adds a plugin, hooks, and AGENTS.md modifications [9][11].
- **Per-invocation cost.** Every non-code query/session costs LLM tokens, unlike fully local grep/read [12].
- **Agent adoption.** The most critical weakness: agents ignore the graph even when hooks nudge them [9][10].
- **Small-repo overhead.** For corpora fitting in a context window, the graph adds complexity without compression [3].
- **Indistinguishable from RAG on retrieval.** On LongMemEval-S, graphify ties dense RAG at 76% accuracy and slightly loses on recall (0.844 vs 0.848) [4][12].

### Sources' Verdict

The Medium/TowardsAI analysis concludes: "Graphify does not out-retrieve a well-tuned vector RAG pipeline. Instead, it matches vector RAG on accuracy while costing a fraction of alternative memory systems to build" [12]. The Augment article positions it as complementary to code navigation rather than a replacement, noting it is "an adjacent tool" for teams already invested in the graph-based context paradigm [8]. The InfoQ article describes it as having "exceptionally promising" conceptual architecture but acknowledges "early-tool adoption friction in daily workflows" [7].

## Works Cited

[1] "Graphify-Labs/graphify." GitHub API, api.github.com/repos/Graphify-Labs/graphify. JSON metadata retrieved 25 Sept. 2026.

[2] "Apache License, Version 2.0." LICENSE file, Graphify-Labs/graphify, v8 branch, raw.githubusercontent.com/Graphify-Labs/graphify/v8/LICENSE.

[3] "How graphify works." Documentation, Graphify-Labs/graphify, v8 branch, raw.githubusercontent.com/Graphify-Labs/graphify/v8/docs/how-it-works.md.

[4] "graphify Benchmarks." BENCHMARKS.md, Graphify-Labs/graphify, v8 branch, raw.githubusercontent.com/Graphify-Labs/graphify/v8/BENCHMARKS.md.

[5] "Benchmarks: graphify as long-term memory and code intelligence." GitHub Discussion #1677, Graphify-Labs/graphify, github.com/Graphify-Labs/graphify/discussions/1677. Author: Safi Shamsi (Graphify-Labs).

[6] "Graphify - Multi-Modal Knowledge Graph Builder." graphify.net, graphify.net/. Archived 25 Sept. 2026.

[7] Pop, Olimpiu. "Graphify: Unifying Codebase Context to Streamline Agentic Software Engineering." InfoQ, 25 Sept. 2026, www.infoq.com/news/2026/09/graphify-codebase-exploration/.

[8] Shah, Molisha. "Graphify hits 63.2K stars." Augment Code, 2026, www.augmentcode.com/learn/graphify-63k-stars-knowledge-graphs.

[9] u/greenhilltony. "Are tools like graphify actually placebos/hype?" Reddit r/ClaudeCode, 2026, reddit.com/r/ClaudeCode/comments/1tlbog1/.

[10] u/intellinker. "Graphify has 58K Stars, a YC Backing, and a 0% Adoption Rate with Claude." Reddit r/ClaudeCode, 2026, reddit.com/r/ClaudeCode/comments/1tv0eql/.

[11] u/MaterialAppearance21. "My experience with Graphify." Reddit r/ClaudeCode, 2026, reddit.com/r/ClaudeCode/comments/1tscls8/.

[12] Estari, Udaykiran. "Graphify OKF or Both: Beyond RAG for Codebases." Medium / Towards AI, 2026, pub.towardsai.net/graphify-okf-or-both-beyond-rag-for-codebases-1aa157420f01.

## Unarchived / Excluded Sources

| Source | Reason for exclusion |
|---|---|
| Reddit r/ClaudeAI "Has anyone tried Graphify and Obsidian" | Tangential to core research questions; overlaps with placebos thread |
| Reddit r/coolgithubprojects "I was bleeding tokens" | Secondary complaint about re-extraction cost; captured in Augment article [8] |
| Hacker News item 47668188 | Minimal discussion (2 points, 1 comment); low signal |
| Hacker News item 49301201 (graft comparison) | Competitor benchmark claims, not independent replication of graphify benchmarks |
| GitHub Discussion #1328 "Are there reliable benchmarks" | Partially captured in github-discussion-benchmarks.md (same thread as #1677) |
| PyPI graphifyy package JSON | Attempted but fetch returned truncated output; key data captured from Augment article [8] |
| README.md (v8 branch) | Extremely long; key content captured across other sources |

## Gaps

What the archived sources do **not** cover:

- **Independent benchmark replication.** No third-party has reproduced the LOCOMO or LongMemEval-S numbers on a common test set.
- **Actual agent-benchmark data on graphify's own benchmarks.** The code-intelligence benchmark (ERPKey key-fact coverage) uses a fixed agent with graphify as one tool; no source reports agent behavior when the graph is present but ignored.
- **Graph staleness measurement.** Community reports mention staleness but no source quantifies how quickly graphs degrade after N edits without re-running.
- **Ollama backend specifics.** Mentioned as an escape hatch on graphify.net but no source describes supported models, performance tradeoffs, or configuration steps.
- **License resolution.** No source has confirmed which license is authoritative (Apache-2.0, MIT, or dual).
- **Maintenance burden at scale.** 1,472 open issues on a 5-month-old project; no source discusses maintainer capacity, roadmap, or triage process.
- **Comparison with OKF (Open Knowledge Format).** The Medium article mentions Google's OKF as related but provides no head-to-head data.
- **Enterprise deployment experiences.** No source describes a production deployment at scale; all usage reports are individual or small-team.
