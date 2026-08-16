# DIA-201 - worktree cleanup: orphaned-dir sweep for .worktrees/ (ana022 R-1)

---

id: DIA-201
title: "worktree cleanup: orphaned-dir sweep for .worktrees/ (ana022 R-1)"
area: dev-infra
severity: Medium
status: OPEN
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
updated: 2026-08-16

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
(committed 8f227f2), recommendation R-1 (finding M-2, section 2).

Problem: `.worktrees/` accumulates orphaned directories that NO existing tool
can see or remove. Evidence (ana022 section 2, measured 2026-08-14):
`git worktree list` shows only the main checkout; 12 orphaned dirs
(`feature-dia132-*` x5, `dia133-*` x2, `dia134-*` x4, `dia135-rules`) + 1
nested dir sit on disk with zero branches and zero registration metadata
(`.git/worktrees/` admin metadata absent entirely); `git worktree prune
--dry-run` is a no-op (rc 0). Their `.git` files point at dead gitdir paths,
so they are pure filesystem orphans. Root causes (M-2): (1) `cleanup`
candidate enumeration is branch-driven only - worktrees.sh:576
`git for-each-ref --format='%(refname:short)' refs/heads/feature/` yields zero
candidates when all branches are deleted (the exact live state); (2)
worktrees.sh:487-498 (row 6) handles a leftover dir only when its branch
still exists; the no-branch orphaned case is untested and unhandled (T27,
worktrees.bats:599, covers only the branch-still-exists case). `.worktrees/`
is git-ignored, so orphans never surface in `git status`.

State note (closeout lane 2026-08-16): the 13 dirs measured by ana022 have
since been removed from disk (0 orphaned dirs remain as of 2026-08-16), but
nothing prevents recurrence - the tooling gap is unchanged.

Fix scope (ana022 M-2 recommendation (a), effort M): add an orphaned-dir
sweep phase to `worktrees.sh cleanup`. After the branch scan, iterate
`$WORKTREES_DIR/*` and classify each dir as (i) registered worktree (entry in
`git worktree list --porcelain`), (ii) leftover for a still-existing branch
(current row 6 path), or (iii) fully orphaned (`.git` file whose gitdir is
missing AND no matching `feature/*` branch). Report (iii) under `--dry-run`,
remove under the existing safety gates (never force; skip a dir that contains
a registered nested worktree; mirror the T11 main-checkout guard so the main
checkout is never touched). Add bats cases T30-T33: orphaned-dir deleted /
orphaned-dir dry-run listed / orphaned-dir skipped when it contains a
registered nested worktree / main-checkout never touched.

## Verification

- [ ] `scripts/worktrees.sh cleanup --dry-run` lists fully-orphaned dirs (case iii) without removing anything (bats T31).
- [ ] `scripts/worktrees.sh cleanup` removes a fully-orphaned dir; a dir whose branch still exists takes the existing row-6 path (bats T30, T27 regression green).
- [ ] A dir containing a registered nested worktree is skipped, not removed (bats T32).
- [ ] Main checkout and registered worktrees are never touched (bats T33, T11 regression green).
- [ ] New bats suite green: `make test-shell` exit 0.
- [ ] `git worktree list` output unchanged for registered worktrees; no force flags used by the sweep.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
