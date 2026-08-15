---
id: DIA-189
title: 'terminal session identity: unique names + notification attribution + Cyrillic visibility'
area: opencode-config
severity: Major
status: OPEN
blocked_by: []
discovered: 2026-08-15
source: session-observation (developer report, 2026-08-15, screenshot clipboard-84a17fb4.png)
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: 'ses_ffb7ba1daffemGh05K4YUPlQe2'
lane_id: ''
agent: 'orchestrator'
model: 'deepseek-v4-flash'
parent_session_id: ''
attempts: 0
lease_expires_at: ''
files_touched:
  [
    'docs/dev-infra-audit/tickets/DIA-189-terminal-session-identity-names-notifications-cyrillic.md',
    'docs/dev-infra-audit/tickets/README.md',
  ]
artifacts: []
evidence: []
---

## Description

**Developer report (2026-08-15):** three usability problems in the multi-session
workflow (2+ active orchestrator sessions, DIA-085 worktree model):

1. **Identical terminal/session names.** The TUI session/terminal list shows
   every entry as the default `opencode poetry-platform` (binary + cwd). No
   unique names, no numbers, no status indicators. With multiple parallel
   sessions it is impossible to tell which terminal is which. Screenshot
   evidence (.opencode/images/ses_ffb7ba1daffemGh05K4YUPlQe2/
   clipboard-84a17fb4.png): 4 rows, all with the identical label, only the
   selected row differs by highlight.
2. **Notifications are not attributed to a session.** The needs-input-observer
   (DIA-122) notification body is `title` + `reason: detail`; since all session
   titles are identical, the notification cannot tell the developer WHICH
   session needs input. The ticker.json view carries session_id, but the
   user-facing notification channels (in-TUI toast + WinRT desktop toast) do
   not identify the originating session.
3. **Cyrillic text invisible in notifications.** Ukrainian notification text
   renders as blank/invisible.

**Preliminary root-cause analysis (orchestrator, 2026-08-15):**

- P3 root cause (code-verified): `.opencode/plugins/needs-input-observer.ts`
  `fireDesktopToast()` sanitizer (lines ~699-704):
  `s.replace(/[\r\n\t]+/g, " ").replace(/[^\x20-\x7E]/g, " ")...` strips EVERY
  non-ASCII character (Cyrillic U+0400-U+04FF) and replaces it with a space,
  making Ukrainian text invisible in the WinRT desktop toast. The ASCII-only
  protocol (DIA-079) is correctly applied to SOURCE files and dispatch
  payloads but must NOT strip user-facing notification content. The in-TUI
  toast path (`tui.showToast`) does NOT strip non-ASCII (message passed raw)
  - verify whether TUI Cyrillic rendering is font-dependent at the terminal.
- P2 root cause (code-verified): `notify()` (lines ~736-765) builds
  `message = "${entry.reason}: ${entry.detail}"` and
  `title = entry.title || resolveTitle(...)` - no session_id, no agent, no
  unique discriminator in either channel body.
- P1 root cause (open question): the TUI session/terminal list derives its
  labels from OpenCode session titles, which default to `opencode <cwd>` for
  sessions without a custom title. Research needed: what API/config controls
  session titles, can a plugin set unique titles on session.created, and is
  there a TUI-level naming config (tui.json / session title).

**Workflow requirements:** opencode-config change -> AGENTS.md section 2.5
AI-Devtools Modernization Workflow: ai-specialist gate research -> developer
review -> design -> coder -> ai-auditor independent review -> validate
(restart + functional smoke) -> register (CHANGELOG, learnings, memory-manager).
DIA-063 ticket gate satisfied by this ticket.

## Verification

- make test-config exit 0 after implementation.
- Plugin typecheck + lint exit 0.
- WinRT desktop toast with Ukrainian text renders Cyrillic characters
  (visual check on host, needs human eyes).
- Notification body identifies the session: title + short session id suffix
  appended in both notification channels (in-TUI toast and desktop toast).
- Terminal/session list shows distinguishable labels (unique per session).
- DIA-079 ASCII-only holds for SOURCE files (dispatch payloads/prompts stay
  ASCII); only user-facing notification text carries Unicode.

## Fix

Implementation merged 2026-08-15 as ef3d97d (squash of omos/dia-189, 3 files +522/-9) onto branch omo-slim-changes (main lineage; the main branch is stale / not checked out - documented deviation). Variant A (developer-approved, ai-specialist gate research): A1 unique session titles via session.update rename on session.created, A2 short-id suffix notification attribution in both channels, A3 Cyrillic-preserving desktop-toast sanitizer (C0/C1-only strip). Files: .opencode/plugins/needs-input-observer.ts (+79/-9), .opencode/plugins/**tests**/needs-input-observer.dia189.test.mjs (NEW +341, 14/14 green).

2026-08-15 follow-up (verification failed - developer confirmed the visible terminal strip is the PTY strip, driven by Pty.title, not Session.title): A1b pty rename on pty.created/pty.updated via ctx.client.pty.update (same default/empty-label + [short-id] guards, fail-soft), A2b boot retro pass over ctx.client.pty.list() + ctx.client.session.list() renaming pre-existing default-titled panes/sessions (closes the after-restart gap); F2 bootRetroPass res.error inspection (non-throw error envelopes now warn, no silent empty fallback), F3 in-memory rename dedupe (5s TTL, no timers). Merged as squash of omos/dia-189b.

## Re-verify

2026-08-15: implementation merged ef3d97d; all automated gates green (test-config 56/56, harness 14/14, tsc 0, eslint 0, ai-auditor APPROVE-WITH-NITS, F1-F4 accepted). PENDING developer restart-verify: restart OpenCode, confirm distinct terminal labels (opencode poetry-platform [xxxxxx]) in the session list, trigger a question/permission/idle to see a notification with the short-id suffix, and confirm a Ukrainian-language notification renders Cyrillic in both the in-TUI toast and the WinRT desktop toast. Then flip DIA-189 CLOSED.

2026-08-15 dia189b follow-up merged (squash of omos/dia-189b, chain 1f202bb/eba07c8/e283214/b43b8c8); all automated gates green (harness 26/26, test-config 56/56, tsc 0, eslint 0, ai-auditor APPROVE-WITH-NITS on both reviews, F1-F6 accepted). PENDING developer restart-verify: restart OpenCode, confirm the PTY strip now shows distinct labels 'opencode poetry-platform [xxxxxx]' for BOTH new and pre-existing terminal panes (boot retro pass), and that a Ukrainian notification renders Cyrillic in both channels. Then flip DIA-189 CLOSED.

## Disposition (2026-08-15)

- ai-auditor verdict: APPROVE-WITH-NITS (implemented Variant A reviewed on
  commit 844bc0b in the omos/dia-189 worktree; harness green 14/14 after the
  RED-lane SHORT_ID fix and F4 coverage commit 20a4432).
- Findings F1-F4 accepted by developer disposition ("Fix all nits").
  F1 ticket-text alignment, F2 DIA-079 debt, F3 duplicate comment block,
  F4 harness coverage gap - all addressed across the GREEN/RED lanes.
- F2 noted as OUT-OF-SCOPE follow-up: 24 pre-existing non-ASCII em-dashes in
  plugin comment lines (needs-input-observer.ts), byte-identical in the
  DIA-189 baseline, NOT introduced by this ticket. Rewriting them belongs to
  a separate DIA-079 cleanup task, not this fix.

## UPDATE (2026-08-15, NIT4 ticket-text applied)

Residual terminal-label gap root cause (post-restart follow-up; P1/A1 chain):

- Root cause: guard predicate mismatch vs runtime 1.18.18 defaults. The
  rename guard tested the current label against an expected suffix pattern,
  but 1.18.18 default labels are "New session - <ISO timestamp>" (sessions)
  and "Terminal N" (PTY panes) - the guard predicate never matched, so
  0/1742 sessions were ever suffixed.
- Fix de6239ec (squash-merged onto omo-slim-changes 2026-08-15 as 9d96310):
  rename-if-not-suffixed - the rename applies whenever the current label is
  NOT already suffixed (alreadySuffixed-only gate). Default/empty labels get
  the [short-id] suffix; already-suffixed labels are left untouched
  (idempotent, no double-suffix, no rename churn on every event).
- Verification evidence: harness 28/28 (needs-input-observer.dia189.test.mjs
  suite), test-config 56/56, test-shell 390, tsc 0 errors, eslint 0,
  prettier 0. Pre-commit lint-staged (eslint --fix + prettier) autofix passed
  on the squash commit.
- ai-auditor: APPROVE-WITH-NITS accepted 2026-08-15. NIT4 (ticket-text
  alignment) applied by this UPDATE block; NIT5 (pre-existing non-ASCII
  em-dash debt in plugin comment lines, F2 lineage) deferred to a separate
  DIA-079 ASCII cleanup task.
- Status: PENDING restart-verify - NOT flipped CLOSED. Restart OpenCode,
  confirm distinct PTY labels 'opencode poetry-platform [xxxxxx]' for both
  new and pre-existing terminal panes, and confirm a Ukrainian-language
  notification renders Cyrillic in both channels (in-TUI toast + WinRT
  desktop toast). Flip CLOSED only after developer confirms both channels.
