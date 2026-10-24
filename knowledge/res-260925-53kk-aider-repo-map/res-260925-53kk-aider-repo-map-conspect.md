# Aider Repo Map: Architecture, Pipeline, and Standalone Reimplementations

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 7
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## 1. What the Repo Map Is

Aider's repo map is a concise, ranked summary of a git repository that surfaces the most important classes, functions, and their call signatures to the LLM with each change request. It solves the core problem of LLM-assisted code editing: the model is good at writing correct code once it knows what to change, but needs context about the codebase's structure to find the right files and understand their relationships (Aider Docs). The map contains file names, symbol definitions, and the critical lines of source code for each definition (Blog). It is sent alongside every user message so the LLM can see classes and methods from across the entire repo without loading full file contents (Aider Docs).

## 2. The Full Build Pipeline

### 2.1 File Discovery

Aider enumerates files in the git repository. Files matching `.aiderignore` should be excluded, though users report this is not always honored (Issue 3902). The set of chat files (files the user has added to the current session) and other files (everything else in the repo) are tracked separately.

### 2.2 Tree-Sitter Parsing

Aider uses `py-tree-sitter-languages` to parse source code into Abstract Syntax Trees (ASTs) for 40+ programming languages (Blog). Tree-sitter replaces an earlier ctags-based approach, producing richer maps with full function call signatures and removing the need for users to install `universal-ctags` (Blog). Modified `tags.scm` files from open-source tree-sitter language implementations (MIT and Apache 2.0 licensed) drive the extraction of definitions and references (Blog).

### 2.3 Tag Caching

Parsed tags are stored on disk in `.aider.tags.cache.v{VERSION}/` using `diskcache` (SQLite-backed) (Source). A separate in-memory map cache is keyed by the tuple `(chat_files, other_files, max_map_tokens, mentioned_fnames, mentioned_idents)` (Source). Refresh modes include `auto`, `always`, `files`, and `manual` (Source).

### 2.4 Graph Construction

A `networkx.MultiDiGraph` is built with source files as nodes. Directed edges connect referencer files to definer files, weighted by symbol-level multipliers (Source):

| Condition | Multiplier |
|-----------|-----------|
| Mentioned identifiers (named in the user's message) | x10 |
| Snake_case / kebab-case / camelCase identifiers >= 8 chars | x10 |
| Private identifiers (starting with `_`) | x0.1 |
| Symbols defined in >5 files (too generic) | x0.1 |
| Referencer is a chat file (in the active session) | x50 |
| Base scaling | sqrt(num_refs) |

### 2.5 Personalized PageRank

PageRank is executed on the weighted graph with a personalization vector that favors chat files and mentioned identifiers (Source):

```
ranked = nx.pagerank(G, weight="weight", **pers_args)
```

This produces a per-file importance score that accounts for both the structural position of files in the dependency graph and the user's current focus.

### 2.6 Binary-Search Token Fitting

A binary search over the number of top-ranked tags to include finds the largest set that fits within the token budget (Source). The search uses a 15% error tolerance:

```
pct_err = abs(num_tokens - max_map_tokens) / max_map_tokens
ok_err = 0.15
```

If the tree of selected tags is within 15% of the target, it is accepted. The search starts from `min(max_map_tokens // 25, num_tags)` and adjusts bounds based on whether the current tree is over or under budget (Source).

### 2.7 Rendering

`grep_ast.TreeContext` renders the selected tag tree with context, eliding non-essential lines to produce the final text output sent to the LLM (Source).

## 3. Ranking Multipliers (Exact Values)

From the source code analysis (Source):

- **Mentioned identifiers** (named in user message): **x10** boost
- **Long snake_case/kebab/camelCase identifiers** (>= 8 chars): **x10** boost
- **Chat files** (files in the active session): **x50** boost
- **Private identifiers** (leading `_`): **x0.1** (deprioritized)
- **Symbols defined in >5 files** (too generic): **x0.1** (deprioritized)
- **Base edge weight**: `sqrt(num_refs)` -- square root of reference count

These multipliers are applied multiplicatively on the graph edges before PageRank execution.

## 4. Soft-Token-Limit Behavior

The `--map-tokens` flag (default 1024) sets a *soft* target, not a hard cap. Aider dynamically adjusts the repo map size based on chat state (Aider Docs). The binary-search fitting algorithm accepts output within 15% of the target token count (Source). Users have observed that setting `--map-tokens 1024` still produced 16,419 tokens in some cases (Issue 752).

## 5. Adaptive 8x Expansion

When no files have been added to the chat, Aider multiplies the token budget by `map_mul_no_files` (default 8) to give a broader view of the repository (Source):

```python
padding = 4096
if max_map_tokens and self.max_context_window:
    target = min(
        int(max_map_tokens * self.map_mul_no_files),
        self.max_context_window - padding,
    )
```

This is the mechanism behind Issue 3796, where a user observed the repo map being "more than double the configured size" -- in that case, the 8x multiplier was active because no files were in the chat.

## 6. User Complaints (Detailed)

### Token Limit Not Respected (Issue 752)

User reported setting `--map-tokens 1024` yet observing 16,419 tokens consumed by the repo map. The issue explains that `--map-tokens` is a soft target and aider adjusts dynamically, but the user found this behavior surprising and undocumented (Issue 752).

### Full Function Bodies Instead of Signatures (Issue 3932)

User wrote: "From what I've read, I was under the expectation that the repo map would contain a bit of a stencil of the project, function signatures, classes, etc, but I see entire function bodies. This very quickly overflows the size of the repo map." The workaround is setting `parent_context=False` in the TreeContext constructor. This is particularly severe on Go projects where implementations are less dense and more spread out (Issue 3932).

### .aiderignore Not Respected (Issue 3902)

User reported: "It seems like the initialization and updating of the repo map includes all files, even those included in the .aiderignore file. Additionally, even with the --subtree-only flag, other files in the git repo are included in the repo map." This makes the tool difficult to use with larger monorepos (Issue 3902).

### No In-Session Control (Issue 3187)

User stated: "Especially when working in a large repo, you end up sending the entire repo map even when you want to ask a question that's not related to the content of the repo. Not all requests need the entire repo map, but you end up paying for it anyway." There is no way to temporarily disable the repo map within a session (Issue 3187).

### Monorepo Symbol Collisions (MeetsMore Blog)

The MeetsMore engineering team reported that the repo map "assumes all symbols are unique" -- for example, 10 different symbols named `fetchRequest` across different modules are treated as a single entity. They also found that the map "doesn't model relevance according to files targeted for changes" and "assumes frequency of usage increases relevance." Their result: "Our entire repo map mostly being our feature flag methods, or really general symbols like `name()`" (MeetsMore).

### Build Freeze on Large Repos (Issue 3297)

User reported: "A project I have worked on extensively in the past with the same Aider options is now refusing to build the repo map, without the repo having grown significantly in size. It freezes at 15% and will not go any further" (Issue 3297).

### Excluded Dependencies Causing Hallucinated APIs (Issue 3603)

User observed: "When dependencies are omitted from the repo map, the LLM has no context about their existence, API signatures, or semantics. This frequently leads to hallucinated APIs and incorrect suggestions, negatively impacting usability" (Issue 3603).

### Graph Granularity Request (Issue 1385)

Feature request to use code entities (functions, classes) as graph nodes instead of files, with dependencies between entities as edges. The response noted this would require a proper LSP integration (Issue 1385).

## 7. Extractability Assessment

### Reusability as a Library

Aider's repo map is implemented as a single Python class (`RepoMap` in `aider/repomap.py`) under Apache-2.0 license. Its dependencies are `networkx`, `diskcache`, `grep-ast`, `tree-sitter`, and `tiktoken` (or equivalent token counter). The core algorithm (tree-sitter parsing, graph construction, PageRank, binary-search fitting) is theoretically extractable, but in practice the class is tightly coupled to Aider's `main_model`, `io`, and coder infrastructure. Standalone extraction would require replacing these dependency-injection points.

### CLI Usability

The repo map cannot be invoked as a standalone CLI command from Aider. It is an internal component of the chat loop. Users who want CLI access must use one of the reimplementations below.

### MCP Server Potential

No official MCP server exists for Aider's repo map. RepoMapper provides one. The architecture (input: file paths + token budget; output: ranked text tree) maps cleanly to an MCP tool interface.

### Port Effort

A port to another language requires: (1) tree-sitter bindings for the target language, (2) a graph library with PageRank, (3) a token counter, (4) a tag-caching layer. The TypeScript port (agentmap) demonstrates this is feasible with ~500 lines of application code on top of `ts-morph`.

## 8. Standalone Reimplementations

### RepoMapper (Python, MIT)

- **Repository**: `pdavis68/RepoMapper`
- **Language**: Python (same stack as Aider: tree-sitter, networkx, diskcache, grep-ast)
- **License**: MIT
- **Stars**: 209
- **Features**: CLI tool and MCP server; tree-sitter parsing, PageRank ranking, token-aware output, persistent caching, 35+ languages (RepoMapper).
- **Methodology**: The author fed Aider's `RepoMap` class to an LLM (Claude or Gemini 2.5 Pro) to generate specifications, then used those specs with Aider and Claude 3.7 to build the implementation. The author states it is "100% based on Aider's Repo map functionality, but I don't believe it shares any code with it" (RepoMapper).
- **MCP Support**: Yes, via stdio-based MCP server (RepoMapper).

### agentmap (TypeScript/JS, license not specified)

- **Repository**: `vivalafreak1/agentmap`
- **Language**: TypeScript/JavaScript (uses `ts-morph` instead of tree-sitter)
- **License**: Not explicitly stated in archived source; credited as "faithful ports of Aider's approach (credit: Aider, Apache-2.0)"
- **Language Coverage**: TS/JS only (by design, built on ts-morph)
- **Features**: Personalized PageRank (file + symbol graphs), token-budget output (`--map [--tokens N]`), agent-loop integration with post-commit auto-refresh and PreToolUse hook, CLI dispatch via `--any <query>` (agentmap).
- **Self-Reported Token Savings**: 99.8% for whole-repo map, 99.9% for reuse-before-rebuild lookup, 99.2% for blast-radius, 99% for find-symbol (agentmap). Cold build ~1.2s, warm cached query ~0.2s.
- **Limitations**: TS/JS only; file-level import graph, not a full reference graph; feature detection assumes Next.js app/ router (agentmap).

### Allenbrd/repomap

Not found in the archived sources. The research manifest does not include this reimplementation; it may not have been archived or may not exist at the time of research.

### lean-ctx (Rust, independent)

- **Repository**: `yvgude/lean-ctx`
- **Language**: Rust
- **Stars**: 2,600+
- **Features**: Personalized power-iteration PageRank, session-aware ranking (recent files boosted, task context weighting), token budget control (default 1024), binary search fitting, 26 languages via tree-sitter (Comparisons).
- **Key Distinction**: Works with 28 agents (Cursor, Claude Code, Codex, Windsurf, Gemini, and others) via MCP, unlike Aider's repo map which is locked to Aider CLI (Comparisons).

## 9. Benchmark Provenance

### Self-Reported Figures (agentmap)

agentmap claims "98% fewer tokens (up to 99.9% per task) vs reading raw files" (agentmap). These are self-reported from the project's own testing on TypeScript/JavaScript repositories. No independent peer review or replication is cited.

### Independent Comparison (Stacklit Discussion, 2026-04-10)

A community comparison on the Stacklit GitHub discussion forum ranked code-context tools by token cost on a ~10k-line repo (Comparisons). Aider's repo-map was listed at ~1k tokens versus 50k-500k for full-dump tools (Repomix, Gitingest, code2prompt, files-to-prompt). However, this comparison was posted by a community member, not a controlled benchmark, and the Star counts listed are for entire projects, not just the repo-map feature.

### No Isolated Benchmark Exists

No source in the archive provides a controlled, isolated benchmark measuring repo-map's effect on LLM task success rate, code quality, or edit accuracy. The available evidence is limited to token-count comparisons and user-reported qualitative experiences.

## 10. Unarchived/Excluded Sources

| URL | Status | Reason |
|-----|--------|--------|
| `aider.chat/docs/languages.html` | NOT ARCHIVED | All fetch methods exhausted |
| `github.com/Aider-AI/aider/pull/5052` | NOT ARCHIVED | All fetch methods exhausted |
| `github.com/Aider-AI/aider/issues/45` | NOT ARCHIVED | All fetch methods exhausted |
| `github.com/Aider-AI/aider/issues/330` | NOT ARCHIVED | All fetch methods exhausted |
| `github.com/aaif-goose/goose/issues/3382` | NOT ARCHIVED | All fetch methods exhausted |
| `dxt.so/mcp-server/coding-agents/repomapperpublic-mcp` | NOT ARCHIVED | All fetch methods exhausted |
| `github.com/shenxingy/Clade/blob/main/docs/research/2026-03-30-aider-research.md` | NOT ARCHIVED | All fetch methods exhausted |
| `github.com/Aider-AI/aider/blob/main/LICENSE` | EXCLUDED | Aider is Apache-2.0 (confirmed by project metadata and multiple references) |
| `raw.githubusercontent.com/Aider-AI/aider/main/LICENSE` | EXCLUDED | 404 on fetch; license confirmed via multiple references |
| `registry.npmjs.org/@raymondchins/agentmap` | EXCLUDED | npm package not found; agentmap is distributed via npx |
| `github.com/metric-space-ai/greppy` | Excluded | Rated Low reliability; data captured indirectly via Issue 3603 discussion in user-complaints-issues.md |

## Works Cited

"Aider Official Documentation: Repository Map." *Aider*, aider.chat/docs/repomap.html. Accessed 25 Sept. 2026.

"Building a Better Repository Map with Tree Sitter." *Aider Blog*, aider.chat/2023/10/22/repomap.html. 22 Oct. 2023.

"agentmap: A Queryable, Ranked Code-Relationship Map." *GitHub*, github.com/vivalafreak1/agentmap. Accessed 25 Sept. 2026.

"Comparisons: Repo Map vs Other Code Context Approaches." Archived from multiple sources. 25 Sept. 2026.

"Aider RepoMap Source Code (aider/repomap.py)." *GitHub*, github.com/Aider-AI/aider/blob/main/aider/repomap.py. Accessed 25 Sept. 2026.

"RepoMapper: Standalone Reimplementation of Aider Repo Map." *GitHub*, github.com/pdavis68/RepoMapper. Accessed 25 Sept. 2026.

"User Feedback and Complaints about Aider Repo Map." Archived from multiple GitHub Issues (#752, #3932, #3902, #3187, #3796, #3297, #1385, #3603) and MeetsMore Engineering Blog. 25 Sept. 2026.
