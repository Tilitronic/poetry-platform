# WSL2 desktop notifications require a daemon - dbus-send to WSLg is not zero-install (2026-08-12)

- **Date:** 2026-08-12
- **Source:** DIA-122 Phase-1 GATE research (ai-specialist lane, web-fresh; ticket docs/dev-infra-audit/tickets/DIA-122-needs-input-ticker.md). Installed-package ground truth: @opencode-ai/sdk v2 gen types + @opencode-ai/plugin@1.18.10 Hooks interface.
- **Status:** APPLIED - DIA-122 implemented with the corrected channel (in-TUI toast + powershell.exe WinRT desktop toast; dbus-send dropped until a daemon is installed).
- **Outcome note:** the approved channel for the DIA-122 needs-input ticker ("dbus-send direct -> WSLg toast, zero installs") was CONTRADICTED by gate research: the freedesktop Notifications spec REQUIRES a notification server (daemon) on the session bus, and WSLg does not provide org.freedesktop.Notifications by default. dbus-send fails with ServiceUnknown without one.

## Pattern

A developer-approved notification channel assumed `dbus-send` to `org.freedesktop.Notifications` would reach WSLg and render a Windows toast with zero installs. Gate research (freedesktop spec + WSL2 community evidence) showed the assumption was wrong: WSLg does NOT host the org.freedesktop.Notifications service; a daemon (WslNotifyd, wsl-notify-send, dunst/mako/swaync) is required. Zero-install alternatives that DO work on WSL2: OSC 777 terminal notifications (VS Code/Windows Terminal support it), powershell.exe WinRT toast (via WSL interop, ~500ms spawn), and in-TUI toast (tui.showToast).

## Rule

Before designing a dbus-based notification channel, verify the notification SERVER exists on the session bus (daemon installed), not merely that dbus-send exists and the bus is reachable. On WSL2, do not assume WSLg delivers org.freedesktop.Notifications - verify daemon presence or use a zero-install path (OSC 777 / powershell.exe WinRT / in-TUI toast).

## Verified facts (also recorded for the DIA-122 implementation)

- The plugin "event" catch-all receives question.asked / permission.asked / question.replied / question.rejected / permission.replied / session.idle / session.status at RUNTIME, but the installed @opencode-ai/plugin@1.18.10 TS types (v1 Event union) do not declare the question events - the plugin must cast to a custom union. Handle BOTH question.asked and question.v2.asked (same for permission.v2.asked).
- The "question" tool emits question.asked (question service publishes Event.Asked). The wait_for_user tool path is UNVERIFIED - add a tool.execute.before hook on wait_for_user as a belt-and-suspenders ENTER trigger (dedup makes double-entry harmless).
- chat.message fires for genuine user messages (role user) - use it to CLEAR needs-input, but guard against synthetic/compaction auto-continue messages (check variant or use experimental.compaction.autocontinue as a suppression flag).
- Session titles: available at session.created properties.info.title AND session.updated properties.info.title; fall back to ctx.client.session.get() for pre-existing sessions.
- session.idle noise: only ENTER on orchestrator idle with delegationsSinceHandoff > 0 (mirror the delegation-observer handoff pattern); subagent idle must not enter the developer-input bucket.
- Community plugin cross-check CONFIRMED: no scanned plugin maintains a persistent multi-session "which sessions are waiting" ticker (closest: opencode-notify kdcokenny + opencode-notifier expose {sessionTitle} placeholders). Build in-house stands.
- TUI-safety (res007): the OSC 777 escape sequence from a server plugin must go through a subprocess whose stdout cannot interleave with the TUI render (e.g. ctx.$.echo) - empirically verify; powershell.exe stdout must be discarded.

## Outcome

- DIA-122 IMPLEMENTED with the corrected channel (config change applied 2026-08-12 via `.opencode/plugins/needs-input-observer.ts`): in-TUI toast (`tui.showToast`) as primary + powershell.exe WinRT desktop toast as away-from-terminal channel; dbus-send dropped until a notification daemon is ever installed.
- Restart-verify pending (section-10 Phase 5): next opencode launch - trigger a question, verify ticker.json/ticker.md entry + in-TUI toast + WinRT toast, clear on reply.

## Reusable lesson

Verify the notification server (daemon) exists before committing to a dbus notification channel; on WSL2 prefer zero-install paths (OSC 777, powershell.exe WinRT, in-TUI toast) unless a daemon is already installed. Also: plugin event-hook type safety lags runtime for question/permission events on plugin@1.18.10 - expect to cast, and handle versioned event names.

## Tags

DIA-122, wsl2, wslg, dbus, notifications, freedesktop, osc-777, powershell-winrt, needs-input-ticker, ai-specialist, section-10-gate
