# DIA-260909-zeik - simplify repeated failure-cleanup paths in standalone harness scenarios

---

id: DIA-260909-zeik
title: "simplify repeated failure-cleanup paths in standalone harness scenarios"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: "DIA-260903-o7n0"
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-09
source: inventory
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-09

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

Post-audit cleanup item 5 from ponytail audit /tmp/architecture-review-20260909-170245.html (ephemeral; substance carried here). Parent context: DIA-260903-o7n0 de-bloat + observer-lib extraction work. Item 1 ALREADY FIXED at 420ce4f.

Simplify repeated failure-cleanup paths in standalone harness scenarios. Standalone harness scenario files (run under `bun run`, not `bun test`) duplicate failure-cleanup logic (remove temp dirs, reset fixtures, restore env) across multiple `catch`/`finally` branches. Extract into a shared `withCleanup` wrapper or deduped finally block in helpers/plugin-harness.mjs or scenario helper.

Estimated savings: -45..-70 LOC.

Guard (MANDATORY): do NOT delete the 7 extracted production modules, capability loader guards, or independent checksum logic. Failure-cleanup simplification must preserve independent checksum/parity assertions - only deduplicate the cleanup mechanics.

Source: ponytail audit item 5, DIA-260903-o7n0 follow-up. Campaign ticket DIA-260901-91qy.

## Verification

- [ ] Standalone harness scenarios no longer duplicate failure-cleanup paths (single cleanup path per scenario)
- [ ] Cleanup helper or shared finally block covers all failure branches without losing error context
- [ ] 7 extracted production modules, capability loader guards, checksum logic untouched
- [ ] LOC delta -45..-70 verified via git diff --stat
- [ ] Harness scenarios pass under `bun run`

## Fix

Implemented 2026-09-09 (coder lane, campaign ticket DIA-260909-zeik).

- New `.opencode/plugins/__tests__/harness-scenarios/scenario-runner.mjs`
  (36 lines, 1 export `runScenario`): sole cleanup owner via one
  try/finally; injected `fail(msg)` throws a module-private sentinel;
  exit 0 pass / 1 fail; `[cleanup]` line verbatim in finally.
- Migrated 3 scenarios to `runScenario(prefix, fn)`: 24 cleanup sites
  (4+8+12) across 21 branches collapsed to 1; zero `cleanup()` /
  `process.exit` refs remain in scenarios; `readRegistry` /
  `canonicalChecksum` / `readJson` stay per-scenario; mock-before-import
  stays per-file top-level.
- Baseline green pre-change: `bun run` x3 exit 0 (host bun 1.3.14;
  poetry-dev container down, docker daemon unavailable, so the bats
  replay leg was covered by running the exact underlying
  `bun run <name>.scenario.mjs` commands: 3/3 exit 0 post-change).
- Negative probes (throwaway, reverted): (a) flipped assertion ->
  exit 1, `FAIL:` line, no /tmp/c5-s1-_ left; (b) body throw ->
  `ERROR:` line + stack, exit 1, no /tmp/c5-s2-_ left. Re-ran green.
- LOC delta actual: scenarios net -124 (s1 -23, s2 -42, s3 -59) plus
  runner +36 = net about -88. Outside the -45..-70 estimate and the
  gate-forecast -30..-45; reported as-is per no-pad rule, for developer
  disposition. Lib 8-vs-7 count from gate risk 4 is moot (lib/ untouched).
- Guards: `plugin-harness.mjs` (4 exports), replay bats, lib/,
  delegation-observer.ts, budget-baselines.json all untouched;
  `mock.module("@opencode-ai/plugin"` literal only in plugin-harness.mjs;
  prettier + eslint clean on all 4 files; ASCII-only.
- Budget: commit carries `Budget-Scope: test-debloat` trailer, backing
  approved campaign DIA-260903-o7n0; `check-budget-gate.sh` ok line
  captured at commit time.

## Re-verify

> To be filled at re-verify time.
