# Graft: Repo-Understanding and Code-Mapping Tooling for Coding Agents

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 6
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## 1. Identity and Metadata

The name "graft" is shared by at least three distinct open-source projects. The primary subject of this conspect is **NanoNets/Graft** (now **trailhq/Graft**), a context layer for coding agents that builds a persistent, markdown-based knowledge graph of a codebase. Created July 3, 2026, written in TypeScript (strict), licensed MIT, it has accumulated over 9,200 GitHub stars and approximately 7,500 weekly npm downloads as of September 2026 (NanoNets/Graft). The npm package is published as `@nanonets/graft`, currently at v0.18.x with 492 commits and 97 open issues (NanoNets/Graft). The repo was originally hosted at `github.com/NanoNets/Graft` and now redirects to `github.com/trailhq/Graft` (NanoNets/Graft).

Two other projects sharing the name are covered in Section 6 for disambiguation: **amaar-mc/graft** (a simpler PageRank-based MCP codebase context engine, 1 star) and **flyingrobots/graft** (a "context governor" for coding agents, 14 stars, Apache-2.0) (amaar-mc/graft; flyingrobots/graft).

## 2. Technical Mechanism

### 2.1 Two-Tier Architecture

Graft's core design is a two-tier architecture (NanoNets/Graft):

| Tier | What it produces | Engine | Cost |
|------|-----------------|--------|------|
| **Structural** | Per-symbol wiring graph, per-file cards, call and reference edges | Deterministic tree-sitter parsing | Free (no model calls, no network) |
| **Concept** (`--deep`) | Plain-language file summaries, synthesized concept nodes, per-symbol summary and crux | User's chosen LLM provider | Token cost under user's own API key |

The structural tier requires no model, no key, and no network. It produces a graph spanning 23 languages: full-fidelity support for TypeScript, JavaScript, Python, Go, Java, Kotlin, PHP, Swift, and R; broad support for Rust, C, C++, C#, Ruby, Scala, Elixir, Solidity, OCaml, Zig, Dart, Clojure, Nix, and Lua. Optional LSP edges are available via rust-analyzer, clangd, gopls, pyright, and typescript-language-server (NanoNets/Graft).

### 2.2 Delivery Mechanism: Hooks over MCP

The delivery mechanism is the critical design choice. As andrew.ooo observes: "The interesting design choice isn't the graph -- plenty of tools build those. It's the delivery mechanism: hooks, not MCP tools" (andrew.ooo). Claude Code is trained to reach for its built-in Grep tool and frequently ignores custom MCP tools. Graft addresses this by installing hooks (statusline, auto-sync, context-on-tap) alongside MCP tools, ensuring context is injected into the agent's workflow even when the agent would not self-serve it (andrew.ooo). The MCP tools offered include `graft_find_code`, `graft_file_api`, `graft_trace_calls`, `graft_find_all`, `graft_repo_map`, and `graft_check_freshness` (NanoNets/Graft).

### 2.3 Graph as Regenerable Cache

A key design decision is that the graph under `graft/` is gitignored -- treated as a local cache analogous to `node_modules`, regenerable from the working tree at any time. Every query refreshes the graph against the working tree in approximately 3 ms for the structural layer. What travels through version control is the wiring configuration (`.claude/`, `AGENTS.md` marker-fenced section, MCP config), not the graph itself (NanoNets/Graft; Wavect).

### 2.4 Provider-Neutral

Graft is provider-neutral: it supports OpenAI, Anthropic, OpenRouter, Fireworks, Groq, and local models for the concept tier. No vector store, embeddings, or database is used (NanoNets/Graft).

## 3. Integration Surface

### 3.1 Agent Wiring

`graft init` produces integration wiring for Claude Code (deepest integration: hooks, statusline, skill file), Cursor, Codex, GitHub Copilot, Gemini, Kiro, Windsurf, Grok (xAI), and AdaL (NanoNets/Graft). The Claude Code integration is the most mature, with hooks that auto-sync the graph and inject context (andrew.ooo).

### 3.2 OpenCode / AGENTS.md Wiring

Graft supports `AGENTS.md` as an integration surface: `graft init` writes a marker-fenced section into `AGENTS.md` that provides the agent with instructions on how to use Graft's tools (NanoNets/Graft; Wavect). This is the same `AGENTS.md` file used by OpenCode-based agent systems. The wiring travels through git even though the graph itself does not (Wavect).

### 3.3 MCP Server

Graft runs as an MCP (Model Context Protocol) server, exposing its six tools to any MCP-compatible client. It can also be wired as a stdio server or daemon (NanoNets/Graft).

## 4. User Praise and Complaints

### 4.1 Praise

Wavect's independent review calls Graft "a good answer to a badly framed question" -- coding agents do throw away expensive understanding after every task, and writing that understanding to disk with a cheap structural refresh loop is a sound fix (Wavect). Joey Wang frames Graft as producing "an architectural briefing" for the agent, best suited to answering "How does this subsystem fit together?" (Joey Wang). The hooks-over-MCP decision is praised as the key insight that makes Graft actually work in practice (andrew.ooo).

### 4.2 Complaints and Controversies

The **benchmark controversy** is the most prominent complaint. Commenter "seizethecheese" on the Hacker News Show HN thread noted that the SWE-bench sample grew from 9 to 20 to 36 to 50 across README updates, in increments of 11, 16, and 14, with one update scoring 16/16 and another 2/14 -- suggesting possible cherry-picking. The maintainer replied that the increments coincided with Claude API limit exhaustion, but the reviewer noted that "HN commenters shouldn't have to be Sherlock Holmes" and that seed IDs, instance IDs, and per-instance results should have been published from the start (andrew.ooo). The README itself was criticized for being visibly LLM-written; the maintainer conceded that "the README gets updated by coding agents as they iterate" (andrew.ooo).

Other complaints include: large monorepos can OOM at around 2,900+ files; grammar-level bugs exist (PHP heredocs crash tree-sitter, `.vue` files were unindexed until recently); `init` writes outside the repo to `~/.codex/` (machine-wide); telemetry is on by default (andrew.ooo). Pre-1.0 maturity means no tagged releases and a need for pinned versions with tested upgrade paths (Wavect; andrew.ooo).

## 5. Benchmark Results (All Vendor-Reported)

All published benchmarks are vendor-run. No independent replication exists (Wavect).

### 5.1 Controlled Sweep (162 Runs)

| Metric | Cold Claude Code | With Graft | Change |
|--------|-----------------|------------|--------|
| Cost | $0.0429 | $0.0292 | -32% |
| Tokens | 8,070 | 4,650 | -42% |
| Tool calls | 4.2 | 2.3 | -46% |
| Latency | 39.8 s | 15.8 s | -60% |
| Correctness | 93% | 93% | Equal |

The "pull" variant (tools available but nothing injected) achieved 98% correctness, +5 over cold. This is the actionable finding: if correctness matters more than speed, pull is the configuration to test first (Wavect; NanoNets/Graft).

### 5.2 SWE-bench Verified (50 Instances)

| Metric | Cold Claude Code | With Graft | Change |
|--------|-----------------|------------|--------|
| Correctness | 27/50 (54%) | 33/50 (66%) | +12 pts |
| Tokens | 142.0 M | 109.4 M | -23% |
| Cost | $52.34 | $42.43 | -19% |
| Wall-clock | 13,094 s | 8,922 s | -32% |

Wavect notes: full Verified has 500 instances; Graft tested 50 (a tenth); the write-up does not identify which 50 instances; the six-instance margin is a single run with no variance reported. The grading itself is trustworthy (official swebench harness, not a model judge), but "credible mechanism, not procurement evidence" (Wavect; andrew.ooo). Joey Wang summarizes: "evidence worth testing, not a guarantee" (Joey Wang).

### 5.3 Retrieval Quality

When compared to Graphify, Graft achieved MRR 0.73 vs 0.38 and recall@10 54% vs 20%, because Graft ranks against code bodies while name-and-path indexes rank against identifiers (andrew.ooo).

## 6. Disambiguation: Other "Graft" Projects

The researcher archived two alternative projects sharing the name. They are categorically different from NanoNets/Graft and must not be confused with it.

### 6.1 amaar-mc/graft

A simpler, PageRank-based MCP codebase context engine. npm package: `graftmap`. 1 star, 91 commits, 10 open issues. It produces a ranked dependency graph (files as nodes, imports as edges) and serves it via MCP, with tools like `graft_map`, `graft_context`, `graft_search`, `graft_impact`, and `graft_summary`. It lacks the markdown knowledge graph, the `--deep` concept tier, agent-specific wiring (hooks, statusline), extensive language support (only TypeScript, JavaScript, Python, with Go and Rust planned), and the SWE-bench benchmarks of the primary project (amaar-mc/graft).

### 6.2 flyingrobots/graft

A "context governor" for coding agents that enforces read policy, returning the minimum structurally correct view of a codebase. 14 stars, Apache-2.0, 1,442 commits, 134 open issues. It sits between agent and filesystem, returning full content for small files, AST-derived outlines for large files, and hard refusal with reason code for binaries/secrets/lockfiles. It features WARP (Structural Worldline Memory, git-warp-backed structural history) and session governance via GovernorTracker. It does not build a markdown knowledge graph for agent orientation and focuses on context budget management rather than codebase mapping (flyingrobots/graft).

A third candidate, **AEndrix03/graft** (an agentic memory daemon in C, alpha stage), was not archived by the researcher due to low relevance and reliability.

## 7. Empirical Results Summary

All empirical data comes from vendor-reported benchmarks or the npm/GitHub metadata. The Wavect review provides a structured two-week pilot plan for independent evaluation (10 steps covering frozen task sets, three experimental arms, freshness attacks, and scale gates), but no independent replication results were found in the archived sources (Wavect). The andrew.ooo review is authored by an AI-agent-operated publication and does not present original benchmarks (andrew.ooo).

## 8. Limitations and Failure Modes

Based on the archived sources, the following limitations are documented:

- **Pre-1.0 maturity**: v0.18.x with 97 open issues, no tagged releases, pinned version and tested upgrade path recommended (NanoNets/Graft; Wavect; andrew.ooo).
- **OOM on large monorepos**: approximately 2,900+ files reported as a trigger (andrew.ooo).
- **Grammar-level bugs**: PHP heredocs crash tree-sitter; `.vue` files were unindexed until recently (andrew.ooo).
- **Machine-wide side effects**: `init` writes outside the repo to `~/.codex/` (andrew.ooo).
- **Plausible but wrong summaries**: The concept tier produces LLM-generated summaries that are not compiler facts; they risk reinforcing wrong conclusions (Joey Wang; Wavect).
- **Staleness is philosophical**: Fresh sessions catch mistakes because they carry no assumptions; a persistent graph could reinforce wrong conclusions if not refreshed (andrew.ooo).
- **Non-conforming gateways**: Non-standard MCP gateways may fail silently, since enrichment reads only `toolCalls` (andrew.ooo).
- **Unreviewed prose**: Machine-written summaries in the concept tier are unreviewed prose that a human must audit (Wavect).
- **No independent benchmark replication**: All published gains are vendor-run; no third-party has replicated them (Wavect).

## 9. Privacy Posture

- **Structural build**: local, deterministic, no source-code upload (Wavect).
- **Concept tier (`--deep`)**: sends file and symbol content to the user's chosen LLM provider; DPA/region/retention review needed for EU deployments (Wavect).
- **Telemetry**: anonymous usage stats on by default; disable with `graft telemetry disable`, `DO_NOT_TRACK=1`, or untick during init (NanoNets/Graft; andrew.ooo).
- **npm version check**: the CLI can make a daily npm version check and anonymized opt-out usage ping (Wavect).

## 10. Competitive Positioning

Joey Wang's three-way comparison positions Graft, Graphify, and codebase-memory-mcp as complementary tools with different strengths (Joey Wang):

| Tool | Metaphor | Best question | Risk |
|------|----------|---------------|------|
| Graft | Architectural briefing | "How does this subsystem fit together?" | Plausible but wrong summaries |
| Graphify | General knowledge graph | "How are these code and project artifacts connected?" | Broad graph with mixed evidence types |
| codebase-memory-mcp | Structural code database | "What calls or depends on this symbol?" | Operational complexity and uneven language depth |

Joey Wang's recommendation order: start with codebase-memory-mcp for structural queries, add Graft for agent-facing explanations, bring in Graphify when schemas, ADRs, and config are part of the debugging path (Joey Wang).

Wavect notes the prior art: "Aider shipped a tree-sitter repository map ranked by PageRank in October 2023. The ranked repo map is not new. The refresh loop and the multi-agent wiring are the contribution" (Wavect).

---

## Works Cited

NanoNets/Graft. "Graft: Context Layer for Coding Agents." GitHub, trailhq/Graft, github.com/trailhq/Graft. Accessed 25 Sep. 2026. https://github.com/trailhq/Graft.

Wavect. "Graft Review 2026: Agent Repo Map." Wavect GmbH, 2 Sep. 2026, wavect.io/blog/graft-review-agent-repo-map/. https://wavect.io/blog/graft-review-agent-repo-map/.

andrew.ooo. "Graft Review: A Code Graph That Cuts Agent Tokens 42%." andrew.ooo, 25 Aug. 2026, andrew.ooo/posts/graft-nanonets-code-graph-coding-agents-review/. https://andrew.ooo/posts/graft-nanonets-code-graph-coding-agents-review/.

Wang, Joey. "Codebase Memory for Coding Agents: Graft, Graphify, and codebase-memory-mcp." joeywang.github.io, 14 Aug. 2026, joeywang.github.io/posts/codebase-memory-for-coding-agents-graft-graphify-codebase-memory-mcp/. https://joeywang.github.io/posts/codebase-memory-for-coding-agents-graft-graphify-codebase-memory-mcp/.

amaar-mc/graft. "Local-First Codebase Context Engine for AI Coding Tools." GitHub, github.com/amaar-mc/graft. Accessed 25 Sep. 2026. https://github.com/amaar-mc/graft.

flyingrobots/graft. "A Context Governor for Coding Agents." GitHub, github.com/flyingrobots/graft. Accessed 25 Sep. 2026. https://github.com/flyingrobots/graft.

---

## Unarchived / Excluded Sources

| URL | Reason |
|-----|--------|
| https://www.npmjs.com/package/@nanonets/graft | Not archived by researcher |
| https://graft.nanonets.ai | Not archived by researcher; landing page webfetch returned only partial content; key info captured from README |
| https://blog.adafruit.com/2026/08/19/graft-gives-your-coding-agent-a-map-of-your-codebase/ | Not archived by researcher |
| https://blog.bluelupin.com/2026/09/09/stop-making-the-agent-rediscover-the-repo/ | Not archived by researcher |
| https://news.ycombinator.com/item?id=49299985 | Not archived by researcher; HN thread content fetched via websearch snippets only |
| https://www.reddit.com/r/ClaudeAI/comments/1v8zmev/ | Not archived by researcher |
| https://mcpmarket.com/server/graft-2 | Not archived by researcher |
| https://www.ssdnodes.com/learn/graft-codebase-graph-for-agents | Not archived by researcher |
| https://github.com/AEndrix03/graft | Not archived by researcher; low relevance and reliability |
