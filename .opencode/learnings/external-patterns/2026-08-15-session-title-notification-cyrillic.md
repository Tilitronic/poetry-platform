# DIA-189: session title uniqueness, notification attribution, Cyrillic visibility - gate research (2026-08-15)

- **Date:** 2026-08-15
- **Source:** DIA-189 (Major, opencode-config) - developer screenshot report (clipboard-84a17fb4.png, 4 identical "opencode poetry-platform" TUI rows) -> ai-specialist Phase 1 gate research (AGENTS.md section 2.5) -> developer-reviewed Variant A design -> coder implementation merged as ef3d97d (squash of omos/dia-189) -> ai-auditor APPROVE-WITH-NITS (F1-F4 accepted). Registered per AGENTS.md section 2.5 Phase 6.
- **Status:** APPLIED - implementation merged ef3d97d onto omo-slim-changes; all automated gates green (test-config 56/56, harness 14/14, tsc 0, eslint 0); restart-verify PENDING (needs an OpenCode restart + visual checks).
- **Ticket:** DIA-189 (OPEN) - "terminal session identity: unique names + notification attribution + Cyrillic visibility" (docs/dev-infra-audit/tickets/DIA-189-terminal-session-identity-names-notifications-cyrillic.md).

## Gate research findings (ai-specialist Phase 1, 2026-08-15)

### 1. Session titles ARE settable programmatically (SDK 1.18.10)

- OpenCode SDK 1.18.10 `types.gen.d.ts`: `Session.create` accepts `title?`, `Session.update` accepts `title?`.
- A plugin CAN rename a session on `session.created`: `ctx.client.session.update({ path: { id }, body: { title } })`.
- Verified in the merged implementation: needs-input-observer.ts `event` handler, `case "session.created"` (DIA-189 A1) renames any session whose title is missing/empty or still the default label to "<label> [<short-id>]" via the SDK. Guards: never double-rename a title that already carries a " [xxxxxx]" suffix; fail-soft (a cosmetic rename must never crash the plugin - warn on error and continue).

### 2. TUI session list label source and default

- The TUI session list displays `Session.title`.
- Default label is binary + cwd: "opencode poetry-platform" for this project - identical for every parallel session (DIA-085 worktree model), which is exactly the reported problem.
- No `/title` TUI command exists; no `tui.json` title template exists - there is no user-facing naming surface to lean on, so the plugin-side rename is the correct seam.

### 3. Cyrillic invisibility was a SANITIZER bug, not a channel bug

- `tui.showToast` passes text raw (terminal font dependent for Cyrillic - OK at the terminal that renders Unicode).
- `powershell.exe` WinRT ToastText02 is UTF-16 and Unicode-capable - the desktop toast channel was NEVER the blocker.
- Root cause (code-verified): the project's DIA-122-era sanitizer in `fireDesktopToast()` was `s.replace(/[^\x20-\x7E]/g, " ")` - it stripped EVERY non-ASCII character (Cyrillic U+0400-U+04FF) and replaced it with a space, making Ukrainian notification text blank. The DIA-079 ASCII-only protocol correctly governs SOURCE files and dispatch payloads but must NEVER strip user-facing notification content.

### 4. Safe PowerShell sanitizer (DIA-189 A3)

- Strip control chars C0/C1 only: `[\x00-\x1F\x7F-\x9F]` -> space.
- Collapse CR/LF/TAB first (unchanged behavior): `[\r\n\t]+` -> space.
- Double single quotes for single-quoted PowerShell literals: only `'` needs doubling (PowerShell escapes by doubling, no backslash escaping).
- Truncate to 180 chars (unchanged).
- Printable Unicode (Cyrillic) is preserved end-to-end: the toast template (ToastText02) + CreateTextNode + UTF-16 interop all handle it once the strip is gone.

## Outcome: DIA-189 Variant A (applied)

1. **A1 - unique session titles:** `session.update` rename on `session.created` -> "opencode poetry-platform [xxxxxx]" distinct labels in the TUI session list.
2. **A2 - short-id notification attribution:** `notify()` pins the same " [<short-id>]" suffix (session_id.slice(-6)) onto the title in BOTH channels (tui.showToast title + desktop toast title); never double-appends when the suffix is already present.
3. **A3 - Cyrillic-preserving sanitizer:** C0/C1-only strip replaces the old [^\x20-\x7E] strip in the WinRT desktop toast path; Ukrainian notification text now renders in both channels.

Evidence-backed decision variants (EBDV, DIA-115) recorded in the DIA-189 ticket.

## Outcome field

- Verified 2026-08-15: implementation merged ef3d97d (3 files, +522/-9); automated gates green (test-config 56/56, harness 14/14, tsc 0, eslint 0); ai-auditor APPROVE-WITH-NITS with F1-F4 accepted by developer disposition. Restart-verify PENDING (developer step): restart OpenCode, confirm distinct terminal labels (opencode poetry-platform [xxxxxx]) in the session list, trigger a question/permission/idle to see a notification with the short-id suffix, and confirm a Ukrainian-language notification renders Cyrillic in both the in-TUI toast and the WinRT desktop toast. Then flip DIA-189 CLOSED; if regression found, update this entry to 'regressed'.

## Tags

DIA-189, session-title, session.update, notification-attribution, cyrillic, sanitizer, powershell, toast, tui, section-10, ai-specialist, ai-auditor, restart-verify, variant-A

## DIA-189b follow-up (2026-08-15): Pty vs Session fix-target mismatch
- VERIFICATION LESSON: the OpenCode TUI 'terminal strip' (rows with terminal glyphs + '+' chevron) is driven by Pty.title (types.gen.d.ts:562-570: { id, title, command, args, cwd, status, pid }), NOT Session.title. DIA-189 Variant A renamed Session titles via session.update on session.created - the visible surface never changed. Always verify WHICH object drives the visible UI surface before implementing a rename fix.
- SDK SURFACE CORRECTION: ctx.client.pty IS fully exposed to server plugins: pty.list() GET /pty, pty.create() POST /pty, pty.update({path:{id},body:{title?}}) PUT /pty/{id}, pty.get, pty.remove, pty.connect (sdk.gen.d.ts:38-63; plugin dist index.d.ts:37 ctx.client = ReturnType<typeof createOpencodeClient>). The earlier claim 'no pty.update exposed to plugins' was FALSE. pty events (pty.created/updated/exited/deleted) are in the v1 Event union (types.gen.d.ts:571-602) and reach the plugin event hook.
- RETRO-RENAME PATTERN: session.created/pty.created hooks only fire for NEW items; after a restart, pre-existing sessions/ptys are re-listed from persistence (no created event). A boot-time retro pass (void async after seedFromDisk(): pty.list() + session.list(), fail-soft per surface, skip custom/suffixed titles, [short-id] suffix, in-memory dedupe with 5s TTL) closes the after-restart gap.
- HARNESS PATTERN: mock ctx.client.pty.list/update + session.list; boot pass must settle within two setTimeout(0) macrotask turns for hermetic Bun tests; tolerate plain-array AND {data,error} SDK envelope shapes; test non-throw {error} envelopes (silent-empty degradation is the classic invisible failure).
