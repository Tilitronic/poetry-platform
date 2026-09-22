# TUI stdout corruption from auto-discovered plugins writing to process.stdout (2026-08-09)

- **Date:** 2026-08-09
- **Source:** §10 Phase-1 gate research by @ai-specialist + conspect pipeline (res007). Registered per AGENTS.md §10 ("orchestrator registers the findings"); conspect: `knowledge/res007-tui-corruption-stdout/` (10 upstream sources + docs). Executor lane applied the developer decision: DISABLE over rewrite.
- **Status:** REGISTERED 2026-08-09 — plugin disabled (renamed `.disabled`), learnings entry + CHANGELOG + memory-shelf res007 registration complete.

## Outcome

- **Plugin disabled 2026-08-09 (developer chose disable over rewrite).** The offending global plugin `~/.config/opencode/plugins/subagent-reporter.ts` was renamed to `subagent-reporter.ts.disabled` (reversible, NOT deleted). Root cause: the plugin wrote FULL subagent text output and chain-of-thought reasoning to `process.stdout` on every `message.part.updated` (source lines ~218 `[AGENT FINISHED]`, ~248 tool progress, ~266 full subagent text, ~281 thinking). OpenCode's TUI has no alternate screen buffer and calls `disableStdoutInterception()` — raw writes land on the live render surface → corrupted TUI during subagent calls (flat raw text dump, misplaced cursor, garbled glyphs). Grep confirmed NO config reference to `subagent-reporter` (it was auto-discovered from `~/.config/opencode/plugins/`, not in any `plugin[]` array), so rename alone fully disables it.

## Findings

- **1 — Bug class:** OpenCode TUI (@opentui/solid + @opentui/core ~0.1.77) uses NO alternate screen buffer and explicitly calls `disableStdoutInterception()` → process stdout/stderr stay live to the TTY while the renderer paints. Any process-global write (`process.stdout.write`, `console.log`, `console.trace`) interleaves with renderer ANSI sequences → corruption.
- **2 — Culprit (local):** `~/.config/opencode/plugins/subagent-reporter.ts` — auto-discovered (direct `.ts`/`.js` children of the global plugins dir are loaded; NOT required to be in `plugin[]`). Writes full subagent text + reasoning to `process.stdout` on every `message.part.updated` → reproduced the exact symptom (full-viewport dump of subagent chain-of-thought, block cursor mid-text, ▓▓▓▓ glyphs on last line).
- **3 — TUI-safe alternative:** use the SDK logger — `ctx.client.app.log()` (docs guidance in #6830) — instead of `process.stdout.write` / `console.*` inside plugins running in the TUI process.
- **4 — Upstream landscape (anomalyco/opencode):** #8639 background logs printed to TUI; #6830 plugin console/stdout pollutes TUI (app.log() recommended); #19108 plugin console output corrupts TUI (PR #19109 global console interception); #12931 async handler errors corrupt TUI; #16859 UI layout broken / no alt-screen semantics; #6880 subagent output breaks render pipeline; #31219 hook stderr painted into input box; #16841 console.trace corruption; #17793 TUI corruption regression. Related: #15751, #20047.

## Recommendations

- **Mitigation = disable OR rewrite.** Chosen: disable (rename to `.disabled`, reversible) — fastest safe local fix, keeps the option to rewrite later with `ctx.client.app.log()`.
- **If rewritten:** replace all `process.stdout.write(...)` with `ctx.client.app.log(...)`; avoid `console.log`/`console.trace` in plugins.
- **Upstream:** adopt global console interception / alternate-screen-buffer policy while the renderer is active (PR #19109 direction).

## Sources

- Conspect: `knowledge/res007-tui-corruption-stdout/res007-tui-corruption-stdout-conspect.md` + `sources/*.md` (10) + `.source-urls.txt`
- Plugin source (disabled): `~/.config/opencode/plugins/subagent-reporter.ts.disabled` (lines 218/248/266/281)
- OpenCode plugin docs: `https://opencode.ai/docs/plugins/`
- Upstream issues: #8639 #6830 #19108 #12931 #16859 #6880 #31219 #16841 #17793

## Tags

§10, tui-corruption, stdout, plugins, subagent-reporter, process.stdout, disableStdoutInterception, alternate-screen-buffer, app.log, res007, upstream
