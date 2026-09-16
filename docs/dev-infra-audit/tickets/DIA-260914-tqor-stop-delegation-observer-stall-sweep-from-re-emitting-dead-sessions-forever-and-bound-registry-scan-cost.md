# DIA-260914-tqor - Stop delegation-observer stall sweep from re-emitting dead sessions forever and bound registry scan cost

---

id: DIA-260914-tqor
title: "Stop delegation-observer stall sweep from re-emitting dead sessions forever and bound registry scan cost"
area: opencode-config
severity: Critical
status: CLOSED
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
updated: 2026-09-16

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

evidence:

- commit:8fd40c5
- commit:e753215
- 2026-09-16: verified archive migration, focused 189/189, archive readers 50/50, shell 708/708, config 57/57, OpenSpec strict valid, runtime smoke non-empty, two sweep intervals stable, ai-audit GO-WITH-CHANGES with follow-ups DIA-260831-b7c8 and DIA-260916-z5pf

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
- [x] Behavioral tests cover repeated intervals, restart, many stale sessions,
      current-lifetime stalls, and explicit recovery.
- [x] Existing stall detection for a genuinely live current-lifetime session is
      preserved; `make test-shell` and `make test-config` pass.
- [x] A migration/compaction command preserves the current registry as a
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
- Explicit operator-only rotation now creates a byte-identical immutable archive
  and verified manifest under the shared lock, compacts active lifecycle state,
  preserves both counter high-water marks, and rolls back the authoritative
  active registry if a later index/counter/event step fails. It is never called
  by the periodic sweep or hot hooks and provides no archive deletion API.
- Archive-aware readers use source-aware semantic identity: distinct legacy
  rows sharing a sequence within one immutable source remain queryable,
  identical cross-source overlaps deduplicate, compact active projections are
  shadowed by their archived full rows, and genuine cross-source conflicts
  fail closed.
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
- RED-F commits `06d62f8`, `35c50e4`, `e2696cd`, and `7b74497` establish the
  real-filesystem, cross-process, failure-stage, rollback, and raw-byte contract.
  GREEN-F commits `8319d05` and `9d11a2c` implement it in a separate coder
  instance. Focused registry verification is 70/70; Podman pre-commit, Prettier,
  and `git diff --check` pass.
- Targeted GREEN-F re-review cycle 1/2 verified all four accepted findings
  closed: distinct failure stages, archive/manifest rename coverage,
  post-replacement rollback, and byte-identical non-UTF-8 archival.
- RED/GREEN archive-reader fixed points are `11bc4d8`, `293948d`, `fe96467`,
  `359e224`, `f5b1b42`, and `c9d7362`. Targeted re-review cycle 2/2 verified
  source identity and legacy duplicate-sequence compatibility closed.
- Controlled live migration on 2026-09-16 archived 44,861,601 bytes / 128,373
  rows (0 malformed; seq 1..128378) to
  `registry-20260916101142-6b3f7c15-2b1b-4c9d-b061-dfd2ae76e79b.jsonl`.
  Independent SHA-256 matched
  `a09216e8599488ba83a2e5c3a4455d8f3b4eaa4df629f60e0c39e1f4ab6c830f`;
  12 active generations were retained, the active file became 4,012 bytes / 13
  rows, registry high-water became 128380, message high-water remained 126585,
  and rotation elapsed 415 ms. The archive and manifest remain outside Git.
- Final focused gates: TQOR plugin suites 189/189, archive/query Bats 50/50,
  `make test-shell` 708/708, `make test-config` 57/57, strict OpenSpec valid,
  and `git diff --check` clean. The complete plugin glob ran 541 pass / 1 skip /
  1 unrelated `parallel-handoff` logging assertion failure owned by
  DIA-260827-36ht 'plugin behavioral gate is red and missing from pre-push'.
- Runtime reload selected `orchestrator - gpt-5.6-luna` and returned non-empty
  `TQOR_SMOKE_OK`. Across two unchanged sweep intervals active
  `stall_detected` remained 0 -> 0; health stayed `index_dirty=false`, with one
  verified archive and monotonic registry seq 128383 after normal smoke writes.
- Live historical `session-query` returned archived evidence in about 2 seconds.
  Full historical `jsonl-cross-check` is intentionally O(history) and exceeded
  an 8-second bounded audit probe; periodic sweep and hot append paths remain
  archive-blind and bounded. This performance observation is not a hot-path
  regression and is retained for the later reader-optimization backlog.
