Res006 — Telemetry plugin alternatives for OpenCode

Sections: 7

1. Executive summary
2. opencode-telemetry (local forensic plugin)
3. opencode-token-monitor (budgeting & monitoring plugin)
4. Native OpenCode capabilities (what core provides)
5. Plugin alternatives survey (Tokenscope, OTEL plugin, Context Analysis, others)
6. OMO / oh-my-opencode-slim relevance
7. Decision-relevant conclusion

Executive summary

This conspect synthesizes the locally archived sources collected for the telemetry plugin alternatives investigation. Primary findings:

- opencode-telemetry provides local-first, passive session persistence to SQLite with forensic per-session inspection tools and a CLI (`octm`) for report/inspect operations (github-agostinilabsrl-opencode-telemetry.md).
- Several open-source alternatives address complementary needs: Tokenscope (deep per-session breakdown), opencode-plugin-otel (OTLP export to backends), and Igor Warzocha's Context-Analysis plugin (live session breakdown). These are described in the preserved READMEs (github-ramtinJ95-opencode-tokenscope.md, github-DEVtheOPS-opencode-plugin-otel.md, github-IgorWarzocha-Opencode-Context-Analysis-Plugin.md).
- The opencode CLI and native database paths expose built-in commands and storage (opencode-cli-docs.md; opencode-troubleshooting.md).
- A small set of operational issues are tracked upstream for opencode-telemetry (issues #50–53), notably version-pinning, DB migration/indexing, short sessions not recorded (reinstall-on-start), and a `--content` TUI failure (github-agostinilabsrl-opencode-telemetry-issues.md).
- Registry metadata (npm/dist-tags, published release dates) for opencode-telemetry, opencode-token-monitor, and DEVtheOPS plugin, and the ccusage pricing/cost notes, were NOT archived by the researcher and are therefore flagged below as [source not archived — from researcher res-1 findings].

1) opencode-telemetry (local forensic plugin)

Source anchors: knowledge/res006-telemetry-plugin-alternatives/sources/github-agostinilabsrl-opencode-telemetry.md; issues: knowledge/res006-telemetry-plugin-alternatives/sources/github-agostinilabsrl-opencode-telemetry-issues.md.

Key facts (sourced):

- opencode-telemetry is explicitly described as "local-first" and writes session-level token/metadata to a local SQLite DB. It exposes CLI commands (`octm report`, `octm inspect <session_id>`, `octm sql`, etc.) and a companion command/controller that can be used from inside OpenCode as slash commands (github-agostinilabsrl-opencode-telemetry.md).
- The plugin maintains two on-disk artefacts: a metrics DB (data.db) and an optional content cache populated only when `--content` is used; the README documents the default paths and the `content_cache` config (github-agostinilabsrl-opencode-telemetry.md).
- Open issues filed in the repository document operational gaps: docs recommending version pinning because OpenCode runtime can cache `@latest` (issue #50); DB schema/index problems causing silent telemetry loss on pre-v2 databases (issue #52); short sessions sometimes not recorded (issue #53); `--content` failing under TUI (issue #51) (github-agostinilabsrl-opencode-telemetry-issues.md).
- The README positions the plugin as complementary to live/deep analysis tools (Tokenscope, Context-Analysis) — passive cross-session persistence vs on-demand decomposition (github-agostinilabsrl-opencode-telemetry.md).

Claims not archived here: npm registry dist-tags and release timeline (e.g., "opencode-telemetry v0.1.19 = npm latest; 16 releases Apr 28–Jun 4 2026 then silent") — [source not archived — from researcher res-1 findings].

2) opencode-token-monitor (budgeting & monitoring plugin)

Source anchors: knowledge/res006-telemetry-plugin-alternatives/sources/github-Ainsley0917-opencode-token-monitor.md

Key facts (sourced):

- The token-monitor plugin documents real-time monitoring, historical trends, ASCII charts, export capabilities, and three registered tools: `token_stats`, `token_history`, and `token_export` (github-Ainsley0917-opencode-token-monitor.md).
- It explicitly supports local pricing overrides via a `pricing.json` and budgeting via `token-monitor.json` (examples shown in the README). The README includes installation/build instructions and notes on copying the built plugin into OpenCode's plugin directory (github-Ainsley0917-opencode-token-monitor.md, lines 92–114 and 104–113).
- The README also describes per-project tagging and backward-compatibility behavior for historical records (github-Ainsley0917-opencode-token-monitor.md).

Claims not archived here: registry/npm dist-tag (e.g., "opencode-token-monitor 0.5.0 = latest") and the stated dormancy since Feb 9 2026 (~6 months) are not present in the saved repository README — these come from the researcher res-1 report and are flagged as [source not archived — from researcher res-1 findings].

3) Native OpenCode capabilities (what core provides)

Source anchors: knowledge/res006-telemetry-plugin-alternatives/sources/opencode-cli-docs.md; knowledge/res006-telemetry-plugin-alternatives/sources/opencode-troubleshooting.md; issue discussion on OTEL support: knowledge/res006-telemetry-plugin-alternatives/sources/github-anomalyco-opencode-issues-14246.md.

Key facts (sourced):

- `opencode stats` exists as a documented CLI command to show token usage/cost statistics, with `--days`, `--tools`, `--models`, and `--project` filters (opencode-cli-docs.md).
- The CLI includes `opencode db` tooling and `opencode session`/`opencode export` features; the CLI reference documents a broad set of commands for session management and data export (opencode-cli-docs.md).
- OpenCode stores session and application data under `~/.local/share/opencode/` on macOS/Linux (opencode-troubleshooting.md), which is the same location leveraged by local-first telemetry plugins.
- There is an open request and discussion about native OTEL-style environment-variable-driven export; issue #14246 asks whether OpenCode will support standard OTEL_* env vars. That issue indicates the project does not currently provide first-class OTEL via standard env-vars (github-anomalyco-opencode-issues-14246.md).

4) Alternatives: survey of saved plugin sources

- Tokenscope (ramtinJ95): deep per-session breakdown tool that consumes recorded OpenCode telemetry and emits a standalone report; designed to run on recorded data and keep recorded totals separate from estimates (github-ramtinJ95-opencode-tokenscope.md).
- opencode-plugin-otel (DEVtheOPS): exports metrics/traces/logs to OTLP backends; documents metric names, event shapes, a long list of environment variables and plugin options, and examples for SigNoz, Datadog, Honeycomb (github-DEVtheOPS-opencode-plugin-otel.md). Note: the package's npm page metadata was not archived here (see flagged claims).
- Context-Analysis-Plugin (Igor Warzocha): provides instant visual breakdowns (`/context`) for a live session with charts and tool-level attribution (github-IgorWarzocha-Opencode-Context-Analysis-Plugin.md).
- SigNoz integration guide (signoz-opencode-observability.md) documents using opencode-plugin-otel to send data to SigNoz and contains practical setup steps and troubleshooting guidance.
- External/auxiliary tools mentioned in higher-level notes (coldhell7 token-counter, ccusage CLI) were not fully archived here; the ccusage guide file is empty in the saved sources and must be treated as [source not archived — from researcher res-1 findings].

5) OMO / oh-my-opencode-slim relevance

Source anchor: knowledge/res006-telemetry-plugin-alternatives/sources/github-alvinunreal-oh-my-opencode-slim.md

Key fact (sourced):

- The oh-my-opencode-slim project bundles background-agent orchestration, skills, and presets; its preserved README does not bundle or recommend the telemetry plugins under review and instead documents its own bundled skills and subagents. There is no indication in the archived oh-my-opencode-slim README that it ships a telemetry plugin or that the OMO preset explicitly recommends any of the three plugins above (github-alvinunreal-oh-my-opencode-slim.md).

6) Decision-relevant synthesis and conclusion

Evidence-based observations (source anchors noted inline):

- Native `opencode stats` + the core database path (`~/.local/share/opencode/`) provide a baseline capability that already satisfies many operational needs for on-demand token/cost summaries and ad-hoc exports (opencode-cli-docs.md; opencode-troubleshooting.md).
- opencode-telemetry fills the niche of passive, persistent, forensic historical recording and cross-session rollups; it is complementary to Tokenscope's deep one-shot analyses and to opencode-plugin-otel's streaming-export model when an external backend is required (github-agostinilabsrl-opencode-telemetry.md; github-ramtinJ95-opencode-tokenscope.md; github-DEVtheOPS-opencode-plugin-otel.md).
- Upstream issues indicate a handful of operational bugs and migration/portability gaps that explain some observed data loss (DB index/schema migrations, version pinning needed to avoid `@latest` caching, short-session recording gaps). These are tracked as issues #50–53 in the plugin repository (github-agostinilabsrl-opencode-telemetry-issues.md).

Bottom line (decision-relevant):

- The audit found no evidence that external analytics consumption is currently taking place from the locally archived sources — opencode-telemetry is intentionally local-first (github-agostinilabsrl-opencode-telemetry.md).
- Core OpenCode tooling (stats + DB) covers a majority of standard needs; where continuous external export is required, opencode-plugin-otel is a supported path and Tokenscope/Context-Analysis cover interactive and deep forensic workflows (opencode-cli-docs.md; github-DEVtheOPS-opencode-plugin-otel.md; github-ramtinJ95-opencode-tokenscope.md; github-IgorWarzocha-Opencode-Context-Analysis-Plugin.md).
- A portability/installation bugset (pinning, DB migrations, short-session installs) appears to be project-local and is tracked upstream in the opencode-telemetry issue list; operational mitigation is to pin plugin versions and apply the documented migration checks (github-agostinilabsrl-opencode-telemetry-issues.md).

Works cited (local archived sources — MLA-style pointer to saved files):

- agostinilabsrl. "opencode-telemetry". README and docs. knowledge/res006-telemetry-plugin-alternatives/sources/github-agostinilabsrl-opencode-telemetry.md.
- agostinilabsrl. "opencode-telemetry — issues". knowledge/res006-telemetry-plugin-alternatives/sources/github-agostinilabsrl-opencode-telemetry-issues.md.
- Ainsley0917. "opencode-token-monitor". knowledge/res006-telemetry-plugin-alternatives/sources/github-Ainsley0917-opencode-token-monitor.md.
- DEVtheOPS. "opencode-plugin-otel". knowledge/res006-telemetry-plugin-alternatives/sources/github-DEVtheOPS-opencode-plugin-otel.md.
- RamtinJ95. "opencode-tokenscope". knowledge/res006-telemetry-plugin-alternatives/sources/github-ramtinJ95-opencode-tokenscope.md.
- IgorWarzocha. "Opencode-Context-Analysis-Plugin". knowledge/res006-telemetry-plugin-alternatives/sources/github-IgorWarzocha-Opencode-Context-Analysis-Plugin.md.
- anomalyco. "OpenCode Issues: OTEL support". knowledge/res006-telemetry-plugin-alternatives/sources/github-anomalyco-opencode-issues-14246.md.
- opencode docs. "CLI". knowledge/res006-telemetry-plugin-alternatives/sources/opencode-cli-docs.md.
- opencode docs. "Troubleshooting". knowledge/res006-telemetry-plugin-alternatives/sources/opencode-troubleshooting.md.
- SigNoz. "OpenCode Observability". knowledge/res006-telemetry-plugin-alternatives/sources/signoz-opencode-observability.md.
- oh-my-opencode-slim. knowledge/res006-telemetry-plugin-alternatives/sources/github-alvinunreal-oh-my-opencode-slim.md.

Flagged claims — outside archived sources (see registration below):

- npm registry metadata (dist-tags, release dates) for opencode-telemetry — [source not archived — from researcher res-1 findings]
- npm registry metadata (dist-tags, release dates) for opencode-token-monitor — [source not archived — from researcher res-1 findings]
- npm/@devtheops package metadata (version/date) for opencode-plugin-otel — [source not archived — from researcher res-1 findings]
- ccusage pricing/cost notes (ccusage.com guide) — [source not archived — from researcher res-1 findings]

End of conspect.
