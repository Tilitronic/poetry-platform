---
title: Bun mock.module is process-global and leaks across test files; fix with teardown restore
date: 2026-09-27
ticket: DIA-260926-ch1d
source: ai-specialist / ses_f1ced7fc8ffeFPYLx5FsM924NN (read-only, AGENTS.md 2.5 step 1)
verdict: GO-with-conditions
---

## Confirmed (Bun docs + upstream source, fetched 2026-09-27)

- `mock.module()` writes into a process-global registry
  (`ZigGlobalObject::onLoadPlugins.virtualModules`) whose lifetime is the VM's.
  Without `--isolate` it is shared across every test file in one `bun test`
  run, so a mock installed at one file's top level replaces that module for
  every later import in the same process.
  https://github.com/oven-sh/bun/pull/31319 (fetched 2026-09-27)
- `mock.restore()` does NOT reset modules overridden with `mock.module()`.
  `mock.clearAllMocks()` resets call history only. `jest.resetAllMocks()` drops
  spy implementations only. None of them undo a `mock.module` registration.
  https://bun.sh/docs/test/mocks (fetched 2026-09-27)
- The ONLY undo is re-registering the real module:
  `mock.module(specifier, () => realModule)`. There is no `resetModules`
  equivalent for module mocks.
- `--isolate` = fresh `globalThis` + cleared ESM/CJS module registries per file,
  same process (NOT a process per file); `--parallel` is the process-per-worker
  flag and implies `--isolate`. It fixes cross-file leaks but re-evaluates every
  file's imports and breaks tests that rely on process-lifetime module state.
  https://bun.sh/docs/test/parallel (fetched 2026-09-27)
- Version note: `--isolate`/`--parallel` landed in v1.3.13; 1.3.14 had a
  `--isolate` top-level-await TDZ regression (oven-sh/bun#31410) fixed by 1.4.0;
  1.4.1 fixed `--isolate` memory retention; 1.4.2 is unrelated regression fixes.
  Per-file `mock.module` scoping (PR #31319) is still OPEN / unmerged, so the
  leak is unchanged in the project's pinned Bun 1.4.2.
  https://bun.sh/blog/bun-v1.3.13 (2026-04-20)
  https://bun.com/blog/bun-v1.4.1 (2026-09-04)
  https://bun.com/blog/bun-v1.4.2 (2026-09-05)

## Project evidence (repo pointers)

- Pin: Dockerfile.dev:35 `ARG BUN_VERSION=1.4.2`; .mise.toml bun = "1.4.2";
  parity via scripts/check-pin-sync.sh.
- Leaker: .opencode/plugins/__tests__/plugin-harness.mock-child-process.test.mjs
  (installs porcelain child_process; never restores; lines 98/130 deliberately
  re-register the mock at file end).
- Victim: .opencode/plugins/__tests__/reviewer-immutable-git-envelope.test.mjs:55
  snapshots child_process and treats the leaked mock as real; also installs its
  own mock (lines 63-72) and never restores on file exit.
- Reusable primitive already present:
  .opencode/plugins/__tests__/helpers/plugin-harness.mjs:18-23 (`_realChildProcess`
  spread snapshot) + :130-132 (`restore()` re-registers the real module).
- Prior art: .opencode/learnings/external-patterns/2026-09-11-bun-mock-module-live-namespace-snapshot.md
  (spread-snapshot before mocking, to avoid live-namespace self-recursion).

## Recommended fix (test-side only)

Teardown restore: every file that calls `mock.module()` must re-register the
real module in `afterAll` (via the helper's existing snapshot) and must NOT
re-register the mock at file end. Apply to BOTH the leaker and the envelope file
(the leak is bidirectional: reversing file order breaks the leaker). Optionally
audit all other `mock.module` installers under `.opencode/plugins/__tests__/`.

## Rejected

- `mock.restore()` / `clearAllMocks()` as the fix: they do not undo `mock.module`.
- `bun test --isolate` / `--parallel`: changes suite-wide module-lifecycle
  semantics; measured 225 failures on 1.3.14 (partly the now-fixed TLA
  regression). Rejected.
- lazy/no-snapshot capture: does not help at call time and risks re-introducing
  live-namespace self-recursion.

## Confidence

High (0.9) on mechanism and fix direction (direct docs + upstream source +
analyzer reproduction); Medium on the exact reverse-order failure count and on
the 225 figure, both measured on 1.3.14 and needing re-measure on the pinned
1.4.2.

## Scope limiter

Node built-ins / ESM + CJS under Bun `mock.module()` in one non-isolate
`bun test` process. Not CommonJS-only runners, not `--isolate` mode.

## Outcome

- DONE (2026-09-27): implemented across commits 6bbbef28, 8e57fb2d, 9ff8bb48 and 0518c9e4 (campaign ticket DIA-260926-ch1d); section 2.5 step 6 independent audit verdict SOUND-with-conditions; its findings F1-F4 addressed in 0518c9e4; plugin suite green at 555 pass / 1 skip / 0 fail on bun 1.4.2; `make test-infra` host confirmation still pending.
