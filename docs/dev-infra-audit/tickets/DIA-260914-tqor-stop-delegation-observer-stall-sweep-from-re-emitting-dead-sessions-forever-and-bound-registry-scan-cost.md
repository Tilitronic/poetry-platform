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
updated: 2026-09-14

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

- [ ] A dead/unreconciled session produces at most one durable dead escalation
      until explicit lifecycle recovery changes its authoritative state.
- [ ] Restarting/reloading the plugin does not re-enroll historical dead rows or
      create a new cascade.
- [ ] The periodic sweep does not parse the full unbounded registry on every
      interval; retention/indexing keeps work bounded with preserved audit history.
- [ ] Concurrent plugin instances share one effective sweep and cannot append
      duplicate escalations for the same session/tier.
- [ ] Behavioral tests cover repeated intervals, restart, many stale sessions,
      current-lifetime stalls, and explicit recovery.
- [ ] Existing stall detection for a genuinely live current-lifetime session is
      preserved; `make test-shell` and `make test-config` pass.
- [ ] A migration/compaction command preserves the current registry as a
      recoverable archive before reducing the active file.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
