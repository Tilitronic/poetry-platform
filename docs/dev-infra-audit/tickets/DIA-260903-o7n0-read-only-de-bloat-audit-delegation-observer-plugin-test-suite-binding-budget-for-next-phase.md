# DIA-260903-o7n0 - read-only de-bloat audit: delegation-observer plugin test suite + binding budget for next phase

---

id: DIA-260903-o7n0
title: "read-only de-bloat audit: delegation-observer plugin test suite + binding budget for next phase"
area: opencode-config
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-03
source: inventory
date: 2026-09-03
created: 2026-09-03
updated: 2026-09-03

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
evidence:

- knowledge/ana-260903-qh9y-plugin-test-debloat-audit/ana-260903-qh9y-plugin-test-debloat-audit-report.md

---

## Description

Read-only de-bloat audit of the delegation-observer plugin test suite (~5.4k tests): (1) find duplicated fake-FS, timer, registry, and import scaffolds across tests; (2) extract only genuinely shared test helpers; (3) remove RED-scaffold compatibility leftovers and excessive fallback call-shapes; (4) deletion test on each of the 7 lib modules - hide complexity vs pass-through interface; (5) evaluate whether both raw and normalized copies of all baseline traces are needed; (6) separate generated/ledger churn from code commits; (7) set a binding budget for the next phase.

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Read-only de-bloat audit (ana-260903-qh9y-plugin-test-debloat-audit) - PASS, no files modified.

1. DUPLICATED SCAFFOLDS: 5 patterns hit 14-21 files (60-72% of 29-file suite), ~515 LOC duplicated (opencode mock 16f/150loc, mkdtemp 21f/60loc, harness 14f/52loc, bun:test 19f, tmpdir 21f, 7 RED factory probes 120loc, child_process mock 4f/54loc).
2. SHARED HELPERS: 3 scaffolds justify one helper file (.opencode/plugins/**tests**/helpers/plugin-harness.ts ~100 LOC replacing ~385 LOC); child_process mock consolidatable; RED factory probes are deletes-not-extracts; readRegistry/fakeTimer stay local.
3. RED-SCAFFOLD LEFTOVERS: ~86 LOC dead compat surface (normalizeGateArgs 44loc - 0 shell users, readdirSync probe 14loc, registry ClockDeps aliases 14loc, handoff overload guard 6loc, circuit-breaker clock aliases 8loc) + ~30 LOC Wy .server/PluginInput guards.
4. DELETION TEST: 0 PASS-THROUGH of 7 lib modules - 5 HIDES-COMPLEXITY (registry 373loc, ticket-gate 366loc, stall-sweep 284loc, formatter 258loc, handoff 206loc), 2 MIXED-keep (capability trust-boundary, circuit-breaker state machine), errors 97loc consolidation module.
5. BASELINE TRACES: raw + normalized both load-bearing (audit truth vs byte-equal gate); only 2 identical archive-listing pairs redundant.
6. GENERATED/LEDGER CHURN: 9 runtime artifacts correctly gitignored under .opencode/session/; ANOMALY: .opencode/session/partial-results/ai--2.json tracked at HEAD (needs git rm --cached); tickets README co-mingled with unrelated config edit.
7. BINDING BUDGET (decision): pure-refactor production net LOC <= 0 unless growth separately agreed (baseline 5900 = 4037 shell + 1863 lib); forbid test scaffolding duplication (515 LOC baseline); shell LOC measured as real acceptance gate (4037 baseline).
   Artifact: knowledge/ana-260903-qh9y-plugin-test-debloat-audit/ana-260903-qh9y-plugin-test-debloat-audit-report.md

## Re-verify

## Re-verify -- Slice A disposition + Section 2.5 gate corrections (2026-09-03)

Developer disposition (2026-09-03, fast-path approved pure-refactor):

A untrack-runtime-artifact: ACCEPT with amendment - git rm --cached only, no .gitignore change.
B archive-listing-pairs: DEFER - zero savings; identical content does not prove filenames unneeded by harness.
C red-probes: ACCEPT - delete dead scaffolding, do not centralize.
D shared-helper: ACCEPT, split D1-D4 (createTempWorkspace, mockOpencodePlugin, createHarness, mockChildProcess), one pattern per commit, .mjs not .ts, 4 exports max not target.
E production-leftovers: ACCEPT - -86 LOC, requires production caller check + tests + ai-auditor.
F binding-budget: ACCEPT with amendment - report-only first, blocking after false-positive check.
G wy-guards: DEFER - until legacy loader actually removed.

Section 2.5 gate corrections (approved with adjustments):

C1: .mjs rationale corrected - NOT strip-types (Bun transpiles TS natively; plugin .mjs tests already import .ts). True reason: repo-wide node-runnable test convention + surface consistency.
C2: helper file imports ONLY mock from bun:test, never test/expect (harness-scenario files run under bun run).
C3: mockOpencodePlugin() idempotent and callable multiple times per file.
C4: createTempWorkspace keeps one module-level temp-dir registry + exactly one process.on("exit") handler as FAIL-SAFE ONLY; returns explicit cleanup handle or paired cleanupTempWorkspace(); tests clean up in afterEach/finally; successful explicit cleanup removes path from registry; exit handler is NOT the primary cleanup lifecycle.
R-C: no committed log-on-hit instrumentation, no new registry/message event for normalizeGateArgs; verify callers via static search + focused characterization tests first; temporary UNCOMMITTED instrumentation allowed only if dynamic usage uncertain, removed before commit; delete normalizeGateArgs only after full plugin suite + runtime smoke show zero dependency.
R-A/R-B/R-D/R-E accepted (per-file mock re-registration; no global child_process mock; budget gate validated both directions; // keep: Wy loader contract annotation after E; both Bun + harness gates after each D migration).

Slice A execution (2026-09-03):

- Ran: git rm --cached .opencode/session/partial-results/ai--2.json (kept working-tree copy).
- No .gitignore change: .opencode/session/ already ignored at .gitignore line 82.
- Verified: git ls-files returns empty; git check-ignore confirms ignore rule.
- Commit staged ONLY the removal + this ticket update; other working-tree changes left unstaged.

ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII punctuation).
