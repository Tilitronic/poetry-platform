# DIA-169 - test infra Phase 2: critical gaps (vitest in author-studio, real data-contracts test)

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-126 collided with origin/omo-slim-changes ticket DIA-150-test-infra-phase2-critical-gaps.md (different ticket). Renumbered to DIA-169. This ticket duplicates remote DIA-150-test-infra-phase2-critical-gaps.md (same work, renumbered on the remote lineage via bab080c); SUPERSEDED by the remote ticket. -->

<!-- Ticket 3 of 4 from the approved test-refactoring plan (reviewed with
     mandatory corrections incorporated). Phase 2 - Critical Gaps. Blocked by
     DIA-167; blocks DIA-170. -->

---

id: DIA-169
title: "test infra Phase 2: critical gaps (vitest in author-studio, real data-contracts test)"
area: tests-infra
severity: Critical
status: OPEN
blocked_by: [DIA-167] # Phase 0 safety wins first
discovered:
source: baseline
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Phase 2 of the approved test-refactoring plan: two packages currently have no
real test coverage at all — `apps/author-studio` (test script is the fake
`echo "No test specified" && exit 0`; becomes loud per DIA-167) and
`packages/data-contracts` (no `test` script in package.json at all). Give
both real, behavioral coverage so CI validates what architecture.md
declares.

### 1. Vitest in apps/author-studio + real unit test

- Install Vitest in `apps/author-studio` (devDependency) with a new
  `apps/author-studio/vitest.config.ts`.
- Write a real unit test for a NAMED pure component or Pinia store in
  `apps/author-studio/src/`. Concrete targets that exist today:
  - `apps/author-studio/src/stores/example-store.ts` — Pinia store
    `useCounterStore` (state: counter; getter: doubleCount; action:
    increment). This is the simplest pure-Pinia target: test state getter
    and action behavior with no DOM.
  - `apps/author-studio/src/components/OpusTextEditor/OpusTextEditor.vue` —
    the real editor component (heavier; a store test is the recommended
    tracer bullet, component test optional later).
- The test must assert actual behavior (counter increments, doubleCount
  doubles), not import-only smoke.

### 2. data-contracts real test (MANDATORY CORRECTION applied)

`packages/data-contracts` is a ~13-line TS facade
(`packages/data-contracts/src/index.ts`) that re-exports
`schemas/contract.json` (a JSON Schema file) as `contract` plus the
`PoetryDataContract` type. It does NOT use protobuf-es — there is no
`fromJson`/`toJson` to test.

**MANDATORY CORRECTION (from review):** the test must test what ACTUALLY
exists. Write a ~10-line unit test (vitest, matching the package's existing
TS toolchain — add a `test` script to `packages/data-contracts/package.json`
which currently has none) asserting:

- importing `contract` returns a valid JSON Schema object;
- `contract.$schema` is the expected draft-07 URI
  (`http://json-schema.org/draft-07/schema#`);
- `contract.type === "object"`;
- `contract.properties` exists and contains the expected top-level keys
  (id, version, contract_hash, title, authorId, linesMap, ...).

Do NOT write protobuf-es fromJson/toJson tests — that API does not exist in
this package.

### 3. CI wiring

Both packages' `test` scripts must be part of the turbo `test` task so CI
runs them (consistent with the other packages).

## Verification

Acceptance criteria (all must hold):

- [ ] `apps/author-studio` has vitest + `vitest.config.ts`; `pnpm test` in
      author-studio runs a real runner and passes; the store test asserts
      real behavior of `useCounterStore` (state, getter, action).
- [ ] `packages/data-contracts` has a `test` script; the test imports
      `contract` and asserts `$schema`, `type`, and `properties` per the
      correction above (~10 lines); `pnpm test` passes.
- [ ] Both packages' tests are covered by the turbo `test` task / CI.
- [ ] No protobuf-es references anywhere in the data-contracts test.

Per AGENTS.md 2.3.1, handoff must include verification evidence: exit codes

- summary lines for `pnpm test` in both packages, turbo test output showing
  both packages included, and the test file list.

## Fix

Applied 2026-08-12, landed in commit 6239767 (branch omo-slim-changes):

1. `apps/author-studio`: vitest `^4.1.9` devDependency + new
   `vitest.config.ts` (node env, `src/**/*.test.ts`); real unit test
   `src/stores/example-store.test.ts` asserting `useCounterStore` behavior
   (initial state 0, `doubleCount` getter doubles, `increment` action bumps
   counter) via `createPinia`/`setActivePinia` — no DOM. Replaced the
   DIA-167 loud-fail stub `test` script with `vitest run`.
2. `packages/data-contracts`: vitest `^4.1.9` devDependency + new
   `vitest.config.ts` + `test` script (package previously had none, so turbo
   silently skipped it). Test `src/index.test.ts` asserts the `contract`
   re-export is a valid draft-07 JSON Schema object: `$schema` URI, `type:
"object"`, and expected `properties` keys. No protobuf-es — that API does
   not exist in this package.
3. Root `package.json`: removed `--filter=!author-studio` from the `test`
   script (DIA-167 exclusion) so both packages run in the turbo `test` task;
   turbo now executes 4 test tasks (author-studio, data-contracts,
   editor-engine, phonetics-core) instead of 2.
4. `apps/author-studio/AGENTS.md`: updated stale "no tests / excluded from
   turbo test" notes to reflect the vitest suite.

Verification evidence (all exit 0): `pnpm test` (turbo) — 4/4 tasks
successful; `pnpm --filter author-studio test` — 1 file, 2 tests passed;
`pnpm --filter data-contracts test` — 1 file, 1 test passed; lint +
typecheck for both packages; `make test-config` chain (9 scripts) all
passed; prettier clean on new files.

## Re-verify

> To be filled at re-verify time.
