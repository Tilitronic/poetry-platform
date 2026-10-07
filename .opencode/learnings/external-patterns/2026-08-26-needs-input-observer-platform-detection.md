# Gate Research: needs-input-observer platform detection (powershell.exe toast spam)

Date: 2026-08-26
Source: @ai-specialist section-2.5 gate research (session ses_fc4ceafcdffeUapUVDcuWfjaN0)
Ticket: DIA-260821-3blw 'remove persistent OpenCode input-area banner: powershell.exe toast spawn failed'

## Root cause

needs-input-observer.ts hardcodes powershell.exe WinRT toast as sole desktop channel (DIA-122 WSL-era design); zero platform detection. On pure-Linux host every ENTER into needs-input state spawns powershell.exe -> ENOENT -> console.warn, throttled only by 2s debounces, no warn-once latch -> constant noise.

## Fix pattern (validated against node-notifier / is-wsl / anotifier idioms)

Detection order for powershell-only channel: win32 native OR linux+WSL interop.
WSL detection: existsSync("/mnt/wslg") OR process.env.WSL_DISTRO_NAME OR /proc/version contains /microsoft/i (try/catch read).

1. Platform gate at top of fireDesktopToast(): early-return if !(process.platform === "win32" || isWSL()) - skip silently on pure Linux.
2. Warn-once latch: module-level desktopToastDisabled flag; in child error handler, if ENOENT/"Executable not found": warn ONCE "[needs-input-observer] desktop toast disabled (powershell.exe not found)", set latch, return; other errors warn as before.

Diff ~20 lines added + 1 early-return line. Risk low (pure additive; WSL/Windows behavior unchanged).

Refs: npmjs.com/package/node-notifier (2025-01-26, uses sindresorhus/is-wsl 2.2.0 checking /proc/version for 'microsoft'); anotifier.io (2026, WSL->powershell interop routing).

## Test strategy

needs-input-observer.platform-gate.test.mjs with bun mock.module("node:fs") + mock.module("node:child_process"):
1. pure linux (no WSL markers) -> spawn NOT called
2. WSL with /mnt/wslg -> spawn called with powershell.exe
3. ENOENT latches: first call warns once, second call skips spawn entirely
