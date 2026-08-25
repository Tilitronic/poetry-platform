# DIA-260822-oldn - Plugin reload boot/sweep dedup - 30s persisted dedup and disposal-safe single ticker

---

id: DIA-260822-oldn
title: "Plugin reload boot/sweep dedup - 30s persisted dedup and disposal-safe single ticker"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [DIA-260822-wr2e] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-22
source: fix-lane
date: 2026-08-22
created: 2026-08-22
updated: 2026-08-23

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

- "DIA-260822-wr2e (audit: five proposed delegation-observer plugin fixes)"
- ".opencode/plugins/delegation-observer.ts#L955 (appendRow session_boot at plugin load)"
- ".opencode/plugins/delegation-observer.ts#L966 (atomicWriteBootMarker boot.json)"
- ".opencode/plugins/delegation-observer.ts#L2409 (stallSweepInterval = setInterval 60s)"
- ".opencode/plugins/delegation-observer.ts#L4632 (dispose clearInterval)"

---

## Description

The plugin body runs once per process start and unconditionally emits a
`session_boot` registry row (`appendRow` at L955) and writes a `boot.json`
marker (L966), then starts a 60s stall-sweep interval (`stallSweepInterval`,
L2409). On a real in-process reload (plugin re-evaluated without a full
process restart, or `dispose` not invoked before re-eval), the body re-runs:
a second `session_boot` row and a second `boot.json` marker are appended, and
a second `stallSweepInterval` is created. The prior interval is only cleared
in the `dispose` hook (L4632); if reload does not call `dispose` first, the
two intervals run concurrently, doubling every sweep and the
`stall_detected` emission risk, and the registry accumulates duplicate boot
evidence that breaks the "one boot_id per process start" invariant the
DIA-123 boot determinism relies on.

## Scope

- Add a 30s dedup guard for boot evidence: before emitting `session_boot` +
  `boot.json`, read the persisted boot marker (`boot.json`) / most-recent
  registry `session_boot` row; if a boot occurred within the last 30s
  (`process_started_at` or `timestamp` within 30s of now), skip the new
  emission and reuse the existing `boot_id`. Persisted state is the source of
  truth so the guard survives in-process reloads.
- Make the stall-sweep ticker disposal-safe and single-instance: track the
  interval handle in a module-level singleton (or a guarded "running" flag)
  so a reload clears/reuses the prior interval rather than stacking a second
  one. Ensure `dispose` (L4632) is the single teardown path and re-entry
  cannot create a second concurrent interval.

## Non-Goals

- Does NOT change the 60s sweep cadence or stall thresholds.
- Does NOT dedupe `session_boot` rows across full process restarts (those are
  legitimate distinct boots) — only in-process reloads within 30s.
- Does NOT alter the registry seq recomputation logic (DIA-098 ai-auditor
  finding 1).

## Verification

Acceptance criteria (checkboxes):

- [ ] A forced in-process reload (simulated by re-invoking the plugin body
      without `dispose`) emits exactly ONE `session_boot` row within any 30s
      window (verified via registry row count keyed by `boot_id`).
- [ ] A forced in-process reload results in exactly ONE active
      `stallSweepInterval` (no concurrent intervals); a unit test asserts the
      interval handle is reused/cleared, not stacked.
- [ ] `boot.json` marker is not overwritten with a new `boot_id` within 30s of
      an existing marker; the prior `boot_id` is preserved.
- [ ] Full process restart (fresh `boot.json` older than 30s) still emits a
      new `session_boot` row + new `boot_id` (no regression of legitimate boot
      detection).
- [ ] `dispose()` still clears the single interval (no orphaned timer).

Verification commands:

- New unit test (e.g.
  `.opencode/plugins/__tests__/delegation-observer.reload-dedup.test.mjs`):
  simulate reload, assert single boot row + single interval. Run:
  `docker compose exec -T dev bash -lc 'cd /workspace/.opencode/plugins/__tests__ && bun test'`
- `make test-harness` (runs the bun plugin test suite).
- Static check: grep confirms only one `setInterval` for the stall sweep and a
  dedup check precedes the `appendRow` `session_boot` call.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Decision-variants (UPDATE: DIA-260822-oldn)

The developer revised the original 30s boot.json/mtime dedup scope after
empirical evidence showed the time-window approach conflates two distinct
events: an in-process plugin reload (same PID) and a full process restart.

### Variant A: process-scoped globalThis boot identity (CHOSEN)

Introduce a process-scoped `globalThis` boot identity: the plugin body sets a
module-level `globalThis.__boot_id` on first run and reuses it on any
in-process re-evaluation within the same process (stable PID). `boot.json`
remains the persisted audit marker, but the in-memory `globalThis` token is
what distinguishes a reload from a restart. A full process restart (new PID)
does not carry the prior `globalThis`, so it emits a fresh `boot_id` and a new
`session_boot` row - no time-window suppression.

Evidence:

- `openspec/changes/plugin-reload-boot-sweep-dedup/design.md` (Tier-1 design doc for this change)
- m035: in-process plugin reload observed under a stable PID; the body re-ran
  without a process restart, proving reload and restart are separable events.
- Host smoke: a real 26-second `stop`/`start` changed `boot_id` and incremented
  `session_boot` count, proving the 30s `boot.json` mtime window would have
  deduped a genuine restart into the prior boot.

### Variant B: keep the 30s boot.json/mtime dedup window (rejected)

Retain the original scope: suppress any boot emission within 30s of the last
persisted `boot.json`/registry `session_boot` row.

Evidence:

- `openspec/changes/plugin-reload-boot-sweep-dedup/design.md` (Tier-1; original 30s scope)
- Host smoke (above): a real 26s restart falls inside the 30s window and would
  be suppressed - it erases legitimate restart evidence. Rejected because it
  suppresses real restart detection (breaks the DIA-123 boot determinism
  invariant).

### Variant C: abort / status quo - leave reload storm unmitigated (rejected)

Do not change the plugin; accept duplicate `session_boot` rows and stacked
`stallSweepInterval` timers on every in-process reload.

Evidence:

- `openspec/changes/plugin-reload-boot-sweep-dedup/design.md` (Tier-1; unchanged plugin body)
- [INFERENCE] the unguarded re-emission sites (`.opencode/plugins/delegation-observer.ts#L955`
  appendRow session_boot, `L2409` stallSweepInterval) mean the reload storm
  remains and continues to break the one-boot-per-process invariant. Rejected
  because the reload storm persists.

### Chosen:

Variant A - process-scoped globalThis boot identity. `boot.json` stays the
persisted audit marker; `globalThis` distinguishes an in-process reload from a
full restart; a full process restart emits a new boot (new PID, no prior
`globalThis`), so legitimate restarts are never deduped.
