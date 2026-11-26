---
id: DIA-223
title: 'C1+C2 regression tests for handoff archive collision and slot identity'
area: tests-infra
severity: Major
status: CLOSED
blocked_by: [DIA-222]
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
files_touched: []
artifacts: []
evidence: []
---

## Description

Two bun test files that verify F-1 and F-3 fixes from DIA-222. After this slice, `bun test` passes with 2 new test files.

**Sub-step (a): C1 -- handoff-archive-collision.test.mjs**

New file: `.opencode/plugins/__tests__/handoff-archive-collision.test.mjs` (~80 lines). Mirror `parallel-handoff.test.mjs` pattern (mock `@opencode-ai/plugin`, dynamic import, fresh mkdtemp workspace). Call `atomicWriteHandoff` twice with the same sessionId within the same millisecond. Assert that two distinct archive files are created (different UUID suffixes).

**Sub-step (b): C2 -- handoff-slot-identity.test.mjs**

New file: `.opencode/plugins/__tests__/handoff-slot-identity.test.mjs` (~100 lines). Mirror `parallel-handoff.test.mjs`. Test 1: call `log_decision` with `event_type: 'handoff'` from a session that has no `parentSessionId` set. Assert the slot file is named after the actual `sessionID`, not `"unknown"`. Test 2: call `log_decision` from two different sessions with no `parentSessionId`. Assert two distinct slot files are created (not a single `"unknown.json"` clobber).

**Routing:** section 10 (plugin test) -> @coder implementation (DIFFERENT instance from DIA-222 per DIA-175)

**DIA-175:** this is the RED test-writing. A DIFFERENT instance wrote the GREEN implementation (DIA-222).

## Verification

1. C1 test file exists with at least 1 test case
2. C2 test file exists with at least 2 test cases
3. Both tests pass with DIA-222 applied
4. Both tests fail if DIA-222 is reverted (regression detection)
5. Tests follow the hermetic pattern (fresh mkdtemp, mock `@opencode-ai/plugin`, dynamic import)
