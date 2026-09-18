# Research Workflow Tool-Gaps: Collector/Archiver vs Synthesizer (2026-08-13)

- **Date:** 2026-08-13
- **Source:** DIA-126 direction (c) gate research (ai-specialist lane, web-fresh; ticket docs/dev-infra-audit/tickets/DIA-126-autonomous-mode-permission-hardening.md - OPEN Major). Registered per AGENTS.md section 10 Phase 1 ("orchestrator registers the findings").
- **Status:** VALIDATION-PASSED - Option B implemented 2026-08-13 (see CHANGELOG); restart-verify pending next opencode launch.
- **Ticket:** DIA-126 (OPEN) - "autonomous overnight mode: permission allow-list + no-stall guarantees".

## Context

Conspecter tool-gaps found during the night run review (DIA-126 direction (c)): res018 was archived via webfetch; the model claimed it had no shell while the config granted bash; the crawl4ai tier was documented in the research model but not permitted in the conspecter permission block.

## Finding 1: division of labor - collector/archiver vs synthesizer separation

The collector/archiver vs synthesizer separation is the dominant research-agent architecture:

- Anthropic multi-agent research system (research lead + subagents) separates browsing/collecting from writing.
- FS-Researcher (ACL 2026): Context Builder browses and archives sources; Report Writer reads the knowledge base ONLY, with web tools REMOVED from the writing lane.
- Prompt20 six-stage pipeline keeps fetch/archive stages distinct from synthesis stages.
- Zylos deep-research survey and a 170-papers meta-analysis (blog.sourceshift.io) both converge on the same separation pattern.
- The project's documented model (researcher returns URLs, conspecter archives + synthesizes) is a valid variant of this separation.

Confidence: HIGH. Sources: anthropic.com/engineering/multi-agent-research-system; aclanthology.org/2026.acl-long.288.pdf; blog.prompt20.com; zylos.ai deep-research survey; blog.sourceshift.io 170-papers meta-analysis.

## Finding 2: tool assignment - deny webfetch on synthesis lanes, scope bash on collector lanes

- Synthesis lanes (conspecter) should have webfetch EXPLICITLY denied: OpenCode default-allows unlisted tools, so denial must be explicit.
- Project precedent: orchestrator:149 and ai-auditor:461 already carry webfetch deny entries.
- OWASP agent security cheat sheet: least-privilege for agent tool surfaces.
- Collector lanes get scoped bash (curl/wget/trafilatura/crwl) - a controlled execution surface, not a blanket shell.

Confidence: HIGH. Sources: opencode.ai/docs/permissions (default-allow semantics); local .opencode/opencode.jsonc orchestrator:149 + ai-auditor:461; OWASP agent security cheat sheet.

## Finding 3: crawl4ai naming - the CLI binary is `crwl`, NOT `crawl4ai`

- The crawl4ai CLI binary is named `crwl` (crawl4ai docs / docs.crawl4ai.com/core/cli/), usage: `crwl <url> -o markdown` / `-o markdown-fit` / `-O <path>` for file output.
- Host: crwl present (uv tool crawl4ai v0.9.2 at /home/qualt/.local/bin/crwl); binary responds (`crwl crawl --help` exit 0).
- Container: crawl4ai package + crawl4ai-* helpers exist, but NO crwl binary on PATH.
- Agent bash runs HOST-side per DIA-067, so the `crwl *` allow-list entry suffices; NO container change needed (dev-entrypoint.sh / Dockerfile.dev skipped).

Confidence: HIGH. Sources: github.com/unclecode/crawl4ai; docs.crawl4ai.com/core/cli/; local host probe (2026-08-13); DIA-067.

## Finding 4: model misperception - tool-awareness failure and its mitigation

- deepseek-v4-flash claimed "no shell" while config granted bash - a tool-awareness failure, not a config gap.
- Mitigation adopted: explicit ## Your Tools manifest in the agent prompt + verify-before-claiming instruction (see .opencode/agents/conspecter.md).
- Structural fix: tool-coverage audit (DIA-066, OPEN) remains the long-term remedy.

Confidence: HIGH. Source: DIA-126 night-run review (res018 lane transcript); local conspecter agent config.

## Synthesized recommendation (DIA-126 direction (c), Option B - implemented)

1. Keep the documented research model (researcher returns URLs, conspecter archives + synthesizes) - the separation is best practice.
2. Add `crwl *` to the conspecter bash allow-list (crawl4ai CLI fallback for JS-heavy pages).
3. Add explicit `webfetch: deny` to the conspecter permission block.
4. Remove the websearch MCP from conspecter in all 3 OMO presets (cebula/opencode-go/free) - synthesis lane must not search.
5. Add a ## Your Tools manifest + verify-before-claiming instruction to the conspecter agent prompt.

## Delta: current state vs best practice

| Aspect | Before (night run) | After (Option B) |
| Crawl4ai tier | Documented but NOT permitted | `crwl *` allowed on conspecter bash allow-list |
| webfetch on synthesis lane | Used as fallback (res018) | Explicitly denied |
| websearch on synthesis lane | Present in 3 presets | Removed from all 3 presets |
| Tool awareness | Model claimed no shell | ## Your Tools manifest + verify-before-claiming |
| Container change | Not needed | Not needed (host-side bash per DIA-067) |

## Outcome field (fill at decision time)

Decision: developer approved Option B (keep documented model, fix the gaps). Implemented 2026-08-13 (see CHANGELOG). ai-auditor APPROVE-WITH-NOTES (actionable concern resolved: cross-preset harmonization). Outcome: validation-passed (implemented 2026-08-13, restart-verify pending next opencode launch).

## Tags

DIA-126, research-workflow, tool-gaps, conspecter, crawl4ai, crwl, webfetch-deny, least-privilege, collector-synthesizer, tool-awareness, section-10-gate, ai-specialist
