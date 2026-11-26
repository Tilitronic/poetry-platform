# TUI Corruption — stdout/stderr painted over TUI (res007-tui-corruption-stdout)

Created: 2026-08-09

Summary
The OpenCode terminal UI (TUI) can be corrupted when arbitrary stdout/stderr writes occur while the renderer is active. The core bug class is that OpenCode's TUI implementation does not use an alternate screen buffer and disables stdout interception (via disableStdoutInterception() in the @opentui/solid framework). Any raw writes from plugins, hooks, or internal debug tooling can therefore be emitted directly into the terminal surface at the renderer's current cursor position. The result is visual corruption: raw text dumps replacing the UI, garbled ANSI/UTF-8 sequences, ghost lines, and misplaced block cursor glyphs.

The bug manifested for the poetry-platform user as a full-viewport dump of a subagent's chain-of-thought: panels and borders disappeared, a block cursor sat mid-text, and block glyphs (e.g., ▓▓▓▓) appeared on the last line.

Bug class (technical)
- TUI implementation: @opentui/solid + @opentui/core (~0.1.77) is driving terminal rendering.
- No alternate screen buffer and explicit call to disableStdoutInterception() means the process's stdout/stderr remain live to the TTY while the renderer paints.
- Consequence: any process-global console.write/console.trace/process.stdout.write will interleave with the renderer's ANSI control sequences and the current buffer, producing corruption.

Incident (observed)
- Symptom reported: "terminal UI broken during subagent calls" — full viewport replaced by raw subagent output including chain-of-thought text; TUI panels/borders absent; block cursor mid-text; block glyphs (▓▓▓▓) on final line.
- Repro steps (summary from issue threads): run a plugin or local plugin hook that writes plugin output directly to stdout while the TUI is rendering a subagent session; terminal repaint (resize) sometimes recovers UI state.

Root cause (local, project-specific)
- A local plugin discovered in the user's home config: ~/.config/opencode/plugins/subagent-reporter.ts (auto-loaded per OpenCode docs on plugins). The plugin is not listed in opencode.json plugin arrays but is loaded from the global plugins directory (see OpenCode plugin docs).
- The plugin hooks message events and writes raw data to process.stdout:
  - line ~218: writes "[AGENT FINISHED]"
  - line ~248: writes tool progress
  - line ~266: writes full subagent text output
  - line ~281: writes full chain-of-thought reasoning
- Because these are raw writes to process.stdout within the same TTY process as the TUI renderer, they are emitted into the renderer surface and reproduce the observed symptoms.
- TUI-safe alternative: use the SDK logging API (ctx.client.app.log() / client.app.log()), or the plugin SDK's logger, rather than process.stdout.write or console.log. Issue #6830 explicitly documents guidance to use the app.log() API.

Upstream landscape (issues & relevance)
- #8639 — background logs printed to TUI; reports stdout/stderr pollution of the TUI and background logging interfering with UI rendering. (See GitHub issue #8639.)
- #6830 — plugin console.log / stdout pollutes the TUI. Recommended mitigation: use app.log() (SDK logger) instead of console.*. (See GitHub issue #6830.)
- #19108 — plugin console output corrupts TUI; PR #19109 proposes a global console interception strategy. (See GitHub issue #19108.)
- #12931 — async handler errors can corrupt the TUI when unguarded stack traces are printed.
- #16859 — reports of UI layout broken, including lack of alternate screen buffer semantics.
- #6880 — subagent output rendering broken / subagent output directly interfering with TUI render pipeline.
- #31219 — hook stderr painted into input box (stderr routed to wrong TUI region).
- #16841 — console.trace corruption (trace output interleaving with renderer sequences).
- #17793 — regression reports of TUI corruption in more recent releases.
- Related: #15751 and #20047 (similar stdout/stderr sharing and plugin-scope issues).

Mitigation and short-term fixes
- Remove/disable offending local plugin: rename or move ~/.config/opencode/plugins/subagent-reporter.ts out of the plugins directory so it is not auto-loaded. This is a fast, local mitigation.
- Rewrite the plugin to use the SDK logger (ctx.client.app.log() / client.app.log()) or an API that safely forwards messages to the TUI's logging surface rather than writing to process.stdout. Avoid console.log, console.trace, and process.stdout.write in plugins running inside the TUI process.
- Temporary workaround: resizing the terminal forces a repaint which often restores the TUI to a consistent state (observed as a common workaround in issue reports).
- Upstream: adopt a global console interception / alternate-screen-buffer policy in the TUI runtime so that stdout/stderr are either captured or routed to a non-rendering buffer when the renderer is active (PR #19109 explores interception; alternate-screen-buffer behaviour needs enforcement).

Key technical facts to preserve
- TUI stack: @opentui/solid + @opentui/core ~0.1.77.
- OpenCode release: v1.18.12 (2026-08-04) for the affected runtime.
- Plugin loading: local plugins in ~/.config/opencode/plugins/ are auto-loaded at startup (not required to be listed in opencode.json plugin[] arrays).
- Plugin API drift example: token-monitor pins @opencode-ai/plugin@^1.1.51 while telemetry pins ^1.14.28 — demonstrates incompatible expectations across plugins that can surface in unexpected behaviours.
- Plugins run in the same TTY process and share the global console; they are therefore capable of corrupting the renderer if they write raw ANSI/UTF-8 to stdout/stderr.

Works Cited (MLA-style)
- OpenCode. "Plugins | OpenCode." opencode.ai, https://opencode.ai/docs/plugins/. Accessed 9 Aug. 2026.
- anomalyco. "Issue #8639 — background logs printed to TUI." GitHub, https://github.com/anomalyco/opencode/issues/8639. Accessed 9 Aug. 2026.
- anomalyco. "Issue #6830 — tui output corrupted when using plugins." GitHub, https://github.com/anomalyco/opencode/issues/6830. Accessed 9 Aug. 2026.
- anomalyco. "Issue #19108 — plugin console corrupts TUI." GitHub, https://github.com/anomalyco/opencode/issues/19108. Accessed 9 Aug. 2026.
- anomalyco. "Issue #12931 — handler errors corrupt TUI." GitHub, https://github.com/anomalyco/opencode/issues/12931. Accessed 9 Aug. 2026.
- anomalyco. "Issue #16859 — UI layout broken." GitHub, https://github.com/anomalyco/opencode/issues/16859. Accessed 9 Aug. 2026.
- anomalyco. "Issue #6880 — subagent output broken." GitHub, https://github.com/anomalyco/opencode/issues/6880. Accessed 9 Aug. 2026.
- anomalyco. "Issue #31219 — hook stderr painted into input box." GitHub, https://github.com/anomalyco/opencode/issues/31219. Accessed 9 Aug. 2026.
- anomalyco. "Issue #16841 — console.trace corrupts TUI." GitHub, https://github.com/anomalyco/opencode/issues/16841. Accessed 9 Aug. 2026.
- anomalyco. "Issue #17793 — TUI corruption regression." GitHub, https://github.com/anomalyco/opencode/issues/17793. Accessed 9 Aug. 2026.
