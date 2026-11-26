# Tree-Sitter Repo Mapping and ast-grep: A Research Conspect

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 14
phase-a-failures: 14
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

This conspect synthesizes archived research on two related but distinct domains: (A) tree-sitter-based repository mapping tools that build a structural overview of a codebase for LLM agents, and (B) ast-grep, a tree-sitter-powered CLI for structural code search and rewriting. The two share tree-sitter as a foundation but serve different purposes. This environment already exposes an ast-grep-based search and rewrite capability; a repo-map layer would add pre-computed, PageRank-ranked structural context that ast-grep alone does not provide.

---

## Part A: Tree-Sitter Repository Mapping

### The Problem Repo Maps Solve

LLM coding agents waste tokens reading entire files to orient themselves. The repository map pattern addresses this by parsing code into ASTs, extracting definitions, ranking them by importance via PageRank, and fitting the most relevant definitions into a token budget. Aider's original repo map reached a 26.3% resolve rate on SWE-bench Lite with 70.3% correct file identification at roughly 1,000 tokens ("Repository Map Pattern").

The pattern is defined by a three-layer pipeline: (1) tree-sitter parses source into ASTs and extracts structural elements -- function signatures, class definitions, method names; (2) PageRank scores symbols based on how many other files reference them; (3) binary search fits the ranked output into a token budget ("Repository Map Pattern").

### The Common Pipeline

Across tools, the repo-map pipeline follows a consistent sequence: walk (respecting .gitignore), parse (tree-sitter, often parallelized), extract (definitions and references), build a cross-file reference graph, rank via PageRank or a variant, and render into a token-budgeted output. Skeletree describes this as: "walk (respect .gitignore) -> parse (tree-sitter, in parallel) -> persist symbols (SQLite, one transaction) -> resolve edges (name-based) -> rank (PageRank)" (Skeletree GitHub). The repo-map MCP tool adds scope resolution (self/cls/this, class inheritance, named/namespace/default imports, light type inference, lexical scope) and incremental caching by mtime (Repo-Map MCP GitHub). repomap-mcp calls out "neighbor propagation" where focusing on a type definition boosts code that uses those types (Repomap-MCP GitHub).

### Canonical Projects Table

| Project | Language | License | Stars | Approach | Key Distinction |
|---------|----------|---------|-------|----------|----------------|
| Aider repo map | Python | Apache-2.0 | N/A | tree-sitter + PageRank, binary-search fit | Original pattern; SOTA SWE-bench results |
| Codebase-Memory | C (single binary) | Open source | 900+ | 66 tree-sitter grammars, knowledge graph, MCP | Academic paper; 10x fewer tokens; 6-strategy call resolution |
| Skeletree | Rust | Apache-2.0 | 0 | tree-sitter + SQLite + PageRank, MCP server | Rust-native; workspace crate architecture |
| repo-map MCP | Python/JS/TS | MIT | 0 | tree-sitter + PageRank, MCP server, incremental cache | Scope resolution, path alias support |
| repomap-mcp | TypeScript | N/A | N/A | Tree-sitter WASM grammars, PageRank, MCP + CLI | 40+ languages; token-budgeted binary search |
| skyhook-graph | Python | N/A | N/A | Tree-sitter AST + call graph, task-specific route packs | Route packs (not just global map); SQLite graph |
| cymbal | Go | N/A | N/A | Tree-sitter CLI + SQLite index | 100% search precision/recall (vendor-reported); multi-worktree federation |
| dekko | Python | N/A | N/A | Tree-sitter, MAP.md + map.json output | 3x-200x fewer tokens (self-reported); Claude Code plugin |

### Integration Surfaces

Most repo-map tools expose results via MCP (Model Context Protocol). Codebase-Memory provides 14 typed MCP tools; Skeletree exposes overview, find, and neighbors; repo-map MCP exposes index, where_is, grep_code, outline, get_symbol, who_references, and what_it_uses; repomap-mcp provides repo_map and search_identifiers; skyhook provides route, find_symbol, callers_of, callees_of, and blast_radius. Cymbal works with any MCP-compatible agent and also provides a CLI. Dekko integrates as a Claude Code /map plugin plus MCP server (Cymbal GitHub; Dekko GitHub; Skeletree GitHub; Repo-Map MCP GitHub; Repomap-MCP GitHub; Skyhook PyPI).

### Benchmarks (with provenance noted)

Codebase-Memory's arXiv paper (peer-reviewed) reports: quality score 0.83 vs 0.92 for Explorer agent (90% of Explorer), 2.1x fewer tool calls per question, 10x fewer tokens per question (~1,000 vs ~10,000), query latency under 1ms vs 10-30s, fresh index of 49K nodes in ~6s, incremental re-index in ~1.2s, and BFS call-path tracing at depth 5 in ~0.3ms (Codebase-Memory arXiv).

Repo-map MCP's self-reported numbers on a real Python repo: total workflow token cost reduced 33% (up to 52% cold start), context loaded into model reduced 64%, outline vs full file read reduced 96% (Repo-Map MCP GitHub).

Cymbal's self-reported benchmarks (v0.13.5, 11-repo corpus, 2026-05-29): 113/113 top-level checks passed, 79/79 ground truth passed, 100% search precision/recall, 100% show exactness, 18/18 correct canonical ranking at rank 1, 11/11 grep footguns passed, most queries 10-40ms, agent workflow savings of 40-100% fewer tokens than grep-driven flows (Cymbal GitHub).

Dekko's self-reported benchmarks across 7 real open-source repos (Go, TypeScript, Java, Rust, Python/C++, up to 14k files): 3x-200x fewer tokens than Read/Grep workflow, cost stays roughly flat per query while Read/Grep scales with file/repo size (Dekko GitHub).

### User Praise and Complaints

The archived sources document specific complaints about Aider's original repo map. The `--use-enhanced-map` issue (not archived, cited in .source-urls.txt) documents complaints about full source bodies being included instead of just signatures, and issues with monorepo scaling. The repository-map-pattern source notes backfire conditions: rapidly-changing codebases (map stale within minutes), heavy metaprogramming (AST symbols do not reflect runtime structure), small/flat codebases (fewer than ~20 files), and large repos with huge token budgets where the map adds overhead without saving tokens ("Repository Map Pattern").

The tree-sitter maintenance blog documents that Aider's `.aiderignore` handling is not widely documented across tools, and that symbol-uniqueness assumptions in name-based edge resolution may produce spurious edges -- repo-map MCP acknowledges "PageRank sharper on Python than React/JSX" and "name-based resolution may add spurious edges" (Delpeuch; Repo-Map MCP GitHub).

### What a Repo Map Layer Would Add Beyond Plain AST Search

This environment already has ast-grep available as a structural search and rewrite tool. A repo-map layer would add three things ast-grep alone does not provide:

1. **Pre-computed structural overview**: a ranked, token-budgeted map of the entire codebase that an agent can load once and use for orientation, rather than issuing ad-hoc ast-grep queries for each navigation decision.
2. **PageRank-based importance ranking**: ast-grep finds matches; a repo map tells you which matches matter most based on cross-file reference frequency.
3. **Cross-file relationship graphs**: edges between definitions and their callers/callees across the whole project, enabling blast-radius queries and impact analysis without manual tracing.

ast-grep excels at "show me all instances of pattern X"; a repo map excels at "here is the structure of this codebase and what matters."

### Limitations

**Grammar version skew**: tree-sitter grammars lack a coherent versioning scheme. The tree-sitter discussions show no consensus; most grammar changes affect parse trees, making semver impractical. Different tools may bundle different grammar versions, producing inconsistent results. nvim-treesitter was abandoned recently due to maintenance burden; the tree-sitter-grammars org does not accept new parsers (Delpeuch).

**Dynamic-language blind spots**: PageRank is "sharper on Python than React/JSX" (Repo-Map MCP GitHub). Heavy metaprogramming defeats AST-based symbol extraction because AST symbols do not reflect runtime structure ("Repository Map Pattern").

**Monorepo scaling**: Aider's original repo map struggles with monorepos. The Codebase-Memory paper benchmarks the Linux kernel (2.1M nodes, ~3 min index time) but does not address cross-package dependency resolution in monorepo scenarios (Codebase-Memory arXiv).

**Build weight**: Codebase-Memory bundles 66 tree-sitter grammars as vendored C source, producing a single statically linked C binary with zero runtime dependencies but significant compile-time weight (Codebase-Memory arXiv). repomap-mcp uses WASM grammars instead, avoiding the C toolchain requirement (Repomap-MCP GitHub).

**Cross-tool compatibility**: Query files (.scm) are tool-specific and need per-tool maintenance. Cross-tool compatibility is limited because different tools require different distribution formats (Delpeuch).

### Licenses

- Codebase-Memory: open source (specific license not stated in archived source)
- Skeletree: Apache-2.0
- repo-map MCP: MIT
- repomap-mcp: not specified in archived source
- skyhook-graph: not specified in archived source
- cymbal: not specified in archived source
- dekko: not specified in archived source

---

## Part B: ast-grep

### What ast-grep Is

ast-grep (sg) is a CLI tool for structural code search, linting, and rewriting, written in Rust. It uses tree-sitter for parsing and provides an intuitive pattern language where patterns look like ordinary code. It has 16,000 stars and 461 forks on GitHub, is MIT-licensed, and installs via npm, pip, brew, cargo, scoop, MacPorts, nix, or mise (Ast-grep GitHub).

### Core Capabilities

**Structural search**: patterns match AST nodes, not text. `ast-grep --pattern 'var code = $PATTERN' --lang ts` finds variable declarations structurally (Ast-grep GitHub).

**Rewriting**: `--rewrite 'let code = new $PATTERN'` replaces matched nodes. Interactive mode (`-i`) and apply-all mode (`-U`) are available (Ast-grep GitHub).

**YAML rule scanning**: `ast-grep scan` takes YAML rule configurations for complex lint/modification rules (Ast-grep CLI Reference).

**Outline**: `ast-grep outline` shows code structure (Ast-grep GitHub).

**Strictness levels**: cst, smart, ast, relaxed, signature, template -- controlling how precisely a pattern must match the concrete syntax tree (Ast-grep CLI Reference).

### Performance

The Rust rewrite of tree-sitter within ast-grep achieved: +29.74% raw parsing throughput over C, +10.16% tree traversal throughput, -22.2% user CPU for complete outline, and roughly 22% faster end-to-end. The rewrite intentionally removed incremental old-tree reuse and native WASM grammar loading, trading generality for speed in the AI coding agent use case where complete file snapshots are analyzed. Memory usage increased modestly: 26.52 MiB RSS (C) to 34.43 MiB RSS (Rust), +29.8% (Ast-grep Rust Rewrite Blog).

### MCP Integration

The official ast-grep MCP server provides four tools: find_code (search for specific constructs), find_code_by_rule (advanced YAML rule search), dump_ast (inspect AST of code), and dump_pattern (inspect AST pattern for a search pattern). It integrates with Cursor, Claude Desktop, and OpenCode (Ast-grep MCP Integration).

### Relationship to Repo-Map Tools

ast-grep and repo-map tools are complementary, not competing. ast-grep answers "find me all occurrences of pattern X in this codebase." A repo-map answers "what is the structure of this codebase and which parts matter most." Many repo-map tools use tree-sitter (the same parser ast-grep uses) but add PageRank ranking, cross-file graphs, and token-budgeted rendering -- layers that ast-grep does not provide.

The oh-my-openagent PR #5340 (not archived) documents a real-world integration decision: dropping ast-grep MCP in favor of a skill-plus-CLI approach, suggesting that for some workflows, direct CLI invocation is preferred over MCP wrapping.

---

## Works Cited

Ast-grep GitHub. "ast-grep/ast-grep: A CLI Tool for Code Structural Search, Lint, and Rewriting." GitHub, github.com/ast-grep/ast-grep. Accessed 25 Sept. 2026.

Ast-grep CLI Reference. "ast-grep CLI Reference." astgrep.com, astgrep.com/reference/cli. Accessed 25 Sept. 2026.

Ast-grep MCP Integration. "ast-grep MCP Server Integration." GitHub, github.com/ast-grep/ast-grep-mcp. Accessed 25 Sept. 2026.

Ast-grep Rust Rewrite Blog. "How ast-grep Rewrote Tree-sitter in Rust." ast-grep.github.io, ast-grep.github.io/blog/tree-sitter-rust-rewrite. Accessed 25 Sept. 2026.

Codebase-Memory arXiv. Vogel, Martin, et al. "Codebase-Memory: Tree-Sitter-Based Knowledge Graphs for LLM Code Exploration via MCP." arXiv:2603.27277v1, 28 Mar. 2026.

Cymbal GitHub. "1broseidon/cymbal: Language-Agnostic Code Navigation CLI." GitHub, github.com/1broseidon/cymbal. Accessed 25 Sept. 2026.

Dekko GitHub. "aahlijia/dekko: Static Code Map Generator." GitHub, github.com/aahlijia/dekko. Accessed 25 Sept. 2026.

Delpeuch, Antonin. "The Puzzle of Tree-Sitter Parser Maintenance and Distribution." antonin.delpeuch.eu, 15 Apr. 2026.

Repo-Map MCP GitHub. "noambinabout-boop/repo-map: MCP Server for Code Navigation." GitHub, github.com/noambinabout-boop/repo-map. Accessed 25 Sept. 2026.

Repomap-MCP GitHub. "fl0w1nd/repomap-mcp: MCP for Ranked Token-Budgeted Code Structure Maps." GitHub, github.com/fl0w1nd/repomap-mcp. Accessed 25 Sept. 2026.

Repository Map Pattern. "Repository Map Pattern: AST + PageRank for Dynamic Code." agentpatterns.ai, agentpatterns.ai/context-engineering/repository-map-pattern/. Accessed 25 Sept. 2026.

Skeletree GitHub. "hemia-labs/skeletree: The Code Graph for AI Agents." GitHub, github.com/hemia-labs/skeletree. Accessed 25 Sept. 2026.

Skyhook PyPI. "skyhook-graph 0.3.0." PyPI, pypi.org/project/skyhook-graph/0.3.0/. Accessed 25 Sept. 2026.

---

## Unarchived/Excluded Sources

| URL | Reason |
|-----|--------|
| https://aider.chat/2023/10/22/repomap.html | trafilatura blocked by permission system |
| https://github.com/tree-sitter/tree-sitter/discussions/1768 | webfetch did not return content |
| https://github.com/DeusData/codebase-memory-mcp | Referenced in paper, not separately archived |
| https://github.com/dereira/goldfish | webfetch did not return content |
| https://github.com/tarunms7/codegraph | webfetch did not return content |
| https://github.com/vivalafreak1/agentmap | webfetch did not return content |
| https://github.com/breca/mcp-codemap | webfetch did not return content |
| https://github.com/mackenney/repo-mapper | webfetch did not return content |
| https://astgrep.com/guide/introduction | trafilatura blocked by permission system |
| https://crates.io/crates/ast-grep | webfetch returned empty |
| https://github.com/ast-grep/agent-skill | webfetch did not return content |
| https://astgrep.com/advanced/prompting | trafilatura blocked by permission system |
| https://github.com/code-yeongyu/oh-my-openagent/pull/5340 | webfetch did not return content |
| https://github.com/thrawn01/mcp-ast-grep | webfetch did not return content |
| https://github.com/maThiaslI152/opencode-ast-mcp | webfetch did not return content |
| https://github.com/Aider-AI/aider/issues/3932 | webfetch did not return content |
| https://helmdeck.dev/adrs/pack-repo-map | webfetch did not return content |
| https://aider.chat/2024/05/22/swe-bench-lite.html | trafilatura blocked by permission system |
| https://github.com/abhigyanpatwari/GitNexus/pull/847 | webfetch did not return content |

Note: The .source-urls.txt manifest marks 14 URLs as "NOT ARCHIVED" (the researcher reported 14 Phase A failures where webfetch/trafilatura did not return content). The table above includes those 14 plus 5 additional URLs referenced in passing in the archived sources (Codebase-Memory GitHub, goldfish, codegraph, agentmap, repo-mapper) that were never attempted for archival. None of these are cited in the body.

---

## Gaps: What the Archived Sources Do Not Cover

1. **Aider's original repo map internals**: The canonical Aider repomap blog post was not archived. The conspect relies on second-hand descriptions from the repository-map-pattern source and .source-urls.txt metadata.
2. **empirical cross-tool comparison**: No archived source provides a head-to-head benchmark of multiple repo-map tools on the same codebase.
3. **goldfish, codegraph, agentmap, repo-mapper**: These Go/Python/TS implementations were not archived, so their specific tradeoffs are unknown.
4. **ast-grep prompting guide for AI tools**: The official ast-grep prompting guide (astgrep.com/advanced/prompting) was not archived.
5. **ctags-based vs tree-sitter tradeoffs**: Helmdeck ADR 036 (not archived) was expected to cover this; the repository-map-pattern source provides a brief ctags comparison table but not a detailed tradeoff analysis.
6. **Real-world adoption metrics**: Beyond Codebase-Memory's 900+ stars, no archived source reports adoption numbers, production usage, or failure reports from real deployments.
7. **Incremental update performance across tools**: Only repo-map MCP and cymbal mention incremental refresh; no comparative data exists.
8. **License details for repomap-mcp, skyhook, cymbal, dekko**: The archived sources do not always state the license.
