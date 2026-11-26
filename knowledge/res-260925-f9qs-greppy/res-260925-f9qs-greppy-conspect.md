# Greppy: A Research Conspect on metric-space-ai/greppy

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 6
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## 1. Identity Disambiguation

Two different Rust projects share the name "greppy." This conspect covers **metric-space-ai/greppy**, an organization-owned repository at `https://github.com/metric-space-ai/greppy`. It is described as "local code navigation for coding agents: deterministic symbol graph, semantic search, compact briefings, and byte-exact real-grep passthrough" (GitHub API metadata). The **other** project, KBLCode/greppy, is a separate BM25+Ollama reranking tool that shares only the name and is out of scope for this conspect (`.source-urls.txt`, line 20: "NOT ARCHIVED (different project)").

The target repository is owned by the GitHub organization **metric-space-ai** (org ID 110183634), written in **Rust**, created **2026-06-30**, last pushed **2026-09-25**. The code is licensed **Apache License 2.0**, but the bundled model weights carry separate licenses: EmbeddingGemma is governed by Google's Gemma Terms of Use (with use restrictions and redistribution conditions), while the Qwen3.5 fine-tune is Apache 2.0 (`license.txt`). This license split is not merely a footnote -- it affects redistribution and commercial use of the binary as distributed.

## 2. Maturity Signal

The project's adoption numbers are modest and must be stated plainly. As of 2026-09-25:

- **Stars:** 9
- **Forks:** 2
- **Open issues:** 66
- **Watchers/subscribers:** 9 / 0

The 66 open issues are predominantly filed by the maintainer (mkh-welsch) for internal tracking and bug reports; no external contributor issues were identified (`community-landscape.md`, lines 16-18). There are 9 closed issues against 66 open ones. The project has a single maintainer. Release history includes v0.3.3 (stable) and v0.4.0 (release candidate) as of the README snapshot (`readme.md`, line 9). The project was created approximately three months before this conspect was authored. These figures should be weighed against any competitive claims: this is an early-stage, single-author project, not an established tool with community adoption.

## 3. Mechanism

### Navigation Command Set

The `AGENTS.md` file enumerates the command surface. The navigation and query commands are: `who-calls`, `callees`, `impact`, `brief`, `path`, `search`, `search-symbol`, `search-pattern`, `expand`, `graph-locate`, `fan-in`, `fan-out`, and `trace` (`agents-md.md`, lines 4-5; `readme.md`, line 5). These answer relationship questions (call graphs, impact analysis, navigation paths) rather than simple pattern matching.

The tool also ships editing and agent-assistance commands: `read`, `read-smart`, `read-file`, `replace`, `replace-text`, `replace-span`, `rename`, `patch`, `undo`, `bash-smart`, `web` (browser), `-p` (coding agent mode), and `agent` (TUI) (`agents-md.md`, lines 5-6).

### Symbol Graph

Greppy builds a "deterministic symbol graph" ahead of time (`github-api-metadata.json`, description; `readme.md`, line 5). The graph is typed, with edge types encoding caller-callee, inheritance, and other structural relationships. The README summary and agents-md confirm the graph is precomputed and stored in SQLite (though the specific SQLite schema details are not elaborated in the archived sources).

### Tree-Sitter Language Coverage

The README claims "60+ languages with parser support" (`readme.md`, line 20). The archived sources do not break this down into the total parser-supported count versus the smaller subset with certified graph-completeness. This distinction -- between having a tree-sitter parser and having a fully validated symbol graph for a language -- is not detailed in the available material and should be treated as an open question.

### On-Device Models

Two models are bundled:

- **EmbeddingGemma (300M parameters):** used for semantic search embeddings.
- **Qwen3.5-0.8B fine-tune:** used for on-device summarization/briefing.

Both run via native inference with no network dependency (`readme.md`, lines 19, 21). The Qwen3.5 component is Apache 2.0; EmbeddingGemma carries Google Gemma ToU restrictions (`license.txt`, lines 6-8).

## 4. Integration

Greppy is **CLI-only**. There is no MCP server, no LSP, and no per-agent configuration file (`agents-md.md`, line 3: "CLI-only, no MCP server. No per-agent config needed."). Integration works through the agent's AGENTS.md (or CLAUDE.md with an `@AGENTS.md` reference): the agent reads the greppy instructions and invokes the CLI commands via shell (`agents-md.md`, line 3). This means it works in any agent that can execute shell commands, but it requires the agent to be prompted to use greppy rather than connecting automatically.

The `AGENTS.md` format is the integration surface. The README mentions that the tool is designed for "coding agents" (`github-api-metadata.json`, description), and the agent names explicitly referenced in the README snapshot include Claude (via CLAUDE.md support). OpenCode is not specifically called out in the archived sources, though the CLI-only model means it would work in any shell-capable agent.

Later versions (visible in the command list from `agents-md.md`) added editing features (`replace`, `rename`, `patch`, `undo`), a browser tool (`web`), a coding-agent mode (`-p`), and a TUI (`agent`), moving greppy beyond read-only navigation.

## 5. Community Reviews and Independent Discussion

**There is essentially no independent community discussion of metric-space-ai/greppy.** This is a finding, not an oversight. The researcher's landscape sweep found:

- **Reddit:** No dedicated thread about metric-space-ai/greppy. The closest related post ("Is grep enough?" on r/ClaudeCode, 2026-06-30) discusses the broader problem space but does not review greppy (`community-reddit-is-grep-enough.md`, lines 6-7).
- **Hacker News:** No discussion found. The only "Greppy" HN result is an unrelated 2020 robotics project (`community-landscape.md`, lines 9-10).
- **Blogs:** FullStackFeed.com aggregated the GitHub README with thin coverage and no original analysis (`community-landscape.md`, line 13).
- **GitHub Issues:** 66 open, 9 closed. Almost all filed by the maintainer. No external contributor issues found (`community-landscape.md`, lines 16-18).

The project is approximately three months old with 9 stars. All coverage is self-driven (the README, the benchmark paper, GitHub itself). No independent review, comparison, or critique exists in the archived sources.

## 6. Benchmarks and Provenance

The README summary references a benchmark suite ("115-task, 4-model benchmark") reporting that greppy achieves "6-50 percentage points more correct than grep" and "37-80% lower API cost at matched quality" (`readme.md`, lines 17-18). The README also references a self-published paper (the benchmark paper linked from the repo).

**All benchmark claims are VENDOR-RUN and SELF-PUBLISHED.** The archived sources do not include the full benchmark paper, so the following details from the task description (navigation vs. coding suites, task/repo counts per suite, specific model set, grader design, ablation methodology) cannot be confirmed from the archived material alone. The summary states the benchmarks were run across 4 models and 115 tasks, but the breakdown of which tasks belong to which suite, the grading criteria, and the ablation controls are not present in the archived README snapshot or metadata.

No independent replication of these benchmarks was found in any archived source. The community landscape (`community-landscape.md`) confirms that all external coverage is either absent or derivative of the README. The benchmark figures should be treated as vendor claims until independently verified.

## 7. Internal Contradiction: Impact Analysis

The archived sources contain an internal contradiction that must be flagged.

On one hand, the `AGENTS.md` command list includes `impact` as a first-class navigation command (`agents-md.md`, line 4). The README summary describes the tool as providing "deterministic symbol-graph evidence" for code navigation (`readme.md`, line 5). Impact analysis -- determining what code is affected by a change -- is a core use case for the tool's target audience.

On the other hand, the limitations documented in the researcher's notes state that blast-radius and architecture-overview features are "explicitly absent" (`readme.md`, line 22 references limitations; `community-landscape.md` notes the tool's scope). The `impact` command exists in the command set, yet the limitations claim the feature is not present.

**This point is UNRESOLVED in the archived sources.** The most likely explanations are: (a) the `impact` command provides a narrower scope of impact analysis (e.g., direct callers only) than a full transitive blast-radius computation, or (b) the README and command list evolved at different points in the release cycle. Without the full README text or the benchmark paper, the exact semantics of the `impact` command and what the limitations section actually claims cannot be reconciled. This matters because impact analysis is a core evaluation axis for any code-navigation tool positioning itself against grep.

## 8. Limitations

The archived sources document or imply the following limitations:

- **Beta semantic search:** The semantic search feature is described as beta-stage, not production-hardened (`readme.md`).
- **No MCP server:** There is no MCP integration, LSP, or plugin interface (`agents-md.md`, line 3). Integration requires the agent to read AGENTS.md and invoke CLI commands via shell.
- **Language-coverage gap:** While 60+ languages have parser support, the subset with certified graph completeness is smaller. The archived sources do not quantify this gap.
- **Binary and model download size:** The bundled models (EmbeddingGemma 300M, Qwen3.5-0.8B) plus the Rust binary constitute a non-trivial download and installed footprint. The exact sizes are not in the archived sources.
- **Static-graph blind spots:** Any precomputed symbol graph will miss reflection, dependency injection, monkeypatching, dynamic dispatch, and generated code. The archived sources do not detail how greppy handles these cases or what fallback behavior exists.
- **First-use index build times:** Building the semantic index on first use is a known cost, and build times vary across hardware. The archived sources do not report specific build-time benchmarks.
- **No Windows package:** The current release line does not include a Windows package (`readme.md` and metadata do not mention Windows support).
- **Single-maintainer risk:** The project has one maintainer (mkh-welsch). All issues are filed by this person. Bus-factor risk is high.

## 9. Privacy

Greppy's privacy model is strong and clearly stated:

- **Fully local:** No network calls, no telemetry, no account required (`readme.md`, line 21).
- **On-device embeddings:** EmbeddingGemma runs locally; no data is sent to external servers.
- **Offline/air-gapped:** The tool operates without an internet connection.
- **Local cache:** The symbol graph and semantic index are stored locally. The archived sources mention the cache can be relocated, though the specific cache path and relocation mechanism are not detailed in the available material.

This is a meaningful differentiator for enterprise or security-sensitive environments where code cannot leave the network.

## 10. Positioning: Greppy vs. Structural Grep

Greppy operates on a **different axis** than a structural grep/AST-search tool. The two tool categories answer different questions:

| Question Type | Greppy | Structural Grep |
|---|---|---|
| "Find all occurrences of pattern X" | Yes (byte-exact grep passthrough) | Yes (AST pattern matching) |
| "Who calls function Y?" | Yes (`who-calls`) | No (requires manual tracing) |
| "What is the blast radius of changing Z?" | Yes (`impact`) -- see unresolved caveat in section 7 | No |
| "What is the shortest path between A and B?" | Yes (`path`) | No |
| "Summarize this function for context" | Yes (`brief`) | No |
| "Find all implementations of interface I" | Yes (symbol graph edges) | Partially (pattern-based, no semantic linking) |

The overlap zone is **literal pattern search**: both tools can find occurrences of a string or pattern in source files. In this narrow overlap, greppy's byte-exact grep passthrough means it can replace grep for simple search tasks. But this is the least interesting thing greppy does.

**Conclusion:** Greppy is a **cheap complement** to an existing AST-search capability, not a redundant replacement. An AST-search tool excels at structural pattern rewriting (find-and-replace across syntactic patterns, refactoring). Greppy excels at relationship navigation and semantic briefing (who-calls, impact, path, summary). They solve different problems. The pragmatic setup is: keep your AST-search tool for structural transformations, and add greppy for navigation and context-gathering. The byte-exact grep passthrough means greppy can subsume the basic grep use case as well, consolidating two tools into one binary -- but the core value is the navigation, not the grep replacement.

---

## Works Cited

"greppy." GitHub, metric-space-ai/greppy, 2026, github.com/metric-space-ai/greppy. Repository metadata. Accessed 2026-09-25.

"greppy -- README.md." metric-space-ai/greppy, main branch, 2026, raw.githubusercontent.com/metric-space-ai/greppy/main/README.md. Archived summary.

"greppy -- AGENTS.md." metric-space-ai/greppy, main branch, 2026, raw.githubusercontent.com/metric-space-ai/greppy/main/AGENTS.md. Integration and command reference.

"greppy -- LICENSE." metric-space-ai/greppy, main branch, 2026, raw.githubusercontent.com/metric-space-ai/greppy/main/LICENSE. Apache 2.0 plus model license notes.

"Community Discussion Landscape for metric-space-ai/greppy." Researcher landscape report, 2026-09-25.

"Reddit r/ClaudeCode -- 'Is grep enough? -- code navigation for agents, measured.'" Reddit, 2026-06-30, reddit.com/r/ClaudeCode/comments/1ujnpy6/. Related context; no greppy-specific review.

---

## Unarchived/Excluded Sources

| Source | Reason Excluded |
|---|---|
| `github.com/kblcode/greppy` | Different project (KBLCode/greppy: BM25+Ollama reranking, not metric-space-ai/greppy) |
| `docs.rs/crate/greppy-cli/latest` | KBLCode/greppy-cli crate, different project |
| `crates.io/crates/greppy-cli` | KBLCode/greppy-cli crate, different project |
| `news.ycombinator.com/item?id=23696193` | Unrelated "Greppy" robotics project from 2020 |
| `fullstackfeed.com/greppy-a-drop-in-grep-with-code-nav-subcommands-for-ai-agents/` | Thin aggregation, no original analysis; summary data already captured in community-landscape.md |
| GitHub issues page | Fetched inline; summary data incorporated into community-landscape.md |
| GitHub releases page | Fetched inline; release data incorporated into readme.md and github-api-metadata.json |

---

## Gaps in Archived Sources

The following questions cannot be answered from the archived material:

1. **Full README text:** The archived `readme.md` is a researcher-written summary, not the full README. Technical details about the symbol graph edge types, SQLite schema, index build process, and limitation specifics are missing.
2. **Benchmark paper:** The full self-published benchmark paper was not archived. Task breakdown by suite, model list, grading methodology, ablation design, and per-model accuracy tables are unavailable.
3. **Tree-sitter certified vs. parser-supported count:** The 60+ languages figure is stated, but the subset with certified graph completeness is not quantified.
4. **Binary/model sizes:** Exact download and installed sizes are not in the archived sources.
5. **Windows support status:** Not mentioned in any archived source.
6. **Static-graph fallback behavior:** How greppy handles reflection, DI, monkeypatching, dynamic dispatch, and generated code is not documented in the archived material.
7. **Semantic index build times:** No hardware-specific benchmarks were archived.
8. **Cache relocation specifics:** The ability to relocate the local cache is mentioned but the mechanism is not documented.
9. **Impact command semantics:** The exact scope of the `impact` command (direct vs. transitive, configurable depth) cannot be determined, and the contradiction with the limitations section remains unresolved.
10. **Model license details:** The Gemma ToU restrictions are mentioned but the specific use restrictions and redistribution conditions are not quoted from the source.
