# Conspect: Serena (oraios/serena) -- MCP Server Wrapping Language Servers for Coding Agents

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 16
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## License (PROMINENT)

**WARNING: The Serena application is GPL-3.0-or-later (copyleft).** Any
distribution that combines Serena with other code -- including the
`serena-agent` package -- is subject to GPL-3.0-or-later terms. This means
proprietary or commercial projects that distribute a combined work must
open-source the entire combined work under GPL-3.0-or-later. There is no
dual-license or commercial exception (License-Overview).

The SolidLSP library (the LSP client layer) is MIT-licensed and may be
extracted and used separately under MIT terms. The repository carries both
LICENSES/MIT.txt and LICENSES/GPL-3.0-or-later.txt in a per-component
split (License-Detail).

Historical note: Serena v1.7.0 and all earlier releases remain under MIT.
The GPL switch happened at v2 with architectural changes (License-Overview).

---

## 1. Identity and Project Metadata

Serena is an MCP (Model Context Protocol) toolkit that wraps Language
Server Protocol servers to give coding agents IDE-grade symbol retrieval,
editing, and refactoring capabilities. It is described as "the IDE for your
agent" (GitHub API Metadata; Readme).

| Field | Value |
|-------|-------|
| Repository | `oraios/serena` (github.com/oraios/serena) |
| Organization | oraios (Jain & Panchenko IT-Berater Partnerschaft / Oraios AI) |
| Created | 2025-03-23 |
| Last push | 2026-09-24 |
| Stars | 29,801 |
| Forks | 2,034 |
| Open issues | 173 |
| Primary language | Python |
| Watchers/subscribers | 93 |
| Topics | agent, ai, ai-coding, claude, claude-code, codex, ide, jetbrains, language-server, mcp-server, programming, vibe-coding |

(GitHub API Metadata)

---

## 2. Mechanism: Live LSP Analysis, Not a Pre-Indexed Graph

Serena operates as a live LSP proxy. It does NOT build a pre-indexed
knowledge graph, import graph, call graph, or blast-radius map. Instead,
every query hits a running language server in real time
(Trace-MCP-Comparison).

SolidLSP is the underlying LSP client library, derived from the multilspy
project. Per-file document-symbol caches are stored under
`.serena/cache/` for performance. Memories (agent-written notes) are
stored as plain markdown files under `.serena/memories/` with topic
namespacing (Readme; Privacy-Policy; Trace-MCP-Comparison).

**What is explicitly absent:** No call graph, no import graph, no blast
radius, no importance ranking. The LSP client layer does expose
callHierarchy/incomingCalls, but no tool class surfaces these to the
agent (Trace-MCP-Comparison).

---

## 3. Two Backends

### 3a. Free Language-Server Backend (default)

- Supports 40+ programming languages via LSP.
- Each language server must be installed separately by the user.
- Provides symbol retrieval, symbolic editing, rename (symbols only),
  diagnostics, and file operations.
- Interactive debugging is NOT available in this backend.
- Move, inline, and propagate-deletions are NOT available.

(Readme; Tools-and-API-Docs)

### 3b. Paid JetBrains Plugin

- Available at plugins.jetbrains.com; paid with free trial.
- Not a UI extension -- it is a language intelligence backend that the
  Serena MCP server leverages (JetBrains-Plugin-Docs).
- Adds: move symbol/file/directory, inline, propagate deletions, type
  hierarchy, debugging (REPL-style interactive interface), external
  library indexing, and enhanced multi-agent support.
- Rider and CLion are explicitly unsupported (Starlog-Review).
- Configuration: global (`serena init -b JetBrains`), per-instance
  (`--language-backend JetBrains`), or per-project (`.serena/project.yml`).

(JetBrains-Plugin-Docs; Readme)

---

## 4. Tool Surface

### Tool Groups (28 enabled by default, 22 optional out of 50 total)

| Group | Key Tools | Notes |
|-------|-----------|-------|
| `symbol_tools` | find_symbol, find_declaration, find_implementations, find_referencing_symbols, get_symbols_overview, rename_symbol, replace_symbol_body, insert_after_symbol, insert_before_symbol, safe_delete_symbol, get_diagnostics_for_file | Core symbol operations |
| `jetbrains_tools` | jet_brains_find_symbol, jet_brains_rename, jet_brains_move, jet_brains_inline_symbol, jet_brains_type_hierarchy, jet_brains_debug, jet_brains_safe_delete, jet_brains_list_insepections, jet_brains_run_inspections | Optional; requires JetBrains backend |
| `file_tools` | read_file, find_file, list_dir, search_for_pattern, replace_content, create_text_file, replace_in_files | Basic file operations |
| `memory_tools` | read_memory, write_memory, edit_memory, delete_memory, list_memories, rename_memory | Markdown-backed project memories |
| `config_tools` | activate_project, get_current_config, open_dashboard, remove_project | Session/project config |
| `cmd_tools` | execute_shell_command | Shell access |
| `workflow_tools` | initial_instructions, onboarding, serena_info | Agent onboarding |
| `repl_tools` | serena_repl | BETA in v2; single tool executing Python code |

(Tools-and-API-Docs)

### REPL v2 Interface (BETA)

The REPL provides programmatic access through facades: `lsp` (symbol ops),
`jb` (JetBrains ops), `cfg` (config), `fs` (file ops), `edit`
(content modification), `mem` (memories), `shell` (shell commands), and
`ext` (external project access, optional). Advantages include composition
of multiple operations in a single call, context economy (only needed
results enter the conversation), and results as processable objects
(Tools-and-API-Docs).

---

## 5. Integration

### MCP Transports

Serena supports stdio, HTTP, and SSE transports (Readme).

### Installation

Primary method: `uv tool install -p 3.13 serena-agent` (also via `uvx
--from git+https://github.com/oraios/serena serena`). The maintainers
explicitly warn NOT to install from MCP marketplaces -- the PyPI package
named "serena" is a different project (an AMQP client) (GitHub-Releases;
Trace-MCP-Comparison).

### Runtime Prerequisites

- `uv` (Astral) as the package manager.
- Per-language LSP servers must be installed separately (e.g., `pyright`,
  `jdtls`, `clangd`).

(Readme; MCP-Directory-Guide)

### Listed Clients

Claude Code, Codex, OpenCode, Gemini-CLI, VSCode, Cursor, JetBrains IDEs
(Copilot, Junie, JetBrains AI Assistant), Claude Desktop, Codex App,
OpenWebUI, and any MCP-capable client (Readme).

---

## 6. Empirical Results

### 6a. ManoMano Benchmark (Real-Company, Self-Published Manual Benchmark)

Source: Vincent Aubrun (Staff Engineer, ManoMano), published 2026-03-19,
benchmark date 2026-02-02, using Sonnet 4.5 (Manomano-Benchmark).

- **Test project:** Core payment service, Java multi-module, 381 classes,
  36,407 LOC, 1,017 tests.
- **Four tasks** tested across three setups: Vanilla Claude, Claude + LSP
  (built-in), Claude + Serena.

**Refactoring task results (the headline):**

| Setup | Subagents | Time | Cost | Outcome |
|-------|-----------|------|------|---------|
| Vanilla Claude | 12 | 1 hr | $23.54 | FAILED (project not building) |
| Claude + built-in LSP | -- | 1 hr | $28.63 | GAVE UP (9 tests still failing) |
| Claude + Serena | 4 | 45 min | $27.30 | SUCCESS (all 1,017 tests pass) |

**Negative results from the same source:** Quick exploration (read-only)
tasks cost 4x more and ran 60% slower with Serena. Built-in LSP
hallucinated methods and missed test classes during analysis
(Manomano-Benchmark).

**Decision:** ManoMano adopted Serena for all contributors, pushing the
`.serena` folder to repositories (Manomano-Benchmark).

### 6b. Self-Reported Token Savings

- **andrew.ooo (2026-05-03):** Rename across a TypeScript monorepo:
  38K tokens without Serena vs 4K tokens with Serena (one-shot, no
  hallucinated edits). Self-reported (Andrew-Ooo-Review).
- **md.eknath (2026-02-04):** ~100K-line Android/KMP project: ~70%
  token savings, from ~15,000 tokens to ~4,500 tokens for a "find auth
  logic" query. Self-reported, non-independent benchmark
  (MD-Eknath-Token-Savings).

### 6c. No Formal Independent Controlled Benchmark Exists

The maintainers stated in a June 2026 GitHub Discussion that they were
"running benchmarks of serena on various real-world tasks and are planning
to publish the results soon" (GitHub-Discussion-1592). As of the
archiving date, no formal independent controlled benchmark has been
published. The ManoMano data is the closest to independent but is
self-published and manual (Manomano-Benchmark).

---

## 7. Review Sentiment

### Praise

- Claude Opus 4.6 (evaluation-overview): "Serena's IDE-backed semantic
  tools are the single most impactful addition to my toolkit."
- GPT-5.4 (evaluation-overview): "It gives me the missing IDE-level
  understanding of symbols, references, and refactorings."
- ManoMano: "Serena is now an absolute must-have in our setup."
- r/ClaudeAI: "Try out Serena MCP. Thank me later" -- hundreds of
  upvotes (Andrew-Ooo-Review).

### Complaints

- **Install friction:** "75% of the time it takes some finagling" --
  community report from r/ClaudeAI (Andrew-Ooo-Review).
- **Per-request tool-description overhead:** Registering an MCP server
  adds its tool descriptions to every request; for small projects this
  overhead outweighs token savings (MCP-Directory-Guide).
- **Users hitting context limits faster** when the full tool set is
  loaded (MCP-Directory-Guide).
- **Starlog warning (2026-05-08):** 23,958 stars "relative to a project
  that still has rough edges and limited production adoption patterns
  raises yellow flags about hype cycles." Described as "a sophisticated
  experiment in agent-IDE integration that works brilliantly in specific
  scenarios and struggles in others" (Starlog-Review).

---

## 8. Limitations and Failure Modes

- **Language-server cold start on fresh checkouts:** Several minutes on
  large monorepos; empty results during the warm-up window. `serena
  project index` pre-builds the symbol index to mitigate this
  (Andrew-Ooo-Review; MCP-Directory-Guide).
- **Agent context behavior:** When Serena's agent context is active, the
  tools `read_file`, `search_for_pattern`, and `execute_shell_command`
  are disabled (provided by the client already) (Readme).
- **Slow jdtls startup** for Java projects (MCP-Directory-Guide).
- **clangd requires compile_commands.json** for C/C++ projects
  (MCP-Directory-Guide).
- **No data on Docker memory footprint** in any archived source.
- **No call-graph capability** -- explicitly absent (Trace-MCP-Comparison).
- **Refactor coverage uneven:** move, inline, and propagate-deletions
  require the JetBrains backend (Andrew-Ooo-Review; Readme).
- **Memory system is simple project-local markdown files**, not a vector
  store; no staleness verification against code at recall time
  (Andrew-Ooo-Review; Trace-MCP-Comparison).

---

## 9. Privacy

- **Local-only operation** confirmed by official documentation: no
  personal data or project data sent to external servers (Privacy-Policy).
- Anonymous telemetry collects only: Serena version, OS, language backend
  type, dashboard status, agent-context status (Privacy-Policy).
- Opt-out: `SERENA_USAGE_REPORTING=false` (Privacy-Policy).
- Memories and caches stored locally under `.serena/memories/` and
  `.serena/cache/` (Privacy-Policy).

---

## 10. Positioning: Where Serena Beats Graph-Based Tools and Where It Loses

### Where Serena Wins

- **Live semantic accuracy:** LSP handles overloads, re-exports,
  generics, and dynamic dispatch through interfaces -- cases where AST
  heuristics in graph-based tools get wrong results (Trace-MCP-Comparison).
- **Exact references:** 100% precise (not just lines but referencing
  symbols) (Readme).
- **Cross-file refactoring:** Rename, move, inline with all usages
  updated (Readme; Evaluation-Overview).
- **Agent-driven debugging** via the JetBrains plugin (JetBrains-Plugin-Docs).
- **Language breadth:** 40+ languages via real language servers
  (Readme).

### Where Serena Loses

- **No graph:** no import graph, no call graph, no impact traversal
  (Trace-MCP-Comparison).
- **No blast radius analysis** (Trace-MCP-Comparison).
- **No importance ranking** of symbols (Trace-MCP-Comparison).
- **No cross-repo linking** (Trace-MCP-Comparison).
- **No framework edges** -- language servers do not model framework
  conventions (Trace-MCP-Comparison).

### Verdict from Sources

"Pick Serena for one mainstream language with a first-class language
server, or if you need agent-driven debugging in JetBrains. Pick
trace-mcp for polyglot repositories, framework edges no language server
models, transitive impact analysis, and the work that comes after
navigation" (Trace-MCP-Comparison). Serena is **complementary** to
graph-based tools, not a substitute.

---

## Works Cited

Andrew-Ooo-Review. "Serena MCP Review: An LSP-Powered IDE for AI Agents."
andrew.ooo, 3 May 2026, andrew.ooo/posts/serena-mcp-coding-agent-ide-review/.

Evaluation-Overview. "Serena Evaluation Overview." Oraios, oraios.github.io/serena/04-evaluation/000_evaluation-intro.html.

GitHub-API-Metadata. "oraios/serena." GitHub API, api.github.com/repos/oraios/serena. Accessed 25 Sept. 2026.

GitHub-Discussion-1592. "Serena vs Headroom and RTK." GitHub Discussions, github.com/oraios/serena/discussions/1592, 21 Jun. 2026.

GitHub-Releases. "Serena GitHub Releases." GitHub API, api.github.com/repos/oraios/serena/releases. Accessed 25 Sept. 2026.

JetBrains-Plugin-Docs. "Serena JetBrains Plugin Documentation." Oraios, oraios.github.io/serena/02-usage/025_jetbrains_plugin.html.

License-Detail. "Serena License Documentation." Oraios, oraios.github.io/serena/01-about/060_license.html.

License-Overview. "LICENSE Overview -- oraios/serena." GitHub, raw.githubusercontent.com/oraios/serena/main/LICENSE.

Manomano-Benchmark. "Project AEGIS -- Benchmarking AI Agents and Why Serena is Our New Must-Have." Medium, 19 Mar. 2026, medium.com/manomano-tech/project-aegis-benchmarking-ai-agents-and-why-serena-is-our-new-must-have-311673db35dd.

MCP-Directory-Guide. "Serena MCP: Semantic Code Tools for Claude (2026 Guide)." mcp.directory, 12 Jun. 2026, mcp.directory/blog/serena-mcp-complete-guide-2026.

MD-Eknath-Token-Savings. "Supercharging Claude Code with Serena -- Save 70% on Tokens." md.eknath.dev, 4 Feb. 2026, md.eknath.dev/posts/ai-ml/serena-claude-code-setup/.

Privacy-Policy. "Serena Privacy Policy." Oraios, oraios.github.io/serena/01-about/070_privacy.html.

Readme. "README.md -- oraios/serena." GitHub, raw.githubusercontent.com/oraios/serena/main/README.md.

Starlog-Review. "Serena: The MCP Toolkit That Turns AI Agents into IDE-Native Developers." Starlog, 8 May 2026, starlog.is/articles/ai-dev-tools/oraios-serena/.

Tools-and-API-Docs. "Serena Tools and APIs Documentation." Oraios, oraios.github.io/serena/01-about/035_tools.html.

Trace-MCP-Comparison. "trace-mcp Comparison: Serena vs Graph-Based Tools." trace-mcp.com, 3 Sept. 2026, trace-mcp.com/comparisons.html.

---

## Unarchived/Excluded Sources

| Source | Reason |
|--------|--------|
| YouTube Open Source Friday interview (youtube.com/watch?v=QiB5B7DaF4M) | Not archived; content captured via websearch only |
| Glama MCP directory listing (glama.ai/mcp/servers/oraios/serena) | Not archived; directory listing, low relevance |
| PyPI serena package (pypi.org/pypi/serena/json) | Different project entirely (AMQP client by Lura Skye, not oraios/serena) |
| rywalker.com research page | Not archived; content captured via websearch |
| daily.dev post | Not archived; aggregator repost of GitHub README, low relevance |
| mcpmarket.com listing | Not archived; MCP marketplace listing, low relevance |
| mcpserverfinder.com listing | Not archived; MCP marketplace listing, low relevance |
| mcp.nacos.io listing | Not archived; older content, MCP marketplace listing, low relevance |

---

## Gaps in Archived Sources

1. **Docker/memory footprint:** No source reports Serena's memory usage
   or Docker resource requirements.
2. **Cold-start benchmarks:** No source quantifies language-server
   startup time across different project sizes in a controlled way.
3. **Independent controlled benchmark:** As of the archiving date, no
   formal independent benchmark exists. The ManoMano data is the closest
   but is self-published and manual.
4. **REPL v2 stability:** The REPL interface is marked BETA; no source
   reports production usage data or stability metrics for it.
5. **JetBrains unsupported IDEs:** Rider and CLion are noted as
   unsupported but no source explains why or whether support is planned.
6. **Upgrade path from v1 to v2:** No source describes migration
   complexity or breaking changes beyond the license shift.
