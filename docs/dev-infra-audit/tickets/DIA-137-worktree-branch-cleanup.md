# DIA-137 - Worktree branch cleanup subcommand with merge verification

---

id: DIA-137
title: "worktree branch cleanup subcommand with merge verification"
area: dev-infra
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: developer-request
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-14

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fffbdce25ffe4zHF4PVNVKp6nN"
lane_id: ""
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-137-worktree-branch-cleanup.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

**Problem:** we run parallel @coder lanes in separate git worktrees (DIA-100,
DIA-132, DIA-134). After a squash-merge to main, the teardown step
(`scripts/worktrees.sh remove`) removes the worktree directory but KEEPS the
branch for the rollback window (DIA-100 cleanup policy, documented in
`docs/dev-infra-audit/worktree-conventions.md` "Cleanup policy"). The
rollback window has been unbounded in practice: nothing ever deletes those
branches after the merge, because the Teardown step 5 stops at `remove` and
never runs `cleanup`, and branch deletion is denied for lanes at the config
layer (`git branch -d`/`-D`, DIA-096). As of 2026-08-14 the repo holds 10
leftover feature branches (`feature/diaXXX-*`) and 13 worktrees (12
`feature/dia132-*`, `feature/dia133-*`, `feature/dia134-*`,
`feature/dia135-*` plus a nested selfcheck worktree) whose merged content is
already on main.

**Proposed cleanup policy:** a branch is deleted immediately after a
successful merge, verified by `git diff main <branch>` being empty (plus
the branch being merged by `git merge-base --is-ancestor`). The age window
is configurable for opt-in conservative runs (`--days N` flag >
`WORKTREES_CLEANUP_DAYS` env var > default 0); the default is 0 because
the merge-content check plus the dirty-worktree protection are the real
safety gates -- age adds only delay. Invocation is via the existing
orchestrator-dispatched Teardown lane (worktree-conventions.md step 5,
post-merge) AND may also be run manually by the developer, mirroring the
`remove` pattern: the script is the policy boundary. Lanes still never
delete branches directly -- the DIA-096 deny of `git branch -D *` stays
unchanged; the script's own internal deletion is governed by the script
itself, same invariant as `remove` (see
`docs/dev-infra-audit/worktree-conventions.md` DIA-096 safe/destructive
mapping note: the permission config gates the OUTER command, so the script
enforces its own boundaries).

**Scope of the change:** add a `cleanup` subcommand to
`scripts/worktrees.sh` (current subcommands: `create` / `remove` / `list`,
dispatch at lines 296-300) plus bats coverage in
`scripts/__tests__/worktrees.bats` (real isolated git repo fixture under
`$BATS_TEST_TMPDIR`, FAKE-mock invariant preserved). No change to the DIA-096
permission config.

## Scope

Single dev-infra change: a `cleanup` subcommand in `scripts/worktrees.sh`
with merge-verification (empty `git diff main <branch>`), a configurable
rollback-window age check (default 0 days, immediate post-merge cleanup),
invocation via the orchestrator-dispatched Teardown lane (+ manual escape
hatch), and bats tests. Does NOT touch the DIA-096 permission deny list
(`git branch -D` stays denied for lanes); the script remains the policy
boundary.

## Verification

Prove the defect exists: `git branch -a` shows `feature/diaXXX-*` branches
whose content is fully merged into main still present; `git worktree list`
shows 13 stale worktrees.

Prove the fix:

1. Bats tests for the `cleanup` subcommand in
   `scripts/__tests__/worktrees.bats` (real git repo fixture):
   - **merged-only deletion:** a branch fully merged into main (empty
     `git diff main <branch>`) is deleted under the default 0-day window;
   - **window enforcement:** with an explicit `--days N` (N > 0), a
     fully-merged branch younger than the N-day window is preserved;
   - **unmerged branch preserved:** a branch with content NOT in main
     (non-empty diff) is never deleted regardless of age;
   - **dirty worktree refusal:** `cleanup` refuses (non-zero exit, no
     deletion) when a worktree for a candidate branch has uncommitted
     changes, without needing `--force` semantics that lanes could reach.
2. `make test-shell` exit 0 (full bats suite incl. the new cases).
3. Teardown dispatch end-to-end: the orchestrator runs the existing
   Teardown pattern (worktree-conventions.md step 5) post-merge and
   invokes `bash scripts/worktrees.sh cleanup` after `remove`; the
   merged branch is gone post-run, the DIA-096 deny list is byte-
   identical to its pre-change state.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
