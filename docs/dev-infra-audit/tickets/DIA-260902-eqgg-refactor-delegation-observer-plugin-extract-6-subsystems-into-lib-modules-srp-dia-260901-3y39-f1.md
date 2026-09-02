# DIA-260902-eqgg - Refactor delegation-observer plugin: extract 7 seam modules into lib modules (SRP, DIA-260901-3y39 F1)

---

id: DIA-260902-eqgg
title: "Refactor delegation-observer plugin: extract 7 seam modules into lib modules (SRP, DIA-260901-3y39 F1)"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-02
source: inventory
date: 2026-09-02
created: 2026-09-02
updated: 2026-09-02

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

SRP refactor of the delegation-observer plugin file (currently 1100+ lines, 7 seam modules in one file) -- finding F1 from DIA-260901-3y39 architecture-check.

Extract each seam into separate lib modules under `.opencode/plugins/lib/` (or equivalent):
1. capability-token mint/verify
2. ticket-gate scan + keyword correlation
3. handoff slots + active.json + boot.json lifecycle
4. stall-sweep scheduler
5. edit-time formatter hook (prettier --no-install, non-fatal)
6. tool-level circuit breaker
7. registry/messages writer (appendRow/appendMessageRow/boot marker)

Keep thin plugin shell (LOC advisory ~3,700, binding = Gates A/B/C: every retained lib has production importer, no duplicate shell definitions, tests on canonical interface). NO behavior change -- import discipline only (mechanical extraction, tests prove parity).

Already started: `lib/errors` module (DIA-260825-oyh) as pattern precedent.

This is OpenCode config work -- section 2.5 chain: ai-specialist gate -> @architector design (if non-trivial) -> @coder implement -> test-config + restart-verify -> @ai-auditor independent review -> CHANGELOG.yaml entry.

Workflow: OpenSpec interview-first spec (proposal/design/tasks under openspec/changes/<name>/) -> TDD-Craftsman RED/GREEN with instance separation DIA-175 (test-author != implementer). No scope expansion beyond the 7 seams.

## Verification (corrected V-A structural criteria, developer approved 2026-09-02 before final wiring; LOC advisory)

- [x] OpenSpec change proposal/design/tasks authored and approved (interview-first, user writes substance) — `openspec/changes/dia-260902-eqgg-delegation-observer-srp/` validated
- [x] Each lib module extracted with unit tests (bats/pytest per artifact type) -- RED/GREEN with instance separation DIA-175 (7 libs: capability, ticket-gate, handoff, registry, stall-sweep, formatter, circuit-breaker; 270 lib tests) — *LOC is advisory (~3,700), binding is structural gate A/B/C, not grep LOC*
- [x] `make test-config` clean (57 tests) — JSONC validity, `validate-plugin-loads.sh` Node+Bun Wy-compat, `validate-observer-dedupe.sh`, `validate-plugin-structure.sh` Gate A/B/C PASS; no behavior change (hook parity verified via normalized harness traces)
- [x] Harness parity 3/3 scenarios + boot-only implicit (boot-only, empty-result-silent-failure, parallel-handoff-archive, slot-identity-no-clobber) — normalized `registry/messages/boot` traces exact on stable fields per Q7 §3
- [x] Perf smoke Q7 §5 — warm-up + multi-sample no-op `tool.execute.before/after` p95 <5ms (p50/p95 recorded)
- [x] Restart OpenCode + functional smoke: delegation-observer hooks fire correctly (if Docker down, report what could not run)
- [x] @ai-auditor independent review — APPROVE cycle 2/2 (O1-O3 verified-closed) — F1-F6 fixes verified, ai-auditor independent review APPROVE
- [x] CHANGELOG.yaml entry appended + `scripts/changelog-render` + learnings registered (DIA-260902-eqgg entry, verification manual -> real verification, learnings outcome recorded)

**Decision chronology:** developer approved corrected V-A structural criteria (LOC advisory, binding = Gates A/B/C) before final wiring → ai-auditor REJECT 2026-09-02 (F1 ticket sync, F2 stall/meta-task, F3 unused factories, F4 gate script, F5 line count, F6 types.ts) → developer disposition **Option A** accepted → recovery from dangling blob `ec487dc3ced110824019c0766d4b25656515a793` (4236 lines, SHA df6497bc…) after cod-3 clobber incident (BATS fixture `restore_plugin` only after `assert_status`, so RED failure left fixture clobbering real plugin) → S11 shell re-verified and F1-F6 fixes applied via original cod-18 session (DIA-175 R5).

## Fix

**S11 evidence (2026-09-02, DIA-175: RED≠GREEN, fixes via original S8/S9 lanes) — updated post F3/F6/O1-O3:**
- shell: `wc -l .opencode/plugins/delegation-observer.ts` → **4093** (was 5048 HEAD, 4920 S8, 4686 S9, 4236 S11 recovered, 4104 after F3 stall-sweep wiring + F6 types.ts deletion, 4093 after O2 13-import pruning; advisory ~3,700 LOC, binding = structural gate A/B/C PASS per V-A correction 1).
- shell_composition: **composition/lifecycle only** — static imports (8 libs), path construction (`join(ctx.directory, ...)`), `globalThis` singleton ownership (`STALL_SWEEP_KEY`, `BOOT_EMITTED_KEY`, `ROUTING_WRITE_KEY`), hook/tool registration (`tool.execute.before/after`, `event`, `experimental.session.compacting`, `tool` log_decision/mint_capability/context_usage), cross-seam orchestration. Subsystem algorithms + persistence serialization live in `lib/*.ts`.
- per-hook contract (correction 1): **factory `async (ctx) =>`**, **`experimental.session.compacting` async**, **stall timer `setInterval(async () => { // sync body })`**, **formatter `spawnSync` sync**, **other hot hooks sync** (`tool.execute.before` `(input, output) =>`, `tool.execute.after` `(input, output) =>`, `event` `async (input) =>` contains `await runContextPolicy` but hot path is sync; `event` kept async for that await, other hot hooks sync). Verified via `grep -n "tool.execute"`.
- perf wording (correction 3): **no FS scans on generic hot path** — `tool.execute.before` only calls `scanTickets` when `input.tool === "task"` (lazy, via `createTicketGate` + `scanTickets` only for task dispatch); `grep -n "scanTickets"` shows only task-gated call. **Ticket scan lazy only for relevant task() dispatch** — verified.
- structural gate S10: **Gate A 8/8 PASS** (capability, ticket-gate, handoff, registry, stall-sweep, formatter, circuit-breaker, errors all `from "./lib/..."`), **Gate B 23/23 PASS** (no local `function/const/class` for canonical symbols), **Gate C 10/10 PASS** (no test imports removed aliases), `bash scripts/validate-plugin-structure.sh` **PASS**, wired into `make test-config`.
- parity **Global gates Q7 §1-6**: `make test-config` **0** (incl. `validate-plugin-loads.sh` Node+Bun Wy-compat **PASS**, `validate-observer-dedupe.sh` **PASS**, `validate-plugin-structure.sh` **PASS**), `scripts/__tests__/*` harness **PASS**, `bun test` lib suites **270/270** (7 libs: 20+62+23+33+31+63+36; S11 268 -> N1 correction 270), total plugin tests 435 (S8 evidence incorrectly said 302; corrected), `batch-d-infra.test.mjs` **PASS** (57/57), harness **3/3 scenarios PASS** + boot-only implicit (boot-only, empty-result-silent-failure, parallel-handoff-archive, slot-identity-no-clobber) — normalized `registry/messages/boot` traces exact on stable fields per Q7 §3, `plugin-load` Node+Bun **PASS**, restart smoke **PASS** (hooks `tool.execute.before/after`, `event`, `experimental.session.compacting` fire), formatter smoke isolated tmp fixture **PASS** (fail-soft, `runEditTimeFormatter` with `spawnSync` + `workspaceRoot`).
- perf smoke Q7 §5: **warm-up 100 + 500 samples** `tool.execute.before/after` no-op (`bash` tool, excl. formatter) on same runtime (bun), **p50=0.187ms, p95=0.268ms, p99=0.362ms, n=500, regression <5ms PASS** (after-minus-before p95 <5ms, no flaky CI assertion added). Recorded via `bun /tmp/perf-smoke.mjs`.
- formatter smoke Q7 §3: isolated `mkdtemp` workspace with `test.ts` `const   x=1`, `tool.execute.after` for `edit` → **PASS** (no throw, fail-soft, not tracked source).
- DIA-260902-eqgg S0 baseline traces at `openspec/changes/dia-260902-eqgg-delegation-observer-srp/baseline-traces/` (4 dirs, normalized per Q7 §3).

## Re-verify

**Re-verify 2026-09-02 (final gates, this session):**
- structural gate: `bash scripts/validate-plugin-structure.sh` PASS — Gate A 12/12, Gate B 25/25, Gate C 13/13
- `make test-config` exit 0 — 57 tests, 0 fail (incl. validate-plugin-loads Node+Bun Wy-compat, validate-observer-dedupe, validate-plugin-structure)
- `openspec validate dia-260902-eqgg-delegation-observer-srp` exit 0 — change valid
- lib suites: 270/270 PASS (7 libs: capability, ticket-gate, handoff, registry, stall-sweep, formatter, circuit-breaker)
- integration regressions: 12/12 PASS
- structural-gate Bats: 10/10 PASS
- harness parity: 3/3 PASS (boot-only, empty-result-silent-failure, parallel-handoff-archive, slot-identity-no-clobber)
- perf smoke: p50=0.188ms, p95=0.267ms, p99=0.319ms, n=500 — regression <5ms PASS
- shell: `wc -l .opencode/plugins/delegation-observer.ts` = 4093 (advisory ~3,700; binding = Gates A/B/C PASS)
- ai-auditor independent review APPROVE cycle 2/2 — F1-F6 + O1-O3 verified closed
- temporary ai-auditor model override ACTIVE (developer KEEP decision, uncommitted)
- implementation commit: recorded at closure

## Closure

Closure pending: implementation commit + final status flip after all gates green (this session). Docker gate not required for this commit (no container-dependent gates in the eqgg set; make test-config is host-side).
