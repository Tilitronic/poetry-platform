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
rollback window is unbounded in practice: nothing ever deletes those branches
after the window expires, because branch deletion is developer-only
(`git branch -d`/`-D` denied for lanes, DIA-096) and there is no scripted
path. As of 2026-08-14 the repo holds 10 leftover feature branches
(`feature/diaXXX-*`) and 13 worktrees (12 `feature/dia132-*`,
`feature/dia133-*`, `feature/dia134-*`, `feature/dia135-*` plus a nested
selfcheck worktree) whose merged content is already on main.

**Proposed cleanup policy:** a branch is kept for a configurable rollback
window of N days (default 7). After the window, `scripts/worktrees.sh
cleanup` deletes the feature branch only when its content is FULLY merged
into main, verified by `git diff main <branch>` being empty (plus the branch
being merged by `git merge-base --is-ancestor`). Invocation is developer-only
(after the rollback window, per the DIA-100 cleanup policy), mirroring the
existing `remove --force` env-guard pattern (`WORKTREES_FORCE=1`): the script
is the policy boundary. Lanes still never delete branches directly - the
DIA-096 deny of `git branch -D *` stays unchanged; the script's own internal
deletion is governed by the script itself, same invariant as `remove`
(see `docs/dev-infra-audit/worktree-conventions.md` DIA-096 safe/destructive
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
rollback-window age check (default 7 days), developer-only invocation, and
bats tests. Does NOT touch the DIA-096 permission deny list (`git branch -D`
stays denied for lanes); the script remains the policy boundary.

## Verification

Prove the defect exists: `git branch -a` shows `feature/diaXXX-*` branches
whose content is fully merged into main still present; `git worktree list`
shows 13 stale worktrees.

Prove the fix:

1. Bats tests for the `cleanup` subcommand in
   `scripts/__tests__/worktrees.bats` (real git repo fixture):
   - **merged-only deletion:** a branch fully merged into main (empty
     `git diff main <branch>`) and older than the window is deleted;
   - **window enforcement:** a fully-merged branch younger than the N-day
     window (or the age check via a fake/mocked date or `--days 0`
     boundary) is preserved;
   - **unmerged branch preserved:** a branch with content NOT in main
     (non-empty diff) is never deleted regardless of age;
   - **dirty worktree refusal:** `cleanup` refuses (non-zero exit, no
     deletion) when a worktree for a candidate branch has uncommitted
     changes, without needing `--force` semantics that lanes could reach.
2. `make test-shell` exit 0 (full bats suite incl. the new cases).

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
