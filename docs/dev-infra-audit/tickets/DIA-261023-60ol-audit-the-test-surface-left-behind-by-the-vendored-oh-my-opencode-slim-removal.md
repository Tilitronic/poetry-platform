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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
