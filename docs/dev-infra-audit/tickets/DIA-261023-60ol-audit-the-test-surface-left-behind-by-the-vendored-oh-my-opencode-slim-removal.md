# DIA-261023-60ol - audit the test surface left behind by the vendored oh-my-opencode-slim removal

---

id: DIA-261023-60ol
title: "audit the test surface left behind by the vendored oh-my-opencode-slim removal"
area: tests-infra
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-10-23
source: inventory
date: 2026-10-23
created: 2026-10-23
updated: 2026-10-24

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_e9614a62bffeaW9wRMZgbswXug"
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

A concurrent session (campaign ticket DIA-261022-5n2v) removed the vendored,
locally-downloaded oh-my-opencode-slim tree, leaving only a small override
layer. This ticket governs a follow-up audit of the test surface that survived
that removal: tests, gates, fixtures, and Makefile targets that were written
to validate the deleted copy may now be dead weight or tautological.

### Context (verified facts)

Removal batch - five commits, combined 423 files, +643/-101334 lines
(sum of per-commit `git show --stat` totals):

- `4f233a0e` "trim the vendored OMO tree to the override layer and guard it"
  (372 files, +116/-92428). Deleted `scripts/test-omo.sh` (32 lines), removed
  the `test-omo` Makefile target, its `.PHONY` entry, and the doc-comment line
  (Makefile -9 lines, verified in commit diff), rewired the
  `verify-pre-push.sh` step-ladder (test-omo leg removed; comment now reads
  "format, js, js-tests, test-config, dia189-toast, python, test-shell LAST"),
  and added override-layer guards to `scripts/check-omo-version-sync.sh`
  (+42 lines: required-overrides existence checks for analyzer_append.md,
  coder.md, coder_append.md, orchestrator_append.md, reviewer.md, plus an
  allowed-extra-\*.md list of only REFERENCE-ONLY.md).
- `d8c4ea0b` "drop the Quasar demo and i18n from author-studio, refresh
  lockfiles" (12 files, +112/-7077).
- `48015b99` "delete the query_web bridge and stub the six opsx commands"
  (10 files, +20/-1544). Deleted `.opencode/scripts/query_web.py` AND its
  test `.opencode/scripts/test_query_web.py` (both confirmed absent from the
  working tree); stubbed exactly six command files:
  `.opencode/commands/opsx-{apply,archive,explore,propose,sync,update}.md`
  (opsx-continue.md and opsx-new.md were NOT touched by this commit).
- `f18f3d19` "land the rollback-free simplification set" (7 files,
  +73/-248).
- `f5ee368e` "record audit dispositions, findings, and lessons" (22 files,
  +322/-37).

What survives in `.opencode/oh-my-opencode-slim/` - exactly 8 files:
REFERENCE-ONLY.md, analyzer_append.md, coder.md, coder_append.md,
orchestrator_append.md, reviewer.md, knowledge/ai-assist-sources.yaml,
knowledge/opencode-best-practices.md.

Additional verified state:

- No textual `test-omo` references remain in Makefile, `scripts/*.sh`,
  `.husky/*`, or `docs/dev-infra-audit/*` (grep, 2026-10-23).
- The removal batch itself already modified two related bats suites:
  `scripts/__tests__/check-omo-version-sync.bats` and
  `scripts/__tests__/verify-pre-push.bats` (both in commit `4f233a0e`).

The audit lanes establish the conclusions below; nothing in this ticket
asserts them.

### Open questions the audit must answer

1. Which SURVIVING tests, gates, fixtures and Makefile targets exist
   primarily to validate the deleted copy, and are therefore now dead weight
   or tautological (for example assertions that a file is absent, or that a
   removed script does not exist)?
2. How many of them are there, counted per file and per test case, split
   into: (a) now meaningless, (b) still load-bearing for the override layer,
   (c) partially meaningful and needing rework?
3. What coverage was silently lost with the deletion - which behaviours that
   still exist in the trimmed layer were previously exercised and are now
   unexercised?
4. Which harness helpers, fixtures or pattern generators are reusable
   elsewhere even if the tests around them are dead?
5. Is `scripts/check-omo-version-sync.sh` still meaningful when the vendored
   copy is gone, and what does it actually compare now?

## Verification

Acceptance criteria (a single audit artifact must satisfy all):

- [ ] Per-test classification covering every surviving test/gate/fixture/
      Makefile target touched by the removal batch: each marked dead /
      load-bearing / rework, with file:line or test-case-name evidence.
- [x] Counts per file and per test case, split into the three buckets of
      open question 2.
- [x] Reuse assessment (open question 4): helpers/fixtures that survive even
      if their surrounding tests are dead.
- [ ] Coverage-loss list (open question 3): behaviours of the trimmed
      override layer no longer exercised by any surviving test.
- [x] Explicit disposition recommendation for `check-omo-version-sync.sh`
      and its bats suite (open question 5).
- [x] No test is deleted before the developer dispositions the audit's
      recommendation.

## Fix

Cleanup commit 7048c576 "DIA-261023-60ol: prune orphaned worktree residue,
fix stale prose test counts" landed on branch omo-slim-changes.

Worktree residue pruned: 15 orphaned `.worktrees/` directories removed,
489,408,432 bytes freed, 0 directories kept, 0 uncertain. Each directory
passed a per-directory safety gate before deletion: a `git worktree list`
membership check (dir not registered as a live worktree), a not-in-HEAD file
classification (no file inside the dir existed in HEAD), and a branch /
unpushed-work check (no live branch or unpushed commits tied to the dir).
After the prune `git worktree list` reports only /workspace, `.worktrees/`
is empty, and `git status --short` shows no deletions of tracked files.

Four prose corrections (stale or hard-coded test counts):

- `scripts/__tests__/bats-wrapper.sh`: "240 tests ... ~25 s floor" replaced
  with "the full suite, ~99 s as of 2026-10-23; live totals print at end of
  run".
- `scripts/__tests__/verify-pre-push.bats`: "the full 711-test bats suite"
  replaced with "the full bats suite" (hard number removed).
- `scripts/verify-pre-push.sh`: "100+ tests" replaced with "728 tests as of
  2026-10-23" (dated hard number).
- `docs/dev-infra/eval-lite-tasks.md`: analytics-pipeline pytest suite
  description corrected from "(4 tests)" to "(2 tests)".

No tracked file was deleted and no test case was deleted by this cleanup.

## Re-verify

Independent verification lane (2026-10-23, branch omo-slim-changes):

- Observed HEAD: 7048c576 "DIA-261023-60ol: prune orphaned worktree
  residue, fix stale prose test counts".
- `git show --stat 7048c576`: exactly 4 files changed, 6 insertions(+),
  6 deletions(-), zero tracked files deleted. File list matches the Fix
  record: docs/dev-infra/eval-lite-tasks.md, scripts/**tests**/bats-wrapper.sh,
  scripts/**tests**/verify-pre-push.bats, scripts/verify-pre-push.sh.
- Deletion outcome re-checked: 0 `.worktrees/*/` directories, `.worktrees`
  size 0, `git worktree list` shows only /workspace, no deletions in
  `git status --short`.

Gate results (own reported totals, UTC 2026-10-23T23:37:33Z):

- `make test-config`: exit 0. Reported: 22 agents audited, 0 gaps, 362
  warnings; node suites 64/64, 38/38, 5/5 pass, 0 fail; plugin
  structural gates all PASS.
- `bash scripts/__tests__/bats-wrapper.sh`: exit 0. Runner's own totals:
  728 ok, 0 not ok (plan line `1..728`; 728 `ok` lines counted, zero
  `not ok`). Warning observed (pre-existing, non-fatal): vendored bats
  version mismatch, v1.11.0 vs pinned v1.14.0 (DIA-121 drift check).

pytest and vitest were NOT re-measured by this verification lane (they
require the dev container); their figures below remain as recorded by the
audit lanes.

### Count discrepancies left unresolved

Cross-lane discrepancies recorded by the audit (left unresolved; the
settling rule is: take the runners' own reported counts, never occurrence
greps):

- files: 109 vs 110
- cases: 1536 vs 1603
- pytest: 28 vs 64
- vitest: 120 vs 132
- line delta: -101334 vs -92428

Current runner-truth observed today: bats wrapper 728; `make test-config`
exit 0. pytest/vitest not re-measured by this lane.

## Close disposition

Developer disposition: close the ticket on 2026-10-24. Status set to
CLOSED via `scripts/tickets update` (the ledger's canonical terminal
value: the frontier logic treats any non-OPEN status as out-of-frontier
and the CLI help documents the pair "OPEN, CLOSED"; DONE/COMPLETE exist
only as minor variants).

### Delivered

- Audit artifact: knowledge/ana-261023-07sa-omo-slim-dead-test-surface/
  ana-261023-07sa-omo-slim-dead-test-surface-report.md (analyzer lane,
  2026-10-23; present in the working tree, untracked by git as of this
  close).
- B cleanup: commit 7048c576 (15 orphaned worktree directories pruned,
  489,408,432 bytes freed; four stale prose test counts corrected; zero
  tracked files and zero test cases deleted).
- Independent re-verify evidence: commit d2340a45 (this ticket's Fix and
  Re-verify sections; gates re-run by the verifying lane: bats wrapper
  728 ok / 0 not ok exit 0, `make test-config` exit 0).
- Lessons: commit 84443e9b (memory lane; .opencode/memory/lessons.md
  entries L20261023-60ol-001 and L20261023-60ol-002).

### Acceptance criteria disposition

- Criterion 1, per-test classification of everything the removal batch
  touched: NOT TICKED (partial). The report classifies the 10 surviving
  OMO-touching files with per-file case counts (report section 1.4), the
  kind-3 items with file:line refs (section 2), and the 0/0 dead-tracked
  totals (section 1), but verify-pre-push.bats (surviving, modified by
  4f233a0e per this ticket's verified context) receives no classification
  line anywhere in the report, verify-pre-push.sh gets only its stale
  comment noted (section 3) rather than a dead/load-bearing/rework mark,
  and the report labels itself a FIRST PASS with the gate-execution audit
  (Q1, Q2) deferred to section 7, so the load-bearing marks are
  conditional on gates actually running.
- Criterion 2, counts per file and per case in the three buckets:
  TICKED. Section 1.4 (per-file OMO/total counts, totals 78 of 1,603),
  section 2 (subject-deleted 0 files / 0 cases, vacuous-absence 0 cases
  with grep evidence, vestigial 1 case plus 2 embedded assertions at
  named lines), sections 1.2-1.3 (before/after totals).
- Criterion 3, reuse assessment: TICKED. Section 5 lists four
  reusable-as-is helpers with file:line, the JSONC stripper duplication
  gap, and the deleted-file pattern table.
- Criterion 4, coverage-loss list: NOT TICKED (partial). Exactly one
  evidenced loss item exists (section 3: the DIA-260827-6wvm
  visible-alias regression, explicitly "not, in this repo" guarded); Q5
  (whether upstream 2.2.19 carries that fix) and Q7 (whether
  captureConfigLoadSignal is consumed or write-only) remain unanswered
  inside the artifact, and section 7 defers them to other lanes. No
  systematic enumerated coverage-loss list was produced.
- Criterion 5, disposition for check-omo-version-sync.sh and its bats
  suite: TICKED. Section 1.4 row 1 (what the 7 cases now compare),
  section 2 (positive contracts that fail on a real edit, not vacuous),
  options C and E rows plus section 6 (keep, extend with the
  anti-revendor invariant).
- Criterion 6, no test deleted before developer disposition: TICKED.
  Fix section (no tracked file, no test case deleted), Re-verify
  (7048c576 stat: 4 files, 6 insertions, 6 deletions, zero deletions;
  bats wrapper re-run 728 ok), and the audit's recommended option E was
  explicitly designed as "Do not touch a single test case".

### Deferred by developer disposition

These are NOT satisfied, NOT started, and NOT tracked by any other
ticket. The next reader must not assume any coverage exists for them.

- C invariant (make the removal permanent): a gate that fails if the
  vendored src tree is ever re-vendored (no .opencode/oh-my-opencode-slim
  src tree), plus the REFERENCE-ONLY.md presence check, plus no file://
  plugin entry pointing at the override directory. NOT satisfied; NOT
  tracked by any other ticket.
- D gate-hardening agenda (campaign audit findings, items 4-12): NOT
  satisfied; NOT started; NOT tracked by any other ticket. The item-level
  enumeration lives in the campaign audit-findings record, not in this
  ledger.

### Count discrepancies

Unresolved cross-lane count discrepancies are recorded under
"Count discrepancies left unresolved" (subsection of Re-verify above);
not repeated here.
