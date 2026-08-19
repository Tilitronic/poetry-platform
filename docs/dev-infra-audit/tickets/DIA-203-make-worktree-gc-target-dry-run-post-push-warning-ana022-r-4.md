# DIA-203 - make worktree-gc target + dry-run post-push warning (ana022 R-4)

---

id: DIA-203
title: "make worktree-gc target + dry-run post-push warning (ana022 R-4)"
area: dev-infra
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-16
source: inventory
date: 2026-08-16
created: 2026-08-16
updated: 2026-08-19

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

Follow-up from DIA-200 (closed 2026-08-16): ana022 report
knowledge/ana022-worktree-mechanism-analysis/ana022-worktree-mechanism-analysis-report.md
(committed 8f227f2), recommendation R-4 (finding M-1, section 7).

Problem: teardown enforcement is orchestrator-discipline only. The cleanup
machinery is fully implemented (M-1: two-pass merge check worktrees.sh:411-424
is-ancestor fast path; tree-subset squash parity `branch_tree_in_main`
worktrees.sh:223-233; internal `-D` deletion worktrees.sh:510 with the
deliberate-`-D` rationale at worktrees.sh:501-505), but lessons.md:882-884
records the post-merge Teardown dispatch was "NEVER actually executed" after
DIA-172 and DIA-174, and the DIA-177 design accepted this
(worktree-branch-cleanup design.md:211-213, D7: invocation via the
orchestrator-dispatched Teardown lane). The accumulation this allows is
exactly the ana022 section 2 state (13 orphaned dirs measured 2026-08-14;
0 on disk as of 2026-08-16 after manual removal).

Fix scope (ana022 M-1 recommendation (b) + dry-run (a), effort M): (1)
`make worktree-gc` target (Makefile, effort S) running `remove` leftovers +
`cleanup` + `prune` as the documented post-merge step; (2) dry-run post-push
warning (`.husky/post-push` running `worktrees.sh cleanup --dry-run`, effort
M with bats tests) printing a warning when stale branches/worktrees exist -
advisory only, never auto-delete (auto-run with default window 0 would delete
branches at push time); (3) document the post-merge `make worktree-gc` step
in worktree-conventions.md. EXPLICITLY NOT cron/auto-scheduled: ana022 O-4 +
worktree-branch-cleanup design.md:46-53 make auto-scheduling a non-goal;
M-1(b) covers the real need without a scheduler. Do NOT change the merge
strategy (M-1a rejected: squash-merge stays; regular-merge rejected for
main-history quality).

## Verification

- [x] `make worktree-gc` runs remove-leftovers + cleanup + prune and exits 0 on a clean tree (smoke).
- [x] `.husky/post-push` dry-run fires after a push and prints the stale-branch/worktree warning when stale state exists; no deletion happens (bats).
- [x] worktree-conventions.md documents `make worktree-gc` as the post-merge step (no cron/auto-schedule anywhere).
- [x] `make test-shell` exit 0 (new bats coverage for the hook + dry-run path).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

<!-- UPDATE 2026-08-19: Implementation landed (Makefile:307-309 worktree-gc target; .husky/post-push dry-run hook; tests post-push.bats:81-109; docs worktree-conventions.md:220-248). make test-shell green. Status -> CLOSED. -->
