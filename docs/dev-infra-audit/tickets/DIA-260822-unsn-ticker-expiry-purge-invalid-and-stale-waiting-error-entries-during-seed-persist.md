# DIA-260822-unsn - Ticker expiry - purge invalid and stale waiting/error entries during seed/persist

---

id: DIA-260822-unsn
title: "Ticker expiry - purge invalid and stale waiting/error entries during seed/persist"
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
updated: 2026-08-22

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
- ".opencode/plugins/needs-input-observer.ts#L603 (persist)"
- ".opencode/plugins/needs-input-observer.ts#L631 (seedFromDisk)"
- ".opencode/plugins/needs-input-observer.ts#L121 (WaitingEntry: reason question|permission|idle, since)"
- ".opencode/plugins/needs-input-observer.ts#L130 (TickerErrorEntry: since, error)"

---

## Description

`needs-input-observer` maintains `.opencode/session/ticker.json` — a
persistent cross-session state of sessions waiting for developer input
(`waiting`: reason `question`/`permission`/`idle`) and a separate `errors`
bucket. On boot it re-reads the file via `seedFromDisk` (L631) and on every
transition it rewrites it via `persist` (L603). Neither path expires
entries: a `since` timestamp that is malformed, or a waiting/error entry left
over from a long-dead session, is carried forward indefinitely. The audit
(DIA-260822-wr2e) requires purging during seed/persist: invalid timestamps,
`question`/`permission` waiting entries older than 24h, `idle` waiting
entries older than 4h, and `errors` older than 48h.

## Scope

- Add expiry purging invoked from BOTH `seedFromDisk` (L631) and `persist`
  (L603) — ideally a single shared helper so seed and persist agree.
- Drop any waiting/error entry whose `since` is not a valid parseable ISO
  timestamp (invalid timestamp).
- Drop waiting entries with reason `question` or `permission` whose age
  (`now - since`) exceeds 24h.
- Drop waiting entries with reason `idle` whose age exceeds 4h.
- Drop `errors` entries whose age exceeds 48h.

## Non-Goals

- Does NOT change the ticker schema/version or the `permissions` watchdog
  list (that has its own `armPermissionTimer` timeout, L426).
- Does NOT change the ENTER/CLEAR/ERROR transition logic or the in-memory
  `waiting`/`errors` Maps beyond the seed/persist purge.
- Does NOT add live background TTL eviction beyond seed/persist (the audit
  scopes this to seed/persist only).

## Verification

Acceptance cases (checkboxes):

- [ ] An entry with an invalid/unparseable `since` is dropped on seed and on
      persist.
- [ ] A `question`/`permission` waiting entry older than 24h is purged; one
      younger is retained.
- [ ] An `idle` waiting entry older than 4h is purged; one younger is
      retained.
- [ ] An `errors` entry older than 48h is purged; one younger is retained.
- [ ] A freshly seeded ticker with mixed valid/invalid/stale entries yields
      only valid, in-window entries after seed/persist.
- [ ] No regression: valid current entries survive a persist round-trip.

Verification commands:

- New unit test (e.g.
  `.opencode/plugins/__tests__/needs-input-observer.ticker-expiry.test.mjs`,
  mirroring the existing `needs-input-observer.dia189.test.mjs`): seed a
  ticker doc with invalid + stale + fresh entries, assert purge outcomes. Run:
  `docker compose exec -T dev bash -lc 'cd /workspace/.opencode/plugins/__tests__ && bun test'`
- Existing `needs-input-observer.dia189.test.mjs` MUST still pass (no
  regression of current behavior).
- `make test-harness` (runs the bun plugin test suite).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
