# Proposal: dia-260909-zeik-scenario-cleanup-dedupe

## Why

The three standalone harness scenario scripts under `.opencode/plugins/__tests__/harness-scenarios/` duplicate the same failure-cleanup boilerplate across every assertion branch: `try { cleanup() } catch (e) { console.error(...) }` appears 24 times (4 + 8 + 12 per file) because `process.exit()` skips `finally` blocks, so each of the 21 failure branches must clean up before exiting. The duplication is pure mechanics: it buries the assertions it guards, and any change to cleanup semantics requires edits at 24 sites. This is ponytail-audit item 5 (ticket DIA-260909-zeik), estimated at -45..-70 net LOC.

## What Changes

- **New** `harness-scenarios/scenario-runner.mjs`: exports exactly one symbol, `runScenario(prefix, body)`. The runner owns temp-workspace creation, the single cleanup path (one `try/finally`), failure control flow via an injected `fail(message)` (throws a module-private sentinel; runner prints, cleans up once, exits 1), and the final `process.exit(0|1)`.
- **Migrated** (behavior-preserving): `empty-result-silent-failure.scenario.mjs`, `parallel-handoff-archive.scenario.mjs`, `slot-identity-no-clobber.scenario.mjs`. Each assertion branch collapses from console.error + manual cleanup + `process.exit(1)` to a single `fail(...)` guard; the per-file trailing `finally` block and `process.exit(0)` move into the runner.
- **Frozen, zero edits:** `scripts/__tests__/harness-scenario-replay.bats` (replay contract: same `bun run <name>.scenario.mjs` invocation, exit 0 pass / exit 1 fail), `helpers/plugin-harness.mjs` (owned by concurrent ticket DIA-260909-fkiy; keeps its 4 exports), per-scenario `readJson`/`canonicalChecksum` assertion helpers (independence is a ticket-mandated guard), and the mock-before-import ordering, which stays local to each scenario file.
- **File budget (developer ruling, Q4):** exactly 4 implementation files = new `scenario-runner.mjs` + the 3 scenario scripts. Ticket / spec / changelog evidence edits do not count toward the limit.
- **Budget trailer:** the implementation commit names DIA-260909-zeik and carries `Budget-Scope: test-debloat`; backing is a ruling-authorized `test-debloat` entry for OPEN DIA-260909-zeik in `scripts/budget-baselines.json` (the o7n0 campaign entry was CLOSED at implementation time), so `scripts/check-budget-gate.sh` passes with that one-line manifest addition.

## Capabilities

### New Capabilities

None. This is a test-infrastructure deduplication with no externally observable behavior change.

### Modified Capabilities

None. The scenario-replay contract (filenames, `bun run` runtime, exit codes) is unchanged by construction; the cleanup mechanics are an implementation detail of the scenarios. This change sets `skip_specs: true` in `.openspec.yaml`.

## Impact

- **Files (4, implementation):** `.opencode/plugins/__tests__/harness-scenarios/{scenario-runner.mjs (new), empty-result-silent-failure.scenario.mjs, parallel-handoff-archive.scenario.mjs, slot-identity-no-clobber.scenario.mjs}`.
- **LOC:** scenarios 428 lines today; target net delta -45..-70 across the 4 files per ticket verification (runner adds ~30-40; scenarios must shed ~75-110). If the measured net lands outside the range, report to developer for disposition (see interview.md "Open tension").
- **Gates:** `bun run` x3 inside `poetry-dev` (same command the bats suite issues), `scripts/__tests__/harness-scenario-replay.bats` 3/3 via `make test-shell`, commit-msg budget gate.
- **Untouched (guards):** delegation-observer plugin and `lib/*.ts` production modules, capability-loader guards, independent checksum logic, `plugin-harness.mjs`, the bats file. (`scripts/budget-baselines.json` carries the ruling-authorized one-line `test-debloat` entry for OPEN DIA-260909-zeik at manifest:15; the o7n0 entry is CLOSED.)
- **Dependencies:** none new. Node builtins + existing helper imports only; no test-framework imports.

## Alternatives considered

- **A. `withCleanup` wrapper inside `helpers/plugin-harness.mjs`** (the ticket's original suggestion): rejected. Concurrent ticket DIA-260909-fkiy edits the same file (collision), and a 5th export breaks the DIA-260903-o7n0 disposition "4 exports max not target".
- **B. Status quo / do nothing**: rejected. Ticket stays open; 24 duplicated cleanup sites remain and the o7n0 de-bloat campaign item uncompleted.
- **C. Chosen - separate `scenario-runner.mjs` in `harness-scenarios/`**, because it has zero file overlap with fkiy, respects the 4-export cap without touching plugin-harness, keeps the mock-before-import ordering local per scenario, and stays native `bun run` with no test-framework imports.

## Testing Decisions

The scenarios ARE the tests; no new test file exists (4-file cap). Verification strategy (detail in design.md): native `bun run` green for all three scenarios inside the container, unedited bats replay suite green, throwaway (non-committed) negative probes for the failure and unexpected-throw error states with evidence recorded in the ticket, `git diff --stat` for the LOC delta, and grep checks that the canonical `mock.module` string remains confined to `plugin-harness.mjs` (budget-B detector, baseline 0).
