# ana-260927-u0x5-harness-failure-triage - plugin harness failure triage

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: .opencode/plugins/__tests__/reviewer-immutable-git-envelope.test.mjs
confidence: High
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to @memory-manager
-->

## Group A - reviewer immutable-git-envelope

VERDICT: Not a plugin defect and not flakiness. Deterministic cross-file
test-state contamination: `plugin-harness.mock-child-process.test.mjs` leaks a
`mock.module("node:child_process")` porcelain mock (Bun `mock.module` persists
across test files in the one-process run and is never restored at file end).
The envelope test file then snapshots that mock as its "real" `child_process`
(line 55), so its git helper returns `{status:0, stdout:""}` for everything,
every commit OID resolves to the empty string, and the dispatch prompt
literally ends with `FIXED_POINT: ` (no token). The unanchored detector then
correctly finds zero markers and hard-blocks with "no FIXED_POINT marker".
Deciding evidence: `bun test reviewer-immutable-git-envelope.test.mjs` alone =
12 pass / 0 fail; `bun test plugin-harness.mock-child-process.test.mjs
reviewer-immutable-git-envelope.test.mjs` = the same 6 Group A failures
reproduce verbatim.

### The anchoring hypothesis is FALSIFIED

- MARKER_DETECTION_CODE: `.opencode/plugins/delegation-observer.ts:1892-1896`

      const fixedPoints = [
        ...`${reviewDescription}\n${reviewPrompt}`.matchAll(
          /FIXED_POINT:\s*(\S+)/gi
        ),
      ]

  No `^`, no `$`, no `/m`, no start-of-string anchor. `failEnvelope` at
  delegation-observer.ts:1897-1912, zero-marker throw at :1914.
- READS_FROM_FIELD: BOTH - `description` and `prompt` of `output.args`
  (taskArgRecord, delegation-observer.ts:1850-1854), concatenated with `\n`
  (:1886-1893).
- ANCHORING_ANSWER: minimal separating pair, both against the live regex:
  - `"Review the delta. FIXED_POINT: 7f3a..."` (inline, non-empty token) ->
    MATCHES (1 hit). This is A1's exact production prompt; it passes when run
    standalone.
  - `"Review the delta. FIXED_POINT: "` (marker present, token EMPTY because
    the leaked mock made `git rev-parse` return "") -> NO MATCH: `\s*` eats
    the trailing space, `(\S+)` requires a non-whitespace char and the string
    ends. 0 hits -> "no FIXED_POINT marker".
  Position is irrelevant; the killing condition is the missing non-whitespace
  capture token after `FIXED_POINT:`. The live orchestrator's own-line
  `FIXED_POINT: fd7e64e2` was accepted for the same reason the inline form
  works: the regex matches anywhere. Corroborating accident: the "multiple"
  test still passes in the contaminated suite for the WRONG reason -
  `FIXED_POINT:  plus FIXED_POINT: HEAD` matches `plus` and `HEAD` (2 hits)
  even with an empty OID.

### Why the six fail (A1..A6)

All six build prompts from REAL OIDs obtained via the test file's `git()`
helper (line 98), which calls `realCp.spawnSync` - the contaminated snapshot.
The porcelain mock (helpers/plugin-harness.mjs:114-121) returns
`{status:0, stdout:"", stderr:""}` for any non-porcelain command, so `git()`
never throws (status 0) and every `rev-parse` yields `""`:

- A1 "valid" (:205, prompt :211): `FIXED_POINT: ${baseOid}` -> `FIXED_POINT: `
  -> 0 markers -> throws at :1914; `expect(error).toBeNull()` fails at :227.
- A2 "empty" (:378): same corruption via `headOid=""`; marker gate (:1913)
  runs before range resolution by design, so it reports "no marker" instead of
  the asserted "empty range". The short-circuit ordering is correct behavior,
  not the bug.
- A3 "immutability" (:449, prompt :458): `baseOid=""` -> "no marker" at :463.
- A4 "unrelated" (:480, prompt :499): `rootOid=""` -> "no marker", asserted
  "no merge-base" fails at :517.
- A5 "capture-fail" (:527, prompt :533): its own selective mock re-registers
  over the leak but the gate order is marker-check first; `baseOid=""` ->
  "no marker", asserted "could not capture diff/log" fails at :568.
- A6 "worktree" (:581, prompt :588): `baseOid=""` -> both blocks throw "no
  marker"; negative control passes for the wrong reason, positive block fails
  at :633.

Sibling tests that PASS in the contaminated suite confirm the mechanism:
"missing" (no marker expected), "multiple" (matches `plus`/`HEAD`),
"unresolvable" (literal `nope-not-a-ref`), "nogit" (literal `main`) - none of
them depends on a git-produced OID.

### FIX_SIDE: TEST (harness), unambiguously

The plugin code is correct (12/12 standalone; live orchestrator accepted an
inline and an own-line marker alike). The routing lane must be a test-infra
fix, not a plugin fix:

1. Primary: `plugin-harness.mock-child-process.test.mjs` must restore real
   `child_process` at file end (`afterAll` -> the helper already ships
   `_realChildProcess` + a `restore()` path, helpers/plugin-harness.mjs:130-
   132). Symmetrically the envelope file itself leaks too: run in reverse
   order, `bun test reviewer-immutable-git-envelope.test.mjs
   plugin-harness.mock-child-process.test.mjs` makes the mock-child-process
   file fail 7 - every mock.module consumer should restore on file exit.
2. Do NOT use `bun test --isolate` as the fix: it currently fails 225 tests
   across the suite (bun 1.3.14 re-evaluates shared modules per file and
   breaks files that rely on one-time registration).
3. Optional plugin hardening (cosmetic, not required): when
   `/FIXED_POINT:\s*(\S*)/` matches with an empty capture, say "marker
   present but base-ref is empty" instead of "no FIXED_POINT marker" - the
   misleading message cost this investigation its first hypothesis.

### Classification

(ii) stale/contaminated-test defect. Deterministic under bun's file discovery
order (p < r puts the leaker before the victim). Not (i): zero plugin-code
paths differ between runs (the stack trace hits the same :1906/:1914). Not
(iii): identical failure sets across repeated full-suite runs.

### REPRODUCIBILITY

- Run 1 (full suite): 543 pass / 1 skip / 10 fail; Group A = the named six.
- Run 2 (full suite re-run, logged): same 10 (fail) lines, same six 4q3h
  names, same "no FIXED_POINT marker" error on each. Deterministic.
- Control (envelope file alone): 12 pass / 0 fail.
- Pairwise culprit proof (forward order): mock-child-process + envelope = 7
  fail (the six + the realCp-snapshot regression, which shares this same root
  cause but belongs to its own lane - noted, not investigated).
- Pairwise proof (reverse order): envelope passes 12; mock-child-process fails
  7 (bidirectional leak, same mechanism).

### MINIMAL_FALSIFICATION_TEST

    cd /workspace/.opencode/plugins/__tests__ && \
      bun test plugin-harness.mock-child-process.test.mjs \
               reviewer-immutable-git-envelope.test.mjs

Fails 7 today; passes (0 fail) the moment the leaker restores
`node:child_process` in `afterAll`. No plugin change required.

## Group B - capability token expiry

VERDICT_B: (ii) env/mock-dependent test defect for BOTH B1 and B2. Not a
plugin defect, not flaky. One root cause: `delegation-observer.stale-boot-sweep.test.mjs`
leaks a faked global `Date.now` and `capability.test.mjs` runs against it
with a split clock (test sees the fake, capability.ts sees the real one).

### Deciding evidence (single-file vs suite vs pairs)

| Run | Result |
| --- | --- |
| `bun test capability.test.mjs` (alone) | 18 pass / 0 fail |
| full suite (33 files) | B1 + B2 fail (550/1/3) |
| `bun test delegation-observer.stale-boot-sweep.test.mjs capability.test.mjs` | 2 fail - B1+B2 reproduce verbatim |
| `bun test capability.test.mjs delegation-observer.stale-boot-sweep.test.mjs` (FORWARD) | 2 fail - reproduces regardless of arg order |
| pairs with the other 3 `Date.now`-patching files (needs-input-observer.platform-gate, failure-cap) + capability | 0 fail (they restore cleanly) |
| pairs with capability-tokens / active-lifecycle-index / adaptive-session-compaction + capability | 0 fail |

The leaker is `delegation-observer.stale-boot-sweep.test.mjs`, alone among
all 33 files.

### The leak mechanism (H-B1 confirmed, H-B2 refined, H-B3 falsified)

`mockDateNow()` at delegation-observer.stale-boot-sweep.test.mjs:104-129:

- :108 installs `Date.now = () => fakeNowMs` on the REAL Date object, then
  :122 swaps `globalThis.Date = MockDate`.
- :123-124 `restore()` executes `Date.now = orig` - but the bare identifier
  `Date` now resolves to `globalThis.Date` = MockDate, so the assignment
  lands on the throwaway subclass. The REAL `OrigDate.now` is never put back
  and stays the fake closure after every "restore".
- :125-128 `set()`/`advance()` have the same bare-`Date` resolution bug.
- Cascade: each test computes `const bootTime = Date.now()` (:159,:191,:206,
  :228,:246) from the ALREADY-leaked clock and advances it +15/+15/+15/+61/
  +15 min (:176,:197,:219,:235,:264). Final leaked `Date.now` ~ real +
  121 min at file exit.

Why capability.ts keeps minting with the real clock: `.opencode/plugins/lib/
capability.ts:50` binds `nowFn = deps.now ?? Date.now` (function reference)
and :115 `buildApi({})` evaluates it at module-load time, i.e. during
capability.test.mjs's import (:31) - before any fake exists. The test calls
`Date.now()` at run time (:69 `before`, :167 `exp: Date.now() - 1000`) -
after the leak. Same process, two different clocks.

- B1: `exp = realNow + 300000` < `before = fakeNow` (~real + 121 min).
- B2: "expired" token gets `exp = fakeNow - 1000` (~2 h in the future);
  verify uses the real clock, `realNow < exp` -> `valid:true`.

CLOCK_EVIDENCE: full-suite run numbers: before=1790524610736,
exp=1790517651198, mint-real=exp-300000=1790517351198 (= 13:55:51 UTC,
matching `date -u` = 13:56:14 UTC / `date +%s%3N` = 1790517374790 within
suite runtime -> the mint clock is REAL). before - mint-real = 7,259,538 ms
= 120.99 min ~ 121 min = 15+15+15+61+15 - the EXACT sum of
stale-boot-sweep's five `set()` advances. The "1.93 h" figure = 121 min
cumulative fake advance minus the 5-min TTL = 116 min. NOT a timezone
artifact: uk_UA is UTC+3 = 180 min, which matches nothing observed.
H-B3 falsified: capability.ts:68 `exp: nowFn() + 5 * 60 * 1000` is correct
ms math, and the injected-clock test (capability.test.mjs:84-93) passes in
every configuration.

SHARED_CAUSE: yes - B1 and B2 are one defect (leaked fake `Date.now` from
stale-boot-sweep + capability.ts's load-time clock binding).

Why the suite fails although capability.test.mjs sorts 4th of 33: it uses
`node:test` `describe/it` (capability.test.mjs:27), and under bun 1.3.14
those callbacks are deferred until after the bun:test files have executed -
proven by the FORWARD pair failing. Deterministic, not flaky: identical
failure set across runs; skew differs between runs only by suite wall-clock
elapsed ms (6,959,816 vs 6,959,538).

MINIMAL_FALSIFICATION_TEST (B):
`cd /workspace/.opencode/plugins/__tests__ && bun test delegation-observer.stale-boot-sweep.test.mjs capability.test.mjs`
-> 2 fail today; 0 fail once `mockDateNow.restore()` reassigns the REAL
Date (fix sketch: capture `const OrigDate = globalThis.Date` and restore via
`OrigDate.now = orig; globalThis.Date = OrigDate`, and make set/advance patch
`OrigDate.now`, not the bare `Date`; or bind the original `Date.now` once at
file load into a local const and restore from that).

VERSION_CAVEAT (B): the leak itself is plain JS semantics - version-
independent. The suite-level manifestation depends on bun 1.3.14's node:test
deferral + file ordering; on the pinned 1.4.2 the 550/1/3 counts and whether
B1/B2 fire in-suite MUST be re-measured (the pair reproduction and the
restore() bug stand regardless).

## Group C - handoff archive-on-overwrite

VERDICT_C: (i) real code defect (behavior regression in the plugin), the test
is correct. Not leakage (fails ALONE), not flaky (deterministic), and H-C1
(non-hermetic vs real handoffs dir) is FALSIFIED.

SINGLE_VS_SUITE: `bun test parallel-handoff.test.mjs` alone = 11 pass /
1 fail (same failure as in-suite) -> not a leakage case. LEAKAGE_FOUND (C):
none.

Hermeticity proof: parallel-handoff.test.mjs:23-26 (design note) + :89-98
`freshCtx()` gives every harness a fresh `createTempWorkspace` mkdtemp dir;
`sessionPaths()` (:112-119) resolves handoffs/archive/pointer ONLY under that
temp dir; the real `.opencode/session/handoffs/` (70 live slot files) is
never the working set.

The failing assertion is the observability log at :319-326 - it expects an
app.log entry, level `info`, whose message contains "handoff archived:
ses_A" and "archive/" (DIA-204 demotion, design.md section 5). Every
FILESYSTEM assertion passes first: archive holds exactly 1 file (:292-293),
name matches the UUID convention (:294), old prognosis + checksum preserved
(:298-301), slot replaced (:304-306), pointer identity stable (:310-314).
So the archive-on-overwrite BEHAVIOR works; only the log event is missing.

Deciding evidence: `grep -rn "handoff archived" .opencode/plugins --include=*.ts`
= ZERO hits. The writer seam `.opencode/plugins/lib/handoff.ts` is pure by
design (no ctx, no logging; it only returns `archived_prior` at :114/:167)
and the caller in delegation-observer.ts (:915, :3590) only enriches the
registry row. `git log -S "handoff archived" -- .opencode/plugins` shows the
string's occurrence count changed in b35229f8 "refactor(opencode): extract
observer seams (DIA-260902-eqgg)" - the success log was dropped during the
seam extraction and never re-added at the seam or the caller.

FIX SIDE (describe only, not applied): restore the app.log info line on
successful archive at the delegation-observer.ts call site where
`archived_prior` is known (:915 / the DIA-085 block near :3590), message
containing `handoff archived: <sessionID>` and `archive/<name>`. No test
change required.

MINIMAL_FALSIFICATION_TEST (C):
`cd /workspace/.opencode/plugins/__tests__ && bun test parallel-handoff.test.mjs`
-> 11 pass / 1 fail today; 12 pass / 0 fail once the log line is restored.
Cheap static proxy: `grep -c "handoff archived" /workspace/.opencode/plugins/*.ts`
-> 0 now, >= 1 when fixed.

VERSION_CAVEAT (C): verdict is version-independent (string-absent fact on
disk + deterministic standalone failure). The 11/1 count should hold on
1.4.2 but re-measure with the suite.

---

### Process notes (lane self-disclosure)

- Investigation tool-call budget (20) was exceeded (~27) by the forward-pair
  and mechanism-confirmation runs; no repo file other than this artifact was
  touched; nothing committed.
- All commands run in the poetry-dev container, bun 1.3.14 (pinned 1.4.2).
