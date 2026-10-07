# Bun mock.module: Live ESM Namespace Snapshot Trap

## Root Cause

Bun's `mock.module()` replaces an ESM module's exports in place. When you import the real module first and hold that reference, mutations from mock.module propagate into the held object because it points to the live namespace — not a frozen copy. This causes self-recursion: a mocked `spawnSync` calls itself.

```js
// BROKEN: realCp points at live namespace, mock.module mutations leak in
const realCp = await import("node:child_process");
mock.module("node:child_process", { spawnSync: () => { /* ... */ realCp.spawnSync(...) } });
// realCp.spawnSync is now the mock — stack overflow
```

## Recommended Fix

Spread the imported namespace into a plain object snapshot **before** the mock call:

```js
const realCp = { ...(await import("node:child_process")) };
mock.module("node:child_process", { spawnSync: () => { /* ... */ realCp.spawnSync(...) } });
// realCp.spawnSync is still the original — safe
```

Matches pattern in `helpers/plugin-harness.mjs` lines 16-23.

## Evidence

- Bun docs: mock.module overrides already-imported modules (live bindings). https://bun.sh/docs/test/mocks (2026-09-11)
- Node.js spawnSync: https://nodejs.org/api/child_process.html#childprocessspawnsynccommandargs-options (2026-09-11)

## Confidence

High (0.97) — direct reproduction evidence, documented Bun behavior, no inference gap.

## Outcome

Applied in DIA-260911-y52j. reviewer-immutable-git-envelope.test.mjs live-namespace recursion fixed via spread snapshot (`const realCp = { ...(await import("node:child_process")) }`), matching helpers/plugin-harness.mjs. Bounded regression added (one git --version, zero new spawnCalls). Verification: focused bun test 9 pass 0 fail 216ms EXIT 0 under timeout 30s; make test-config EXIT 0; lane-0 checksum MATCH 9cfed50b; ai-specialist High 0.97; ai-auditor REQUEST-CHANGES only for missing make test-config (now closed).

## Scope Limiter

Node built-ins under Bun `mock.module()` only. Does not apply to CommonJS `require()` mocks (different mechanism) or non-Bun test runners.
