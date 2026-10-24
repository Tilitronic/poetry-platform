# DCP vs Headroom - Conspect (res036)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 16
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

Conspect for DIA-260821-8kpc (disable DCP plugin, context/cache concerns, OPEN): compare the DCP plugin (formerly used in this project, now removed from active config) against the Headroom plugin (github.com/headroomlabs-ai/headroom) and determine whether Headroom is a viable cache-friendlier replacement. Every external claim is grounded in the 16 locally archived source files under `sources/` (Phase A output, archived 2026-08-21 by @researcher). All 16 provisioned sources passed the researcher's evaluation (High/Med relevance + High/Med reliability) and are cited in the body; none were excluded or failed (manifest lines 25-27). This conspect feeds the DIA-260821-8kpc removal decision and the broader cache-economics record.

## 1. Decision context and constraint frame (project-internal, not external-source claims)

- **DIA-260821-8kpc ticket**: "Disable and remove the DCP plugin from everywhere in the project. Rationale: models have large context windows, rarely run for very long, frequent DCP calls consume time and reduce cache-hit rates; the team has doubts about DCP's usefulness." This ticket is the tracking ticket for the removal; the removal itself is a separate config-change task (sources/.source-urls.txt line 21; ticket DIA-260821-8kpc).
- **DCP is already removed from active config (project-internal ground truth)**: the current `.opencode/opencode.jsonc` plugin array (lines 592-605) contains only `oh-my-opencode-slim`, `ponytail`, `envsitter-guard`, `delegation-observer.ts`, and `needs-input-observer.ts` - DCP is NOT present. The project `dcp.jsonc` does not exist (glob returned NO FILE). The ADR records the removal: "deleted dcp.jsonc, removed from config validator, removed from Dockerfiles... No remaining DCP config surface" (sources/.source-urls.txt lines 16-17; project-internal ADR; DIA-260819-9oxi shows DCP was already `enabled: false` at global level by 2026-08-19). The comparison below is therefore retrospective/forward-looking: DCP is gone, and the question is whether Headroom should take its place.
- **Relationship to prior research**: the DIA-197 DCP-removal conspect (res029) already established DCP's mechanics, the 85% vs 90% cache-hit claim, the 50x DeepSeek miss/hit asymmetry, and that DCP has NO cache-preserving mode. The DIA-183 learnings file and ticket already ran the Headroom feasibility spike. This conspect re-grounds those findings against the freshly archived Headroom sources and delivers the direct DCP-vs-Headroom verdict (sources/res029-dcp-removal-evaluation-conspect.md; project-internal learnings; DIA-183 ticket).

## 2. DCP: what it was and why it left (archived evidence)

- **Mechanics**: DCP reduces context size through a compress tool (replaces closed/stale conversation content with high-fidelity technical summaries) plus deduplication (keeps only the most recent output of repeated tool calls) and purgeErrors (prunes inputs of errored tool calls after a configurable number of turns). "Your session history is never modified - DCP replaces pruned content with placeholders before sending requests to your LLM." Two compression modes: `range` (default) and experimental `message`. Config surface is broad (enabled, autoUpdate, manualMode, turnProtection, experimental, protectedFilePatterns, compress.*, strategies.*) (sources/dcp-readme.md; sources/dcp-schema.json).
- **Cache impact (self-reported)**: DCP's own README states the mechanism plainly: "When DCP prunes content, it changes messages, which invalidates cached prefixes from that point forward." It frames the trade-off ("You lose some cache reads but gain token savings") and asserts: "In testing, cache hit rates were approximately 85% with DCP vs 90% without." This is a single unquantified vendor sentence (no methodology, sample size, provider, or date) - but it is the authoritative statement that DCP busts the provider prefix cache (sources/dcp-readme.md).
- **No cache-preserving mode exists**: `turnProtection` shields the newest turns (the tail), not the cached prefix; `manualMode.automaticStrategies` still runs dedup/purgeErrors which also mutate messages; `compress.permission: "deny"` or `enabled: false` are disable-only levers. There is no configuration that keeps DCP functional while preserving the prompt-cache prefix (sources/dcp-schema.json; sources/dcp-readme.md; res029 section 4).
- **Package/repo facts**: npm latest 3.1.15 (beta 3.2.8-beta0); license AGPL-3.0-or-later (the 0.1.0 MIT entry is overridden by the 3.1.15 manifest); GitHub Actions trusted publisher; 223 files. Development has slowed because the author moved new work to Sleev (sources/dcp-npm-registry.json; sources/dcp-3.1.15.json; sources/dcp-readme.md).

## 3. Headroom: architecture, license, maturity (archived evidence)

- **What it is**: Headroom compresses "everything your AI agent reads - tool outputs, logs, RAG chunks, files, and conversation history - before it reaches the LLM." It ships as a library, a proxy, an MCP server, and an agent-wrap CLI (`headroom wrap opencode`). Core pipeline: CacheAligner -> ContentRouter -> SmartCrusher/CodeCompressor/Kompress-v2-base, with CCR (reversible compression, originals cached locally for on-demand retrieval) (sources/headroom-readme.md).
- **Architecture is a PROXY, not an in-process plugin**: although a native `headroom-opencode` OpenCode plugin package exists (exports `HeadroomPlugin` for in-process transport interception), the primary and recommended integration is `headroom wrap opencode`, which starts a local proxy, writes a `headroom` provider pointing at `http://127.0.0.1:<port>/v1`, injects Headroom MCP tools, and launches OpenCode through the proxy. The docs themselves state: "Headroom is the proxy - that's what we build and offer." This is architecturally different from DCP, which runs in-process as an OpenCode plugin (sources/headroom-opencode-docs.md; sources/headroom-readme.md).
- **License and maturity**: Apache-2.0 (sources/headroom-readme.md; sources/headroom-repo-meta.json). GitHub repo metadata: 67,071 stars, 5,171 forks, 501 open issues, Python, created 2026-01-07, pushed 2026-08-21 (today), NOT archived - i.e. very active and popular. The `headroom-opencode` npm package is at latest 0.36.2, Apache-2.0, depending on `headroom-ai ^0.36.0` + `@opencode-ai/plugin ^1.18.2` (sources/headroom-repo-meta.json; sources/headroom-opencode-npm.json).
- **Cache-alignment marketing**: Headroom advertises a `CacheAligner` that "detects and warns about volatile content that can bust provider KV cache prefixes; never rewrites prompts" (read-only drift detector), and "Live-zone compression - compresses only new bytes (fresh tool output, latest turn); frozen prefix stays byte-identical so provider cache is not busted. History is never dropped." This is the feature that made Headroom look like a cache-friendlier candidate (sources/headroom-readme.md).

## 4. The decisive verdict: Headroom cache-mode DRIFTS the frozen prefix (project-measured)

- **DIA-183 B1 feasibility spike (project-internal, measured 2026-08-16)**: the single blocking unknown was whether Headroom's cache-preserving mode actually preserves the provider prefix cache through the OpenAI-compatible proxy path used by opencode-go (opencode.ai/zen/go/v1/*). The spike resolved NEGATIVE. Method: a mock OpenAI-compatible upstream + Headroom proxy (v0.35.0) in cache mode, a three-turn synthetic opencode-style conversation, byte-identity checks of the shared prefix across turns.
  - T1 (frozen prefix vs client): PASS - Headroom forwards the frozen prefix byte-identical.
  - T2a/T2b (turn N+1 shared prefix vs turn N forwarded prefix): FAIL - DRIFT. Turn A forwarded the live-zone tool result COMPRESSED (202,503 bytes); turn B forwarded the SAME logical message at 218,109 bytes (client-original). First byte divergence at exactly the previous turn's live zone. Reproduced 3x with identical numbers.
  - Passthrough control (`--no-optimize`): T2a/T2b PASS, drift null - proving the drift is caused by the compression+restore path, not by proxying or the mock.
  - Mechanism: cache mode compresses the newest observation (live zone) in turn N and forwards those compressed bytes; in turn N+1 that message is inside the frozen count, the pipeline skips it, and `_restore_frozen_prefix` (runs AFTER `overlay_cached_prefix`) forcibly overwrites it with the CLIENT-ORIGINAL bytes. The provider's prefix cache is keyed on the compressed bytes forwarded in turn N; turn N+1's original bytes do not match, so the provider prefix cache busts from the previous live zone onward on every subsequent turn (project-internal DIA-183 ticket UPDATE 2026-08-16; project-internal learnings outcome field).
- **Cache economics of the drift (project-internal, estimated)**: the learnings baseline establishes DeepSeek V4 Flash cache hit $0.0028/1M vs cache miss $0.14/1M - a 50x ratio - and that the Go subscription request is ~86% cached reads (68,000 cached of ~68,790 input tokens). The measured drift converts the previously-compressed live zone (a large share of the accumulated cached prefix in tool-heavy agentic traffic) from $0.0028/1M to $0.14/1M. The 50x multiplier on a large busted region dwarfs the ~25% compression on the small new delta. Net cost delta estimated strongly negative. Spike verdict: NOT-RECOMMENDED to enable Headroom on the opencode-go endpoint; Headroom stays OFF (project-internal DIA-183 ticket; project-internal learnings).
- **Conclusion on the core question**: Headroom is NOT a cache-friendlier replacement for DCP on this project's opencode-go/DeepSeek path. Its cache-preserving mode was project-measured to DRIFT the frozen prefix, producing the same class of cache-busting cost that DCP self-reports (85% vs 90%) - but with the additional 50x miss multiplier on a large busted region, the net effect is worse than DCP's documented degradation. The marketing claim (live-zone compression keeps the frozen prefix byte-identical) does not hold once a live-zone message is compressed and later restored (project-internal DIA-183 ticket; project-internal learnings).

## 5. DCP vs Headroom comparison

| Dimension | DCP (removed) | Headroom (evaluated, not adopted) |
|---|---|---|
| Integration model | In-process OpenCode plugin | Proxy (primary); native plugin pkg exists but wrap-proxy is recommended |
| License | AGPL-3.0-or-later | Apache-2.0 |
| Popularity / activity | Slowed dev; moved to Sleev | 67,071 stars; pushed today; very active |
| Cache behavior (documented/measured) | Self-reported 85% vs 90% hit; busts prefix by design | Cache-mode CLAIMS frozen-prefix preservation; project-measured DRIFT (202,503 -> 218,109 bytes, 3x) on opencode-go path |
| Net cache economics for this project | ~5% hit degradation, recurring 50x-multiplier cost on pruned slice | Measured drift + 50x miss multiplier on large busted region; net strongly negative |
| Verdict | Removed (DIA-260821-8kpc tracking; already absent from active config) | NOT-RECOMMENDED as cache-friendlier replacement (DIA-183 B1 spike) |

## 6. Answer to the research question

Headroom is Apache-2.0, extremely popular (67k stars), and very actively developed, and it is architecturally a proxy rather than an in-process plugin like DCP. On paper its cache-alignment features (CacheAligner, live-zone compression) look like they would make it a cache-friendlier replacement. However, the project's own DIA-183 B1 feasibility spike measured that Headroom's cache mode DRIFTS the frozen prefix on the opencode-go/DeepSeek path (byte divergence 202,503 -> 218,109, reproduced 3x; passthrough control clean), so it is NOT a cache-friendlier replacement. Combined with DCP already being removed from the project's active config and DCP's own self-reported ~85% vs 90% cache-hit degradation, the evidence supports keeping DCP removed and not adopting Headroom as a cache-preserving substitute. The ponytail ruleset (already active in the plugin array) remains the zero-cache-interaction alternative for token discipline (project-internal DIA-183 ticket; project-internal learnings; sources/.source-urls.txt lines 16-17).

## 7. Unarchived / excluded sources

None. The researcher's Phase A manifest (sources/.source-urls.txt lines 25-27) records that all provisioned URLs were fetched successfully (trafilatura was absent, so curl-raw fallback was used for all HTML/markdown pages; all succeeded), and no sources were excluded or failed. All 16 archived sources (8 external + 8 project-internal) passed the evaluation and are cited above.

## 8. Works cited (MLA)

1. Opencode-DCP. "opencode-dynamic-context-pruning - README." GitHub, 2026, github.com/Opencode-DCP/opencode-dynamic-context-pruning. Accessed 21 Aug. 2026. [archived: sources/dcp-readme.md]
2. Opencode-DCP. "dcp.schema.json - DCP Plugin Configuration schema." GitHub raw, 2026, raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json. Accessed 21 Aug. 2026. [archived: sources/dcp-schema.json]
3. npm registry. "@tarquinen/opencode-dcp - registry metadata." registry.npmjs.org, 2026, registry.npmjs.org/@tarquinen/opencode-dcp. Accessed 21 Aug. 2026. [archived: sources/dcp-npm-registry.json]
4. npm registry. "@tarquinen/opencode-dcp@3.1.15 - package manifest." registry.npmjs.org, 2026, registry.npmjs.org/@tarquinen/opencode-dcp/3.1.15. Accessed 21 Aug. 2026. [archived: sources/dcp-3.1.15.json]
5. headroomlabs-ai. "headroom - README." GitHub, 2026, github.com/headroomlabs-ai/headroom. Accessed 21 Aug. 2026. [archived: sources/headroom-readme.md]
6. headroomlabs-ai. "OpenCode Integration - docs/content/docs/opencode.mdx." GitHub raw, 2026, raw.githubusercontent.com/headroomlabs-ai/headroom/main/docs/content/docs/opencode.mdx. Accessed 21 Aug. 2026. [archived: sources/headroom-opencode-docs.md]
7. GitHub API. "headroomlabs-ai/headroom - repository metadata." api.github.com, 2026. Accessed 21 Aug. 2026. [archived: sources/headroom-repo-meta.json]
8. npm registry. "headroom-opencode - registry metadata." registry.npmjs.org, 2026, registry.npmjs.org/headroom-opencode. Accessed 21 Aug. 2026. [archived: sources/headroom-opencode-npm.json]
9. poetry-platform. "DIA-260821-8kpc - Disable DCP plugin (context/cache concerns)." Project-internal ticket, 2026, docs/dev-infra-audit/tickets/DIA-260821-8kpc-disable-dcp-plugin-context-cache-concerns.md. Accessed 21 Aug. 2026.
10. poetry-platform. "Prompt-cache economics for context compression (DIA-183 Phase 1 gate findings; headroom cache-mode DRIFTS the frozen prefix, NOT-RECOMMENDED)." Project-internal learnings, 2026, .opencode/learnings/external-patterns/2026-08-15-ponytail-headroom-cache-economics.md. Accessed 21 Aug. 2026.
11. poetry-platform. "DIA-183 - Properly introduce ponytail skill and headroom context-compression (B1 spike: prefix-preservation FAIL measured 3x)." Project-internal ticket, 2026, docs/dev-infra-audit/tickets/DIA-183-ponytail-headroom-context-compression.md. Accessed 21 Aug. 2026.
12. poetry-platform. "DIA-197 DCP Removal Evaluation - Conspect (res029)." Project-internal conspect, 2026, knowledge/res029-dcp-removal-evaluation/res029-dcp-removal-evaluation-conspect.md. Accessed 21 Aug. 2026.
13. poetry-platform. "ADR: Memory Storage Strategy (and related ADRs; records DCP removal: no remaining DCP config surface)." Project-internal memory, 2026, .opencode/memory/adr.md. Accessed 21 Aug. 2026.
14. poetry-platform. "DIA-260819-9oxi - DCP plugin still injecting system-reminders despite DIA-197 V2 config (CLOSED: DCP disabled, enabled: false)." Project-internal ticket, 2026, docs/dev-infra-audit/tickets/DIA-260819-9oxi-dcp-plugin-still-injecting-system-reminders-despite-dia-197-v2-config.md. Accessed 21 Aug. 2026.
15. poetry-platform. ".opencode/opencode.jsonc - plugin array (lines 592-605): DCP NOT present." Project-internal config, 2026. Accessed 21 Aug. 2026.
16. poetry-platform. ".opencode/dcp.jsonc - glob returned NO FILE (config removed)." Project-internal config, 2026. Accessed 21 Aug. 2026.

## 9. Claim-to-source mapping (key claims)

- "DCP removed from active config; dcp.jsonc deleted; no remaining DCP config surface; DCP was enabled: false by 2026-08-19" -> sources/.source-urls.txt lines 16-17; project-internal ADR; DIA-260819-9oxi; opencode.jsonc (cite 15-16, 13-14)
- "DCP compress/dedup/purgeErrors mechanics; session history never modified, request messages mutated only" -> sources/dcp-readme.md, sources/dcp-schema.json (cite 1-2)
- "DCP self-reports 85% vs 90% cache hit; pruning invalidates cached prefixes by design; no cache-preserving mode" -> sources/dcp-readme.md, sources/dcp-schema.json (cite 1-2; res029 section 4, cite 12)
- "DCP npm latest 3.1.15; AGPL-3.0-or-later; dev slowed, moved to Sleev" -> sources/dcp-npm-registry.json, sources/dcp-3.1.15.json, sources/dcp-readme.md (cite 1,3-4)
- "Headroom is a proxy (primary) with a native plugin pkg; wrap opencode starts proxy + injects provider/MCP" -> sources/headroom-opencode-docs.md, sources/headroom-readme.md (cite 5-6)
- "Headroom Apache-2.0; 67,071 stars; pushed 2026-08-21; very active; headroom-opencode 0.36.2" -> sources/headroom-repo-meta.json, sources/headroom-opencode-npm.json (cite 7-8)
- "Headroom markets CacheAligner (never rewrites prompts) + live-zone compression (frozen prefix byte-identical)" -> sources/headroom-readme.md (cite 5)
- "DIA-183 B1 spike: Headroom cache-mode DRIFTS frozen prefix (202,503 -> 218,109 bytes, 3x); passthrough control clean; 50x miss multiplier net loss; NOT-RECOMMENDED" -> project-internal DIA-183 ticket, project-internal learnings (cite 10-11)
- "DeepSeek 50x miss/hit; Go request ~86% cached reads" -> project-internal learnings (cite 10; res029 section 3, cite 12)
- "Verdict: Headroom is NOT a cache-friendlier replacement; ponytail is the zero-cache-interaction alternative" -> project-internal DIA-183 ticket, project-internal learnings, sources/.source-urls.txt (cite 10-11, 15-16)
