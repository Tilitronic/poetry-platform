# Codebase-Memory-MCP (DeusData): Conspect

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 7
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## 1. Identity and Repository Profile

codebase-memory-mcp is a C-native MCP (Model Context Protocol) server that
indexes a codebase into a persistent knowledge graph using tree-sitter parsing
and a SQLite-backed graph store. The project is authored by DeusData
(github.com/DeusData), a single user account with no organization or team
indicated. The repository was created 2026-02-24 and is MIT-licensed
("github-api-metadata.json"). As of the archived metadata snapshot
(2026-09-25), it carries 44,904 stars, 3,669 forks, 176 subscribers, and
633 open issues ("github-api-metadata.json"). The primary language is
listed as C. The npm package name is codebase-memory-mcp, latest version
0.11.0, with 15 published versions and MIT license confirmed
(".source-urls.txt" npm metadata).

The single-maintainer bus-factor risk is implicit: the GitHub API metadata
shows one owner (DeusData, user ID 81762164), no organization membership, and
no evidence of co-maintainers in the archived sources. The 633 open issues
against a solo maintainer represent a significant triage burden.

## 2. Language-Count Discrepancy

Three sources give three different language counts, and the discrepancy is
material:

- The arXiv paper (2603.27277) states 66 languages parsed
  (arxiv-2603-27277.md, abstract).
- The README badge (cited in emre-cavunt-independent-benchmark.md and
  russ-mckendrick-blog.md) claims 162 languages.
- The npm package description in the GitHub API metadata says "158 languages"
  ("github-api-metadata.json").

The paper was submitted 28 March 2026 and likely reflects the language count
at that snapshot. The README and npm figures are later and may include
incremental tree-sitter grammar additions. No source reconciles the three
numbers. The discrepancy is reported honestly here rather than resolved.

## 3. MCP Tool-Discovery Defect

An independent benchmark by Emre Cavunt (2026-08-01) identified a significant
integration defect: the MCP tools/list endpoint exposes only 8 of the 14
documented tools. The missing six -- list_projects, index_status,
detect_changes, delete_project, manage_adr, and ingest_traces -- are
reachable via the CLI but invisible to any spec-compliant MCP client relying
on tool discovery (emre-cavunt-independent-benchmark.md).

Cavunt drove the server over raw stdio JSON-RPC as three different client
identities (claude-code, cursor, a made-up name) and received the same
eight-tool response each time. He flags this as "the kind of bug that quietly
halves the product" because "a client that relies on MCP discovery will never
offer them to its agent." The detect_changes tool -- which maps a git diff to
a blast radius of affected symbols -- is specifically called out as
high-value yet undiscoverable. Additionally, delete_project fires through the
CLI with no confirmation prompt, posing a safety risk if exposed to an agent
without an approval boundary (emre-cavunt-independent-benchmark.md).

This defect is flagged prominently as an integration risk: any agent or
workflow that depends on MCP tool discovery rather than manual CLI invocation
will see reduced functionality.

## 4. arXiv Benchmark (2603.27277)

The paper "Codebase-Memory: Tree-Sitter-Based Knowledge Graphs for LLM Code
Exploration via MCP" (Vogel, Meyer-Eschenbach, Kohler, Grunewald, and Balzer,
submitted 28 March 2026) presents the following methodology and results
(arxiv-2603-27277.md):

**Methodology**: Evaluated across 31 real-world repositories using a
file-by-file baseline agent for comparison. The system constructs a persistent
tree-sitter-based knowledge graph with parallel worker pools, call-graph
traversal, impact analysis, and community discovery.

**Results**:
- 83% answer quality versus 92% for the file-exploration agent (a 9-point gap).
- 10x fewer tokens consumed.
- 2.1x fewer tool calls.
- Matches or exceeds the explorer on 19 of 31 languages for graph-native
  queries (hub detection, caller ranking).

**Caveats noted in the paper**: The comparison is against a single baseline
(a file-exploration agent). The paper's language count was 66 at time of
submission. These numbers reflect a controlled academic evaluation, not
real-world production use.

**Distinction from marketing figures**: The README's "99.2% reduction / 120x"
headline comes from a narrow 5-query benchmark on a multi-service test project
(~3,400 tokens via the graph versus ~412,000 via file-by-file exploration),
as reported in russ-mckendrick-blog.md and andrew-ooo-review.md. This is a
vendor-published marketing figure on a favorable workload, not an independent
or peer-reviewed measurement. The arXiv paper's 83%/10x figures are the
peer-reviewed baseline. Real-world independent measurements fall between
these ranges (see Section 5).

## 5. Independent Benchmark (Emre Cavunt)

Emre Cavunt's evaluation (2026-08-01) is the most rigorous independent
measurement available. Key findings (emre-cavunt-independent-benchmark.md):

- On two Google repositories, codebase-memory-mcp returned 22x smaller
  response payloads than a disciplined grep baseline, and roughly 500x less
  than naive full-file reads. The README's 99.2% reduction (~120x) falls
  within the measured range on this workload.
- Measured indexing throughput: ~25K LOC/second. The README reports a
  three-minute full index of the 28M-LOC Linux kernel; Cavunt's extrapolation
  at measured throughput yields ~19 minutes. He notes this is "directional,
  not conclusive" due to hardware differences but states he "could not
  reproduce the headline throughput."
- Query latency: ~10ms for a full CLI round trip, versus the README's
  "under 1ms" claim. Cavunt judges this "holds in practice."
- 3D graph UI on port 9749: works as advertised.

**Criticisms**:
1. Tool-discovery defect (Section 3 above).
2. delete_project fires without confirmation.
3. Indexing throughput not reproducible at advertised speed.
4. Advertised agent count (11) did not match installer help output (9 found).

Cavunt's overall verdict: "Install it for the code graph. The context
economics survived a hostile measurement." But he cautions: "Treat the
README's broadest promises as aspirational."

## 6. Review Sentiment

### Positive

Russ McKendrick (2026-05-10) calls codebase-memory-mcp a tool he has
"quietly become part of my default setup" for refactoring questions like
"where is this used?" and "what's actually dead?" He reports that his full
session cost 0.299 GBP, with 198.3K of 238.9K input tokens served from cache.
He notes the graph indexes structure rather than text content, so it will not
find misspelled config strings, but praises it for the structural queries
that arise constantly in real projects (russ-mckendrick-blog.md).

andrew.ooo (2026-07-07) concludes that "for exploratory queries, architecture
overviews, change impact analysis, and dead code detection, the speed and
token efficiency make it an obvious default," while acknowledging the 83%
accuracy trade-off is real and worth knowing. He measured 8-10x token
reduction in a 45-minute session with ~30 structural queries on a TypeScript
project (andrew-ooo-review.md).

Community quotes collected in andrew.ooo's review include praise for fast
indexing ("300-file Next.js app indexed in 11 seconds"), the single-binary
install ("no Docker, no npm, no 500MB of Python dependencies"), and
cross-service route mapping on Go monorepos.

### Negative

Documented complaints from the archived GitHub issues and reviews:

- **OOM / memory bloat**: GitHub issue #49 reports 13.4 GB RSS when the
  server is idle. Issue #46 is an open memory-leak investigation. These
  suggest the SQLite-backed graph can consume unbounded memory on large
  repositories.
- **SQLite lock contention**: Issue #52 documents the server hanging due to
  SQLite lock contention, a known limitation of SQLite's concurrent-access
  model.
- **macOS ARM64 stack overflow**: Issue #139 reports a stack overflow crash
  on Apple Silicon, likely related to recursive tree-sitter traversal on deep
  ASTs.
- **Idle CPU burn**: Issue #1764 documents a regression since version
  0.9.1-rc.1 where the server burns CPU while idle.
- **search_code timeouts**: Issue #474 reports constant timeouts on Windows,
  suggesting platform-specific performance issues.
- **Large-repo crash**: Issue #317 documents a dump-phase crash on large
  TypeScript monorepos.
- **False positive**: Windows Defender flags the binary, a known issue with
  unsigned C binaries distributed via GitHub.

andrew.ooo's review also quotes community feedback noting semantic query
irrelevance and C++ template metaprogramming gaps in the Hybrid LSP layer
(andrew-ooo-review.md).

## 7. Privacy Posture

The archived sources consistently describe codebase-memory-mcp as 100% local:
no telemetry, no API keys, no Docker required (andrew-ooo-review.md,
russ-mckendrick-blog.md). The npm package description in the GitHub API
metadata confirms "single static binary, zero dependencies"
("github-api-metadata.json"). An opt-in diagnostic mode (CBM_DIAGNOSTICS)
is referenced in community discussions but not detailed in the archived
sources.

**Caveat**: The install and postinstall scripts fetch from GitHub to download
the platform-specific binary (".source-urls.txt" notes this was fetched and
verified via webfetch). This means the initial installation is not fully
air-gapped; a network-restricted environment would need to manually supply
the binary.

## 8. Integrations and Install Footprint

**MCP integration**: The server communicates over stdio JSON-RPC, the standard
MCP transport. It auto-detects and configures 11 AI coding agents out of the
box (andrew-ooo-review.md, russ-mckendrick-blog.md list: Claude Code, Codex
CLI, Gemini CLI, Zed, OpenCode, Antigravity, Aider, KiloCode, VS Code,
OpenClaw, and Kiro). However, Cavunt's independent check found only 9 in the
installer help, suggesting the agent list may be aspirational or
version-dependent (emre-cavunt-independent-benchmark.md).

**CLI mode**: Full CLI access to all 14 tools, including the six not exposed
via MCP discovery.

**Install footprint**:
- Binary drops into ~/.local/bin.
- Index stored in ~/.cache (per the README, confirmed in russ-mckendrick-blog.md).
- Install command writes configuration files (AGENTS.md, skill files, agent
  configs) into detected agent directories.

**OpenCode support**: Listed among the 11 auto-configured agents
(russ-mckendrick-blog.md, andrew-ooo-review.md). No OpenCode-specific
integration details beyond auto-detection are described in the archived
sources.

**3D graph UI**: A web-based 3D graph visualization runs on port 9749, confirmed
working by Cavunt (emre-cavunt-independent-benchmark.md).

## Works Cited

"DeusData/codebase-memory-mcp." GitHub API Repository Metadata, archived
25 Sept. 2026. JSON file.

Cavunt, Emre. "The Token Economy of codebase-memory-mcp: A Knowledge Graph
Benchmark." emrecavunt.com, 1 Aug. 2026.
knowledge/res-260925-70v6-codebase-memory-mcp/sources/
emre-cavunt-independent-benchmark.md.

McKendrick, Russ. "codebase-memory-mcp: Giving Claude Code (and Codex) a
Map." russ.cloud, 10 May. 2026.
knowledge/res-260925-70v6-codebase-memory-mcp/sources/
russ-mckendrick-blog.md.

reddit-locallm-review.md. "codebase-memory-mcp Review: 99% Token Cut for
Code Agents." r/LocalLLM, Reddit, 25 Jun. 2026.
knowledge/res-260925-70v6-codebase-memory-mcp/sources/
reddit-locallm-review.md.

Vogel, Martin, et al. "Codebase-Memory: Tree-Sitter-Based Knowledge Graphs
for LLM Code Exploration via MCP." arXiv:2603.27277, 28 Mar. 2026.
knowledge/res-260925-70v6-codebase-memory-mcp/sources/
arxiv-2603-27277.md.

andrew-ooo. "Codebase Memory MCP Review: 99% Fewer Tokens for AI Agents."
andrew.ooo, 7 Jul. 2026.
knowledge/res-260925-70v6-codebase-memory-mcp/sources/
andrew-ooo-review.md.

## Unarchived/Excluded Sources

| URL | Reason |
|-----|--------|
| reddit.com/r/codex/comments/1rp9ks1/ | NOT ARCHIVED per manifest; content only in websearch snippets |
| news.ycombinator.com/item?id=48175665 | NOT ARCHIVED per manifest; brief HN comment comparing to Semble |
| reddit.com/r/mcp/comments/1nxy8s6/ | NOT ARCHIVED per manifest; general memory MCP discussion, not specific to codebase-memory-mcp |

## Gaps in Archived Sources

- No source provides the full text of the README badge language count
  (162); only the discrepancy is noted across sources.
- No source details the CBM_DIAGNOSTICS opt-in mechanism or what data it
  collects.
- No source provides Windows-specific testing data beyond the timeout issue.
- No source covers the SQLite schema design or graph query language syntax in
  detail.
- No source evaluates the tool against alternatives (e.g., Semble, other MCP
  memory servers) in a controlled comparison.
- No source covers upgrade/migration behavior across the 15 npm versions.
- No source provides the single maintainer's response to the OOM/memory-leak
  issues beyond issue tracker labels.
