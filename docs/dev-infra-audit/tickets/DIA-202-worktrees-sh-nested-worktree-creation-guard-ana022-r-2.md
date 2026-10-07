# DIA-202 - worktrees.sh: nested-worktree creation guard (ana022 R-2)

---

id: DIA-202
title: "worktrees.sh: nested-worktree creation guard (ana022 R-2)"
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
(committed 8f227f2), recommendation R-2 (finding M-3).

Problem: nested worktree creation is unguarded and the removal-order
constraint is undocumented. Evidence (M-3): (1) worktrees.sh:58-60 - `ROOT`
derives from `BASH_SOURCE` (the script's own checkout) and
`WORKTREES_DIR=$ROOT/.worktrees`, so invoking `worktrees.sh create` from
INSIDE a worktree nests by construction (a nested lane lands at
`.worktrees/feature-dia134-shim/.worktrees/...`); (2) a nested dir was live
on disk at `.worktrees/feature-dia134-shim/.worktrees/
feature-dia134-shim-selfcheck` (its `.git` pointed at the dead gitdir
`/workspace/.git/worktrees/feature-dia134-shim-selfcheck`); (3) grep for
`feature-dia134-shim-selfcheck` across worktrees.bats and
worktree-conventions.md returns nothing - the case is unreferenced and
untested; (4) `git worktree remove` of an outer worktree fails while a
registered nested worktree exists inside it (git requires innermost-first),
so a nested lane can block teardown of its parent.

Fix scope (ana022 M-3 recommendation (a) + (c), effort S-M): (a) create-time
guard - refuse `create` when the current checkout is not the main worktree
(detect via `git worktree list --porcelain` first entry, or refuse when
`git rev-parse --show-toplevel` != the main root); (c) remove-time check -
`remove` lists any registered worktrees whose path is a subdirectory of the
target and fails with an actionable "remove nested worktrees first
(innermost-first)" message instead of the raw git error. Document the
innermost-first ordering in worktree-conventions.md regardless. Optional
hardening (b, deferred): anchor `WORKTREES_DIR` to the MAIN checkout root so
nested invocation lands flat under `.worktrees/`.

## Verification

- [x] `worktrees.sh create` run from inside a worktree exits non-zero with a clear "not the main worktree" message (bats).
- [x] `worktrees.sh create` from the main checkout behaves exactly as before (regression green).
- [x] `worktrees.sh remove` on a worktree containing a registered nested worktree fails with the innermost-first message naming the nested path (bats).
- [x] worktree-conventions.md documents the innermost-first removal ordering.
- [x] `make test-shell` exit 0 (worktrees.bats suite green).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

<!-- UPDATE 2026-08-19: Implementation landed (worktrees.sh:261-268 create guard, :367-383 remove guard; tests T35-T36; docs worktree-conventions.md:65-91). make test-shell green. Status -> CLOSED. -->
