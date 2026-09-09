# Design: dia-260909-zeik-scenario-cleanup-dedupe

References (does not override): AGENTS.md sections 2.3-2.4, 6; parent epic DIA-260903-o7n0 dispositions (helper 4-export cap, `.mjs` repo-wide node-runnable convention, helper imports only `mock` from `bun:test`); ticket DIA-260909-zeik guards; interview.md decision table (Q1-Q4, practice-protected, developer-ruled).

## 1. Constraints (developer-confirmed)

| #   | Constraint                                                                                                                                                         | Source       |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------ |
| C1  | Exactly 4 implementation files: new `scenario-runner.mjs` + 3 scenario scripts. Evidence files exempt.                                                             | Q4           |
| C2  | Native `bun run`; no test-framework imports in new code.                                                                                                           | Q2           |
| C3  | Bats replay contract unedited: filenames `<name>.scenario.mjs`, exit 0 pass / 1 fail.                                                                              | Q2           |
| C4  | Mock-before-import stays local per scenario; runner never wraps the plugin import.                                                                                 | Q3           |
| C5  | `helpers/plugin-harness.mjs` untouched (concurrent ticket DIA-260909-fkiy owns it; 4-export cap respected).                                                        | Q4 rest      |
| C6  | Error states as specified in section 3 accepted.                                                                                                                   | Q4           |
| C7  | Commit names DIA-260909-zeik, carries `Budget-Scope: test-debloat` trailer, passes `check-budget-gate.sh`.                                                         | Q4 rest      |
| C8  | Independent checksum/parity assertions stay per-scenario; only cleanup mechanics deduplicated. 7 extracted production modules, capability-loader guards untouched. | ticket guard |
| C9  | DIA-104 grilling gate stays `skipped`.                                                                                                                             | ticket       |

## 2. Runner design

New file `.opencode/plugins/__tests__/harness-scenarios/scenario-runner.mjs` (lives beside the scenarios, not in `helpers/`, so it cannot collide with fkiy and cannot be picked up by the bats runner, which only invokes `$name.scenario.mjs` for the three known names).

Exports: exactly one symbol (C1-C5 cap discipline: 1 < 4).

```js
import { createTempWorkspace } from '../helpers/plugin-harness.mjs';

class ScenarioFailure extends Error {}

// runScenario: single cleanup path for standalone bun-run scenarios.
// body receives { directory, fail }; fail(msg) throws the sentinel so the
// finally block below is the ONLY cleanup site. process.exit() skipping
// finally is why the old per-branch manual cleanup existed; throwing
// instead of exiting is what lets one finally cover every failure branch.
export async function runScenario(prefix, body) {
  const { directory, cleanup } = createTempWorkspace(prefix);
  let code = 0;
  const fail = (message) => {
    throw new ScenarioFailure(message);
  };
  try {
    await body({ directory, fail });
  } catch (err) {
    if (err instanceof ScenarioFailure) {
      console.error(`FAIL: ${err.message}`);
    } else {
      console.error('ERROR: unexpected scenario failure');
      console.error(err);
    }
    code = 1;
  } finally {
    try {
      cleanup();
    } catch (e) {
      console.error(`[cleanup] scenario cleanup failed: ${e?.message ?? e}`);
    }
  }
  process.exit(code);
}
```

Target size: <= 40 lines including this header comment (LOC budget, see section 6).

The `[cleanup]` log line is byte-identical to the current per-site text, moved once into the finally.

NOTE: the snippet above is illustrative; the committed runner adds the fail()-from-awaited-body-only header and follows the local double-quote no-semi file convention.

## 3. Error-state semantics (Q4 accepted)

| State                                             | Behavior                                                                                       | Exit code |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------- | --------- |
| All assertions pass                               | cleanup, exit                                                                                  | 0         |
| `fail(msg)` called                                | print `FAIL: msg` to stderr, cleanup, exit                                                     | 1         |
| Unexpected throw (bug in plugin or scenario body) | print `ERROR:` line + error/stack, cleanup, exit                                               | 1         |
| Cleanup itself throws                             | print `[cleanup] scenario cleanup failed: <msg>`; NEVER changes the exit code determined above | 0 or 1    |
| Hard process death                                | `plugin-harness` `process.on("exit")` fail-safe sweep remains as last resort (untouched, C5)   | n/a       |

Behavior delta vs today: previously an unexpected throw propagated to bun's crash handler (nonzero exit, finally still ran). Now the runner catches, prints, and exits 1. The bats contract (only 0 vs nonzero-fail is distinguished) is unaffected (C3). Assertion-failure output is contract-identical: same `FAIL: ` prefix on stderr and exit 1 after cleanup (bats never parses stderr; only 0 vs nonzero is distinguished).

## 4. Seams and migration pattern

Seams (tdd-craftsman vocabulary):

- S1 scenario <-> runner: `runScenario(prefix, async ({ directory, fail }) => {...})` - the only new seam.
- S2 runner -> `plugin-harness`: imports `createTempWorkspace` only; signature frozen by C5.
- S3 bats -> scenarios: filename + exit code; frozen by C3.

Per-scenario migration (mechanical, identical shape in all three):

```js
// BEFORE (today, per branch):
mockOpencodePlugin()
const { directory, cleanup } = createTempWorkspace("c5-sN-")
try {
  ...
  if (!cond) {
    console.error(`FAIL: ...`)          // 1-3 lines
    try { cleanup() } catch (e) {...}   // duplicated site
    process.exit(1)
  }
  ...
} finally {
  try { cleanup() } catch (e) {...}
}
process.exit(0)

// AFTER:
mockOpencodePlugin()                     // C4: stays at module top, before the plugin import
const { default: createDelegationObserver } = await import("../../delegation-observer.ts") // s1 only; s2/s3 keep createHarness
await runScenario("c5-sN-", async ({ directory, fail }) => {
  ...
  if (!cond) fail(`...`)                 // single-line guard
  ...
})
```

`readJson`, `canonicalChecksum`, `writeTerminalHandoff`, `readRegistry` remain defined inside each scenario body (C8 independence guard). Multi-line `console.error` argument blocks collapse into the `fail()` template string.

Expected site counts removed: scenario-1 4 sites / 3 branches, scenario-2 8 sites / 7 branches, scenario-3 12 sites / 11 branches.

## 5. Forward-compatibility with DIA-260909-fkiy

fkiy extracts workspace-cleanup retry loops into `helpers/plugin-harness.mjs` (its disposition: extend that file, do not create a new helper). This change deliberately does the opposite in a disjoint file set:

- **Zero file overlap** -> no merge conflict in either landing order; this change never edits `plugin-harness.mjs` (C5).
- **Composition, not duplication:** the runner calls `createTempWorkspace`; when fkiy later adds bounded retry/backoff inside that helper, all three scenarios inherit it with zero edits here.
- **If fkiy changes the helper's export surface additively** (allowed under its own 4-export arbitration), no impact here. A signature change to `createTempWorkspace` is out of fkiy's stated scope; if it ever lands, the fix is a one-line import adjustment in `scenario-runner.mjs` - flagged here for whoever rebases.
- The `mock.module` canonical string stays confined to `plugin-harness.mjs` (budget-B detector, baseline 0): the runner and scenarios only reference the `mockOpencodePlugin()` indirection, never the literal pattern (C2, C4).

## 6. Budget-gate compliance (C7)

- The 4 touched files sit under `.opencode/plugins/__tests__/` -> scoped, role `test`. `delegation-observer.ts` and `lib/*.ts` untouched -> production/shell totals unchanged.
- Trailer: subject line names `DIA-260909-zeik`; body ends with `Budget-Scope: test-debloat`. `has_backing` resolves the approved `test-debloat` campaign entry for OPEN ticket DIA-260909-zeik in `scripts/budget-baselines.json` (ruling-authorized one-line manifest addition; the o7n0 campaign entry is CLOSED) -> gate passes.
- LOC verification: `git diff --stat` over the 4 files, net deletions target -45..-70 (ticket). Tension + ruling recorded in interview.md: scenarios must shed ~75-110 lines to net out after the runner's ~30-40; if the measured net falls outside the range, report the actual delta to the developer - do not pad or over-cut to fit.

## 7. Test strategy (AGENTS.md 2.4 requirement)

No new test files exist (C1); the scenarios are the tests. Evidence plan, in order:

1. **Baseline green:** before any edit, `bun run <name>.scenario.mjs` (exit 0) for all three inside `poetry-dev` - the exact command bats issues. Container must be Up (`docker compose ps` evidence recorded first; AGENTS.md 6 pre-work gate).
2. **Per-slice green:** after each migration slice, re-run that scenario: exit 0.
3. **Negative probes (throwaway, NOT committed):** (a) temporarily flip one assertion in scenario-1 -> expect exit 1, `FAIL:` line on stderr, temp dir removed (`ls /tmp | grep c5-s1-` empty); (b) temporarily throw inside a body -> expect `ERROR:` line, exit 1, temp dir removed; (c) the cleanup-failure branch is the current per-site `[cleanup]` line moved verbatim into the runner finally - verified by code-walk/diff, not injection (rmSync force:true makes natural failure hard to provoke). Outputs pasted into the ticket evidence.
4. **Contract green:** `scripts/__tests__/harness-scenario-replay.bats` unedited, run via `make test-shell` from host with Docker available -> 3/3 pass.
5. **Guard checks:** `git status` shows no diff for `plugin-harness.mjs`, the bats file, `delegation-observer.ts`, `lib/`; `scripts/budget-baselines.json` shows only the ruling-authorized one-line zeik entry (manifest:15; o7n0 CLOSED); grep confirms the `mock.module("@opencode-ai/plugin"` literal exists only in `plugin-harness.mjs`; export counts: plugin-harness 4, scenario-runner 1.
6. **Commit:** budget gate runs via commit-msg hook; `ok:` line captured.

Bun test suites are NOT used: scenarios run under `bun run` (C2); the `bun:test` `mock` import already guarded inside `plugin-harness.mjs` with a try/catch no-op stays as-is.

## 7.1 Rollback plan (AGENTS.md 2.4 requirement)

- Single atomic commit (scenarios import the runner; a partial revert breaks all three). No data, config, or production changes (one-line manifest backing entry only).
- Rollback = `git revert <sha>`: restores the 24-site boilerplate verbatim; the bats file was never touched, so no test-side change accompanies the revert.
- Trigger to revert: any scenario exits nonzero post-merge for a cause traced to the runner (not to a real plugin regression - a genuine regression must NOT be reverted away).
- Rebase interaction: none expected (disjoint file set from fkiy, section 5).

## 8. Out of scope

- `plugin-harness.mjs` internals (fkiy), the 16 bun-test suites' cleanup retry loops (fkiy), any production module, the bats suite, the budget manifest (beyond the ruling-authorized one-line zeik backing entry), main-spec deltas (skip_specs), re-grilling the DIA-104 gate (C9).
