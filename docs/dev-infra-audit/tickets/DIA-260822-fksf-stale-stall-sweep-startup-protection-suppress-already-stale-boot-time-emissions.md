# DIA-260822-fksf - Stale stall-sweep startup protection - suppress already-stale boot-time emissions

---

id: DIA-260822-fksf
title: "Stale stall-sweep startup protection - suppress already-stale boot-time emissions"
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
- ".opencode/plugins/delegation-observer.ts#L2313 (sweepStalledSessions)"
- ".opencode/plugins/delegation-observer.ts#L2347-L2375 (per-key nonterminal loop)"
- ".opencode/plugins/delegation-observer.ts#L2360 (dead escalation path)"

---

## Description

`sweepStalledSessions` (L2313) reads all registry rows and, for every
delegation key whose LATEST `dispatch_state` row is non-terminal, measures
age from that row's timestamp and emits `stall_detected` once the role
threshold is crossed (L2347-L2375). The per-key dedup (L2331-L2344) only
suppresses keys that ALREADY have a `stall_detected` row within their window;
it does nothing for keys with no prior `stall_detected` row. On plugin load
after a crash/restart, the registry can contain a large population of
nonterminal keys whose latest `dispatch_state` timestamp is already old
(observed: 390 stale nonterminal keys). The first sweep then emits 390
`stall_detected` rows at once — a cascade that floods the registry and
messages.jsonl and masks real, current stalls. The audit (DIA-260822-wr2e)
flags this as a startup-protection gap: already-stale boot-time emissions
must be suppressed while fresh current stalls (those that develop during the
current process lifetime) remain detectable.

## Scope

- Add startup protection to `sweepStalledSessions` so that, on the FIRST
  sweep after plugin load (boot), keys whose latest nonterminal
  `dispatch_state` row is already older than a defined "stale-at-boot"
  threshold are NOT emitted as `stall_detected`. These are stale from a prior
  process lifetime and should not be re-reported.
- Detection of stalls that develop during the CURRENT process lifetime (a key
  whose nonterminal row timestamp is at/after plugin load) MUST continue to
  fire normally on the appropriate sweep.
- The exact suppression threshold and mechanism are intentionally NOT settled
  here (the audit provides no evidence for a specific value) — the acceptance
  cases below pin the behavior; the implementer chooses the mechanism
  (e.g. boot-time snapshot of already-stale keys, a load-time cutoff
  timestamp, or a first-sweep skip-with-watchlist).

## Non-Goals

- Does NOT change the 60s sweep cadence, role thresholds
  (`stallSubagentMinutes`/`stallOrchestratorMinutes`), or the dead-escalation
  path (L2360).
- Does NOT suppress stalls that arise during the current process lifetime.
- Does NOT alter the per-key dedup windows (L2331-L2344).

## Verification

Acceptance cases (checkboxes):

- [ ] Given a registry with N stale nonterminal keys (e.g. 390) whose latest
      `dispatch_state` timestamp predates plugin load by more than the
      stale-at-boot threshold, the FIRST sweep after boot emits ZERO
      `stall_detected` rows for those keys (no cascade).
- [ ] Given a key whose nonterminal row timestamp is AFTER plugin load (a
      fresh current stall), the sweep emits a `stall_detected` row once its
      role threshold is crossed (detection preserved).
- [ ] A key that becomes nonterminal DURING the current process lifetime and
      then crosses the stall threshold is detected on a subsequent sweep (not
      suppressed by the boot guard).
- [ ] The dead-escalation path (L2360) is unaffected for keys that are
      genuinely still nonterminal and cross the 60-min deadline during the
      current lifetime.
- [ ] Regression test: seed 390 stale keys + 1 fresh key; assert the first
      sweep emits exactly 1 `stall_detected` (the fresh one).

Verification commands:

- New unit test (e.g.
  `.opencode/plugins/__tests__/delegation-observer.stale-boot-sweep.test.mjs`):
  seed a registry with stale + fresh nonterminal keys, invoke
  `sweepStalledSessions`, assert first-sweep emission counts. Run:
  `docker compose exec -T dev bash -lc 'cd /workspace/.opencode/plugins/__tests__ && bun test'`
- `make test-harness` (runs the bun plugin test suite).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
