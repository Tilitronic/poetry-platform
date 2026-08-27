# DIA-127 OMO Slim 2.2.13 Version-Gate Research - Conspect (res019)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 10
phase-a-failures: 2
shelf-registration: .opencode/memory-shelf.yaml (shelf.conspects)
-->

Conspect for DIA-127 Step B: persist the ai-specialist version-gate research for the oh-my-opencode-slim 2.2.8 -> 2.2.13 plugin upgrade as a durable knowledge artifact. Every external claim is grounded in the 10 locally archived source files under `sources/` (Phase A output, archived 2026-08-13); 2 of the 12 provisioned URLs could not be archived and their claims are EXCLUDED per the DIA-072 archive-before-claim policy (see section 8). This Phase A archival simultaneously served as the DIA-126 full re-verify of the wildcard bash permissions (curl/wget/trafilatura with arguments) on the post-restart opencode process - all 12 fetch commands ran without a single permission ask (see report).

## 1. Decision context and constraint frame (project-internal, not external-source claims)

- **DIA-127 ticket**: "oh-my-opencode-slim 2.2.8 -> 2.2.13 update evaluation". The developer decision was recorded 2026-08-13 as UPDATE NOW; the global plugin pin was moved to `oh-my-opencode-slim@2.2.13` (`~/.config/opencode/opencode.jsonc` line 148, outside the repo) and the project comment at `.opencode/opencode.jsonc` line 135 was synced (project CHANGELOG 2026-08-13, learnings `2026-08-13-omo-slim-version-gate-upgrade.md`).
- **Dual runtime**: the project wires a LOCAL vendored plugin fork at `.opencode/opencode.jsonc` line 541 (`file:///workspace/.opencode/oh-my-opencode-slim`) while the global runtime loads the npm published build; DIA-128 documented the resulting prompt-precedence divergence (project runtime: FILE wins; npm runtime: INLINE wins via `inlinePrompt ?? filePrompt ?? fallback`), which the project resolved 2026-08-13 by relocating inline prompts to prompt files (project CHANGELOG).
- **Three presets**: `.opencode/oh-my-opencode-slim.jsonc` defines the `opencode-go`, `cebula`, and `free` presets; several upstream changes reviewed here (preset model alignment, websearch MCP removal, disabled_* guards) touch exactly this surface (project CHANGELOG, multiple entries).
- **Conspecter permission hardening (DIA-126)**: the conspecter lane's native permission block (`.opencode/opencode.jsonc`) allows only `curl *` / `wget *` / `trafilatura *` / `crwl *` in bash (everything else falls through to a blanket deny), denies webfetch and task, and scopes edit to `knowledge/*` + `.opencode/memory-shelf.yaml`; DIA-126 also removed the websearch MCP from the conspecter agent across all 3 presets (project CHANGELOG 2026-08-13). This conspect's own Phase A ran entirely inside that hardened block.
- **Agent-name lockstep**: a 4-source containment contract (AGENTS.md section 9 table <-> `.opencode/opencode.jsonc` `agent` block keys <-> `.opencode/oh-my-opencode-slim.jsonc` agents/presets/disabled_agents keys <-> `.opencode/agents/*.md` filename stems), enforced by `scripts/validate-agent-names.sh`; the project renamed the OMO native aliases (oracle/fixer/explorer/librarian) and disabled them in favor of canonical names (architector/coder/reviewer/analyzer/...).

## 2. Release timeline from 2.2.8 to 2.2.13 (archived evidence)

| Version | npm publish (registry `time`) | GitHub tag | Release notes | What is in it (archived) |
|---|---|---|---|---|
| v2.2.9 | 2026-08-03T21:03:33Z (sources/npm-registry-json.json) | release listed (sources/releases.md) | yes, 26 merged items (sources/release-v229.md) | PR #936 websearch MCP removal; PR #892 opencode-go preset variant alignment; PR #875 webfetch enable/disable + dedicated model config; PR #895 disabled_* non-array guard; PR #901 per-preset agent config docs |
| v2.2.10 | 2026-08-04T20:45:19Z (sources/npm-registry-json.json) | no release entry in the archived releases list | none in archive | only the npm publish timestamp |
| v2.2.11 | 2026-08-09T23:47:48Z (sources/npm-registry-json.json) | release listed (sources/releases.md) | yes, 20 merged items (sources/release-v2211.md) | PR #979 opencode2 dual-compat; PR #969 installer persists OPENCODE_ENABLE_EXA alongside background-subagents; PR #982 unified runtime config interface; PR #968 interview feature removed; PR #963 dead-code sweep (608 lines of unused exports); PR #965 FailoverConfigSchema field removal + schema regen |
| v2.2.12 | 2026-08-10T21:58:42Z (sources/npm-registry-json.json) | 10 Aug 21:58 (sources/release-v2212.md) | NO release notes (tag-only) | tag page shows only "2.2.12", commit fb58dd5, 2 assets |
| v2.2.13 | 2026-08-11T20:08:34Z (sources/npm-registry-json.json) | 11 Aug 20:08 (sources/release-v2213.md) | NO release notes (tag-only) | tag page shows only "2.2.13", commit 781ca04, 2 assets; `dist-tags.latest` (sources/npm-registry-json.json) |

The npm publish timestamps for v2.2.12 and v2.2.13 match the GitHub tag timestamps to the second (10 Aug 21:58:42Z vs "10 Aug 21:58"; 11 Aug 20:08:34Z vs "11 Aug 20:08"), confirming publish-on-tag for the two tag-only releases (sources/npm-registry-json.json, sources/release-v2212.md, sources/release-v2213.md).

## 3. The two substantive changes in the 2.2.8..2.2.13 window

### 3.1 v2.2.9 - PR #936: plugin websearch MCP removed (sources/pr-936-websearch-mcp-removal.md, sources/release-v229.md)

- Removed the plugin-managed remote websearch MCP (Exa by default, optional Tavily): `src/mcp/websearch.ts`, its registration in `src/mcp/index.ts`, `WebsearchConfigSchema` and the regenerated `oh-my-opencode-slim.schema.json`, `websearch` removed from `McpNameSchema`, the librarian's default MCP list (`src/config/agent-mcps.ts`), the librarian/fixer agent prompts, and the JSON error recovery exclusion list.
- `docs/mcps.md` now recommends OpenCode's BUILT-IN websearch tool, activated via the `OPENCODE_ENABLE_EXA` / `OPENCODE_ENABLE_PARALLEL` environment flags (fish config and one-liner examples provided).
- The `websearch` key in the agent `permission` schema is RETAINED because it governs the built-in tool.
- Verification recorded in the PR: `check:ci` pass (281 files), `typecheck` pass, `bun test` 1713 pass / 0 fail, `build` pass (schema regenerated). Greptile review: 5/5 confidence, no reachable runtime references remain.
- Companion change in v2.2.11: PR #969 makes the installer persist `OPENCODE_ENABLE_EXA` alongside the background-subagents setting so the built-in websearch is enabled after install (sources/releases.md).

### 3.2 v2.2.11 - PR #979: OpenCode v2 (opencode2) dual-compatibility (sources/pr-979-opencode2-compat.md, sources/release-v2211.md)

- One published package now installs and runs on BOTH OpenCode v1 (`opencode`) and v2 (`opencode2`). The default export becomes `{ id, server, setup }`: the v1 loader calls `.server` (the existing plugin factory, unchanged); the v2 loader decodes `{ id, setup }` and calls `.setup` (a new adapter at `src/v2/`). The bare-function default is NO LONGER used.
- The v2 adapter wraps the v1 factory to reuse all build logic and bridges the returned v1 Hooks into v2 registrations: agent/tool/command transforms, `session.hook("context")` for system+message transforms, tool execute hooks, and the event stream. Includes a task->subagent prompt rewrite and a v2-permissive permission base with v1 overlay (findLast-aware). Typed locally with no v2 plugin package build-time dependency.
- Build: `build:v2` emits a self-contained `dist/server.js` (bundles zod; only `@ast-grep/napi` + `jsdom` external) exposed via the `./server` export subpath that the v2 loader tries first (corroborated by sources/package-json-v2213.json: `exports["./server"]` and the `build:v2` script).
- Tests: `src/v2/adapters.test.ts` (17 tests covering `parseModelRef`, `adaptPermissions` incl. findLast deny-wins and task->subagent/bash->execute mapping, `rewritePromptForV2`, `applyAgentToDraft`); 1697 pass / 0 fail; `check:ci` + `typecheck` clean.
- v1 is unaffected: the v1 loader handles the `{server}` object form via its primary path.
- Known v2 limitations (v2 API constraints, not adapter gaps): (1) foreground model fallback impossible - v2 locks a session's model at creation, with no per-prompt model override, no session model-setter, and no `/model` command; workaround is the `/preset` switcher at load time; (2) interactive is a 3-level v1-TUI UI - v2 commands are template-only; (3) v2 has no programmatic MCP-registration hook - the docs ship a copy-paste `opencode.json` snippet for context7/grep.app; (4) v2 TUI ignores the `default_agent` config field and starts on the first agent in its list (`build`); the adapter calls `draft.default("orchestrator")` for run/API, but fixing the TUI needs an upstream v2 change.
- Two Greptile review findings were fixed in the PR: the message-transform bridge now preserves structural changes (passes the full v2 message as `info`, rebuilds `event.messages` from the transformed array), and replacement tool arguments are written back (`e.input = out.args`).
- Install on v2: `{ "plugin": ["oh-my-opencode-slim@latest"] }`.

## 4. Tag-only releases v2.2.12 and v2.2.13 (sources/release-v2212.md, sources/release-v2213.md, sources/npm-registry-json.json)

Both tag pages contain NO "What's Changed" section - only the tag name, commit SHA (v2.2.12 = fb58dd5, v2.2.13 = 781ca04), "alvinunreal tagged this" timestamps (10 Aug 21:58 / 11 Aug 20:08), and 2 assets each. Combined with the registry `time` entries, these are tag-only releases (version bump + tarball publish at tag time, no code-note release notes). They carry no breaking-change surface of their own; the risk-relevant content sits in v2.2.9 and v2.2.11.

## 5. Compare v2.2.8...v2.2.13 (sources/compare-v228-v2213.md)

The archived compare page states "23 contributors" for the `v2.2.8...v2.2.13` comparison. The commit/file counts (261 commits, 220 files) reported by the DIA-127 ai-specialist research are NOT present in the archive: the page returned "This comparison is taking too long to generate" and suggested running `git diff v2.2.8...v2.2.13` locally, so those two figures are EXCLUDED from this conspect as unverifiable-from-archive (flagged to the orchestrator; the local repo diff can supply them if needed). Only the 23-contributor count is cited.

## 6. npm metadata and package.json dependencies (sources/npm-registry-json.json, sources/package-json-v2213.json)

- Registry document: name `oh-my-opencode-slim`; `dist-tags`: `{ "beta": "2.0.0-beta.15", "latest": "2.2.13" }`; description "Lightweight agent orchestration plugin for OpenCode - a slimmed-down fork of oh-my-opencode"; license MIT; maintainer alvinunreal; package created 2026-01-15T19:15:48Z; `modified` 2026-08-11T20:08:34.699Z (the 2.2.13 publish instant).
- 2.2.13 publish timing vs research: published 2026-08-11T20:08Z, i.e. ~2 days before the DIA-127 research/decision date of 2026-08-13 (project CHANGELOG; registry `time["2.2.13"]`). The rendered npm package page itself was NOT archived (section 8), so this claim is cited to the registry document.
- `package.json` at tag v2.2.13 (raw GitHub archive): runtime dependencies include `@opencode-ai/plugin` **1.18.13** and `@opencode-ai/sdk` **1.18.13** (both exact-pinned, no caret), plus `@ast-grep/cli ^0.44.1`, `@modelcontextprotocol/sdk ^1.30.0`, `@mozilla/readability ^0.6.0`, `jsdom ^29.0.0`, `lru-cache ^11.5.2`, `turndown ^7.2.4`; optional dependency `@opentui/solid ^0.1.97`; `exports` includes the `./server` subpath used by the v2 loader; `scripts.build:v2` confirms the self-contained `dist/server.js` build (only `@ast-grep/napi` + `jsdom` external). The registry `versions["2.2.13"]` entry corroborates the same dependency set.

## 7. Breaking-change signals for the project's customized config

Grounded in the archives for the upstream change, with project-internal mapping marked as such:

1. **Websearch MCP removal (v2.2.9, PR #936)** - any preset/agent `mcps` entry referencing the plugin's `websearch` MCP is dead config on 2.2.13 (schema entry removed; registration gone; librarian default-MCP list changed). The `websearch` PERMISSION key is retained for the built-in tool. Project-internal mapping: DIA-126 already removed the websearch MCP from the conspecter agent across all 3 presets (project CHANGELOG 2026-08-13), so the conspecter lane is aligned; remaining agents/presets should be audited for stray `websearch` MCP references before the restart-verify.
2. **Config surface churn (v2.2.11)** - unified runtime config interface (PR #982), 608 lines of unused exports removed (PR #963), `FailoverConfigSchema` fields removed + schema regenerated (PR #965). Any custom config relying on removed exports/schema fields breaks on 2.2.13. Project-internal mapping: the vendored tree's `oh-my-opencode-slim.schema.json` and any preset keys derived from removed exports must be re-synced; the local vendored fork at `opencode.jsonc` line 541 is a fork divergence point (project CHANGELOG, DIA-128 learnings).
3. **`disabled_*` guard (v2.2.9, PR #895)** - non-array values for `disabled_agents`/`disabled_skills` are now guarded/flagged. Project-internal mapping: the agent-name lockstep relies on `disabled_agents` arrays in `.opencode/oh-my-opencode-slim.jsonc`; they must stay arrays (they are - the lockstep validator enforces containment, project AGENTS.md section 9).
4. **Default export form (v2.2.11, PR #979)** - the bare-function default export is no longer used; consumers must handle the `{ id, server, setup }` object form. v1 loader path is unaffected per the PR, but the project's dual runtime (npm 2.2.13 globally + vendored fork locally) means both loaders must accept the object form after upgrade (project-internal).
5. **OpenCode v2 runtime constraints (PR #979, known v2 limitations)** - no per-prompt model override / no session model-setter / no `/model` (mid-flight foreground model fallback impossible on v2), v2 TUI default agent is `build` not `orchestrator`, and no programmatic MCP registration. Project-internal mapping: the project's model escalation ladder (res014/res016) and foreground-fallback features are v1-runtime behavior; adopting opencode2 would require re-verifying fallback semantics, preset-at-load model selection, and the agent-name lockstep against the adapter's `applyAgentToDraft` registration path (the PR's own verification transcript lists the OMO native specialists explorer/librarian/oracle/designer/fixer, which the project disables/renames - project-internal).
6. **Webfetch config option (v2.2.9, PR #875)** - the schema gained webfetch enable/disable + dedicated-model options. Project-internal mapping: the conspecter lane denies webfetch at the permission level (DIA-126), which is unaffected by schema options; only preset-level webfetch settings (if any) would be affected by the new shape.
7. **Preset model drift (v2.2.9/2.2.11)** - PR #892 aligned opencode-go preset variants and PR #960 updated the zen-free preset (hy3 removed, fixer variant dropped). Project-internal mapping: the project's `opencode-go` preset is one of its 3; the DIA-127 decision (UPDATE NOW) implicitly accepts the 2.2.13 preset model set, and the restart-verify checklist should confirm preset model resolution post-upgrade.

Net assessment consistent with the DIA-127 UPDATE NOW decision: no archived change breaks the project's v1 runtime configuration outright - the two substantive changes are (a) removal of a redundant MCP the project already deprovisioned for the conspecter lane, and (b) an additive v2 compatibility layer that leaves v1's loader path intact; the actionable items are the audits in items 1, 2, and 5 above.

## 8. Unarchived sources (excluded per DIA-072)

- `npm-package-page` - https://www.npmjs.com/package/oh-my-opencode-slim - **[source not archived - excluded per DIA-072 policy]**. Reason: npmjs.com is a client-side-rendered SPA; strategy b (trafilatura) and strategy c (curl with browser UA piped to trafilatura) both returned only the 42-byte "Enable JavaScript and cookies to continue" shell; strategy d (crwl) failed with `BrowserType.launch: Executable doesn't exist at /home/qualt/.cache/ms-playwright/chromium_headless_shell-1228/...` (DIA-129 chromium skew, expected). No claims about the rendered package page are made; equivalent metadata is cited from sources/npm-registry-json.json instead.
- `npm-version-history` - https://www.npmjs.com/package/oh-my-opencode-slim?activeTab=versions - **[source not archived - excluded per DIA-072 policy]**. Same SPA failure mode; the version history is archived via the registry `time` object (sources/npm-registry-json.json).

## 9. Works cited (MLA)

1. alvinunreal. "Releases." GitHub, 2026, github.com/alvinunreal/oh-my-opencode-slim/releases. Accessed 13 Aug. 2026. [archived: sources/releases.md]
2. alvinunreal. "Release v2.2.11." GitHub, 2026, github.com/alvinunreal/oh-my-opencode-slim/releases/tag/v2.2.11. Accessed 13 Aug. 2026. [archived: sources/release-v2211.md]
3. alvinunreal. "Release v2.2.9." GitHub, 2026, github.com/alvinunreal/oh-my-opencode-slim/releases/tag/v2.2.9. Accessed 13 Aug. 2026. [archived: sources/release-v229.md]
4. alvinunreal. "Release v2.2.13." GitHub, 2026, github.com/alvinunreal/oh-my-opencode-slim/releases/tag/v2.2.13. Accessed 13 Aug. 2026. [archived: sources/release-v2213.md]
5. alvinunreal. "Release v2.2.12." GitHub, 2026, github.com/alvinunreal/oh-my-opencode-slim/releases/tag/v2.2.12. Accessed 13 Aug. 2026. [archived: sources/release-v2212.md]
6. alvinunreal. "Compare v2.2.8...v2.2.13." GitHub, 2026, github.com/alvinunreal/oh-my-opencode-slim/compare/v2.2.8...v2.2.13. Accessed 13 Aug. 2026. [archived: sources/compare-v228-v2213.md]
7. adikpb. "feat: remove plugin websearch MCP in favor of opencode's built-in websearch." GitHub pull request #936, 2026, github.com/alvinunreal/oh-my-opencode-slim/pull/936. Accessed 13 Aug. 2026. [archived: sources/pr-936-websearch-mcp-removal.md]
8. GoldJohnKing. "feat(v2): support OpenCode v2 (opencode2) alongside v1." GitHub pull request #979, 2026, github.com/alvinunreal/oh-my-opencode-slim/pull/979. Accessed 13 Aug. 2026. [archived: sources/pr-979-opencode2-compat.md]
9. alvinunreal. "package.json (v2.2.13)." GitHub raw, 2026, raw.githubusercontent.com/alvinunreal/oh-my-opencode-slim/v2.2.13/package.json. Accessed 13 Aug. 2026. [archived: sources/package-json-v2213.json]
10. npm. "oh-my-opencode-slim - registry metadata." registry.npmjs.org, 2026, registry.npmjs.org/oh-my-opencode-slim. Accessed 13 Aug. 2026. [archived: sources/npm-registry-json.json]

## 10. Claim-to-source mapping (key claims)

- "v2.2.11 is the substantive release in the window (20 merged items), including PR #979 opencode2 dual-compat and PR #969 OPENCODE_ENABLE_EXA installer persistence" -> sources/release-v2211.md, sources/releases.md
- "PR #979: single package runs on v1 and v2; default export {id, server, setup}; v2 adapter at src/v2/; build:v2 -> dist/server.js via ./server subpath; 1697 tests pass; known v2 limitations (model fallback, TUI default agent, MCP registration)" -> sources/pr-979-opencode2-compat.md, sources/package-json-v2213.json
- "PR #936: plugin websearch MCP (Exa/Tavily) removed; websearch permission key retained; built-in websearch via OPENCODE_ENABLE_EXA/OPENCODE_ENABLE_PARALLEL" -> sources/pr-936-websearch-mcp-removal.md, sources/release-v229.md
- "v2.2.9 published 2026-08-03, v2.2.11 published 2026-08-09, v2.2.12 published 2026-08-10, v2.2.13 published 2026-08-11; dist-tags.latest = 2.2.13" -> sources/npm-registry-json.json
- "v2.2.12 tagged 10 Aug 21:58 and v2.2.13 tagged 11 Aug 20:08, both tag-only (no What's Changed), 2 assets each" -> sources/release-v2212.md, sources/release-v2213.md
- "v2.2.8...v2.2.13 comparison: 23 contributors (commit/file counts not rendered in archive - excluded)" -> sources/compare-v228-v2213.md
- "package.json v2.2.13 deps: @opencode-ai/plugin 1.18.13, @opencode-ai/sdk 1.18.13 (exact pins)" -> sources/package-json-v2213.json, sources/npm-registry-json.json
- "2.2.13 published ~2 days before the DIA-127 research/decision (2026-08-13)" -> sources/npm-registry-json.json (time["2.2.13"]) + project CHANGELOG (project-internal)
- "Breaking-change surface: websearch MCP removal, config dead-code/schema churn, disabled_* guard, default-export form, v2 runtime constraints" -> sources/pr-936-websearch-mcp-removal.md, sources/pr-979-opencode2-compat.md, sources/release-v229.md, sources/release-v2211.md
