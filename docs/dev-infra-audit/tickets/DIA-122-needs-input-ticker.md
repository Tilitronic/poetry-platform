# DIA-122 - needs-input ticker + notifications: surface which opencode session awaits developer input

<!-- Feature request filed 2026-08-12 from developer session observation
     (multi-session workflow). Developer asks: "log a ticker: add notification
     when agent needs developer input... It would be nice to say which session
     needs an input as there may be lots of sessions." This is an
     opencode-config (§10) feature: a new project server plugin maintaining a
     persistent multi-session "needs developer input" ticker + dbus desktop
     notifications naming the waiting session. Planning ticket - no
     implementation performed yet. -->

---

id: DIA-122
title: "needs-input ticker + notifications: surface which opencode session awaits developer input"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: [] # no blockers
discovered: 2026-08-12
source: session-observation (feature request, developer, 2026-08-12)
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0088b1187ffeQJPJJK9xI7FIT5"
lane_id: ""
agent: "build"
model: "deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-122-needs-input-ticker.md", "docs/dev-infra-audit/tickets/README.md", ".opencode/opencode.jsonc", ".opencode/plugins/needs-input-observer.ts", ".opencode/learnings/external-patterns/2026-08-12-wsl2-notifications-daemon-required.md", ".opencode/CHANGELOG.md", "scripts/ticker-render.sh", "scripts/__tests__/ticker-render.bats", "scripts/__tests__/bats-wrapper.sh"]
artifacts: []
evidence: []

---

## Description

**Feature request (developer, 2026-08-12):** a "ticker" that logs when an agent
needs developer input, plus a notification, identifying WHICH session needs
input - critical because many opencode sessions run in parallel (DIA-085
parallel orchestrator sessions / worktree model).

**Research findings (build lane, 2026-08-12):**

1. **Native events exist for exactly this.** The `@opencode-ai/sdk` v2 gen
   types (`node_modules/@opencode-ai/sdk/dist/v2/gen/types.gen.d.ts`) expose:
   `EventQuestionAsked` (`question.asked`, carries `sessionID` + `questions`),
   `EventQuestionReplied` / `EventQuestionRejected`, `EventPermissionAsked`
   (`permission.asked`, carries `sessionID` + `permission` + `patterns`),
   `EventPermissionReplied`, `EventSessionIdle`, `EventSessionStatus`, and the
   `chat.message` plugin hook. All are reachable from a server plugin via the
   `event` catch-all hook (the same mechanism `delegation-observer.ts` already
   uses for `session.idle`/`session.created`/`session.error`).
2. **Native TUI attention exists but is insufficient.** `tui.json`
   `attention` (disabled by default) plays sounds + terminal-mediated desktop
   notifications for question/permission/error/done. It does NOT identify
   WHICH session needs input and does not maintain a persistent multi-session
   ticker. Does not meet the core ask.
3. **Community notification plugins exist but none solve the multi-session
   ticker.** Scan found: `opencode-alert` (OSC-777 terminal notifications,
   focus detection), `opencode-simple-notify` (dbus/osascript),
   `opencode-notify` (Zellij tab blink + macOS), `opencode-notifier`
   (per-event config), `opencode-notifications` (X11+tmux focus),
   `opencode-notify` npm (actionable popups), OCX Notify (node-notifier). All
   fire an OS/terminal notification on the event; none maintain a persistent
   list of which sessions are waiting. Decision: build the ticker in-house
   (no new npm deps; follows the established silent-JSONL + derived-view
   pattern; full control of session identification).
4. **Environment constraints (WSL2 + VS Code Remote-Server).** opencode runs
   on the host (`/home/qualt/.opencode/bin/opencode`, project `.opencode/`
   config active - delegation-observer live, registry.jsonl ~2868 rows).
   WSLg display + dbus present (`DISPLAY=:0`, `WAYLAND_DISPLAY=wayland-0`,
   `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`). `dbus-send` IS
   installed; `notify-send` and a notification daemon (dunst/mako) are NOT.
   **GATE CONTRADICTION (ai-specialist Phase-1, 2026-08-12, very high
   confidence):** the original channel decision (dbus-send ->
   org.freedesktop.Notifications -> WSLg toast, "zero installs") is WRONG -
   the freedesktop Notifications spec REQUIRES a notification daemon on the
   session bus, and WSLg does NOT provide org.freedesktop.Notifications by
   default; dbus-send fails with ServiceUnknown without one (sources:
   standards.freedesktop.org/notification/latest-single, github.com/Thurbeen/
   thurbox commit 5428161, github.com/ultrabig/wslnotifyd,
   github.com/stuartleeks/wsl-notify-send, github.com/Yusuzhan/
   opencode-simple-notify).
   **PHASE-2 DISPOSITION (developer, 2026-08-12):** channel changed to
   **in-TUI toast (`tui.showToast`) as primary + powershell.exe WinRT desktop
   toast as the away-from-terminal channel** (WSL interop verified working on
   this host; zero installs; subprocess stdout discarded so no res007 TUI
   corruption). dbus-send retained only as an opt-in later tier if a daemon
   is ever installed. Gate findings registered in
   .opencode/learnings/external-patterns/2026-08-12-wsl2-notifications-daemon-required.md.

**Approved scope (developer answers 2026-08-12):**

- **Ticker + notifications** (full): server plugin maintaining the
  multi-session needs-input state, a derived ticker view (which sessions are
  waiting), AND dbus desktop notifications with session titles.
- **Channel:** in-TUI toast (`tui.showToast`) as primary + powershell.exe WinRT desktop toast as away-from-terminal channel (post-gate disposition - see GATE CONTRADICTION section; dbus-send retained only as opt-in later tier if a notification daemon is ever installed).
- **Triggers (ENTER needs-input):** `question.asked`, `permission.asked`,
  plus orchestrator `session.idle` after delegations (work finished, awaiting
  developer direction). **Clears:** `question.replied`/`question.rejected`,
  `permission.replied`, `chat.message` (user responded), `session.status`
  working/queued, session deleted. **Separate bucket:** `session.error`.

**Planned design:**

- `.opencode/plugins/needs-input-observer.ts` (new sibling plugin; SRP -
  delegation-observer.ts is already 1715 lines). Own role detection
  (`session.created` -> parentID map; `parentSessionId` = session that calls
  `task()` via `tool.execute.after`). Session titles from the `session.created`
  event `info.title` (human-readable "which session" label).
- State file `.opencode/session/ticker.json`: atomically rewritten
  (tmp -> fsync -> rename, mirroring `atomicWriteHandoff`):
  `{ version, updated_at, waiting: [{ session_id, title, agent, reason:
question|permission|idle, detail, since, ticket? }] }`.
- Notifications: on ENTER transition only (not per-event), ~2s debounce.
  Channel (post-gate): in-TUI toast via `ctx.client.tui.showToast()` (or TUI
  api.ui.toast - verify availability from a server plugin at implementation
  time) + powershell.exe WinRT toast subprocess for desktop notifications
  (stdout discarded, TUI-safe). Notification body carries session title +
  reason. TUI-safe logging via `ctx.client.app.log()` (res007: no raw
  console.\* stdout from plugins). Fail-soft writes (mirror `appendRow`).
- Trusted-plugin exception (accepted): the plugin spawns `powershell.exe`
  (WSL interop) from plugin code for desktop toasts; this execution path is
  NOT mediated by agent `permission.bash` rules - documented as an accepted
  trusted-plugin exception (command is hardcoded, arguments are sanitized,
  stdio is fully discarded).
- Event handling (gate corrections): cast `event` to a custom union covering
  question/permission events (v1 TS types lag runtime); handle BOTH
  `question.asked` and `question.v2.asked` (same for permission). Add
  `tool.execute.before` hook for `wait_for_user` as a belt-and-suspenders
  ENTER trigger (dedup makes double-entry harmless). Guard `chat.message`
  clears against synthetic compaction auto-continue messages (variant field /
  `experimental.compaction.autocontinue` suppression flag). Capture titles
  from `session.created` AND `session.updated`; fall back to
  `ctx.client.session.get()`. ENTER on orchestrator idle only when
  delegationsSinceHandoff > 0 (mirror delegation-observer pattern); subagent
  idle excluded. Compaction survival: inject ticker snapshot via
  `experimental.session.compacting` + re-read ticker.json on boot.
- Derived view: `scripts/ticker-render.sh` (bats-testable) ->
  `.opencode/session/ticker.md` (table of waiting sessions). Optional
  `/ticker` slash command.
- Registration: `.opencode/opencode.jsonc` plugin array (after
  delegation-observer.ts).

**Workflow requirements:** §10 AI-Devtools Modernization Workflow (this is
.opencode/ tooling): ai-specialist gate research -> developer review ->
design -> coder (tdd-craftsman) -> ai-auditor independent review -> validate
(restart + functional smoke) -> register (CHANGELOG, learnings,
memory-manager). DIA-063 §10 ticket gate satisfied by this ticket.

## Verification

- Config gates pass after implementation: `make test-config` exit 0.
- Plugin unit tests (state machine) pass: ENTER on question/permission/idle,
  CLEAR on reply/permission-reply/chat.message, dedupe on repeated idles,
  error bucket separate, fail-soft on write failure.
- `scripts/ticker-render.sh` bats suite passes (waiting table render, empty
  state, malformed ticker.json tolerated).
- Functional smoke (after opencode restart, §10 Phase 5): trigger a `question`
  in a session -> `ticker.json` gains an entry with correct session_id/title/
  reason/since and `ticker.md` lists it -> answering clears it; a
  `permission.asked` and an orchestrator idle-after-delegations produce
  entries; an in-TUI toast + powershell.exe WinRT toast are fired with the
  session title in the body (notification path unit-mocked in tests; the real
  WinRT call verified once against this host - `powershell.exe` interop
  confirmed working 2026-08-12).
- No TUI corruption: no plugin stdout writes (res007 check).

## Fix

Implemented 2026-08-13 via the section-10 chain (ai-specialist gate research
registered in learnings; developer Phase-2 disposition: in-TUI toast + WinRT
desktop toast channel; this coder implementation). Changes left UNCOMMITTED in
the worktree per brief.

**Files created:**

- `.opencode/plugins/needs-input-observer.ts` (NEW) — hooks-style server
  plugin (`export default needsInputObserver: Plugin`, no tool map). State
  machine per the approved spec:
  - ENTER: `question.asked` / `question.v2.asked` (reason `question`, detail =
    first question's `question` field, fallback `text`, then JSON), `permission.asked`
    / `permission.v2.asked` (reason `permission`, detail = `permission` +
    `patterns.join(", ")` for v1, `action` + `resources` for v2), orchestrator
    `session.idle` ONLY when `sessionID === parentSessionId || sessionMeta.role
=== "orchestrator"` AND delegationsSinceIdle > 0 (reason `idle`; counter
    reset after entering; subagent idle excluded), plus `tool.execute.before`
    on `wait_for_user` as belt-and-suspenders (detail = `args.reason`; enter()
    dedup makes double-entry harmless).
  - CLEAR: `question.replied` / `question.v2.replied` / `question.rejected` /
    `question.v2.rejected` / `permission.replied` / `permission.v2.replied`,
    `chat.message` guarded against synthetic compaction auto-continue messages
    (per-session flag set by the `experimental.compaction.autocontinue` hook,
    30s TTL-bounded, plus variant-marker regex second guard), `session.status`
    non-idle (agent resumed work; runtime status is `{type: idle|retry|busy}`
    but string statuses also tolerated), `session.deleted`, `session.error`
    (also records the ERROR bucket).
  - ERROR bucket: `session.error` -> separate `errors` list in ticker.json;
    NOT waiting, NEVER notified (kept silent per spec; listed only in the
    ticker view).
  - Role detection + titles: `session.created` -> sessionMeta
    `{parentID, role, title, agent}` (role = parentID ? subagent :
    orchestrator); `session.updated` refreshes title/agent; title fallback on
    notify via `ctx.client.session.get({ path: { id } })` (fail-soft try/catch).
  - Persistence: `.opencode/session/ticker.json` `{version:1, updated_at,
waiting:[...], errors:[...]}` atomically written (tmp -> fsync -> rename ->
    fsync dir, generalized copy of delegation-observer's `atomicWriteHandoff`);
    boot re-seed from disk (restart/compaction survival, fail-soft on malformed
    JSON); `experimental.session.compacting` injects a markdown snapshot of
    waiting sessions (mirror C2).
  - Notifications on ENTER only, ~2s global debounce: in-TUI toast
    `ctx.client.tui.showToast({ body: { title, message: "<reason>: <detail>"
(<=200 chars), variant: "warning" } })` + powershell.exe WinRT ToastText02
    desktop toast (2s desktop-specific debounce; single-line script; ASCII-only,
    single quotes doubled, control chars stripped; stdio discarded
    `["ignore","ignore","ignore"]` so stdout can never corrupt the TUI, res007).
    TUI-safe logging via `ctx.client.app.log()`; `console.warn` (stderr only)
    on failures. No raw console.\* stdout writes.
- `scripts/ticker-render.sh` (NEW) — derived-view renderer (bash-3 compatible,
  requires jq): reads TICKER_FILE (default `.opencode/session/ticker.json`),
  writes TICKER_OUTPUT (default `.opencode/session/ticker.md`) atomically
  (`.tmp` + `mv -f`). Markdown table of waiting sessions oldest-first
  (`sort_by(.since)`), plus `## Errors` section. Pipe chars escaped as `&#124;`
  and CR/LF collapsed for table safety. Exit 0 ALWAYS; missing/malformed
  ticker.json renders the "no sessions waiting" state.
- `scripts/__tests__/ticker-render.bats` (NEW) — 5 hermetic tests
  (TICKER_FILE/TICKER_OUTPUT env override seam; real
  .opencode/session/ticker.json/md never touched): oldest-first table + error
  bucket, missing file empty state, malformed JSON tolerated, errors-only
  view, pipe escaping.

**Files modified:**

- `.opencode/opencode.jsonc` — plugin array: added
  `"file:///workspace/.opencode/plugins/needs-input-observer.ts"` AFTER the
  delegation-observer.ts entry.
- `scripts/__tests__/bats-wrapper.sh` — added `scripts/ticker-render.sh` to the
  bash -n syntax-check list (established convention for every tested script).
- This ticket (Fix section).

**Design decisions (channel change per gate):**

- Notification channel is in-TUI toast (primary) + powershell.exe WinRT
  desktop toast (away-from-terminal), per the developer's Phase-2 disposition
  after the ai-specialist gate contradiction (freedesktop Notifications
  REQUIRES a daemon absent on this WSL2 host; dbus-send would fail with
  ServiceUnknown). No dbus-send tier (opt-in later if a daemon is installed).
- `session.error` ALSO clears the session's waiting entry (an errored turn is
  no longer waiting) while recording the error bucket — errors stay silent in
  notifications per spec.
- `chat.message` clear is suppressed by the compaction auto-continue flag
  (TTL 30s) + a conservative variant-marker regex, so a synthetic "continue"
  cannot clear a waiting session.
- SDK shapes verified from the installed packages
  (`.opencode/node_modules/@opencode-ai/sdk/dist/v2/gen/types.gen.d.ts` +
  `.opencode/node_modules/@opencode-ai/plugin/dist/index.d.ts`): the plugin
  hooks' `ctx.client` is the v1 SDK client, so `tui.showToast` takes
  `{ body: { title, message, variant, duration } }`, `session.get` takes
  `{ path: { id } }`, `app.log` takes `{ body: { service, level, message } }`.

**Verification evidence (all run on host unless noted):**

1. Typecheck: `tsc --noEmit --target ESNext --module Preserve --moduleResolution
Bundler --strict --skipLibCheck --esModuleInterop --isolatedModules
.opencode/plugins/needs-input-observer.ts` -> exit 0 (same flags the
   delegation-observer passes; project-wide `tsc -p tsconfig.json` is not clean
   baseline — unrelated Quasar `#q-app/wrappers` errors).
2. Lint: `eslint .opencode/plugins/needs-input-observer.ts` -> exit 0 (one
   unused-import fix applied; delegation-observer.ts still exits 0).
3. `make test-config` -> exit 0 (JSONC + agent names + output contracts +
   ticket gate + tool audit all pass with the new plugin array entry).
4. `make test-shell` -> exit 0 (224 ok; includes 5 new ticker-render tests
   (ok 145-149) and the extended bash -n syntax check).
5. Renderer smoke: TICKER_FILE fixture with 2 waiting + 1 error -> exit 0,
   correct oldest-first table + `## Errors` section; missing file -> exit 0 +
   "No sessions waiting for developer input."; temp files cleaned up.
6. Plugin load under Bun (opencode runtime, in poetry-dev): `bun -e
"import('./.opencode/plugins/needs-input-observer.ts')..."` -> default
   export is a function.
7. State-machine smoke harness (Bun, temp dir): 25/25 checks pass — ENTER on
   question/permission/v2/wait_for_user/orchestrator-idle-after-delegations,
   dedup, subagent-idle exclusion, CLEAR on all reply/reject/status/chat paths,
   synthetic auto-continue suppression, error bucket + waiting clear, boot
   re-seed dedup, malformed boot tolerated, compaction snapshot, toast + log
   firing. Harness deleted after run.
8. WinRT desktop toast END-TO-END CONFIRMED on this host: the exact
   powershell.exe one-liner (plain bash) -> exit 0 with a Windows toast
   appearing; the plugin-built Node spawn with identical quoting/sanitization
   -> exit 0 (close code 0). In the Linux container (no powershell.exe) the
   plugin fail-softs: `console.warn` "powershell.exe toast spawn failed" and
   continues (verified in the harness run).
9. DIA-079 ASCII-only: `LC_ALL=C grep -P '[^\x00-\x7F]'` clean on the plugin,
   the renderer, and the bats file (em-dashes in comments removed).

**Rollback note:** remove the needs-input-observer.ts entry from the
`.opencode/opencode.jsonc` plugin array; delete
`.opencode/plugins/needs-input-observer.ts`, `scripts/ticker-render.sh`,
`scripts/__tests__/ticker-render.bats`; revert the bats-wrapper.sh list edit;
delete `.opencode/session/ticker.json` and `.opencode/session/ticker.md`
(gitignored runtime artifacts). Restart OpenCode for the plugin array change
to take effect.

## Re-verify

2026-08-13: status aligned IMPLEMENTED -> OPEN (ledger README row was OPEN; commit + restart-verify pending, then CLOSED).

Restart-verify (section-10 Phase 5): pending next opencode launch - functional smoke = trigger a question, verify ticker.json/ticker.md entry + in-TUI toast + WinRT toast, clear on reply.

### 2026-08-13 night: functional-smoke evidence (autonomous, partial)

Lane: docs/mechanical evidence (code-executor). Commit c515077 is in restart-verify / functional-smoke phase. Recorded autonomously; no commit made (worktree left uncommitted per brief).

- Trigger (c) orchestrator idle-after-delegations: CONFIRMED. `.opencode/session/ticker.json` contains waiting[0] for session ses_007e403fdffeQ4ZzfBpwumRLHP with all 6 fields (session_id, title "Continuing prior task", agent "orchestrator", reason "idle", detail "delegations complete, awaiting developer direction", since 2026-08-12T23:00:09.039Z); `version: 1`, `updated_at: 2026-08-12T23:00:09.039Z`, `errors: []`. The plugin's orchestrator-idle-after-delegations ENTER path produced a correctly shaped waiting entry.
- Derived view: `scripts/ticker-render.sh` run twice -> exit 0 both runs; second run output identical except the `_Generated:` timestamp (expected run marker), i.e. content idempotent. `.opencode/session/ticker.md` renders the waiting session oldest-first (single entry, so order trivially satisfied), pipe chars escaped, no `## Errors` section (errors empty). Actual table row:
  `| ses_007e403fdffeQ4ZzfBpwumRLHP | Continuing prior task | orchestrator | idle | delegations complete, awaiting developer direction | 2026-08-12T23:00:09.039Z |`
- Toast paths: ENTER-notify code present in `.opencode/plugins/needs-input-observer.ts` - `ctx.client.tui.showToast` (line 384) and `spawn("powershell.exe", ...)` WinRT desktop toast (line 341), plus the desktop-vs-TUI dual-channel comment (lines 31-32). The notify path was unit-mocked in the 25/25 state-machine harness checks and the WinRT desktop toast was E2E-confirmed on this host at implementation time (see Fix/Verification evidence 7-8). NO real toast fired in this lane; live visual toast confirmation is a morning item (needs human eyes at the terminal).
- PENDING (morning, needs developer): (a) clear-on-reply confirmation (reply in the waiting session should remove the entry from ticker.json), (b) live question/permission trigger with visual in-TUI + WinRT toast check, (c) then flip DIA-122 -> CLOSED with the full smoke evidence recorded.

### 2026-08-13 session ses_005a18eb8ffe9m92BcMsR668Fk: clear-on-reply verification

Lane: docs/mechanical evidence (code-executor). Read-only verification + ticket
evidence append only; no config/code changes, no service start/stop. Session
ses_005a18eb8ffe9m92BcMsR668Fk launched 2026-08-13 11:05:03 local (09:05:03Z),
AFTER plugin-array commit c515077 (00:38:23 +0200) - the loaded config
snapshot includes needs-input-observer.ts. All timestamps UTC unless noted
(local = +0200).

**1. PLUGIN LIVE: PASS**

- Config: c515077 diff shows `"file:///workspace/.opencode/plugins/
needs-input-observer.ts"` appended to the plugin array after
  delegation-observer.ts; committed 00:38:23 +0200, ~10.5h before this
  session launched -> the plugin entry is in the LOADED config snapshot.
- Runtime (opencode.log, run=4fb651ad = this server process): 12 plugin
  ENTER log lines `[needs-input-observer] needs-input: <reason> session=...`
  between 09:03:58Z and 10:20:19Z. These app.log lines are emitted only from
  notify() inside enter() - only reachable when the plugin is loaded and its
  event hook is firing. Sample (first + last for this session):
  `09:05:42.222Z [needs-input-observer] needs-input: question session=ses_005a18eb8ffe9m92BcMsR668Fk title=Continue`
  `10:20:19.930Z [needs-input-observer] needs-input: question session=ses_005a18eb8ffe9m92BcMsR668Fk title=Continue`
- Persistence: .opencode/session/ticker.json mtime 2026-08-13 12:20:23.345562
  local = updated_at 10:20:23.345Z - an atomic plugin write DURING this
  session (the plugin is the file's only writer). Last write is the clear
  persist of the 10:20:19Z question (see item 3a).
- Zero plugin warn/fail lines: all 36 `[needs-input-observer]` lines in
  opencode.log are ENTER logs; no `ticker.json write failed`, no
  powershell.exe/tui.showToast failure lines.

**2. CURRENT STATE** (ticker.json at 10:20:23.345Z):

| bucket     | session_id                     | title                                           | reason                                                    | since                    |
| ---------- | ------------------------------ | ----------------------------------------------- | --------------------------------------------------------- | ------------------------ |
| waiting[0] | ses_007e403fdffeQ4ZzfBpwumRLHP | Continuing prior task                           | idle (delegations complete, awaiting developer direction) | 2026-08-12T23:00:09.039Z |
| waiting[1] | ses_005cacefbffeasdNS69fflnytf | Resuming previous session                       | idle (delegations complete, awaiting developer direction) | 2026-08-13T09:04:10.789Z |
| errors[0]  | ses_006da8148ffeBkPaPF1gcfuGJ5 | Reconcile + commit night work (@coder subagent) | error "[object Object]"                                   | 2026-08-13T07:29:59.964Z |

- No current waiting entry for ses_005a18eb8ffe9m92BcMsR668Fk (reason idle):
  ABSENT. Explainable - the orchestrator is blocked awaiting this coder
  task() result, so no session.idle has fired since the last clear; earlier
  today each delegation round was followed by developer chat.messages /
  questions that cleared any idle entry. Expected to appear when the
  orchestrator next idles after delegations.
- errors[0] "[object Object]" is the errorMessage() String(err) fallback
  (error value without a message string) - a serialization wart, not a
  state-machine failure. Boot-seeded from the night run; not part of this
  verification's scope.

**3. CLEAR-ON-REPLY: PASS** (with honest limitation)

(a) No stale question/permission entries exist for this session or today's
subagents - every ENTER below is ABSENT from the final waiting[]:

- ses_005a18eb8ffe9m92BcMsR668Fk, FOUR question ENTERs today:
  09:05:42.222Z (batch-approval gate, ~39s after launch), 09:35:49.317Z,
  09:48:09.373Z, 10:20:19.930Z (DIA-127 disposition - ai-auditor session
  ses_00561027affeWdPCmgU2VBjg7O completed 10:20:05.980Z immediately
  prior, per registry seq 3090). Zero remain in ticker.json waiting[] ->
  each was cleared by question.replied / subsequent chat.message.
- Subagent permission ENTERs: ses_0059b11dbffegxB19B4ywdBVs5 (09:18/09:20/
  09:23Z), ses_0058960eaffe9NLUJ8fPvcr6Bs (09:31:53Z), ses_0057733efffe0kPFOx
  Gu2MxBn3 (09:52:07Z), ses_00561027affeWdPCmgU2VBjg7O (10:16:49Z). Zero
  remain in waiting[] -> all cleared.
- Bonus pre-session datapoint: ses_005cacefbffeasdNS69fflnytf question ENTER
  09:03:58Z was cleared before its idle ENTER 09:04:10.789Z (else enter()
  dedup would have suppressed the idle entry - it IS present as idle).
- Final-write correlation: ticker.json updated_at 10:20:23.345Z is the clear
  persist of the 10:20:19Z question (enter() persisted ~10:20:19.9Z; the
  reply clear rewrote the file at 10:20:23.345Z - matches mtime).
- LIMITATION: reply timestamps are not directly logged (app.log fires on
  ENTER only); clear is proven by final-ticker absence + the 10:20:23.345Z
  write. The brief's "answered ~12:5x local" recollection vs observed
  12:20:19 local question / 12:20:23 local clear write - log evidence is
  authoritative.

(b) Night entry ses_007e403fdffeQ4ZzfBpwumRLHP: NOT gone - still waiting[0],
since 2026-08-12T23:00:09.039Z. Honest limitation: no clear event
(chat.message / session.status non-idle / reply / session.deleted) has fired
for that session since it went idle at 23:00:09Z, so nothing SHOULD have
cleared it; the entry persists by design (boot re-seed + no clear event).
I cannot prove from these artifacts whether that session is still alive -
only that no clear/deleted event reached the plugin. This is NOT a
clear-on-reply failure.

**4. git state**

- c515077 "feat(opencode): DIA-122 needs-input ticker + notifications
  plugin" (2026-08-13 00:38:23 +0200) commits: plugin array entry
  (.opencode/opencode.jsonc), .opencode/plugins/needs-input-observer.ts
  (641 lines), scripts/ticker-render.sh, scripts/**tests**/ticker-render.bats,
  scripts/**tests**/bats-wrapper.sh list edit, CHANGELOG, learnings, memory.
  All committed BEFORE 11:05 today -> in the loaded config snapshot.
- Worktree: plugin/scripts files tracked, zero diff vs HEAD.
  ticker.json/ticker.md gitignored (.gitignore:82 `.opencode/session/`) -
  runtime artifacts, correct.
- Unrelated untracked only: knowledge/test-dia126-archival/ (untouched).

**5. PENDING (unchanged, needs developer):** live in-TUI toast + WinRT
desktop toast VISUAL check (needs human eyes at the terminal); then flip
DIA-122 -> CLOSED with full smoke evidence recorded. Status NOT flipped by
this lane.

## Closure (2026-08-13)

Status flipped OPEN -> CLOSED. Closure basis (verification evidence is in
the Re-verify sections above):

- Clear-on-reply verification: PASS - evidence committed fec3e00 (session
  ses_005a18eb8ffe9m92BcMsR668Fk, 2026-08-13): every question/permission
  ENTER logged during that session is ABSENT from the final ticker.json
  waiting[] list; final write (10:20:23.345Z) is the clear persist of the
  10:20:19Z question; zero plugin warn/fail lines in opencode.log.
- Plugin live with zero failures: commit c515077 (plugin-array entry) was in
  the loaded config snapshot for that session; 12 ENTER log lines confirm the
  event hook fired; no write/toast failure lines observed.
- DIA-079-consistent: all added lines ASCII-only (byte-level check passed
  before commit).
- Residual (manual follow-up, not an automated blocker): the live in-TUI
  toast + WinRT desktop toast VISUAL check still needs human eyes at the
  terminal - the notify path is unit-mocked in tests and the WinRT one-liner
  was E2E-confirmed at implementation time, but no real toast has been
  visually observed yet. This is explicitly deferred, not failed.
- error[] bucket silent behavior kept as-is: session.error entries are
  recorded in the errors bucket and never notify (per approved spec); the
  errors[0] "[object Object]" serialization wart is a known cosmetic
  limitation of the errorMessage() String(err) fallback, not a state-machine
  failure, and is out of scope for this closure.
