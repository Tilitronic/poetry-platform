# DIA-261023-60ol - audit the test surface left behind by the vendored oh-my-opencode-slim removal

---

id: DIA-261023-60ol
title: "audit the test surface left behind by the vendored oh-my-opencode-slim removal"
area: tests-infra
severity: Medium
status: OPEN
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
updated: 2026-10-23

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
- [ ] Counts per file and per test case, split into the three buckets of
      open question 2.
- [ ] Reuse assessment (open question 4): helpers/fixtures that survive even
      if their surrounding tests are dead.
- [ ] Coverage-loss list (open question 3): behaviours of the trimmed
      override layer no longer exercised by any surviving test.
- [ ] Explicit disposition recommendation for `check-omo-version-sync.sh`
      and its bats suite (open question 5).
- [ ] No test is deleted before the developer dispositions the audit's
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
