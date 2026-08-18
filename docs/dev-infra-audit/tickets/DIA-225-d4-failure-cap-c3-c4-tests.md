---
id: DIA-225
title: 'D4 failure cap + C3/C4 tests (empty-result detection + failure cap)'
area: tests-infra
severity: Major
status: DONE
blocked_by: [DIA-223, DIA-224]
discovered:
  source: council-consensus
  date: 2026-08-18
created: 2026-08-18
updated: 2026-08-18
session_id: ''
lane_id: ''
agent: ''
model: ''
parent_session_id: ''
attempts: 0
lease_expires_at: ''
files_touched:
  - .opencode/plugins/delegation-observer.ts
  - .opencode/plugins/__tests__/empty-result-detection.test.mjs
  - .opencode/plugins/__tests__/failure-cap.test.mjs
artifacts: []
evidence:
  - commit: dd1b005
  - test_results: '5 pass, 0 fail (C3: 2 pass, C4: 3 pass)'
---

## Description

Add per-lane failure counter + two bun test files (C3 empty-result detection, C4 failure cap). After this slice, 3 consecutive empty results within the cooldown window emit a warning event.

**Sub-step (a): D4 failure cap implementation**

- Add a `Map<string, { count: number; firstFailure: number }>` keyed by lane_id (or session_id if lane_id is not available)
- On each SILENT_FAILURE detection (DIA-224), increment the counter for that lane
- If count reaches 3 within a cooldown window (default 10 minutes = 600000 ms), emit a warning event to messages.jsonl with `gen_ai.operation.name: 'failure_cap_reached'`
- Reset the counter when a non-empty result is observed from the same lane
- Cooldown: if `Date.now() - firstFailure > 600000`, reset the counter before incrementing

**Sub-step (b): C3 -- empty-result-detection.test.mjs**

New file: `.opencode/plugins/__tests__/empty-result-detection.test.mjs` (~120 lines). Test: simulate a `session.idle` event with an empty task result and no file edits. Assert registry.jsonl contains a row with `dispatch_state: SILENT_FAILURE`. Test: simulate a `session.idle` event with file edits present. Assert NO SILENT_FAILURE row is emitted.

**Sub-step (c): C4 -- failure-cap.test.mjs**

New file: `.opencode/plugins/__tests__/failure-cap.test.mjs` (~100 lines). Test: simulate 3 consecutive `session.idle` events with empty results within 10 minutes. Assert messages.jsonl contains a `failure_cap_reached` warning event. Test: simulate 2 consecutive empty results, then a non-empty result, then 2 more empty results. Assert NO `failure_cap_reached` event (counter reset on non-empty). Test: simulate 2 consecutive empty results, wait 11 minutes (mock Date.now), then 1 more empty result. Assert NO `failure_cap_reached` event (cooldown expired, counter reset).

**Routing:** section 10 (plugin change + tests) -> @coder implementation

## Verification

1. Failure cap counter tracks consecutive SILENT_FAILURE events per lane
2. Warning event emitted after 3 consecutive failures within 10-minute cooldown
3. Counter resets on non-empty result
4. Counter resets after cooldown window expires
5. C3 test passes (empty-result detection works)
6. C4 test passes (failure cap works)
