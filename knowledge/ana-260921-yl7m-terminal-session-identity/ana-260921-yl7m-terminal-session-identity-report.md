# DIA-189: Terminal Session Identity, Notification Attribution, Cyrillic Visibility

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: .opencode/plugins/needs-input-observer.ts
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## 1. Scope and evidence

Campaign ticket DIA-189. Three usability defects in the multi-session
(DIA-085 worktree) workflow, all code-verified in
`.opencode/plugins/needs-input-observer.ts` (1552 lines) plus the
DIA-189 harness suite
`.opencode/plugins/__tests__/needs-input-observer.dia189.test.mjs`
(32 test blocks). Ticket status at analysis time: OPEN, implementation
merged (ef3d97d + dia189b squash + de6239ec + word-pair naming), PENDING
human restart-verify. Domain fully comprehended; no cannot-comprehend
condition.

## 2. Methods

5-Whys (one chain per problem, section 3), MECE partition of the fix
surface (Session-title vs Pty-title vs notification-title vs toast
sanitizer, section 4), systems thinking for feedback loops (boot retro
pass, rename dedupe, reload guards, section 5).

## 3. Five-Whys chains

### P1 -- identical terminal names

1. Why indistinguishable? Every row shows the default label.
2. Why default? OpenCode titles new sessions generically; nothing
   assigned a unique name.
3. Why did the first fix (A1, session.update only) not show? The visible
   strip is the PTY strip (Pty.title), not Session.title -- wrong surface.
4. Why did the corrected fix still rename 0/1742 sessions? Guard tested
   for an `opencode ` prefix, but runtime 1.18.18 defaults are
   `New session - <ISO>` (sessions) and `Terminal N` (ptys) -- predicate
   never matched.
5. Root fix: rename-if-not-suffixed (only gate = already suffixed),
   applied to BOTH surfaces plus a boot retro pass for pre-existing
   panes. Predicate is now default-format agnostic.

### P2 -- unattributed notifications

1. Why unattributable? Body was `reason: detail`, title was the
   identical default -- no session discriminator in either channel.
2. Why not add session_id? Raw ids (ses_..., pty_...) are unreadable in
   a toast glance.
3. Fix: pin the SAME `[word-pair]` suffix that A1 writes into the
   terminal label onto both toast titles (notify(), lines 932-962).
   One shared suffix, two surfaces, visual join key.
4. Aug-18 feedback (`[de6239]` hex still hard to read) resolved by
   replacing hex short-id with deterministic adjective-noun word-pair.

### P3 -- invisible Cyrillic

1. Why invisible? `fireDesktopToast()` sanitizer stripped every
   non-ASCII char (`[^x20-x7E]` -> space), deleting the entire Cyrillic
   block U+0400-U+04FF.
2. Why was the strip there? DIA-079 ASCII-only protocol over-applied:
   correct for SOURCE files and dispatch payloads, wrong for
   user-facing notification content.
3. Fix (A3, lines 859-871): strip only C0/C1 controls
   (U+0000-U+001F, U+007F-U+009F); printable Unicode preserved.
   In-TUI channel never stripped (passed raw) -- its Cyrillic rendering
   is terminal-font dependent, noted as a human-verify item.

## 4. MECE fix-surface partition (all four implemented)

| # | Surface | Mechanism | State |
|---|---------|-----------|-------|
| A1 | Session.title | rename-if-not-suffixed on session.created + boot retro over session.list() | Implemented (lines 1247-1302, 1150-1172) |
| A1b | Pty.title (the visible strip) | same rule on pty.created/pty.updated + boot retro over pty.list() | Implemented (lines 1342-1353, 1123-1149) |
| A2 | Notification titles | `[word-pair]` prefix on BOTH tui.showToast and WinRT toast, double-append guard | Implemented (lines 932-962) |
| A3 | Toast sanitizer | C0/C1-only strip, printable Unicode preserved | Implemented (lines 865-871) |

No overlap, no gap: every user-visible label path carries the suffix,
and both notification channels share it.

## 5. Word-pair design analysis (systems view)

- Scheme: FNV-1a 32-bit hash of session_id, lower 16 bits select from
  100 adjectives, upper 16 bits from 100 nouns. 10,000 combinations,
  zero dependencies (humanhash/moniker rejected -- correct YAGNI call).
- Determinism is a feature: same session always maps to the same pair,
  so terminal label and toast attribution agree across restarts without
  persisted state.
- Collision math: per-pair p = 1e-4; for N = 10 concurrent sessions,
  P(any collision) approx 45/10000 = 0.45%. Acceptable at current
  scale (2-10 sessions). No runtime collision detection exists --
  recorded as residual risk R1.
- Stabilizing loops (all sound): 5s-TTL in-memory rename dedupe (F3,
  no timers, lazily pruned); globalThis singleton guards against
  in-process reload double-rename/re-toast (DIA-260821-5r03); boot
  retro pass runs once per process; F2 res.error envelope inspection
  (no silent empty fallback).

## 6. Residual risks

| ID | Risk | Severity | Recommendation |
|----|------|----------|----------------|
| R1 | Word-pair collision (two sessions, same pair), no detection | Low (0.45% at N=10) | Accept; if session count grows past ~30, add collision check with numeric fallback |
| R2 | alreadySuffixed regex `^[a-z]+-[a-z]+` also matches a user title that happens to start with a lowercase bracketed pair (rename skipped) | Trivial/cosmetic | Accept; tighten to exact current-pair match only if ever reported |
| R3 | In-TUI toast Cyrillic depends on terminal font coverage | Low | Covered by human restart-verify step |
| R4 | DIA-189 test-file header comments still describe the old hex short-id scheme (stale doc, e.g. `[3456]` references) | Trivial/doc | One cleanup commit refreshing comments to word-pair |

## 7. Verdict

All three reported problems are root-caused and code-fixed, and the
Aug-18 readable-ID follow-up is already implemented (word-pair naming
replaced hex short-ids in both renames and attribution). Test coverage
is strong (32 harness blocks across P1/P2/P3, pty, boot retro,
word-pair). Remaining work is procedural, not technical:

1. Developer restart-verify: distinct PTY labels for new + pre-existing
   panes, short-id/word-pair suffix in a live notification, Cyrillic
   rendering in both channels.
2. Flip DIA-189 CLOSED on confirm.
3. Optional: R4 comment refresh; R1 collision guard only if scale demands.

Confidence: High (findings are code-verified against the merged plugin,
not inferred from ticket prose).
