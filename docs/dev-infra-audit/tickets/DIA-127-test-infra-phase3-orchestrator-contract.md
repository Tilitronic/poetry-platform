# DIA-127 - test infra Phase 3: Orchestrator contract test (acceptWorkerResult, zero mocks)

<!-- Ticket 4 of 4 from the approved test-refactoring plan (reviewed with
     mandatory corrections incorporated). Phase 3 - Orchestrator Contract
     Test. Blocked by DIA-126. -->

---

id: DIA-127
title: "test infra Phase 3: Orchestrator contract test (acceptWorkerResult, zero mocks)"
area: tests-infra
severity: Medium
status: DONE
blocked_by: [DIA-126] # Phase 2 critical gaps first
discovered:
source: baseline
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: "coder"
model: ""
parent_session_id: ""
attempts: 1
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Phase 3 of the approved test-refactoring plan: cover the Orchestrator worker
result contract defined in architecture.md (revision ordering and priority)
with a direct unit test and zero mocking.

### MANDATORY CORRECTION applied (replaces the original worker-mock plan)

The original plan proposed mocking `MessageChannel`/`Worker` to exercise the
worker wiring in `apps/author-studio/src/workers/` (bootstrap.ts, w1-stress.ts,
w2-phonetics.ts). Review corrected this: those worker files are `export {};`
stubs — there is no worker machinery to test, and mocking
MessageChannel/Worker adds ceremony without coverage.

Instead, write a direct unit test of `Orchestrator.acceptWorkerResult` in
`packages/editor-engine/src/orchestrator/Orchestrator.ts` (lines ~24-33).
That method implements the architecture.md contract:

- `acceptWorkerResult(lineId, data, workerRevisionId)` looks up the line in
  state; if the line is missing it returns early;
- if `workerRevisionId < line.value.revisionId` the result is DISCARDED
  (stale worker output must not overwrite newer state);
- otherwise the line is updated with the worker data and the revisionId is
  advanced.

### Test shape (zero mocks)

`packages/editor-engine` already has vitest (`"test": "vitest run"` in its
package.json). Add a test alongside Orchestrator.ts (e.g.
`packages/editor-engine/src/orchestrator/Orchestrator.test.ts`) that:

1. Instantiates `new Orchestrator()` directly (no DI fakes, no
   MessageChannel/Worker).
2. Inserts lines via `insertLine(id, text, index)`.
3. Calls `acceptWorkerResult` with various `workerRevisionId` values —
   older, equal, and newer than the current line revision.
4. Asserts: stale (older revisionId) results are discarded and do not
   overwrite the line's marks/stress/ipa; current/newer revisionId results
   are applied; unknown lineId is a no-op.
5. Asserts the resulting line state matches the architecture.md revision
   ordering and priority contract.

Do NOT mock MessageChannel or Worker. Do NOT touch the `export {};` worker
stubs in apps/author-studio.

## Verification

Acceptance criteria (all must hold):

- [ ] New test file exists next to Orchestrator.ts (or in the matching test
      tree) covering `acceptWorkerResult`.
- [ ] Test passes with `pnpm test` in `packages/editor-engine` (vitest).
- [ ] Stale-result-discard, apply-newer, equal-revision, and unknown-line
      cases are all asserted.
- [ ] No `MessageChannel`/`Worker` mocks anywhere in the test; worker stubs
      in apps/author-studio untouched.

Per AGENTS.md 2.3.1, handoff must include verification evidence: exit codes

- summary lines for `pnpm test` (editor-engine), the test case list, and
  confirmation no worker files were modified.

## Fix

Applied 2026-08-12, landed in commit bb0bf7a (branch omo-slim-changes):

1. New `packages/editor-engine/src/orchestrator/Orchestrator.test.ts` — direct
   unit test of `Orchestrator.acceptWorkerResult` with zero mocks
   (no MessageChannel/Worker; worker stubs in apps/author-studio untouched).
   Enforces the architecture.md revision-ordering + priority contract
   ("Orchestrator - single write point", ~lines 503-509):
   - stale result (workerRevisionId < current revision) discarded — marks/
     stress/ipa and revisionId unchanged;
   - equal revision applied (equal is not stale; computed against current doc);
   - newer result applied and revisionId advanced to the worker's;
   - unknown lineId is a no-op (no throw, no state change);
   - priority: a user override (revision bumped via the real line atom, since
     the user-input write path is not yet wired into Orchestrator) is never
     clobbered by a stale worker recomputation that started before it.
2. Orchestrator already satisfies the contract — all 5 new tests passed GREEN
   on first write; no production-code changes were needed. Existing
   opusFormattingFilter suite unchanged (91 tests).

Verification: editor-engine vitest 96 passed (2 files); turbo `pnpm test`
4/4 tasks successful; editor-engine lint + typecheck exit 0; make test-config
all sub-gates exit 0 (E1-E11).

## Re-verify

> To be filled at re-verify time.
