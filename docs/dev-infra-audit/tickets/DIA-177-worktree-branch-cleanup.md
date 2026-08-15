# DIA-177 - Worktree branch cleanup subcommand with merge verification

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-137 collided with origin/omo-slim-changes ticket DIA-137-orchestrator-routine-work-and-artifact-systems-research-lightweight-reliable-tools-to-simplify-operations-sibling-of-dia-136.md (different ticket). Renumbered to DIA-177. -->

---

id: DIA-177
title: "worktree branch cleanup subcommand with merge verification"
area: dev-infra
severity: Low
status: FIXED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-14
source: developer-request
date: 2026-08-14
created: 2026-08-14
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_fffbdce25ffe4zHF4PVNVKp6nN"
lane_id: ""
agent: "coder"
model: "opencode-go/deepseek-v4-flash"
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-177-worktree-branch-cleanup.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

**Problem:** we run parallel @coder lanes in separate git worktrees (DIA-100,
DIA-172, DIA-174). After a squash-merge to main, the teardown step
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
   - **dirty worktree refusal:** `cleanup` refuses (no deletion) when a
     worktree for a candidate branch has uncommitted changes: the
     candidate is an intentional skip (exit 0, `would-skip (worktree
dirty)` report, no `--force` flag reachable by lanes); non-zero exit
     is reserved for hard-abort conditions (not a git repo / no main) and
     per-candidate git failures (spec.md exit-code contract).
2. `make test-shell` exit 0 (full bats suite incl. the new cases).
3. Teardown dispatch end-to-end: the orchestrator runs the existing
   Teardown pattern (worktree-conventions.md step 5) post-merge and
   invokes `bash scripts/worktrees.sh cleanup` after `remove`; the
   merged branch is gone post-run, the DIA-096 deny list is byte-
   identical to its pre-change state.

## Fix

> Filled at fix time (2026-08-15, coder lane, worktree `.slim/worktrees/dia-177`,
> branch `omos/dia-177`). NOTE: the implementation landed pre-renumber under
> DIA-137 (commits f169711 feat + 8dadeb6 re-review hardening) and was
> renumbered to DIA-177 by DIA-153 (commit e1c69c1). This lane VERIFIED the
> existing implementation against the DIA-177 contract, filled the ticket, and
> committed the closure record. No re-implementation was needed.

**Delivered behavior** (`bash scripts/worktrees.sh cleanup [--days N] [--dry-run]`):

1. **Merged-only deletion (immediate post-merge, default window 0):** a
   `feature/*` branch is deleted when its content is fully on main — fast
   path `git merge-base --is-ancestor <branch> main`, slow path the
   tree-subset squash-parity check (`git ls-tree -r` on the branch, then
   `git diff --quiet refs/heads/main <branch> -- <paths>`). The tree-subset
   check is the refined form of the ticket's "empty `git diff main <branch>`"
   wording (design D2): it holds whenever the branch tree is a subset of
   main, so it stays correct in the realistic post-batch state where main
   already carries other merged content. Tests T20/T27; smoke test confirms a
   squash-merged branch with empty `git diff main <branch>` is deleted.
2. **Window precedence:** `--days N` flag > `WORKTREES_CLEANUP_DAYS` env >
   default 0 (design D6). `--days` non-integer or leading-zero is a usage
   error exit 2 (T26, T29).
3. **Dirty-worktree protection, NO `--force`:** a candidate with a linked
   worktree that has uncommitted changes is ALWAYS skipped with a
   `would-skip (worktree dirty)` report; `cleanup` has no `--force` flag at
   all (design D5). No deletion, no worktree removal, scan continues (T23).
4. **DIA-096 unchanged:** `git branch -D *` remains denied for lanes in
   `.opencode/opencode.jsonc` (byte-identical before/after); the script is
   the policy boundary, same invariant as `remove` (verified in this lane).
5. **Invocation mirrors `remove`:** flag parsing, usage/exit-code contract
   (0 success / 1 runtime error / 2 usage) copied from `cmd_remove`.

**Exit-code contract resolution (deviation from ticket wording, spec-authoritative):**
the ticket Verification ORIGINALLY said dirty refusal exits non-zero, but the
REVIEWED openspec spec (re-review cycle 1/2, all findings verified-closed, commit
8dadeb6) resolves the exit-code contract as: exit 0 when every candidate was
handled or intentionally skipped (dirty, unmerged, young, checked-out);
non-zero ONLY on hard-abort (not a git repo / no main) or per-candidate git
FAILURE (broken ref, lock). A dirty worktree is an intentional skip, not a
failure — the refusal is the no-deletion + no-`--force` behavior, which is
implemented. T23/T25 encode this contract. CORRECTED IN THIS COMMIT (DIA-177
re-review cycle 1/2): the stale Verification bullet above was updated to match
the spec (exit 0 for intentional dirty skips; non-zero only for hard-abort /
per-candidate git failure) — the deviation is now resolved in the ticket text
itself, no spec change needed.

**Verification evidence (this lane, 2026-08-15):**

- `make test-shell` exit 0 — 343 bats tests pass (T1-T29 worktrees incl.
  T20-T29 cleanup cases; full suite incl. all other shell suites).
- `make test-config` exit 0.
- Smoke (isolated fixture under /tmp/opencode, NOT the real repo):
  `cleanup` deleted `feature/DIA-177-merged` (empty `git diff main
<branch>`), preserved `feature/DIA-177-unmerged` (non-empty diff) and
  `feature/DIA-177-dirty` (dirty linked worktree refused with
  `would-skip (worktree dirty)`).
- DIA-096 deny list byte-identical (no diff in `.opencode/opencode.jsonc`).

## Re-verify

> Pending @reviewer re-verification. Prior-review history: DIA-137 review
> findings were all verified-closed in re-review cycle 1/2 (commit 8dadeb6);
> no open findings carried into DIA-177. The single wording deviation above
> (ticket "non-zero exit" vs spec exit-0-for-intentional-skips) is documented
> for disposition.
>
> Re-review cycle 1/2 fixes applied (commit 057386d): Spec MAJOR fail-safe
> exit-code dispatch (named-var brc; any non-1 non-zero git failure -> stderr
> warn + skip), Standards MINOR per-path quoted diff (word-split false-merged
> fix), Spec MINOR Verification-bullet correction to the spec exit-code
> contract. New bats case T30 (mocked git diff exit 2). test-shell 344/344,
> test-config 56/56.
>
> Re-review RO fixes applied (commit 54c7fa5): RO-1 outer fail-safe warn now
> includes the exit code (`exited $rc`); RO-2 heredoc `<<EOF` replaced with
> a here-string `<<< "$paths"` (no delimiter-collision edge case, verified
> one-path-per-line with space filenames); RO-3 rc comment reworded. Same
> gates re-run: test-shell 344/344, test-config 56/56.
