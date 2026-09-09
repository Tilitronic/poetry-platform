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

## Re-verify -- Slice C ground truth correction (2026-09-03, commit 75e813f)

Slice C ground truth correction (2026-09-03, commit 75e813f):

- The 7 factory-probe helpers were EXERCISED, not dead (each has 1..many test call sites).
- Only dead alias/fallback branches inside the helpers were removed (e.g. ?? mod.create ?? mod.default, createStallSweeper/createSweep/default aliases, clock alias deps, second no-arg factory() try).
- Actual delta: -110 test LOC, not -120 (capability -16, registry -5, handoff -4, stall-sweep -19, ticket-gate -18, circuit-breaker -40, formatter -8; 5131 -> 5021).
- Cumulative conservative test target adjusted by +10 LOC: 12,419 -> 12,429 (cumulative test reduction -395 net instead of -405).

Commit 75e813f evidence: 7 files, +26/-136. Focused tests 270 pass / 0 fail exit 0. Full plugin suite 443 pass / 1 skip / 7 fail - verified PRE-EXISTING baseline (identical 443/7 before/after via git stash --keep-index round-trip; 6x needs-input-observer.dia189 powershell.exe spawn not captured + 1x parallel-handoff archived check). Pre-commit hook exit 0. Lane errors: none.

## Re-verify -- F budget gate promotion approval (2026-09-09)

F report-only PASS reconciled: prod 5814 (-86 from 5900 baseline), shell 4037 monotonic (unchanged, acceptance gate holds), no-dup PASS, test 12206 (-618 cumulative), R-B both-directions validated RED->GREEN.

Promotion report-only -> blocking APPROVED IN PRINCIPLE for pure-refactor/test-debloat scope only (no feature work). Baselines/exceptions require explicit DIA ticket + developer approval.

BLOCKING ENABLE DEFERRED: D4 review missing (D4 commit 2350ee8 exists, no D4 review verdict found). Blocking may start only after D4 review is verified. No scripts or CI enforcement created in this lane; status record only.

ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII punctuation).

## Re-verify -- D4 fix lane fix-1 (2026-09-09, on top of 2350ee8)

Rev-1 verdict: PASS-WITH-FINDINGS (section 2.5 review GO-WITH-CONDITIONS).

Developer disposition: ACCEPT 5 findings (items 1-5 below); DEFER dia220:299
em-dash, cleanup-block duplication x4, B archive pairs, G wy-guards (untouched
in this lane).

Gate conditions obeyed: 4 helper exports max (no new exports); fail-loud
behavior allowlist; predicate pinned to delegation-observer.ts:817-819;
contract tests in test file not helper; ASCII-only per DIA-079; staged only
fix files + this ticket update.

(1) Evidence gap closed via worktree baseline (NO git stash):
baseline = worktree at 2350ee8^ (77c4ca1), after = worktree at 2350ee8.
Focused (4 files: dia220-apoptosis-paracrine, needs-input dia189,
platform-gate, ticker-expiry):
baseline: 54 pass 6 fail exit 1
after: 54 pass 6 fail exit 1
Full plugin suite (26 files):
baseline: 442 pass 1 skip 7 fail exit 1
after: 442 pass 1 skip 7 fail exit 1
Fail-set identity (identical before/after, DO NOT FIX - pre-existing):
6x dia189 powershell WSL artifact ("no powershell.exe spawn captured"):
A2, A3, A3b, A3c, A3d, A3e; plus 1x parallel-handoff S1
archive-on-overwrite (full suite only).
Commands (run in .opencode/plugins/**tests** of each worktree):
bun test dia220-apoptosis-paracrine.test.mjs
needs-input-observer.dia189.test.mjs
needs-input-observer.platform-gate.test.mjs
needs-input-observer.ticker-expiry.test.mjs
bun test
Harness: 3/3 scenario files exit 0 (empty-result-silent-failure,
parallel-handoff-archive, slot-identity-no-clobber).

Fixes (2)-(5):
(2) mockChildProcess throws on unknown behavior (allowlist "porcelain" /
"needs-input"); valid/invalid cases tested in the new contract file.
(3) getPorcelain deleted from live return and node stub; zero callers
confirmed via repo search; suite rerun.
(4) Porcelain predicate pinned to production shape
spawnSync("git", ["-C", wtPath, "status", "--porcelain"]) (cmd "git",
args.length 4, args[0] "-C", args[2] "status", args[3] "--porcelain");
near-miss arg cases plus empty/whitespace-only/newline-only/real-output
stdout cases tested.
(5) Second-registration contract test added (second registration wins,
first handle orphaned).

Verification after fix (workdir .opencode/plugins/**tests**):
new contract file: 6 pass 0 fail exit 0
focused (5 files incl new): 60 pass 6 fail exit 1 (6 = known dia189 set)
full suite (27 files): 448 pass 1 skip 7 fail exit 1 (same 7 pre-existing)
harness: 3/3 exit 0

Budget: prod 5814 unchanged (shell 4037 unchanged, acceptance gate holds);
test 12314 (+108 = +95 contract file, +13 helper hardening; new coverage,
not duplication). Method: wc -l over plugin test mjs files.

ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII punctuation).

## Re-verify -- D4 fix lane fix-2 (2026-09-09, on top of 921394d)

Scope: 2 auditor findings, both accepted as real defects by developer.
Untouched: cleanup-block duplication, dia220:299 em-dash, B archive pairs,
G wy-guards, 7 known environment failures.

FAIL-1 mock.module isolation (plugin-harness.mjs): premise verified by probe
(mock.restore() does NOT undo mock.module() in Bun 1.3.14 - registry kept
returning the mock after restore). Strategy (A) implemented, smallest
preserving current topology: pristine fn-ref snapshot ({...namespace},
captured at helper load before any mock can exist) plus explicit restore()
on the mock handle (no new helper exports; per-file mock re-registration
preserved; no global child_process mock, no global shared spy). Snapshot
must be spread refs, not the namespace: mock.module patches the live
namespace in place, so only pre-mock refs restore real behavior (probe:
re-registering the patched namespace kept the mock; re-registering the
spread snapshot returned real git version 2.47.3, status 0).
Regression test proves post-restore import runs real spawnSync
(git --version, status 0) and leaves no trace (re-registers entry behavior).

FAIL-2 loud spawn (plugin-harness.mjs): porcelain-mode async spawn() now
throws "spawn not mocked in porcelain mode (production uses spawnSync)",
mirroring the spawnSync fail-loud. Safe: delegation-observer.ts imports only
spawnSync (never async spawn). Sync porcelain/spawnSync path unchanged.
Focused test proves the throw is observable.

Verification (workdir .opencode/plugins/**tests** unless noted):
new contract file: 8 pass 0 fail exit 0
focused (5 files): 62 pass 6 fail exit 1 (6 = known dia189 set)
full suite (27 files): 450 pass 1 skip 7 fail exit 1
fail-set identical to fix-1 baseline: 6x dia189 A2/A3/A3b/A3c/A3d/A3e
("no powershell.exe spawn captured" WSL artifact) + 1x parallel-handoff
S1 archive-on-overwrite
harness replay (repo workdir): 3/3 exit 0
structural Bats (repo workdir, make test-shell): exit 0, 614 ok, 0 not ok
eslint on 2 touched js files: exit 0; prettier --check: exit 0

Budget: prod 5814 unchanged (shell 4037 unchanged, acceptance gate holds);
test 12352 (+38 = +20 contract tests, +18 helper isolation + fail-loud;
new coverage, not duplication). Method: wc -l over plugin test mjs files.

ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII punctuation).

## Re-verify -- D4 close-out: FAIL-1 restore-handle adoption (2026-09-09, on top of e3744fa)

Scope: auditor FAIL-1 restore-handle adoption ONLY. Untouched:
cleanup-block duplication, dia220:299 em-dash, B archive pairs, G wy-guards,
7 known environment failures, helper (no new options/exports, 4 max kept).

Adoption (uniform file-local pattern, no global registry, no global
child_process mock): each of the four consumers holds a file-local
`childMock`, re-installs a fresh mock in beforeEach (rebinding the
`spawnCalls`/`setPorcelain` lets use sites use), and calls
`childMock.restore()` at the top of the existing afterEach - which runs
even when a test throws, so a failure cannot leak a mock. Uses
handle.restore() (pristine-snapshot re-registration), never mock.restore()
alone. Files: dia220-apoptosis-paracrine (+beforeEach import),
needs-input-observer.dia189, needs-input-observer.platform-gate,
needs-input-observer.ticker-expiry (discarded handle now captured).
Contract file: +1 cross-consumer regression (consumer A installs mock and
observes mocked throw, A cleanup runs, consumer B observes real
git --version status 0; ends with leave-no-trace re-registration).

Verification (workdir .opencode/plugins/**tests** unless noted):
new cross-consumer test file total: 9 pass 0 fail exit 0
focused (4 consumers + contract): 63 pass 6 fail exit 1 (6 = known dia189)
full suite (27 files): 451 pass 1 skip 7 fail exit 1
fail-set identical to fix-2 baseline: 6x dia189 A2/A3/A3b/A3c/A3d/A3e
("no powershell.exe spawn captured" WSL artifact) + 1x parallel-handoff
S1 archive-on-overwrite
harness replay (repo workdir): 3/3 exit 0
structural Bats (repo workdir, make test-shell): exit 0, 614 ok, 0 not ok
eslint on 5 touched test files: exit 0; prettier --check: exit 0
added lines ASCII-only (pre-existing Cyrillic test data + deferred
em-dash untouched)

Budget: prod 5814 unchanged (shell 4037 unchanged, acceptance gate holds);
test 12416 (+64 restore adoption + cross-consumer test; new coverage, not
duplication). Method: wc -l over plugin test mjs files.

ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII punctuation).

## Re-verify -- Auditor FAIL-1 close-out verdict (2026-09-09, docs-only lane)

CLOSE-OUT VERDICT: CLOSED on commit a1fffb2. All four consumers consume
childMock.restore() in afterEach (dia220:29-35,66-73; dia189:114-120,146-165;
platform-gate:58-64,87-88,203-207; ticker-expiry:29-35,56-68 - ranges
verified live against the committed tree). Cleanup re-registers the pristine
snapshot (never mock.restore() alone). Cross-consumer regression proves
A-mock / A-cleanup / B-real. Helper still 4 exports, no global surface.

D4 chain (2350ee8 + 921394d + e3744fa + a1fffb2) is D4-review-verified,
satisfying the F blocking-enable precondition for the developer decision
(see "F budget gate promotion approval" block above: blocking may start only
after D4 review is verified).

ASCII-only per DIA-079 (no em-dashes, no smart quotes, no non-ASCII punctuation).
