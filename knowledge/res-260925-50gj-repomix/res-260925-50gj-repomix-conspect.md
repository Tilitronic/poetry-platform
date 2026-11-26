# Repomix: Repository-to-Single-File Context Packer for AI Tools

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 14
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

## Claim Verification

The previous scan's claims about Repomix were made without archived sources. The following is verified against the 14 archived source files:

- **Canonical repository:** `yamadashy/repomix` on GitHub (github-api-metadata.json).
- **Language:** TypeScript (github-api-metadata.json).
- **License:** MIT License, copyright 2024 Kazuki Yamada (license.txt, readme.md, npm-package.json).
- **Star count:** 28,493 (github-api-metadata.json, as of 2026-09-25).
- **Fork count:** 1,543 (github-api-metadata.json).
- **Open-issue count:** 144 (github-api-metadata.json).
- **Creation date:** 2024-07-13 (github-api-metadata.json). This predates most comparable tools in the evaluation set.
- **Latest release:** v1.18.1, published 2026-09-21 (github-api-latest-release.json).
- **npm publication:** latest version 1.18.1, published 2026-09-21; 90+ versions published since 2024-07-13 (npm-package.json). npm downloads approximately 255k/month (readme.md).
- **Contributor spread (github-api-contributors.json):**

| Contributor | Contributions | Type |
|---|---|---|
| yamadashy (Kazuki Yamada) | 3,598 | User (primary author) |
| renovate[bot] | 345 | Bot |
| dependabot[bot] | 105 | Bot |
| devin-ai-integration[bot] | 95 | Bot |
| claude | 53 | User |
| huy-trn | 34 | User |
| serhiizghama | 32 | User |
| github-actions[bot] | 31 | Bot |
| autofix-ci[bot] | 29 | Bot |
| pranshugupta01 | 18 | User |

**Bus-factor picture:** The primary author (yamadashy) accounts for 3,598 of the top-10 total of 4,310 contributions (83.5%). Automation bots (renovate, dependabot, devin-ai-integration, github-actions, autofix-ci) account for 605 contributions (14.0%). Community human contributors (claude, huy-trn, serhiizghama, pranshugupta01) total 137 contributions (3.2%). The "claude" user (53 contributions) is likely AI-assisted. This is a single-maintainer project with significant bot automation and modest community contribution -- a stronger bus-factor picture than purely solo projects, but still heavily owner-dependent.

## Mechanism

### Packing Pipeline

Repomix traverses a local directory (or clones a remote repository) and concatenates all non-excluded files into a single output file. The file discovery pipeline respects multiple ignore/include layers:

1. **`.gitignore`** -- honored by default; disabled with `--no-gitignore`.
2. **`.ignore`** -- standard ignore file (readme.md).
3. **`.repomixignore`** -- project-specific ignore file for Repomix-specific exclusions (readme.md).
4. **`--ignore` patterns** -- CLI-level ignore patterns (readme.md).
5. **`--include` patterns** -- explicit inclusion patterns (readme.md).

Binary files are excluded from output; their paths appear in the directory structure but contents are omitted (guide-security.md).

### Output Formats

Four formats are available: XML (default), Markdown (`--style markdown`), JSON (`--style json`), and plain text (`--style plain`) (readme.md, website-homepage.md). XML is described as providing hierarchical structure with XML tags that aid AI comprehension (website-homepage.md).

### Tree-Sitter Compression Mode

The `--compress` flag (or `{"output": {"compress": true}}` in config) activates Tree-sitter-based code compression. It preserves function and method signatures, interface and type definitions, class structures and properties, and other important structural elements. It removes function and method implementations (collapsed to `...`), loop and conditional logic details, internal variable declarations, and implementation-specific code (guide-code-compress.md). The feature is marked as experimental (guide-code-compress.md).

### Per-File Inclusion Levels

The `output.patterns` configuration supports three per-file inclusion levels: full content, compressed, and directory-structure-only. The first matching pattern wins per file. `directoryStructureOnly` takes precedence over `compress` (guide-code-compress.md).

### Secret/Credential Scanning

Repomix integrates Secretlint to detect API keys, access tokens, credentials, private keys, and environment variables. It is **enabled by default** and can be disabled with `--no-security-check` or `{"security": {"enableSecurityCheck": false}}` (guide-security.md).

### Token Counting

Repomix provides token counts per file and for the entire repository (readme.md). The library API exposes a `TokenCounter` component (guide-using-as-library.md). The `--token-budget` flag causes the CLI to exit with a non-zero code when output exceeds N tokens (readme.md). The tree view in the output also reports token counts (readme.md). However, independent reports suggest the token counting may be inaccurate -- see Reviews and Benchmarks sections below.

### Watch Mode

The `-w` / `--watch` flag performs an initial pack then watches for file changes. New, changed, or deleted files trigger a re-pack after a **300ms debounce** period. Ignored directories are not watched. Watch mode is incompatible with `--remote`, `--stdout`, `--stdin`, `--split-output`, `--skill-generate`, and `--copy` -- combining any of these exits with an error (guide-watch-mode.md).

## Integration Surface

### CLI Invocation Paths

- **npx runner:** `npx repomix@latest` (readme.md).
- **Global install:** `npm install -g repomix` (readme.md).
- **Package manager:** `brew install repomix` (readme.md).
- **Container image:** `docker run -v .:/app -it --rm ghcr.io/yamadashy/repomix` (readme.md, guide-mcp-server.md).
- **MCP Docker variant:** `docker run -i --rm ghcr.io/yamadashy/repomix --mcp` (guide-mcp-server.md).

### Library API

The package exports `runCli`, `searchFiles`, `collectFiles`, `processFiles`, and `TokenCounter` for programmatic use (guide-using-as-library.md). The entry point is `./lib/index.js` with TypeScript types at `./lib/index.d.ts` (npm-package.json). Bundling notes: `tinypool` must remain external (spawns worker threads via file paths); WASM files (`web-tree-sitter.wasm` and Tree-sitter language files) must be copied, configurable via `REPOMIX_WASM_DIR` env var (guide-using-as-library.md).

### MCP Server

Running `repomix --mcp` starts a Model Context Protocol server (guide-mcp-server.md). Available tools:

| Tool | Description |
|---|---|
| `pack_codebase` | Package local code directory into consolidated output |
| `pack_remote_repository` | Fetch, clone, and package a GitHub repository |
| `read_repomix_output` | Read packed output file with optional line range |
| `grep_repomix_output` | Search patterns in packed output with JS RegExp syntax |
| `file_system_read_file` | Read file relative to workspace root (sandbox only) |
| `file_system_read_directory` | List directory contents with [FILE]/[DIR] indicators (sandbox only) |

**Sandbox mode** (`--sandbox`) confines the MCP server's file tools to a single workspace directory. Paths must be relative to the workspace root; absolute paths, `~`, `..`, and symlinks are refused. Only read-only, root-confined tools are registered. Remote packing, skill generation, and attaching external outputs are disabled in sandbox mode. This is application-level confinement, not OS-level sandboxing (guide-mcp-server.md).

MCP server configuration is documented for VS Code, Cline, Cursor, Claude Desktop, and Claude Code (guide-mcp-server.md).

### Editor and Browser Extensions

- **Chrome and Firefox extensions** for one-click packing from GitHub repositories (readme.md).
- **VSCode Extension:** Community-maintained "Repomix Runner" by massdo (readme.md).

### Claude Code Plugins

Three official plugins: `repomix-mcp`, `repomix-commands`, `repomix-explorer` (readme.md).

### Agent Skills Generation

The `--skill-generate` flag generates output in Claude Agent Skills format (readme.md).

### OpenCode-Specific Integration

**No.** No OpenCode-specific integration is documented in any of the archived sources.

## Reviews

### Praise

- **Doolpa review rating:** 89/100. Described as "the right pick for anyone who's tired of copy-pasting random files into ChatGPT, Claude, or Gemini." Sentiment described as "overwhelmingly positive" (community-feedback.md, doolpa.com).
- **JSNation Open Source Awards 2025:** Nominated in the "Powered by AI" category (readme.md, community-feedback.md).
- **Hacker News (pridkett, 2025-03-19):** "Repomix can take care of this for you. I pack it, cat the file to my clipboard with pbcopy, and just paste it into the prompt" (community-feedback.md).
- **Hacker News (2025-06-04):** "I use repomix with AI Studio extensively and never found anything (including the cli agents) that's close" (community-feedback.md).
- **Reddit r/softwarecrafters (2026-03-26):** Posted with positive summary of the tool's value proposition (community-feedback.md).

### Complaints

- **Token-count accuracy:** "it regularly says 40,000 tokens but when uploading the resulting single XML file to Gemini it's actually 55k-65k tokens" -- Hacker News, 2025-06-04 (community-feedback.md).
- **Large-repo context blowout:** Very large repos (50k+ files) blow past LLM context windows even after compression (community-feedback.md, Doolpa review).
- **No topic-based sharding:** No auto-sharding across multiple files by topic (community-feedback.md, Doolpa review).
- **Runtime dependency weight:** Node.js dependency feels heavy; requests for Go or Rust binary (community-feedback.md, Doolpa review).
- **Security concern (Reddit, 2025-09-25):** User asked about data leak concerns. Community consensus: CLI processes locally, no cloud upload, source code is open for audit (community-feedback.md).

## Benchmarks and Provenance

### Compression Figure

The claim of "~70% token reduction" via Tree-sitter compression appears in the readme.md, guide-code-compress.md, and guide-mcp-server.md. This is a **vendor claim** from the project itself. No independent benchmark with a published methodology was found in the archived sources confirming this figure.

### Third-Party Comparison (Doolpa review)

The Doolpa review (community-feedback.md, doolpa.com/article/repomix) provides a third-party comparison using the `python-docs-samples` benchmark:

| Tool | Token Count |
|---|---|
| Repomix | ~56M tokens |
| code2prompt | ~57M tokens |
| GitIngest | ~69M tokens |

**Provenance:** This is a third-party comparison from a review site, not from the project's own documentation. The benchmark corpus (`python-docs-samples`) and methodology are not described in the archived sources beyond the tool names and token counts.

### Token-Count-Accuracy Complaint

A Hacker News commenter (2025-06-04) reported that Repomix's token estimate was "too optimistic" -- reporting 40,000 tokens while the actual count on upload to Gemini was 55k-65k tokens (community-feedback.md). This undermines reliance on the tool's own token accounting for budget-constrained contexts.

## Limitations

1. **One-shot packing:** Repomix produces a single snapshot. It does not provide ongoing navigation, querying, or incremental updates (inferred from the packing model described across all sources; no source describes a continuous or incremental mode).
2. **No call graph / blast radius / importance ranking:** The output is a flat concatenation (with optional directory structure). No source describes any graph-based analysis, dependency analysis, or importance ranking.
3. **Large repositories:** Repos with 50k+ files exceed context windows even after compression (community-feedback.md, Doolpa review).
4. **Staleness between packs:** In watch mode, the output is rebuilt on file changes, but between manual packs there is no automatic freshness guarantee (inferred from the one-shot model).
5. **Splitting behavior:** `--split-output` exists but is incompatible with watch mode (guide-watch-mode.md). The split-output mode shows each part's own directory tree (github-api-latest-release.json).
6. **Token-count mismatch:** The tool's token estimate may not match the target model's actual tokenization, as documented by the Hacker News complaint (community-feedback.md).
7. **Runtime dependency:** Requires Node.js >= 18.0.0 (npm-package.json). Community requests for a compiled binary port exist (community-feedback.md).
8. **Security advisory fixed in v1.18.1:** GHSA-4p5g-gh74-q524 -- repository-level git config was previously executed by Repomix's git commands. A directory shipped with a crafted `.git/config` could run arbitrary commands via settings like `gpg.program`, `diff.external`, `textconv` drivers, and `core.fsmonitor`. Fixed in v1.18.1 by disabling repository-level git config for all git commands run in a target directory (github-api-latest-release.json). The trust assumption: config files in remote repositories are treated as untrusted by default; `--remote-trust-config` opts in to loading them (guide-security.md).

## Privacy

### CLI-Local Processing

The CLI does NOT collect, transmit, or store any user data, telemetry, or repository information. It is fully offline after installation. The only network usage is: npm installation, `--remote` flag for remote repositories, and manual update checks (guide-privacy.md).

### Project-Specific Ignore and Secret Scanning

The `.repomixignore` file provides project-level control over what Repomix processes (readme.md). Secretlint is enabled by default, detecting and excluding credentials from output (guide-security.md).

### Website and Browser Extensions vs. CLI

The website (repomix.com) uses Google Analytics for usage data and Cloudflare Turnstile for bot protection. File uploads are temporarily stored and automatically deleted after processing (guide-privacy.md). The browser extension does NOT collect user data and requests minimal permissions (guide-privacy.md). These differ from the CLI, which operates entirely locally with no network calls.

### ZDR Compatibility

The privacy policy states the CLI tool operates with a posture compatible with Zero Data Retention (ZDR) -- no telemetry, no cloud upload, content stays on the user's machine (guide-privacy.md).

## Positioning

### Category Boundary

Repomix **packs** context. It does NOT build queryable graphs, perform ranked search, or provide structural/semantic navigation. This is a fundamental category distinction: packing is a one-shot flattening operation, whereas tools that build queryable graphs or perform ranked/structural search enable iterative, targeted exploration.

### Where Packing Helps

- **Whole-repo one-shot analysis:** Feeding an entire codebase to an LLM for code review, refactoring suggestions, or architectural analysis in a single prompt (website-homepage.md).
- **Clipboard-style context handoff:** Pack, copy, paste into any LLM prompt -- the workflow described by Hacker News users (community-feedback.md).
- **Cross-tool portability:** The output works with ChatGPT, Claude, Gemini, Grok, DeepSeek, Perplexity, and others (website-homepage.md).

### Where Packing Does Not Serve

- **Cheap ongoing navigation:** Packing is a snapshot, not a queryable interface. For ongoing exploration, graph-based or search-based tools are more appropriate.
- **Large codebases:** Repos exceeding context windows cannot be packed into a single file, and even compressed output may exceed limits (community-feedback.md).
- **Topic-specific queries:** No sharding or topic-based filtering beyond glob patterns exists (community-feedback.md).

### Complement, Not Alternative

The Doolpa review lists alternatives (GitIngest, code2prompt, Yek) as comparable packing tools, not as replacements for graph-based or search-based tools (community-feedback.md). The sources' collective verdict is that Repomix is a complement to, rather than an alternative for, tools that provide queryable code graphs or ranked search. The README itself recommends GitIngest for the Python ecosystem (readme.md).

## Works Cited

1. "GitHub API Metadata -- yamadashy/repomix." *GitHub API*, 2026-09-25. `github-api-metadata.json`. Archived source file.
2. "npm Package Registry -- repomix." *npm Registry*, 2026-09-25. `npm-package.json`. Archived source file.
3. "GitHub API Contributors -- yamadashy/repomix." *GitHub API*, 2026-09-25. `github-api-contributors.json`. Archived source file.
4. "GitHub API Latest Release -- v1.18.1." *GitHub API*, 2026-09-21. `github-api-latest-release.json`. Archived source file.
5. "LICENSE." *MIT License*, Copyright 2024 Kazuki Yamada. `license.txt`. Archived source file.
6. "README.md." *yamadashy/repomix*, 2026-09-25. `readme.md`. Archived source file.
7. "Repomix." *repomix.com*, 2026-09-25. `website-homepage.md`. Archived source file.
8. "MCP Server Guide." *repomix.com/guide/mcp-server*, 2026-09-25. `guide-mcp-server.md`. Archived source file.
9. "Code Compression Guide." *repomix.com/guide/code-compress*, 2026-09-25. `guide-code-compress.md`. Archived source file.
10. "Security Guide." *repomix.com/guide/security*, 2026-09-25. `guide-security.md`. Archived source file.
11. "Privacy Policy." *repomix.com/guide/privacy*, 2026-09-25. `guide-privacy.md`. Archived source file.
12. "Watch Mode Guide." *repomix.com/guide/watch-mode*, 2026-09-25. `guide-watch-mode.md`. Archived source file.
13. "Using Repomix as a Library." *repomix.com/guide/development/using-repomix-as-a-library*, 2026-09-25. `guide-using-as-library.md`. Archived source file.
14. "Community Feedback Compilation." *Hacker News, Reddit, Doolpa*, 2025-2026. `community-feedback.md`. Compiled archived source.

## Unarchived/Excluded

- **npm download count badge image** (img.shields.io/npm/d18m/repomix): excluded because it is an image badge, not a data source. The download data was captured via the npm registry JSON instead.

## Gaps

The archived sources do not cover:
- Detailed benchmarks with published methodology (the Doolpa comparison lacks corpus description and run parameters).
- Internal architecture or code-level design documentation.
- Performance profiling or throughput measurements.
- Comparison with graph-based or search-based tools in a structured evaluation framework.
- Specific version history details beyond the latest release.
- Community contribution guidelines or governance documentation.
- The full set of CLI options with detailed per-option documentation (only key options are listed in the README).
