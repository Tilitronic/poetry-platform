# DIA-198 - reconcile self-rerun thresholds 15/25 across OMO inline prompts + drift-checker marker (DIA-191 F4/F5 follow-up)

<!-- FILED 2026-08-16 (merge lane cod-13). Follow-up from ai-auditor review of
     the DIA-191 threshold retune (F4/F5 nits, developer-accepted 2026-08-16).
     Small config reconciliation - no behavior change beyond aligning the
     threshold text in the OMO inline prompts + drift-checker contract with
     the already-merged NEXT-RUN.md / context_usage tool retune (15/25). -->

---

id: DIA-198
title: "reconcile self-rerun thresholds 15/25 across OMO inline prompts + drift-checker marker (DIA-191 F4/F5 follow-up)"
area: opencode-config
severity: Low
status: CLOSED
blocked_by: [] # no blockers
parent_epic: "DIA-191" # optional DIA-NNN parent epic ticket (DIA-125 keep-local extension; scripts/tickets emits this field always)

# DIA-104 grilling-gate markers (ai--7 validated design): fill at creation time

# with the defaults below (absent = legacy/skipped, grandfather precedent).

gate_state: "waived" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [spike-poc] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-16
source: ai-auditor-review
date: 2026-08-16
created: 2026-08-16
updated: 2026-08-16

# --- Session Attribution (v2 schema, optional ---)

session_id: "" # filed by merge lane cod-13 (session attribution optional per GRANDFATHERED note)
lane_id: "cod-13"
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: "" # orchestrator session (merge dispatch context)
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

The DIA-191 threshold retune (ana025 V1, commit f18281f, merged 47064d0)
changed the self-rerun authority from 30%/50% to **15%/25%** in
`docs/dev-infra-audit/NEXT-RUN.md` and retuned the `context_usage` tool
output fields (`threshold_15pct`/`threshold_25pct`, delegation-observer.ts
~2845). Three surfaces still carry the OLD 30/50 text and now drift from the
merged authority:

1. **OMO inline orchestrator prompt summaries** -
   `.opencode/oh-my-opencode-slim.jsonc` lines 26 / 209 / 433 still say
   `>=30% (primary) / >=50% (safety-net)` in the "Orchestrator Operating
   Rules" prompt (all three presets).
2. **Drift-checker marker contract** -
   `scripts/check-orchestrator-prompt-drift.sh` line ~35-36 (comment) and
   line 67 (`THRESHOLD_MARKER="30% (primary)"`) still assert the 30% text,
   so the drift gate would FAIL once the inline prompts are retuned to 15% —
   the marker and the prompts must change together. Companion fixture
   needles in `scripts/__tests__/check-orchestrator-prompt-drift.bats`
   (lines ~151-159, `30% (primary)`) must be updated to match.
3. **context_usage tool description** - `delegation-observer.ts` (~line 2693) tool description still describes the old threshold semantics
   (single 30/50 framing); should document the dual 15/25 fields.

Impact: inline orchestrator guidance contradicts the merged NEXT-RUN.md
authority, and the drift-checker would hard-fail (or force a --no-verify
bypass) on the next prompt retune. Low severity: text-alignment only, no
runtime behavior change.

## Verification

- `make test-config` exit 0 (the drift checker test is wired into the config
  suite; it must go GREEN with the retuned markers).
- `grep -n "30%\|50%" .opencode/oh-my-opencode-slim.jsonc` returns NOTHING in
  the inline prompt sections (no 30/50 summary text remains).
- `scripts/check-orchestrator-prompt-drift.sh` exit 0 against the current
  tree (marker 15% (primary) matches the inline prompts).

## Fix

Implemented 2026-08-16 (cod-13 follow-up lane, branch omo-slim-changes,
commit referencing DIA-198). Text-alignment only; no runtime behavior change.

1. `.opencode/oh-my-opencode-slim.jsonc` - replaced `>=30% (primary) / >=50%
(safety-net)` with `>=15% (primary) / >=25% (safety-net)` in the
   "Orchestrator Operating Rules" prompt of ALL THREE presets (lines 26 / 209
   / 433, opencode-go / cebula / free).
2. `scripts/check-orchestrator-prompt-drift.sh` - retuned the marker contract:
   header comment (line 19 + lines 35-36) and `THRESHOLD_MARKER` (line 67)
   now assert `15% (primary)`; internal marker token renamed
   `threshold-30-50` -> `threshold-15-25` (MARKERS array + case arm) so the
   contract id matches the needle it locks.
3. `scripts/__tests__/check-orchestrator-prompt-drift.bats` - fixture needles
   `>=30% (primary) / >=50% (safety-net)` -> `>=15% (primary) / >=25%
(safety-net)` in FULL*PROMPT and all DRIFTY*\* fixtures; comments + test
   name + output assertion updated to `15% (primary)`.
4. `.opencode/plugins/delegation-observer.ts` (~line 2700) - context_usage
   tool description now documents the dual self-rerun output fields
   (`threshold_15pct` primary >=15% / `threshold_25pct` safety-net >=25% per
   NEXT-RUN.md) instead of the old single `>=25%` framing. Description-string
   edit only; validated by the esbuild bundle in
   `scripts/__tests__/batch-d-infra.test.mjs` (wired into make test-config).

Verification evidence (all run on the current tree):

- `make test-config` exit 0 (56 tests pass / 0 fail; includes batch-d-infra
  plugin bundle + drift-checker Makefile wiring).
- `make test-shell` exit 0 (404 bats tests pass; drift-checker suite green,
  incl. retuned "missing threshold text (15% primary)" test).
- `grep -n "30%\|50%" .opencode/oh-my-opencode-slim.jsonc` -> empty (exit 1,
  no matches) - no 30/50 summary text remains.
- `bash scripts/check-orchestrator-prompt-drift.sh` exit 0 ("3 preset(s)
  checked, 8 markers each, 0 gaps").
- `grep -n "30%\|50%"` across the other three changed files -> empty too.

No tsc config exists for `.opencode/plugins/` (plugin typecheck path is the
esbuild bundle in test-config, which passed); the edit is a string literal so
no type surface changed.

## Re-verify

Re-verified 2026-08-16 (same lane, post-fix): all four surfaces now carry
the 15/25 authority and the drift-checker contract is internally consistent:

| Check                                        | Result                                                          |
| -------------------------------------------- | --------------------------------------------------------------- |
| grep 30%/50% in oh-my-opencode-slim.jsonc    | empty (0 matches)                                               |
| grep 30%/50% in drift script + bats + plugin | empty (0 matches)                                               |
| scripts/check-orchestrator-prompt-drift.sh   | exit 0, 0 gaps                                                  |
| make test-config                             | exit 0 (56/56)                                                  |
| make test-shell                              | exit 0 (404/404, drift suite green)                             |
| git status                                   | only the 5 intended files staged; sibling dirty files untouched |

No behavioral delta: prompts/contract/tool description all read 15% primary /
25% safety-net, matching the merged NEXT-RUN.md (lines 81-82, 238-239) and
the context_usage output fields (threshold_15pct/threshold_25pct).

## UPDATE (2026-08-16) - CLOSED: implementation verified + ai-auditor APPROVE-WITH-NITS + pushed

Closure evidence (register lane, omo-slim-changes):

- Implementation: commit f4dcf73 (5 files, +74/-27) retuned all THREE preset
  "Orchestrator Operating Rules" inline prompts (opencode-go / cebula / free,
  lines 26/209/433), retuned the drift-checker marker contract
  (THRESHOLD_MARKER `15% (primary)`, internal token threshold-30-50 ->
  threshold-15-25), updated the bats fixture needles, and documented the dual
  threshold_15pct/threshold_25pct fields in the context_usage tool
  description. Text-alignment only; no runtime behavior change.
- Test evidence: make test-config exit 0 (56/56, incl. batch-d-infra plugin
  bundle + drift-checker wiring); make test-shell exit 0 (404/404, drift
  suite green); bash scripts/check-orchestrator-prompt-drift.sh exit 0 (3
  preset(s) checked, 8 markers each, 0 gaps); grep `30%|50%` empty across all
  four non-ticket files.
- Review: ai-auditor Phase 6 review APPROVE-WITH-NITS (2026-08-16) - all
  Major compliance PASS; the single optional nit (independent 25% safety-net
  marker in the drift-checker) DEFERRED by developer disposition as
  future-hardening - logged here, NOT part of this closure.
- Pushed to origin/omo-slim-changes: f4dcf73 -> 9a1c08e (pre-push
  ladder passed: prettier, eslint, js-tests, test-config, python, test-shell).
- Registration: .opencode/CHANGELOG.yaml entry appended (DIA-198, 2026-08-16)
  - derived CHANGELOG.md regenerated via scripts/changelog-render;
    validate-changelog.sh exit 0. Learnings outcome: no DIA-191/ana025 learnings
    entry carries an outcome field (lessons.md L20260815-011 has none; adr.md is
    a pre-existing sibling dirty file) - skipped per register-lane instruction.

Status: CLOSED.
