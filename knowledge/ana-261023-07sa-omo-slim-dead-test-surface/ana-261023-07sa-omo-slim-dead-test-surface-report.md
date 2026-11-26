# ana-261023-07sa: Is the OMO test surface dead weight after the vendored-tree removal?

<!-- ANALYZER-OUTPUT-CONTRACT
schema-version: 1.0
agent: analyzer
claim-type: finding
evidence-source: commit 4f233a0e (removal) and HEAD 244847ca (git ls-files + measured suites)
confidence: Medium
shelf-registration: memory-shelf.yaml (shelf.analyses), delegated to memory-manager
-->

Campaign ticket: DIA-261023-60ol. Analysis date: 2026-10-23.
Fixed point: HEAD `244847ca`, removal commits `4f233a0e`, `d8c4ea0b`,
`48015b99`, `f18f3d19`, `f5ee368e`; baseline for "before" numbers is
`4f233a0e^`.
Method: MECE inventory of the tracked test surface, followed by a
before/after delta over the removal commit, then a three-way disposal test
(subject-deleted / vacuous-absence / alive-but-vestigial) applied per file.
Every number below is reproducible with the command shown next to it.
This is a FIRST PASS; see section 7 for what could overturn it.

Rule used for "test file": a git-tracked file matching `.test.ts`,
`.test.tsx`, `.test.mjs`, `.spec.*`, `test_*.py`, `*_test.py`, or `.bats`.
Untracked vendored runners (`scripts/__tests__/vendor/bats-core/test/*`) and
`.venv` site-packages are excluded on purpose; they are not repo tests.

---

## 1. Findings (quantified)

### 1.1 Headline

The premise is inverted. The tests that exercised the vendored tree are not
present-and-dead; they were deleted in the same commit as their subject.
`4f233a0e` removed 81 test files (84 test-related paths, counting
`test-helpers.ts`, `test-setup.ts`, and one test SKILL) together with the
`make test-omo` target and `scripts/test-omo.sh`. The tracked dead weight is
therefore **0 files and 0 cases**. What remains is **10 files / 78 cases** that
touch the OMO layer, and every one of them asserts against a *surviving*
artifact: the npm pin, `.opencode/oh-my-opencode-slim.jsonc`, the prompt
override directory, or the preset launch path.

The only real dead mass is **off-tree**: 15 orphaned worktree directories hold
**1,186 stale copies of the deleted suite** (360 MB of OMO-tree copies, 506 MB
of worktrees total). No gate traverses them. That is the removal target that
`4f233a0e` did not reach.

### 1.2 Current tracked test surface

```
git ls-files | grep -E '\.(test|spec)\.(ts|tsx|js|mjs|cjs)$|(^|/)test_[^/]*\.py$|(_test|_tests)\.py$|\.bats$' | wc -l
# 110
```

| Area | Files | Runner | Cases | How the case count was obtained |
| --- | ---: | --- | ---: | --- |
| `scripts/__tests__` | 62 (59 `.bats`, 3 `.mjs`) | bats 1.14.0 + node:test | 834 (727 bats + 107 node) | `@test` count; node:test reporter totals (64+38+5) |
| `.opencode/plugins/__tests__` | 34 | bun test | 573 | runner output (`572 pass, 1 skip, 34 files`) |
| `packages/*` + `apps/*` | 6 (all `.ts`) | vitest via turbo | 132 | runner output (104 + 24 + 2 + 2) |
| Python (8 files: apps, packages, `.opencode/scripts`) | 8 | pytest | 64 | `def test_` count per file (36 + 18 + 4 + 2 + 1 + 1 + 1 + 1); PROVISIONAL |
| **Total** | **110** | | **1,603** | |

Measured wall-clock, this machine (`poetry-dev`, node 24.18, bun 1.3.x):

| Gate | Command | Result | Elapsed |
| --- | --- | --- | ---: |
| Shell suite | `bash scripts/__tests__/bats-wrapper.sh` | 727 ok, 0 not ok | 91.9 s |
| Plugin suite | `cd .opencode/plugins/__tests__ && bun test` | 573 cases | 3.5 s |
| Config gate | `make test-config` | exit 0 | 8.4 s |
| Product tests | `pnpm test` | 132 cases, FULL TURBO cache hit | 0.07 s |
| Python + non-cached vitest | not runnable here (no pytest in the host interpreter) | UNKNOWN | UNKNOWN |

### 1.3 Before the removal (what the deleted suite actually was)

```
git ls-tree -r --name-only 4f233a0e^ | grep -E '\.(test|spec)\.(ts|tsx|js|mjs|cjs)$|(^|/)test_[^/]*\.py$|(_test|_tests)\.py$|\.bats$' | wc -l
# 193   (110 today)
git show --name-status 4f233a0e | awk '$1=="D" && $2 ~ /oh-my-opencode-slim\/.*test/' | wc -l
# 81 test files under the vendored tree
```

| Metric | Value | Source |
| --- | ---: | --- |
| Tracked test files before removal | 193 | `git ls-tree 4f233a0e^` |
| Of those, in the vendored OMO tree | 81 | same |
| Test cases in those 81 files (grep) | 1,371 | `test(`/`it(`/`@test`/`def test_` over each blob |
| Cases reported by the retired gate | 1,366 pass / 1 fail (2026-08-27), 1,409 pass (later ADR) | DIA-260827-6wvm, `.opencode/memory/adr.md` |
| Gate wrapper | `scripts/test-omo.sh` (fail-open: `if [ ! -d "$OMO/src" ]; then exit 0`) | deleted in `4f233a0e` |
| Gate cost | 0:02-0:05 | `.opencode/learnings/DETAILED-BOTTLENECK-EXPLANATIONS.md:881` |

The grep count and the reported gate count differ by 3-4 percent because bun
expands table-driven cases at runtime. The order of magnitude is stable:
about **1.4k cases in 81 files**, all removed.

### 1.4 The 78 surviving OMO-touching cases

Attribution rule: a case touches the OMO layer if its assertion reads or
exercises an OMO artifact (npm pin string, `oh-my-opencode-slim.jsonc`,
`.opencode/oh-my-opencode-slim/` override files, `OH_MY_OPENCODE_SLIM_PRESET`,
or `scripts/presets.py`). Attribution was done by reading each file; it is
the one subjective number in this report, so it is marked PROVISIONAL.

| File | OMO cases / total | What it actually guards |
| --- | ---: | --- |
| `scripts/__tests__/check-omo-version-sync.bats` | 7 / 7 | Pin parity across `opencode.jsonc`, `tui.json`, `Dockerfile.dev`; all five override prompt files present and non-empty; stray root `.md` rejected; knowledge files present |
| `scripts/__tests__/validate-agent-names.bats` | 10 / 10 | Four-source agent-name lockstep, with `oh-my-opencode-slim.jsonc` as source S3 (synthetic fixture, not the real file) |
| `scripts/__tests__/check-orchestrator-prompt-drift.bats` | 16 / 16 | Nine required markers still present in each audited preset orchestrator prompt |
| `scripts/__tests__/preset-single-path.bats` | 6 / 6 | One launch path: `make presets`, `make opencode PRESET=`, deprecated `make preset` stub, no stale bridge export |
| `scripts/__tests__/workspace-preset-selection.bats` | 10 / 10 | `scripts/presets.py` registry reader: exact inventory, exact-match only, fail-closed parsing |
| `.opencode/plugins/__tests__/preset-model-guard.dia260918-t5.test.mjs` | 3 / 3 | Guard reads preset intent from the live `oh-my-opencode-slim.jsonc` |
| `.opencode/plugins/__tests__/preset-model-guard.dia260918-t1.test.mjs` | 3 / 3 | Guard reacts to `OH_MY_OPENCODE_SLIM_PRESET` env intent |
| `scripts/__tests__/batch-d-infra.test.mjs` | 18 / 64 | Override-file prose contracts (5 x `coder_append.md`, 11 x `orchestrator_append.md`, 2 x preset prompt clauses) |
| `.opencode/plugins/__tests__/registry.test.mjs` | 4 / 77 | `captureConfigLoadSignal` records the `oh-my-opencode-slim.jsonc` mtime (or null) before I/O |
| `scripts/__tests__/routing-order-gate.test.mjs` | 1 / 38 | One fixture row: an `.opencode/oh-my-opencode-slim` path is classified as config work |
| **Total** | **78 / 1,603 (4.9 pct)** | **10 files** |

A false positive worth recording: `check-compose-config.bats` matched an OMO
grep only because of the string `debian:13-slim`. It does not touch the OMO
layer. Grep-based counting over-reports here; read the file.

### 1.5 Where the dead mass actually is

```
                 tracked repo             off-tree residue
                 ------------             ----------------
 110 test files   dead-subject: 0          15 orphaned worktrees
 1,603 cases      (already removed)        2,102 test files
                                             of which 1,186 are
                                             the deleted OMO suite
                                             (360 MB of OMO copies,
                                              506 MB total)
```

Reproduce:

```
git worktree list          # prints ONLY /workspace -> the 15 dirs are orphaned
ls -d .worktrees/*/ | wc -l                        # 15
find .worktrees -path '*oh-my-opencode-slim/src*' -name '*.test.ts' | wc -l   # 1186
cat .worktrees/feature-dia132-docs/.git            # points at a missing admin dir
```

Each `.worktrees/*/.git` is a 54-byte file pointing at
`.git/worktrees/<name>`, and `.git/worktrees/` no longer exists. Git does not
see them as worktrees; they are plain orphaned directories, gitignored via
`.gitignore:60`. `scripts/worktrees.sh cleanup` (target `make worktree-gc`)
already has an orphan sweep for exactly this shape.

---

## 2. The three kinds of dead

The distinction matters because each kind has a different remedy. Applied to
this repo:

**Kind 1 - subject-deleted.** The artifact under test no longer exists, so the
assertion cannot fail for the reason it was written. Remedy: delete.
Count in tracked tree: **0 files, 0 cases**. The 81-file suite was deleted in
`4f233a0e`, not left behind. Off-tree copies: **1,186 files** in the 15
orphaned worktrees. Remedy for those: `make worktree-gc`, not a test edit.

**Kind 2 - vacuous-absence.** The test asserts that something is absent, and
after the subject is gone nothing can reintroduce it, so it passes forever.
Remedy: delete, because a green line that can never go red is a lie about
coverage. Count in tracked tree: **0 cases** for the OMO subject. This is not
an accident: `4f233a0e` converted the surviving absence-style assertions into
positive contracts. Example: `check-omo-version-sync.bats` does not assert
"the src tree is gone", it asserts "these five override files are present and
non-empty and a near-miss filename is rejected" - which fails on a real edit.
The one case that comes close is a real guard, not a vacuous one: `preset-
single-path.bats:55` asserts the Makefile does not reference the dropped
bridge, and that fails if someone re-adds it.
The place where kind 2 usually hides after a mass removal is a
"must-not-exist" check for the deleted path. Grep confirms none exists:
`git grep -n 'oh-my-opencode-slim/src' -- '*test*' '*bats'` returns nothing.

**Kind 3 - alive-but-vestigial.** The assertion is true and can fail, but its
subject is a tombstone nobody uses. Remedy: keep only if it prevents
resurrection; otherwise delete. Count: **1 whole case plus 2 embedded
assertions**:
- `preset-single-path.bats:48` "make preset stub exits 2" - the command is a
  deliberate tombstone (Makefile prints a deprecation and exits 2). The test
  exists only so the tombstone cannot rot into a working path again.
- `preset-single-path.bats:28` and `workspace-preset-selection.bats:17` embed
  "removed presets (`free`, `promo-union-alpha`) are rejected as unknown".
  Same rationale, embedded inside inventory tests rather than standing alone.
- Adjacent artifacts of the same kind, not test cases: the file name
  `workspace-preset-selection.bats` derives from the deleted
  `src/config/workspace-preset.ts`; the subject (`scripts/presets.py`) is live.

These three are cheap (sub-second) and defensible. They are not the problem.

---

## 3. Cost of leaving them

**Runtime.** Measured, not guessed. The OMO-touching shell cases are 49 of
727 and cost **2.9 s** standalone (7 cases 0.27 s + 10 cases 0.84 s + 16 cases
0.90 s + 6 cases 0.36 s + 10 cases 0.54 s), i.e. **3.2 pct of the 91.9 s
shell suite**. `batch-d-infra.test.mjs` is 100 ms of the 8.4 s `test-config`
gate (1.2 pct). The registry and preset-guard cases run inside the 3.5 s bun
suite and were not isolated. Total attributable cost: **about 3 s of about
104 s of gate time (about 3 pct)**. Python and non-cached vitest timings:
UNKNOWN.

**The deleted suite's runtime is irrelevant now** - it was cheap when it
existed (0:02-0:05 per the bottleneck analysis). Its cost was maintenance and
false confidence, not seconds.

**Maintenance noise.** 31 stale references to the retired gate:
`.opencode/learnings` 10 lines, `.opencode/memory` 4 (including `adr.md`
describing `test-omo` as a live ladder step), `memory-shelf.yaml` 1,
`docs/dev-infra-audit/tickets` 16. Two stale comments in live scripts:
`bats-wrapper.sh:17` says "240 tests ... ~25 s floor" (actual 727 / 91.9 s) and
`verify-pre-push.sh:153` says "100+ tests" (actual 727). Neither changes
behaviour; both mislead a reader estimating cost.

**False confidence.** The sharpest case: DIA-260827-6wvm is CLOSED, and its
re-verify evidence reads "embedded OMO bun suite: 1367 pass" plus
"make test-omo: exit 0". Its fix was an edit inside
`src/agents/index.ts` - a file that no longer exists in-tree. A reader
following that ticket believes a displayed-alias regression is guarded. It is
not, in this repo; whether upstream 2.2.19 carries the fix is unknown to this
lane (see Q5). The retired gate's own fail-open wrapper compounded this: it
exited 0 whenever `src/` was missing, so a partial deletion would have looked
green.

**Reader confusion.** The same 31 lines, plus deleted-path references in
learnings and design docs (`docs/design/95fv-return-channel-mitigation-design.md`,
several `external-patterns/*` files). These are historically honest artifacts;
the cheapest fix is a one-line "retired at 4f233a0e" note where the reference
is normative, not a rewrite.

---

## 4. Options table

Effort scale: XS = minutes, S = one small diff, M = a few files plus review.

| Variant | What it does | Concrete files touched | Effort | Buys | Risk left |
| --- | --- | --- | --- | --- | --- |
| **A. Delete outright** | Remove the 78 OMO-touching cases and their wiring | `check-omo-version-sync.bats`, `check-orchestrator-prompt-drift.bats`, `preset-single-path.bats`, `workspace-preset-selection.bats`, `preset-model-guard.dia260918-t{1,5}.test.mjs`, the OMO halves of `batch-d-infra.test.mjs` / `registry.test.mjs` / `routing-order-gate.test.mjs`, `validate-agent-names.bats`; Makefile `test-config` loses `check-omo-version-sync.sh` | S-M | ~3 s and 78 cases | HIGH. Deletes the replacement guards that `4f233a0e` added on purpose: pin parity across three files, exact-filename override discovery, prompt-marker drift, preset registry, agent-name lockstep. Recreates the DIA-260827-6wvm class of silent regression. |
| **B. Keep, retarget** | Keep every assertion but point it at the surviving layer; split mixed-concern files | Split the 18 override-prose cases out of `batch-d-infra.test.mjs` into `omo-override-layer.test.mjs`; rename `workspace-preset-selection.bats` to `preset-registry.bats`; Makefile `test-config` wiring updated once | S | Same protection, clearer ownership; a failure names its subject | Churn in review; no protection gained. Most of B is already done by `4f233a0e` (the two rewritten bats files are the retarget). |
| **C. Convert to guard-rails** | Add invariants about the layer instead of shapes of the deleted tree | `scripts/check-omo-version-sync.sh` + `scripts/__tests__/check-omo-version-sync.bats`: (i) `REFERENCE-ONLY.md` present AND no `src/` re-vendored, (ii) every override prompt file above a minimum non-placeholder size, (iii) no `file://` plugin entry pointing at the override dir | XS-S | Makes the removal permanent; the deleted tree (92,428 deleted lines in `4f233a0e`) cannot creep back unnoticed. This is the only genuinely additive variant. | Low. New assertions can false-fail if upstream renames the override contract. |
| **D. Status quo** | Change nothing | none | 0 | Zero risk of breaking a guard | LOW-MEDIUM: 31 stale references and 2 stale comments keep the retired gate alive in readers' heads; 506 MB of orphaned worktrees stay. |
| **E. Prune the residue (recommended)** | Do not touch a single test case. Delete the off-tree dead mass, correct the two stale comments, annotate the one ticket whose evidence cites a dead gate, and adopt C's anti-revendor invariant | `make worktree-gc` (15 orphaned dirs, untracked); `bats-wrapper.sh:17`; `verify-pre-push.sh:153`; `DIA-260827-6wvm` evidence note (ticket lane, not this lane); `check-omo-version-sync.sh` + its bats file (from C) | S | Removes 2,102 stale test files / 506 MB; keeps all 78 live guards; closes the "can it come back" hole; leaves history intact | Low; orphan deletion is irreversible if any worktree held unmerged work (see Q6). |

Rejected fifth option, for the record: "resurrect the suite against the npm
dist". It cannot work from this repo - the dist bundle is not in-tree, has no
exported test seams, and the clone/alias logic DIA-260827-6wvm touched lives
inside it. Testing it would require importing npm internals, which is exactly
the coupling the removal was meant to end.

---

## 5. Reuse assessment

**Reusable as-is (already present, independent of the deleted tree):**

1. `.opencode/plugins/__tests__/helpers/plugin-harness.mjs` -
   `createTempWorkspace`, `mockOpencodePlugin`, `createHarness`,
   `mockChildProcess`. This supersedes the deleted
   `src/hooks/apply-patch/test-helpers.ts`: it adds an exit-handler cleanup
   registry and restores live `node:child_process` refs after
   `mock.module()`, which the deleted helper did not. Do not port the old
   helper.
2. `write_slim_jsonc` in `validate-agent-names.bats:88-136` - a synthetic
   four-source config generator. Any future test of the OMO config shape
   should call this instead of hand-writing JSONC.
3. `makeFakeFs` in `registry.test.mjs` - fake fs with an mtime map and call
   log. Directly reusable for any config-signal or mtime-ordering test.
4. `scripts/jsonc_strip.py` - the canonical Python JSONC stripper, already
   used by `scripts/presets.py`.

**Reuse gaps worth closing (small, real):** the same JSONC comment stripper is
reimplemented at least three more times: `batch-d-infra.test.mjs`
(`stripJsonc`, about 40 lines), `preset-model-guard.dia260918-t5.test.mjs`, and
inline in several shell validators. One canonical JS stripper would remove
about 60 lines of duplicated parsing and one class of divergence bug.

**Worth lifting as a pattern, not as a file (the 81 deleted files):**

| Deleted file | Lines | Why it is not reusable as a file | Pattern worth reusing |
| --- | ---: | --- | --- |
| `src/config/loader.test.ts` | 1,585 | Tests the vendored loader; npm dist is the loader now | Precedence matrix over config layers - port to a test of the live merge result if config drift becomes a recurring bug |
| `src/agents/display-name.test.ts` | 212 | Tests vendored clone logic; subject is in npm dist | Assert the three preset configs keep visible aliases distinct from disabled internal aliases - a pure JSON assertion on live config, no dist import |
| `src/hooks/apply-patch/test-helpers.ts` | 52 | Subject deleted | Superseded by `plugin-harness.mjs` (see above) |
| `src/utils/background-job-board.test.ts` | 926 | No live background job board in this repo | Only if the board concept returns; grep shows the string survives in CHANGELOG only |
| `src/hooks/task-session-manager/index.test.ts` | 2,304 | Lifecycle moved into the npm runtime | Nothing specific; our delegation-observer suite already covers the live lifecycle |
| `scripts/test-omo.sh` | 32 | Deleted with its target | Reuse only as a negative lesson: its `if [ ! -d src ]; then exit 0` is why a deleted subject can still report green. Do not copy that shape. |

Everything else in the 81 files (multiplexer, interview, council, smartfetch,
auto-update-checker) tests subsystems this repo does not own and does not
invoke. Those are not partial-reuse candidates; they are the reason the tree
was 8 releases behind and worth deleting.

---

## 6. Recommendation

**Variant E, with C's invariant folded in.** Because:

1. There is nothing left to delete in the tracked tree. The 81 files / ~1.4k
   cases went with `4f233a0e`; the residual "dead" tests are 0. The remaining
   78 cases all assert against live artifacts, and 55 of them are the exact
   guards that commit added to replace the deleted suite.
2. The measurable dead mass is off-tree and much larger than the owner
   supposes: 15 orphaned worktrees, 2,102 test files, 1,186 of them copies of
   the deleted suite, 360 MB of OMO-tree copies. They are invisible to every
   gate but visible to every `find`, `grep`, and future reader.
3. Option A would spend the only asset the removal produced - the override
   layer's guard-rails - to buy 3 seconds and 78 cases. That is a net
   regression in protection, and it re-opens the silent-fallback failure mode
   the removal was designed to close (a misspelled override filename falls
   back to the built-in prompt with no error).
4. Option C's invariant is the one missing piece: today nothing fails if
   someone re-vendors `src/`. One three-line guard makes the removal durable.

**Single condition that flips this recommendation:** if the gate audit shows
that these 78 cases do not actually execute in any enforced path on a fresh
clone (for example `test-config` is unreachable when the container is down
because pre-push fails open, and no CI exists), then they are load-bearing in
name only - a guard that never runs is not a guard - and the recommendation
flips to Variant B narrowed to the two bats files that `4f233a0e` itself added
(`check-omo-version-sync`, `check-orchestrator-prompt-drift`), with the rest
deleted rather than retargeted.

---

## 7. Provisional figures and open questions

Marked PROVISIONAL because three parallel lanes hold findings this lane does
not have.

| Figure | Value | Why provisional |
| --- | --- | --- |
| Python case count and runtime | 64 cases (eight files), runtime UNKNOWN | `def test_` count; pytest is absent from the host interpreter, so parametrized expansion and timing were not measured |
| OMO-touching attribution | 78 cases in 10 files | Manual reading; the boundary for `batch-d-infra` (18/64), `registry` (4/77), and `routing-order-gate` (1/38) is a judgement call the inventory lane may draw differently |
| Baseline case count | 1,371 by grep; 1,366-1,409 reported | Runtime table expansion differs by runner and date |
| Removal size | `4f233a0e` alone: 372 files, -92,428 lines | The campaign brief cites -101,334 for the vendored tree; that figure spans the removal series or a different measure, and only the per-commit shortstat is verifiable here |
| Whether the 15 worktrees hold unmerged work | Unknown | Needs the inventory lane (they are orphaned from git's view, so `git log` cannot speak for them) |
| Whether upstream 2.2.19 carries the DIA-260827-6wvm alias fix | Unknown | Needs OMO semantics |

**Questions whose answers would most change the recommendation:**

- Q1 (gate audit): Do the 78 cases execute on a fresh clone in an enforced
  gate? Specifically, does pre-push fail open when the container is down, and
  is `make test-config` reachable from any CI path? This is the flip condition.
- Q2 (gate audit): Confirm no gate traverses `.worktrees/` or `.scratch/`
  (my claim is that `bats-wrapper.sh` globs only `scripts/__tests__/*.bats`
  and turbo sees only the four workspace packages, so the 2,102 off-tree test
  files are inert).
- Q3 (inventory): Are there copies of the OMO suite outside
  `.worktrees/` - npm cache, `.slim/`, `/tmp`, a global config dir, or a clone
  made by the clonedeps skill? My count is git-tracked only.
- Q4 (OMO semantics): In the 2.2.19 dist, what are the exact override
  discovery filenames and directories? If any of the five surviving prompt
  filenames is a near-miss, `check-omo-version-sync` is guarding the wrong
  contract and its 7 cases are actively misleading.
- Q5 (OMO semantics): Does 2.2.19 contain the visible-alias fix from
  DIA-260827-6wvm? If not, removing the tree deleted a real fix, and only a
  behavioural UI check (or a live-config JSON assertion) can catch the
  regression.
- Q6 (inventory): Do any of the 15 orphaned worktree directories contain work
  that was never merged? If yes, Variant E's "delete outright" step needs a
  branch scan first.
- Q7 (gate audit): Is the plugin's `captureConfigLoadSignal` (`omo_jsonc_mtime`)
  consumed by anything that would notice a config change? If it is write-only
  telemetry, its 4 cases are the closest thing to alive-but-vestigial in the
  set.

Cross-lane note: this report deliberately makes no claim about OMO runtime
semantics. Sections 1.2, 1.3, 1.4 and the worktree figures are self-contained
and reproducible; anything about what the npm plugin does at runtime is
deferred to the OMO-semantics lane.
