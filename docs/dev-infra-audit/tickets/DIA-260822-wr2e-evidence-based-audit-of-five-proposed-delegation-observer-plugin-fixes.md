# DIA-260822-wr2e - Evidence-based audit of five proposed delegation-observer plugin fixes

---

id: DIA-260822-wr2e
title: "Evidence-based audit of five proposed delegation-observer plugin fixes"
area: opencode
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-22
source: inventory
date: 2026-08-22
created: 2026-08-22
updated: 2026-09-01

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence:

- "Re-verified 2026-09-01 against HEAD at audit close: plugin source changed since 2026-08-22: yes (18 commits touched delegation-observer.ts / needs-input-observer.ts; head 54e2dc1, oldest in window 03a25e8); per-finding verdicts F1 VERIFIED/APPROVE (fixed via oldn Variant A), F2 VERIFIED/APPROVE, F4/F5 VERIFIED/APPROVE, F6 DISMISSED (rejected, worktree isolation DIA-175); current line evidence cited in Fix table"

---

## Description

Evidence-based audit of five proposed delegation-observer plugin fixes
(F1, F2, F4, F5, F6). The plugin (`delegation-observer.ts`) and the
`needs-input-observer.ts` ticker maintain persistent cross-session state
(registry rows, `boot.json`, `ticker.json`). Five defect proposals were
submitted for review; this audit verifies each against source-line evidence
and either promotes it to a fix-lane child ticket or rejects it. F3 is not
among the five proposed fixes reviewed here and is out of scope of this audit
set.

## Verification

The audit is verified by the source-line evidence cited per finding and by the
acceptance evidence carried in each linked child ticket. Ledger formatting is
validated with `scripts/tickets rollup --check` (exit 0, counts match). The
three verified findings (F1, F2, F4/F5) each have a child ticket with
concrete acceptance cases and a bun unit-test command; the rejected finding
(F6) carries a documented rationale. No plugin code or config was changed by
this audit.

- [x] source-line evidence cited per finding (current line numbers in Fix table)
- [x] child tickets carry acceptance cases (DIA-260822-oldn, DIA-260822-fksf, DIA-260822-unsn)
- [x] F6 rejection rationale documented (worktree isolation DIA-175; same-checkout multi-process unsupported)
- [x] rollup --check exit 0 after STEP 5 (verified 2026-09-01)

## Findings

### F1 - VERIFIED: real in-process reload incident (duplicate boot evidence + sweep intervals)

- Evidence: `delegation-observer.ts` L955 (`appendRow` `session_boot` at
  plugin load), L966 (`atomicWriteBootMarker` `boot.json`), L2409
  (`stallSweepInterval = setInterval` 60s), L4632 (`dispose` `clearInterval`).
- On an in-process reload (plugin re-evaluated without a full process
  restart, or `dispose` not invoked first) the body re-runs: a second
  `session_boot` row and a second `boot.json` marker are appended, and a
  second `stallSweepInterval` is created. The prior interval is only cleared
  in `dispose`; if reload skips `dispose`, the two intervals run concurrently,
  doubling every sweep and the `stall_detected` emission risk.
- Impact: duplicate boot evidence breaks the "one boot_id per process start"
  invariant that DIA-123 boot determinism relies on.
- Actionable: promoted to DIA-260822-oldn (30s persisted dedup +
  disposal-safe single ticker).

### F2 - VERIFIED: 390 stale nonterminal keys caused startup cascade (preserve fresh-stall detection)

- Evidence: `delegation-observer.ts` L2313 (`sweepStalledSessions`),
  L2347-L2375 (per-key nonterminal loop), L2331-L2344 (per-key dedup only
  suppresses keys that ALREADY have a `stall_detected` row within window).
- On plugin load after a crash/restart the registry held 390 stale nonterminal
  keys (latest `dispatch_state` timestamp already old). The first sweep
  emitted 390 `stall_detected` rows at once - a cascade that floods the
  registry and `messages.jsonl` and masks real, current stalls.
- Constraint: fresh-stall detection (keys whose nonterminal row timestamp is
  at/after plugin load) MUST remain detectable; only already-stale boot-time
  emissions are suppressed.
- Actionable: promoted to DIA-260822-fksf (first-sweep startup protection).

### F4 / F5 - VERIFIED: ticker entries never expire (thresholds selected)

- Evidence: `needs-input-observer.ts` L603 (`persist`), L631 (`seedFromDisk`),
  L121 (`WaitingEntry`: reason `question`|`permission`|`idle`, `since`),
  L130 (`TickerErrorEntry`: `since`, `error`).
- Neither `seedFromDisk` nor `persist` expires entries: an invalid/unparseable
  `since`, or a waiting/error entry left over from a long-dead session, is
  carried forward indefinitely.
- Thresholds selected by the audit (no evidence supported a different value):
  - `question` / `permission` waiting entries older than 24h -> purge
  - `idle` waiting entries older than 4h -> purge
  - `errors` entries older than 48h -> purge
  - any entry whose `since` is not a valid parseable ISO timestamp -> purge
- Actionable: promoted to DIA-260822-unsn (shared seed/persist purge helper).

### F6 - REJECTED: same-checkout multi-process coordination

- Rationale: the proposed fix assumed multiple plugin processes could share a
  single checkout and required cross-process coordination. Worktree isolation
  (DIA-175; `worktrees` skill) already provides per-lane process separation,
  and same-checkout multi-process is not a supported runtime configuration for
  this plugin. No code change is warranted; the proposal is out of scope.
- Disposition: rejected - no child ticket, no plugin change.

## Child tickets

The three verified findings are tracked as fix-lane child tickets, each
`blocked_by: [DIA-260822-wr2e]`.

### DIA-260822-oldn 'Plugin reload boot/sweep dedup - 30s persisted dedup and disposal-safe single ticker'

- Scope: add a 30s persisted dedup guard for boot evidence (read `boot.json` /
  latest `session_boot` row; if a boot occurred within 30s, skip emission and
  reuse the existing `boot_id`); make the stall-sweep ticker disposal-safe and
  single-instance (module-level singleton / guarded "running" flag; `dispose`
  is the single teardown path, re-entry cannot stack a second interval).
- Non-goals: no change to 60s sweep cadence or stall thresholds; no dedup
  across full process restarts (legitimate distinct boots); no registry seq
  recompute change.
- Acceptance evidence: forced in-process reload emits exactly ONE
  `session_boot` row within any 30s window (registry count keyed by
  `boot_id`); exactly ONE active `stallSweepInterval` (no concurrent);
  `boot.json` not overwritten with a new `boot_id` within 30s; full process
  restart still emits a new `session_boot` row + new `boot_id`; `dispose()`
  clears the single interval.
- Verification: new unit test
  `.opencode/plugins/__tests__/delegation-observer.reload-dedup.test.mjs`
  (`docker compose exec -T dev bash -lc 'cd /workspace/.opencode/plugins/__tests__ && bun test'`),
  `make test-harness`, plus static grep confirming a single `setInterval` for
  the stall sweep and a dedup check preceding the `appendRow` `session_boot`.

### DIA-260822-fksf 'Stale stall-sweep startup protection - suppress already-stale boot-time emissions'

- Scope: on the FIRST sweep after plugin load, suppress `stall_detected` for
  keys whose latest nonterminal `dispatch_state` row is already older than a
  "stale-at-boot" threshold (stale from a prior process lifetime); stalls that
  develop during the CURRENT process lifetime (timestamp at/after load) MUST
  still fire. Mechanism left to the implementer (boot-time snapshot of
  already-stale keys, load-time cutoff timestamp, or first-sweep
  skip-with-watchlist).
- Non-goals: no change to 60s cadence, role thresholds
  (`stallSubagentMinutes`/`stallOrchestratorMinutes`), or the dead-escalation
  path L2360; no suppression of current-lifetime stalls; no change to per-key
  dedup windows L2331-L2344.
- Acceptance evidence: with N=390 stale nonterminal keys (latest
  `dispatch_state` predates load by > stale-at-boot threshold), the first
  sweep emits ZERO `stall_detected` for them; a fresh key (timestamp after
  load) emits once its role threshold is crossed; a key that becomes
  nonterminal during the current lifetime and crosses the threshold is
  detected on a subsequent sweep; the dead-escalation path L2360 is unaffected
  for genuinely still-nonterminal keys crossing the 60-min deadline during the
  current lifetime; regression test seeds 390 stale + 1 fresh -> exactly 1
  `stall_detected`.
- Verification: new unit test
  `.opencode/plugins/__tests__/delegation-observer.stale-boot-sweep.test.mjs`
  - `make test-harness`.

### DIA-260822-unsn 'Ticker expiry - purge invalid and stale waiting/error entries during seed/persist'

- Scope: a single shared purge helper invoked from BOTH `seedFromDisk` (L631)
  and `persist` (L603); drop any entry whose `since` is not a valid parseable
  ISO timestamp; drop `question`/`permission` waiting entries older than 24h;
  drop `idle` waiting entries older than 4h; drop `errors` entries older than
  48h.
- Non-goals: no ticker schema/version change; no `permissions` watchdog change
  (its own `armPermissionTimer` timeout L426); no ENTER/CLEAR/ERROR transition
  logic change; no live background TTL eviction beyond seed/persist.
- Acceptance evidence: invalid/unparseable `since` dropped on seed and on
  persist; `question`/`permission` waiting >24h purged / younger retained;
  `idle` waiting >4h purged / younger retained; `errors` >48h purged / younger
  retained; a freshly seeded ticker with mixed valid/invalid/stale entries
  yields only valid, in-window entries; valid current entries survive a
  persist round-trip (existing `needs-input-observer.dia189.test.mjs` still
  passes).
- Verification: new unit test
  `.opencode/plugins/__tests__/needs-input-observer.ticker-expiry.test.mjs`
  (mirroring `needs-input-observer.dia189.test.mjs`) + existing dia189 test +
  `make test-harness`.

## Re-verified 2026-09-01 note

> Re-verified 2026-09-01 against current source at HEAD. F1 defect (duplicate
> boot evidence + stacked sweep intervals on reload) was VERIFIED as described
> in the audit; the fix approach originally proposed as "30s persisted dedup
> window" was superseded by DIA-260822-oldn Variant A (process-scoped
> globalThis boot identity) because a real 26s restart would be suppressed by a
> 30s window. Current source implements Variant A (bootFlagStore / stallSweepStore
> on globalThis). F1/F2/F4/F5 findings remain APPROVED and promoted; F6 remains
> DISMISSED.

## Fix

Audit re-verified 2026-09-01 against current source at HEAD. Plugin source
changed since 2026-08-22: yes - 18 commits touched
`.opencode/plugins/delegation-observer.ts` / `.opencode/plugins/needs-input-observer.ts`
(oldest in window 03a25e8, head 54e2dc1). Per-finding verdicts below cite
current line numbers with ~10 lines surrounding context inspected.

| Finding | Verdict   | Disposition                                            | Current line evidence (2026-09-01)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------- | --------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F1      | VERIFIED  | APPROVE -> DIA-260822-oldn (superseded fix: Variant A) | `delegation-observer.ts` L459-L463 `BOOT_EMITTED_KEY = Symbol.for("delegation-observer.bootEmitted")` + `bootFlagStore` on `globalThis`; L1046 `if (!bootFlagStore[BOOT_EMITTED_KEY]) { appendRow(session_boot) + atomicWriteBootMarker } bootFlagStore[BOOT_EMITTED_KEY]=true`; L451-L457 `STALL_SWEEP_KEY = Symbol.for("delegation-observer.stallSweepInterval")` + `stallSweepStore`; L2651-L2653 `priorSweep=stallSweepStore[STALL_SWEEP_KEY]; if (priorSweep) clearInterval; stallSweepStore[STALL_SWEEP_KEY]=setInterval`; L5002-L5004 `dispose` clears `stallSweepStore[STALL_SWEEP_KEY]`. Defect (unconditional emit + stacked intervals) was real; current source already contains the Variant A fix (process-scoped globalThis identity, not the original 30s window). Original 30s window rejected in oldn Decision-variants because a real 26s restart would be incorrectly suppressed. |
| F2      | VERIFIED  | APPROVE -> DIA-260822-fksf                             | `delegation-observer.ts` L2553 `sweepStalledSessions`, L2560-L2568 latest nonterminal per key, L2571-L2584 dedup only from existing `stall_detected` rows (per-key window), L2587-L2615 age check + emit. No boot-time stale suppression exists: first sweep after load still emits `stall_detected` for keys whose nonterminal row predates load. Cascade (390 stale keys) confirmed.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| F4/F5   | VERIFIED  | APPROVE -> DIA-260822-unsn                             | `needs-input-observer.ts` L125 `WaitingEntry (reason question\|permission\|idle, since)`, L134 `TickerErrorEntry (since, error)`, L614 `persist` (sort + atomicWriteTicker, no purge), L642 `seedFromDisk` (validates session_id/reason but copies `since` verbatim, no age/invalid-since purge). Neither path purges invalid `since` or stale entries; stale entries carried indefinitely. Thresholds as audited: question/permission >24h, idle >4h, errors >48h, invalid since.                                                                                                                                                                                                                                                                                                                                                                                                                  |
| F6      | DISMISSED | REJECT (no child ticket)                               | Rejection rationale still holds: worktree isolation (DIA-175) provides per-lane process separation; same-checkout multi-process is not a supported runtime. No cross-process coordination exists in current source and none is warranted. Confirmed no such coordination added since audit.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |

No plugin code or config was changed by this audit. Only the wr2e ticket file
and the README rollup were written, plus lint-staged auto-format.

## Re-verify

Re-verified 2026-09-01: F1 VERIFIED/APPROVE (defect real, fixed via oldn Variant A);
F2 VERIFIED/APPROVE; F4/F5 VERIFIED/APPROVE; F6 DISMISSED (rejected, worktree
isolation). All source-line evidence re-checked at current HEAD.
