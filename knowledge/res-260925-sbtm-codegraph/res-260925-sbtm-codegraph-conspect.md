# CodeGraph (colbymchenry/codegraph) -- Pre-Indexed Code Knowledge Graph for AI Coding Agents

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 12
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

**Disambiguation:** Several unrelated projects share the name "CodeGraph." This
conspect covers only `colbymchenry/codegraph` on GitHub -- the pre-indexed code
knowledge graph distributed as an MCP server for AI coding agents. Other
projects named CodeGraph (e.g., xnuinside/codegraph, code-graph-rag) are
distinct and unaddressed here.

## 1. Identity and Project Metadata

CodeGraph is a pre-indexed code knowledge graph created by Colby McHenry. The
GitHub repository (`colbymchenry/codegraph`) was created on 2026-01-18 and, as
of 2026-09-25, has 72,080 stars, 4,625 forks, 573 open issues, and 171
watchers. The repository language is listed as C, though the application is
primarily TypeScript with a native Rust extraction kernel. The latest release is
v1.6.0 (published 2026-08-26), distributed as self-contained binaries for
darwin-arm64, darwin-x64, linux-arm64, linux-x64, win32-arm64, and win32-x64.
The linux-x64 binary alone has 34,725 downloads as of the release metadata
("github-latest-release.json"). The npm package `@colbymchenry/codegraph` is
also published (latest tag: 1.6.0) with dependencies including tree-sitter,
better-sqlite3, sqlite-vss, and commander ("npm-package.json").

The project is licensed under the MIT License, copyright 2026 Colby McHenry
("license.txt"). Note: the andrew.ooo review characterizes the license as
"Apache 2.0" ("andrew-ooo-review.md"), which contradicts the archived LICENSE
file. The LICENSE file is treated as authoritative here.

### Contributor Concentration (Bus Factor)

The contributors API endpoint returns 30 contributors ("github-contributors.json").
The creator, colbymchenry, accounts for 928 of the approximately 1,028 total
contributions visible in the top-30 list. The next-highest human contributor
(omonien) has 16. Excluding the github-actions[bot] (27 contributions), roughly
391 of approximately 430 non-bot commits come from the creator -- a
contributor concentration of approximately 91%. This constitutes a bus factor of
one: the project's development is overwhelmingly driven by a single maintainer.

## 2. Mechanism and Architecture

CodeGraph combines a TypeScript application with a native Rust extraction kernel
that uses tree-sitter for AST parsing across 20+ languages. It stores
relationships and full-text search in a local SQLite database with FTS5
("rywalker-analysis.md"). The architecture requires no embeddings, no vector
database, and no API keys -- it is a pure structural graph plus full-text
search ("andrew-ooo-review.md").

The primary MCP tool is `codegraph_explore`, exposed by default. Additional tools
are gated behind an environment variable. The tool uses adaptive output sizing
to fit responses within context windows ("rywalker-analysis.md").

Auto-sync is driven by native filesystem events (FSEvents on macOS, inotify on
Linux) with debounced re-indexing. When the watcher encounters lock contention
or other failures, it degrades and displays a staleness banner rather than
silently serving stale data ("github-open-issues.json", issue #1959). The
v1.6.0 release notes confirm fixes for a disk-space leak where a force-killed
session could leave a WAL (write-ahead log) growing without bound
("github-latest-release.json").

Per-language cross-file coverage varies. The rywalker analysis cites Rust at
86.7% and Liquid at 73.8% ("rywalker-analysis.md"). The andrew.ooo review
notes that top-tier languages (TypeScript, JavaScript, Python, Go, Rust, Java)
have "excellent" coverage while Pascal/Delphi and Liquid have "thinner symbol
coverage" ("andrew-ooo-review.md").

Framework-aware routing supports 14 web frameworks, and cross-language bridging
covers Swift-to-ObjC and React Native ("andrew-ooo-review.md").

## 3. Integration and Installation

CodeGraph communicates via stdio MCP. The installer writes an entry into the
agent configuration -- for OpenCode, this is `mcp.servers.codegraph` with
`codemode` set to false ("andrew-ooo-review.md"). The installer targets 9
claimed agent platforms: Claude Code, Codex CLI, Gemini CLI, Cursor, OpenCode,
AntiGravity, Kiro, CoPilot, and Hermes Agent ("github-api-metadata.json",
description field; "andrew-ooo-review.md").

The binary is self-contained. Installation writes an index directory and updates
`.gitignore`. The v1.6.0 release adds `codegraph install --yes --init` for
non-interactive setup and `codegraph install --location=local` for per-project
Codex configuration ("github-latest-release.json").

## 4. Benchmark Provenance

### 4a. Vendor Benchmark (README, re-measured 2026-08-05)

The README benchmark was re-measured on 2026-08-05 using Claude Opus 4.8. The
methodology uses one architecture question per repository, headless CLI mode
(blocked in both arms to prevent CLI bypass), four runs per arm, and reports
the median over 7 repositories. The README explicitly notes that these numbers
are lower than the earlier Opus 4.7 run because the baseline (without
CodeGraph) got stronger ("rywalker-analysis.md").

Headline results (VENDOR-RUN): 44% lower average cost, 62% fewer processed
tokens, 88% fewer tool calls, file reads reduced to zero ("rywalker-analysis.md").

Per-repo breakdown from the andrew.ooo review (which reproduces the README
table, though using the earlier Opus 4.7 figures):

| Codebase   | Language  | Files  | Cost (with/without)   | Tokens (with/without)  | Time (with/without)     | Tool calls |
|------------|-----------|--------|-----------------------|------------------------|-------------------------|------------|
| VS Code    | TS        | ~10k   | $0.60 / $0.80         | 601k / 2.8M            | 1m10s / 2m26s           | 8 / 55     |
| Excalidraw | TS        | ~640   | $0.43 / $0.90         | 344k / 3.5M            | 48s / 2m58s             | 3 / 79     |
| Django     | Python    | ~3k    | $0.59 / $0.67         | 739k / 1.2M            | 1m19s / 1m38s           | 9 / 19     |
| Tokio      | Rust      | ~790   | $0.42 / $2.41         | 379k / 2.6M            | 53s / 3m2s              | 4 / 53     |
| OkHttp     | Java      | ~645   | $0.47 / $0.47         | 636k / 730k            | 42s / 1m1s              | 6 / 11     |
| Gin        | Go        | ~110   | $0.37 / $0.47         | 444k / 675k            | 44s / 1m0s              | 6 / 10     |
| Alamofire  | Swift     | ~110   | $0.61 / $1.14         | 1.0M / 2.8M            | 1m17s / 2m27s           | 12 / 69    |

("andrew-ooo-review.md") -- labeled VENDOR-RUN. The andrew.ooo review notes
these are the Opus 4.7 figures; the August 5 re-measurement on Opus 4.8
produced the stronger headline numbers cited above.

### 4b. Independent Benchmark (harrisonsec.com, Hono)

Harrison Guo ran an independent benchmark on the Hono framework (~280
TypeScript files), 5 questions, 40 runs (5 questions x 4 repeats x 2
conditions) on Claude Opus 4.8, with `--strict-mcp-config`, pre-warmed daemon,
and per-run MCP connection verification ("harrison-independent-benchmark.md").

Results:
- Tool calls: -55% (14.0 avg to 6.3 avg) -- DIRECTION REPRODUCED
- Cost: +6.8% -- NOT REPRODUCED, OPPOSITE SIGN from the vendor's -35%
- Tokens: -22.6%
- Latency: -20.3%

Per-question breakdown:
- Q1 (route lookup): -12.9% tool calls, +22.5% cost
- Q2 (middleware trace): -20.0% tool calls, +43.4% cost
- Q3 (multi-runtime): -80.1% tool calls, -28.9% cost (unambiguous win)
- Q4 (refactor): -40.5% tool calls, +26.5% cost
- Q5 (text search, control): -11.1% tool calls, -5.3% cost

Key finding: narrow-scope questions (Q1, Q2, Q4) are 20-43% MORE expensive with
CodeGraph. The cost win only appears on broad multi-file navigation (Q3).

Variance finding: baseline grep+Read occasionally spiraled to 47-52 tool calls;
CodeGraph never exceeded 16. This bounded worst-case behavior is a meaningful
reliability advantage even when average cost is neutral.

Cross-validation summary (harrisonsec.com vs vendor):
- Tool calls: Published -71%, independent -55% -- reproduces, same ballpark
- Latency: Published -46%, independent -20% -- directionally, half the magnitude
- Tokens: Published -57%, independent -23% -- directionally, smaller
- Cost: Published -35%, independent +6.8% -- DOES NOT REPRODUCE

### 4c. Week-Long Review (Level Up Coding)

Chew Loong Nian, an AI engineer, tested CodeGraph over seven days across four
real repositories and reported: ~70% fewer tool calls, 59% fewer tokens, 49%
faster response time ("levelup-week-long-review.md"). The author notes these
figures "largely restate the headline numbers [the] author publishes" and that
the gap between "median across seven repos" and "newest model on one validation
pass" is "the honest texture you want to see." The author also observes that
cost reduction (18%) lags token reduction (51%) because "CodeGraph trades many
cheap discovery tokens for fewer, denser graph-query tokens."

### 4d. OpenCodeReview Issue #1056 (200-PR Benchmark)

GitHub issue #1056 describes an OpenCodeReview integration proposal that ran a
200-PR benchmark, reporting +7.7% more true positives and -43% zero-line
comments. This issue was NOT ARCHIVED (trafilatura blocked by permission
rules; content captured from websearch highlights only) and is therefore not
cited in the body. It is listed under "Unarchived/Excluded" below.

## 5. Review Sentiment

### Praise

- **andrew.ooo** (2026-05-28): "CodeGraph is the strongest pitch yet for symbol
  graphs as the structural layer beneath AI coding agents. The benchmark is
  reproducible, the install story is the lowest friction in MCP code search"
  ("andrew-ooo-review.md").

- **Independent benchmark** (harrisonsec.com): "On TypeScript / Rust / Go
  projects, install CodeGraph if you want fewer agent steps, lower latency, and
  bounded worst-case exploration -- those reproduce on an independent repo"
  ("harrison-independent-benchmark.md").

- **Reddit testimonial** (quoted in andrew.ooo review): "On a 200k-line legacy
  Java service we cut Claude Code's average session cost from $4 to $1.50"
  ("andrew-ooo-review.md"). NOTE: Reddit source was not archivable; this quote
  is cited only as reproduced in the archived andrew.ooo review.

### Complaints

- **Cost wash on small repos**: The harrisonsec.com benchmark found CodeGraph
  was +6.8% more expensive on Hono (~280 files), with narrow-scope questions
  20-43% more expensive ("harrison-independent-benchmark.md").

- **Fuzzy-question blindness**: "Symbol graphs don't help with fuzzy questions.
  If you don't know what the symbol is called, the graph can't find it. Vector
  search degrades more gracefully here" ("andrew-ooo-review.md").

- **Correctness still needing checks**: The rywalker analysis notes that
  "correctness still needs checks: release notes list language-resolution and
  index-drift fixes" ("rywalker-analysis.md").

- **v1.5.0 context-occupancy report**: GitHub user LeDuyViet reported on
  2026-08-03 that v1.5.0 in Cursor consumed approximately 60.2K context tokens
  versus 40.5K for grep/read on a roughly 2,300-file Go repository. Both
  sessions reportedly reached the correct answer, but CodeGraph consumed 49%
  more context ("rywalker-analysis.md").

## 6. Hacker News Presence and Community Depth

The researcher verified via Algolia search that NO dedicated Hacker News thread
exists for `colbymchenry/codegraph`. Algolia results for "codegraph" return
only unrelated projects (xnuinside/codegraph, code-graph-rag, etc.). The
andrew.ooo review references "what convinced Hacker News" but this appears to
reference general HN discussion or comments rather than a dedicated Show HN
post (".source-urls.txt", lines 58-61).

The andrew.ooo review also quotes an HN comment: "Symbol graph beats embeddings
for 'who calls this?' questions. Embeddings are fuzzy by design. CodeGraph just
knows" ("andrew-ooo-review.md"). This quote exists but does not establish a
dedicated thread.

The overall assessment, supported by the contributor concentration data and the
absence of a dedicated HN thread despite 72k+ stars, is that community depth
does not match star count. The project has high adoption visibility but thin
contributor breadth.

## 7. Privacy and Telemetry

CodeGraph makes local-only claims: the graph is stored locally, no source code
or paths leave the machine. However, anonymous telemetry is ON by default. The
telemetry policy describes: a persistent random machine identifier, coarse
indexing statistics, and daily tool-use totals. It excludes source code, paths,
symbol names, and search queries. Opt-out is via `codegraph telemetry off` or
`DO_NOT_TRACK=1` ("rywalker-analysis.md").

A September 14, 2026 report raises an UNRESOLVED discrepancy: code inspection
allegedly shows that switching telemetry off preserves the machine identifier
and may leave existing processes using cached consent. This issue was open as of
September 15, 2026 when checked by the rywalker analysis ("rywalker-analysis.md").
The status of issue #1869 (the opt-out discrepancy report) is flagged as
**unresolved**.

## 8. Limitations

- **Pre-1.0 churn**: The project went through rapid iteration before reaching
  v1.0, and the v1.6.0 release notes still address fundamental issues like WAL
  leaks and index drift ("github-latest-release.json").

- **Single maintainer**: As documented in Section 1, approximately 91% of
  non-bot commits come from one person. Bus factor is one.

- **Staleness/debounce**: Under lock contention, the watcher can latch off and
  serve from a frozen index with a staleness banner. The FileLock treats a live
  holder's lock as stale after 2 minutes regardless of PID status
  ("github-open-issues.json", issue #1959).

- **Per-project index, no unified cross-repo index**: "No multi-repo workspace
  yet. Index lives per project" ("andrew-ooo-review.md").

- **Large-repo index times**: "First-index time scales with repo size. A 10k-
  file TS repo takes a couple of minutes to parse" ("andrew-ooo-review.md").

- **Language-coverage variance**: Rust 86.7%, Liquid 73.8%
  ("rywalker-analysis.md"). Top-tier languages are excellent; Pascal/Delphi and
  Liquid have "thinner symbol coverage" ("andrew-ooo-review.md").

- **Cost paradox on sub-500-file repos**: The harrisonsec.com benchmark found
  CodeGraph was approximately 7% more expensive on Hono (~280 files), with
  narrow-scope questions 20-43% more expensive. "Skip when: you're optimizing
  dollar cost on a sub-~500-file repo (may cost slightly more)"
  ("harrison-independent-benchmark.md").

- **Sub-agent bypass effect**: When a child agent explores by reading files
  directly rather than querying the graph, the graph becomes overhead. The
  harrisonsec.com benchmark found that Q5 (text search, a control question) showed
  only -5.3% cost difference, suggesting the graph provides minimal value for
  text-search-dominant workflows ("harrison-independent-benchmark.md").

## 9. Comparisons

### vs Aider repo-map

The archived sources do not contain a direct comparison with Aider's repo-map.
No data is available from these sources.

### vs graft

The archived sources do not contain a direct comparison with graft. No data is
available from these sources.

### vs GitNexus

GitNexus is a "zero-server code intelligence engine that runs entirely in the
browser" with approximately 45,000 GitHub stars (as of August 2026). Its
license is PolyForm Noncommercial, which "differs materially from CodeGraph's
MIT terms" ("rywalker-analysis.md", "comparison-sentra.md"). GitNexus "exposes
a larger named MCP tool surface, including targeted impact, trace, and rename
operations, and uses embedded LadybugDB" ("rywalker-analysis.md"). The Sentra
comparison table shows both as local, single-repo, free/OSS tools with near-
zero setup ("comparison-sentra.md").

### vs codebase-memory-mcp

codebase-memory-mcp is "a high-performance code intelligence MCP server
written in C" with 14 MCP tools and approximately 38,000 GitHub stars. License:
MIT ("comparison-sentra.md"). CodeGraph has 1 tool by default (8 available)
versus 14 tools. Both are local, single-repo, MIT-licensed ("comparison-
sentra.md").

### vs Claude Context

The archived sources do not contain a direct comparison with Claude Context.
No data is available from these sources.

## Works Cited

"Andrew.ooo Review: CodeGraph Review -- Pre-Indexed Knowledge Graph for AI
Agents." andrew.ooo, 28 May 2026,
andrew.ooo/posts/codegraph-review-pre-indexed-knowledge-graph-claude-code/.

"Comparison: GitNexus vs Codebase-Memory-MCP vs CodeGraph." Sentra, Aug. 2026,
www.sentra.app/articles/gitnexus-codebase-memory-mcp-codegraph-compared.

GitHub API. "Repository: colbymchenry/codegraph." GitHub REST API, 25 Sept. 2026,
api.github.com/repos/colbymchenry/codegraph.

GitHub API. "Contributors: colbymchenry/codegraph." GitHub REST API, 25 Sept.
2026, api.github.com/repos/colbymchenry/codegraph/contributors?per_page=30.

GitHub API. "Issues: colbymchenry/codegraph (open)." GitHub REST API, 25 Sept.
2026, api.github.com/repos/colbymchenry/codegraph/issues?state=open&per_page=10.

GitHub API. "Issues: colbymchenry/codegraph (bug)." GitHub REST API, 25 Sept.
2026, api.github.com/repos/colbymchenry/codegraph/issues?state=open&labels=bug
&per_page=5.

GitHub API. "Latest Release: colbymchenry/codegraph v1.6.0." GitHub REST API,
25 Sept. 2026, api.github.com/repos/colbymchenry/codegraph/releases/latest.

Guo, Harrison. "I Tested CodeGraph on Hono. The Tool-Call Savings Reproduce --
the Cost Savings Don't." harrisonsec.com, 1 June 2026,
harrisonsec.com/blog/i-tested-codegraph-on-hono-benchmark/.

McHenry, Colby. "CodeGraph." MIT License, 2026,
raw.githubusercontent.com/colbymchenry/codegraph/main/LICENSE.

NPM. "@colbymchenry/codegraph." npm Registry, 25 Sept. 2026,
registry.npmjs.org/@colbymchenry/codegraph.

Nian, Chew Loong. "I Gave Claude Code a Map of My Repo -- CodeGraph Killed 70%
of Its Tool Calls." Level Up Coding, 29 May 2026,
levelup.gitconnected.com/i-gave-claude-code-a-map-of-my-repo-codegraph-killed
-70-of-its-tool-calls-9a7f8400a97d.

Walker, Ry. "CodeGraph Analysis." Ry Walker Research, 15 Sept. 2026,
rywalker.com/research/codegraph.

## Unarchived/Excluded Sources

| Source | Reason |
|--------|--------|
| Reddit r/mcp announcement thread (2026-01-25) | Reddit blocks webfetch extraction; not archived |
| Reddit r/mcp second thread (2026-06-16) | Reddit blocks webfetch extraction; not archived |
| Reddit r/ClaudeCode Codegraph vs Graphify (2026-06-25) | Reddit blocks webfetch extraction; not archived |
| GitHub issue #1056 -- OpenCodeReview 200-PR benchmark | trafilatura blocked by permission rules; content captured from websearch highlights only |
| saas.pet review (2026-08-08) | Marketing-style review, not independent testing; vendor-adjacent |
| toolgenix review (2026-06-06) | SEO/marketing review, minimal independent testing |
| bighatgroup blog (2026-05-26) | Early coverage, stale claims, no independent testing |
| developersdigest.tech (2026-05-29) | General coverage, not independent testing |
| medium.com tools-cut-to-one (2026-07-03) | General coverage article |
| Instagram reel | Social media, no methodology |
