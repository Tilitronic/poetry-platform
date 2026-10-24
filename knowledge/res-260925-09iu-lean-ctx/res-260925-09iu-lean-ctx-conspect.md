# lean-ctx: Context-Compression / Context-Intelligence Layer for AI Coding Agents

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 9
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## Claim Verification

The following figures are asserted about lean-ctx in various places. The archived sources confirm, revise, or leave them unsubstantiated:

**Repo / org / language / license.** The GitHub API metadata confirms the repository is `yvgude/lean-ctx`, written in Rust, with an Apache License 2.0 (GitHub API metadata). LICENSE.txt states "Copyright 2026 Yves Gugger" (LICENSE.txt). The license SPDX identifier is `Apache-2.0`.

**Star count.** The archived GitHub API metadata reports 3,835 stargazers as of 25 September 2026 (GitHub API metadata). The homepage independently reports the same figure (leanctx-homepage.md). An earlier scan's lower figure was stale; the current figure is 3,835.

**"83 MCP tools."** The docs.rs crate page lists 79 MCP tools for version 3.8.11 and 84 for the latest version documented there (docsrs-crate-page.md). The tool count is version-dependent; 83 is within the observed range but is not a fixed figure.

**"298 config keys."** No archived source mentions or substantiates this number. It is unverified.

**"30+ agents."** The docs.rs page lists "24+ AI tools" for the version it documents (v3.8.11), while dudarik-blog-overview.md reports "30+ agents" in the current README context (dudarik-blog-overview.md). The 30+ figure is plausible for the current version but was not 30+ at the documented docs.rs snapshot.

**Contributor concentration.** The contributors.json data shows `yvgude` with 5,400 contributions. The next-highest contributor (`cedric013`) has 120. The top 10 contributors combined total approximately 5,764, of which the sole maintainer accounts for roughly 93.7% (contributors.json). This is a single-maintainer project by any practical measure.

## Mechanism: Five Capability Groups

### A. Context Compression

lean-ctx intercepts file reads and shell output before they reach the model. Rather than compressing an existing stream, it asks whether the agent needs the full content at all (grafsoul-review.md). The system offers ten read modes: full, map, signatures, diff, aggressive, entropy, lines:N-M, density, and others (docsrs-crate-page.md).

**Cached re-reads.** A content-addressed store using MD5 hash plus mtime as a dual-signal invalidation key stores previously-read files (dudarik-blog-overview.md). When a file has not changed, the re-read returns approximately 13 tokens instead of the approximately 2,000 tokens a full read would cost (dudarik-blog-overview.md). This is the source of the "up to 99%" figure that applies specifically to cached re-reads (docsrs-crate-page.md).

**Density and budget modes.** Read modes include density mode, which adjusts token density per read (docsrs-crate-page.md). Budget and density controls allow targeting a token budget per read operation (docsrs-crate-page.md).

**JIT disclosure with line spans.** The lines:N-M mode reads only specified line ranges, delivering content on demand rather than upfront (docsrs-crate-page.md). This is JIT (just-in-time) disclosure.

**Shell-output compression.** Shell command outputs are compressed across 95+ patterns in 34 categories (docsrs-crate-page.md). The wavect field report measured highest shell-output compression at 99%, with shell integrations accounting for 10.3% of total savings (wavect-field-report.md). A concrete example: `git status` output drops from approximately 800 tokens to approximately 120 tokens (dudarik-blog-overview.md).

**Tree-sitter language count.** 24+ languages are supported via tree-sitter AST parsing (docsrs-crate-page.md). The AST extraction allows signature-only or map-mode reads of large code files.

**Reversible content-addressed store.** The MD5-plus-mtime session cache is reversible: the original content can be retrieved from the store (dudarik-blog-overview.md). This makes the compression lossless for cached content.

### B. Intelligent Triage

The system uses Thompson Sampling bandits for adaptive mode prediction (docsrs-crate-page.md). This is an adaptive mode predictor that classifies intent and selects the appropriate read mode for each file access. The classification considers file type, size, and access patterns to route reads into the correct mode (dudarik-blog-overview.md).

Automatic size-based routing rules provide defaults: text config files (MD, JSON, TOML, YAML) are always read in full; code files under 8KB are read in full; code between 8KB and 96KB gets map mode (dependency trees plus API signatures); code over 96KB gets signatures mode (AST structural outlines); other files under 48KB are read in full, over 48KB get map mode (dudarik-blog-overview.md).

### C. Knowledge Routing

**Cross-session memory.** The Context Continuity Protocol (CCP) provides cross-session memory, allowing context to persist between separate agent sessions (docsrs-crate-page.md).

**Temporal-fact knowledge graph with contradiction detection.** The docs.rs page references a temporal-fact knowledge graph with contradiction detection (docsrs-crate-page.md). Property graph edges support typed relationships between facts. The knowledge graph is portable via a package format.

**Portable package format.** The CCP includes a portable package format for transporting cross-session knowledge (docsrs-crate-page.md).

### D. AI Value Gate

The AI Value Gate tracks cost-per-accepted-outcome as a metric (docsrs-crate-page.md). It includes a dashboard for visibility, budgets and throttling controls, and verification commands backed by Ed25519-signed savings ledgers (docsrs-crate-page.md). The signed ledger provides cryptographic verification that reported savings are authentic.

### E. Shadow Recommendations / Baseline Comparison Mode

Shadow mode denies native file-read and shell tools at the permission level, forcing the agent through `ctx_*` operations instead (grafsoul-review.md). This enables direct comparison between compressed and uncompressed reads, establishing a baseline. The shadow mode is the most invasive operational mode because it restricts the agent's tool access.

## Integration

**MCP server plus shell hooks (hybrid mode).** lean-ctx operates as both an MCP server and a set of shell hooks, creating a hybrid integration model (docsrs-crate-page.md). The MCP bridge uses JSON-RPC over stdio (dudarik-blog-overview.md). This dual-path approach covers both structured tool calls (MCP) and command-line output (shell hooks).

**Setup / onboard / init commands.** The project includes setup commands targeting specific AI coding tools. The proxy mode has an enable command that performs the invasive setup described below.

**Install footprint.** The binary is described as a "single lightweight local Rust binary with zero telemetry and zero external dependencies" (dudarik-blog-overview.md). Data and config are stored locally. The repo size is 195,342 KB per the GitHub API (github-api-metadata.json).

**PROXY mode.** This is the most invasive integration path. A single `proxy enable` command writes `*_BASE_URL` environment variable exports into the user's shell configuration file, edits `~/.claude/settings.json` and Codex configuration files, and installs an autostart service (macOS launch agent or Linux user systemd unit) (grafsoul-review.md; dudarik-blog-overview.md). The proxy rewrites shell config, modifies agent settings files, and installs a persistent background service. This is a significant system-level modification.

## Reviews

### Independent and Praise

The independent technical reviewer (grafsoul.com) identifies the core value proposition as the chain of operations rather than any single compression number: "find the right files by search, read them structurally, cache them, return a delta the second time, collapse command output, replace anything oversized with a reference, carry the task across chats" (grafsoul-review.md). The reviewer frames the most valuable aspect as the structural decision of what gets read at all, not the peak compression percentage.

The Wavect field report (a company deployment, not an independent review) measured 64.1% overall context reduction, 92.7% MCP traffic compression, and 56.6% estimated token cost reduction in a real-world deployment (wavect-field-report.md). The dudarik blog reports a 60-90% token consumption reduction range (dudarik-blog-overview.md).

### Independent and Critical

The grafsoul reviewer notes: "A tool that solves all four charges you in complexity, and paying that is only worth it when you genuinely have all four problems" (grafsoul-review.md).

### Complaints

**Proxy invasiveness.** Both the grafsoul review and dudarik blog identify the proxy as the most invasive component: it rewrites shell configuration files, edits agent settings, and installs background services (grafsoul-review.md; dudarik-blog-overview.md).

**Setup complexity / learning curve.** The breadth of ten read modes, 95+ shell patterns, and multiple integration paths creates a steep learning curve. The grafsoul reviewer implicitly notes this by flagging complexity cost (grafsoul-review.md).

**Compression is not edit context.** The Wavect field report explicitly states: "Compressed context is not edit context -- full reads before exact changes" (wavect-field-report.md). Compression helps with discovery and exploration, not with precise code edits.

**Shell-hook quote/expansion defect (security-adjacent).** Open issue #1862 reports that the hook rewrite wraps commands in double quotes, causing the outer shell to expand `$vars` before lean-ctx runs them. The executed command can differ from what the user or agent approved (open-issues-snapshot.md). A suggested fix is base64 encoding or stdin piping instead of double-quoted `-c` arguments. This is a security-adjacent defect because it breaks the invariant that the tool runs exactly the command it was given.

**Gains collapse when agent uses native tools.** The Wavect field report warns: "Integration discipline matters -- if agent keeps using native tools, gain drops" (wavect-field-report.md). The compression benefits are contingent on the agent routing through lean-ctx rather than bypassing it.

## Benchmarks and Provenance

The sources quote multiple different reduction ranges, and they describe different scopes:

- "60-90% fewer tokens" appears in the GitHub description (grafsoul-review.md).
- "50-80% fewer tokens on reads and shell output" appears in the README (grafsoul-review.md).
- "Up to 99%" applies specifically to cached re-reads (docsrs-crate-page.md; grafsoul-review.md).
- The grafsoul review explicitly notes: "These describe different things" (grafsoul-review.md).

The grafsoul benchmark table reports mode-specific figures: map mode achieves 98.1% compression at 8.2ms latency with 78% quality; signatures mode achieves 96.7% compression at 2.6ms with 96% quality; aggressive mode achieves 16.5% compression at 344 microseconds with 100% quality; entropy mode achieves 0.4% compression at 8.4ms with 100% quality (grafsoul-review.md). Quality here refers to information retention relative to full reads, not task acceptance.

**Per-session overhead.** The Wavect report does not provide a single per-session overhead figure but notes that observed tracking estimates are not controlled measurements (wavect-field-report.md). The grafsoul review does not report overhead figures.

**Methodology.** The project documents its approach through the README and docs, but the Wavect field report is the only deployment measurement. The Wavect report explicitly states: "These are observed tracking estimates, not a controlled productivity study" (wavect-field-report.md).

**External validation.** The Wavect report is the sole field measurement. It is self-reported by a company that deployed the tool. No independent controlled productivity study exists. The grafsoul review provides comparative analysis but no empirical measurements of its own (grafsoul-review.md). External validation is thin.

## Limitations

**Configuration complexity.** Ten read modes, 95+ shell patterns, multiple integration paths, and proxy setup create substantial configuration surface area (docsrs-crate-page.md; grafsoul-review.md).

**Shell-hook defect.** Issue #1862 documents a case where the executed command differs from the approved command due to shell variable expansion in double-quoted arguments (open-issues-snapshot.md). This is a correctness and security-adjacent concern.

**Lossy representation trade-offs.** The Wavect field report references the SWE-bench Verified minification study: a 42% token reduction lost 12 percentage points of accuracy (wavect-field-report.md). Another referenced study found that implicit continuous context compression failed to generalize. Compression can hurt quality when it removes information the model needs.

**Dependence on provider prompt-cache pricing.** The dudarik blog states: "If your model provider does not cache compressed payloads, you will save tokens on the network wire but not in billed usage" (dudarik-blog-overview.md). The financial savings depend on the provider's caching behavior, which is not guaranteed.

**Edit-heavy workflows benefit little.** The Wavect report notes that "raw reads, tests and senior review remain mandatory for exact edits, security-sensitive logs and high-risk changes" (wavect-field-report.md). Compression helps most with exploration and discovery, not with editing.

**Complexity cost of covering all four problem classes.** The grafsoul reviewer identifies four problem classes (search, read, compress, carry across chats) and notes that a tool solving all four charges a complexity tax that is only worthwhile when all four problems are present (grafsoul-review.md).

## Privacy

**Default no-telemetry posture.** The dudarik blog describes lean-ctx as having "zero telemetry" (dudarik-blog-overview.md). The docs.rs page lists no telemetry features (docsrs-crate-page.md).

**Opt-in stats.** The homepage does not mention telemetry; the default posture is local-only. No archived source describes opt-in statistics collection explicitly, but the zero-telemetry claim implies no data leaves the machine by default.

**Local-first claim.** The binary runs locally with no external dependencies (dudarik-blog-overview.md). All caching, compression, and knowledge graph operations happen on the local machine.

**Path restriction.** The PathJail feature restricts file access to configured paths (leanctx-homepage.md; docsrs-crate-page.md). This limits the scope of what the tool can read.

**Secret redaction / masking.** The docs.rs page lists secret redaction and injection detection as features (docsrs-crate-page.md). The leanctx homepage mentions security features including PathJail and read-time checks (leanctx-homepage.md).

**What proxy mode does and does not send.** The proxy mode modifies local shell configuration and agent settings files. It routes API traffic through a local proxy that can rewrite requests. It does not appear to send user data to external servers, but the proxy rewrites the shell config and agent settings, which changes what the agent sends to its provider.

## Positioning

lean-ctx is NOT a graph tool. It is a context-compression and context-intelligence layer that contains a property graph as one capability among many.

**Where compression wins:**
- Repeat reads: content-addressed caching reduces re-reads from ~2,000 tokens to ~13 tokens (dudarik-blog-overview.md).
- Shell noise: 95+ compression patterns across 34 categories handle command output bloat (docsrs-crate-page.md).
- Structure-only reads: map and signatures modes deliver AST outlines instead of full source (grafsoul-review.md; dudarik-blog-overview.md).
- Cross-session memory: CCP carries context between sessions (docsrs-crate-page.md).

**Where a structural graph wins:**
- Impact analysis: tracing which parts of a codebase are affected by a change requires structural relationships, not compression.
- Dependency traversal: navigating module dependencies requires a graph representation.
- Cross-repo navigation: understanding relationships across repositories requires a graph that compression alone does not provide.

The property graph in lean-ctx handles temporal-fact relationships and contradiction detection within a single project (docsrs-crate-page.md), but this is a bounded knowledge graph for context continuity, not a general-purpose codebase analysis graph.

**Sources' verdict on when it is worth the complexity.** The grafsoul reviewer states the tool is worth its complexity cost only when the user genuinely has all four problems: finding files, reading them structurally, compressing output, and carrying context across chats (grafsoul-review.md). The Wavect report demonstrates that the tool delivers measurable savings in a real deployment but requires disciplined integration to realize those gains (wavect-field-report.md).

## Unarchived / Excluded Sources

| Source | Reason |
|--------|--------|
| README.md | PARTIALLY ARCHIVED: write blocked by permission system; content available in websearch results and quoted in grafsoul/dudarik reviews |
| crates.io API | NOT ARCHIVED: API returned empty response; crate may be published under a different name |
| Latest releases API | PARTIALLY ARCHIVED: key fields captured in github-api-metadata.json |
| GitHub discussions | NOT ARCHIVED: not fetched |
| Reddit / HN mentions | NOT ARCHIVED: no results found in websearch |
| leanctx.com/docs/getting-started | NOT ARCHIVED: not fetched |
| leanctx.com/compare/ | NOT ARCHIVED: not fetched |

## Works Cited

"GitHub API Metadata: yvgude/lean-ctx." GitHub API, 25 Sept. 2026, api.github.com/repos/yvgude/lean-ctx. JSON.

"LICENSE.txt." Apache License 2.0, Copyright 2026 Yves Gugger. raw.githubusercontent.com/yvgude/lean-ctx/main/LICENSE.

"Contributors: yvgude/lean-ctx." GitHub API, 25 Sept. 2026, api.github.com/repos/yvgude/lean-ctx/contributors. JSON.

"leanctx.com Homepage." LeanCTX, 25 Sept. 2026, leanctx.com.

Grafsoul. "LeanCTX Technical Review." grafsoul.com, 10 Jun. 2026, grafsoul.com/en/ai-tech/leanctx.

Wavect. "LeanCTX Agency Experience: Field Report." Wavect Blog, 26 Jul. 2026, wavect.io/blog/lean-ctx-agency-experience/.

Dudarik. "LeanCTX MCP: Technical Overview." dudarik.com, 8 Jul. 2026, dudarik.com/en/blog/lean-ctx-mcp/.

"lean-ctx Crate Documentation." docs.rs, version 3.8.11, docs.rs/crate/lean-ctx/latest.

"Open Issues Snapshot: yvgude/lean-ctx." GitHub API, 25 Sept. 2026, api.github.com/repos/yvgude/lean-ctx/issues?state=open. JSON.
