# DIA-260914-tqor - Stop delegation-observer stall sweep from re-emitting dead sessions forever and bound registry scan cost

---

id: DIA-260914-tqor
title: "Stop delegation-observer stall sweep from re-emitting dead sessions forever and bound registry scan cost"
area: opencode-config
severity: Critical
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "partial" # grilled | waived | bypassed | partial | skipped
gate_triggers: [schema-state, cross-cutting] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-14
source: inventory
date: 2026-09-14
created: 2026-09-14
updated: 2026-09-15

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched:

- .opencode/plugins/lib/stall-sweep.ts
- .opencode/plugins/delegation-observer.ts
- .opencode/plugins/**tests**/stall-sweep.test.mjs
  artifacts:
- .opencode/session/registry.jsonl
  evidence:
- registry 44853586 bytes / 128347 rows on 2026-09-14
- 119125 stall_detected rows; 1165 session IDs repeated more than twice

---

## Description

`createStallSweep()` reconstructs each session's latest lifecycle row by scanning
the complete append-only `.opencode/session/registry.jsonl` every minute. A
non-terminal row older than the dead threshold emits `stall_detected`, but that
event neither reconciles the lifecycle nor suppresses the session permanently.
The per-key dead throttle expires after 60 minutes, so the same abandoned
session is emitted again forever. With many stale sessions, one sweep becomes a
long append cascade and every future scan gets more expensive.

Current evidence matches the colleague report: the local registry is 44.85 MB
and 128,347 rows; 119,125 rows are `stall_detected`, 1,165 session IDs repeat
more than twice, and one session repeats 185 times. The most recent cascade
ended on 2026-09-12 only because the current process's first-sweep
`pluginLoadMs` guard suppresses pre-boot rows. A session that becomes stuck in
the current process lifetime can still enter the same unbounded cycle.

The DIA-260827-95fv lifecycle repair and OMO 2.2.19 upgrade do not change this
project plugin's stall-sweep persistence contract.

## Verification

- [x] A dead/unreconciled session produces at most one durable dead escalation
      until explicit lifecycle recovery changes its authoritative state.
- [x] Restarting/reloading the plugin does not re-enroll historical dead rows or
      create a new cascade.
- [x] The periodic sweep does not parse the full unbounded registry on every
      interval; retention/indexing keeps work bounded with preserved audit history.
- [x] Concurrent plugin instances share one effective sweep and cannot append
      duplicate escalations for the same session/tier.
- [ ] Behavioral tests cover repeated intervals, restart, many stale sessions,
      current-lifetime stalls, and explicit recovery.
- [x] Existing stall detection for a genuinely live current-lifetime session is
      preserved; `make test-shell` and `make test-config` pass.
- [ ] A migration/compaction command preserves the current registry as a
      recoverable archive before reducing the active file.

## Fix

- `journal-persistence.ts` now owns the shared lock, durable counters, checked
  append/fsync, and crash-gap-safe allocation used by registry and message writers.
- `registry.ts` maintains a bounded process-local lifecycle projection, ingests
  appended bytes incrementally, rebuilds explicitly after rotation/truncation,
  and performs locked durable `(session_id, generation, tier)` stall
  compare-and-append without a full-history contention fallback.
- `needs-input-observer.ts` uses the canonical registry writer. The delegation
  observer and stall sweep notify only after a durable stall append succeeds.
- RED/GREEN fixed points: `22596e2` (RED-D), `c81c827` (GREEN-D), and `8be415a`
  (accepted review fix). Earlier slices are recorded in the OpenSpec history.
- Archive/compaction, archive-aware readers, live migration, and final runtime
  observation remain deferred sections 6-10 of the same OPEN ticket.
- RED-E fixed points `2ce8e1a` and `9ba59c1` cover failure/malformed input.
  GREEN-E `0d0468a` preserves actual failure stages and rate-limits warnings;
  review fix `a306081` bounds warning fingerprints and reports malformed-only
  batches once without blocking later valid rows.

## Re-verify

- Focused registry plus stall-sweep: 91 passed, 0 failed.
- GREEN-D dependent suites: registry 57/57, stall sweep 34/34, stale-boot 5/5,
  reload dedup 3/3, and needs-input focused suites green.
- `make test-shell`: 684/684 passed; `make test-config`: exit 0 (57/57).
- Independent review found one hot-path full-scan fallback on lock exhaustion.
  Same-session fix `8be415a` removed it; targeted re-review cycle 1/2 marked the
  finding verified-closed with no new observations.
- RED-E baseline was 93 passed / 3 intended behavioral failures. After GREEN-E
  and its review fix, registry plus stall-sweep are 96/96 passed; typecheck,
  `git diff --check`, and the Podman pre-commit gate passed.
- The independent reviewer lane could not start because its Codex usage quota
  was exhausted. Root performed the read-only diff review; two boundedness and
  malformed-only observations were fixed in the original GREEN-E session.
- Ticket remains OPEN pending the unchecked archive/migration/runtime-smoke work.
