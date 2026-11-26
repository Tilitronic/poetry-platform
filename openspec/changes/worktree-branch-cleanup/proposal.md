## Why

`scripts/worktrees.sh` today only creates, removes, and lists worktrees; it does
not touch branches. After the squash-merge the worktree is removed but the
`feature/*` branch is kept for the rollback window (DIA-096). Once that window
elapses the developer is left with a manual, error-prone `git branch -d`
ritual per branch — and no single command that answers "which branches are
safe to delete right now, which ones should I keep, and why." A cleanup
subcommand closes the lifecycle gap: one invocation that scans the repo,
classifies each `feature/*` branch by merge status + age, and deletes the
ones past the window while skipping everything else with a clear reason.

## What Changes

- Add a `cleanup` subcommand to `scripts/worktrees.sh`. New entry point in
  the existing lifecycle CLI; reuses `resolve_worktree_path`,
  `path_from_branch`, env-var convention, and the one-bats-suite test seam.
- Two-pass classify-then-act scan over `feature/*` local branches:
  - merge check: `git merge-base --is-ancestor <branch> main` (fast reject)
    THEN a tree-subset squash-parity check — every file on the branch
    exists on main with identical content (git ls-tree + git diff
    --quiet; NOT whole-tree diff emptiness, which fails once main has
    accumulated content from other squash merges) — catching squash-merged
    branches, which `is-ancestor` alone misses.
  - age check: branch-tip commit date older than N days (configurable).
  - worktree presence check (for the `merged+old+worktree-clean` case).
- Default window 0 days (immediate post-merge cleanup); override precedence
  `--days N` flag > `WORKTREES_CLEANUP_DAYS` env var > default 0. The
  `--days` flag and the env var remain for opt-in conservative runs (e.g.,
  `--days 30` for a 30-day grace window); only the default changes from 7
  to 0. The merge-content check (the tree-subset squash-parity check)
  plus the dirty-worktree protection are the real safety gates; age adds
  only delay.
  Mirrors the `WORKTREES_FORCE`/`--force` pattern on `remove`.
- Matrix of actions per candidate:
  - `merged + old + no worktree` -> delete branch (and linked worktree dir
    if still present).
  - `merged + old + worktree-clean` -> remove worktree then delete branch.
  - `merged + old + worktree-dirty` -> SKIP + report `would-skip (worktree dirty)`.
  - `unmerged + old` -> SKIP + report (still has unmerged work).
  - `merged + young` -> SKIP + report (age below window).
  - `unmerged + young` -> silent skip (active lane).
- Never delete `main`/`master`; never delete a currently-checked-out branch
  (git would refuse anyway — script warns on stderr and continues).
- Fail-safe per candidate: any git-op failure on one candidate warns on
  stderr and continues the scan; never deletes if any check fails. Exit 0
  when everything either succeeded or was intentionally skipped; non-zero
  only on hard-abort conditions (not-in-git-repo, no main branch).
- Local git state only — no `git fetch`, no remote checks (off-line-safe,
  no network side effects). Concurrent cleanup handled by git's own locking;
  a lock error is treated as a per-candidate failure.
- `--dry-run` lists would-be-deleted candidates, no side effects.
- Non-integer `--days` is a usage error (exit 2).
- One new bats suite under `scripts/__tests__/worktrees.bats` (9 scenarios,
  real isolated git repo fixture under `$BATS_TEST_TMPDIR`).
- DIA-096 invariant unchanged: `git branch -d`/`-D` remains denied for
  lanes; the cleanup script is the same policy boundary as `remove` (the
  permission config gates the OUTER command, so the script enforces its
  own boundaries — see `docs/dev-infra-audit/worktree-conventions.md`
  lines 193-197). Invocation is orchestrator-dispatched via the existing
  Teardown lane (worktree-conventions.md step 5, post-merge) AND may be
  run manually by the developer; no new lane-accessible destructive
  operation is introduced.

## Teardown integration

The `cleanup` subcommand is the missing piece of the existing "Teardown"
step 5 in `docs/dev-infra-audit/worktree-conventions.md`. Today the
teardown dispatch runs only `scripts/worktrees.sh remove` (worktree dir
gone, branch kept for rollback). With `cleanup` added, the teardown
dispatch becomes `remove` THEN `cleanup` — closing the lifecycle loop
that has been leaving ~10 merged `feature/*` branches behind per batch
(DIA-172/DIA-174 post-merge drift). The orchestrator dispatches this as
part of the existing Teardown pattern — no new dispatch contract, no
cron, no automatic scheduling; the dispatch runs after a successful
merge as a deliberate post-merge teardown step.

## Capabilities

### New Capabilities

- `worktree-branch-cleanup`: the classify-then-act scan and per-branch
  lifecycle close-out (merge check, age check, worktree presence,
  fail-safe skip, dry-run, env/flag configuration). One new subcommand on
  the existing `worktrees.sh` CLI; one new bats suite.

### Modified Capabilities

(none — no existing spec-level behavior changes. `create`/`remove`/`list`
retain their current contracts.)

## Impact

- **Code:** `scripts/worktrees.sh` (one new subcommand + helpers),
  `scripts/__tests__/worktrees.bats` (one new suite, reuses the existing
  `setup_worktree_repo` fixture pattern).
- **Docs:** `docs/dev-infra-audit/worktree-conventions.md` (Cleanup policy
  section gains the new subcommand reference; DIA-096 mapping unchanged).
- **APIs / dependencies:** none. Purely local git state; no remote calls.
- **Systems:** invoked by the orchestrator via the existing Teardown
  dispatch (worktree-conventions.md step 5, post-merge) AND may be run
  manually by the developer. DIA-096 is unaffected: `git branch -d`/
  `-D` remain denied for lanes; the script = policy boundary (same as
  `remove`); the permission config gates the OUTER command, the script
  enforces its own boundaries.
- **Rollback plan:** the subcommand is additive; removing it reverts to
  today's state. Within a run, the fail-safe per-candidate model means a
  bad run cannot delete more than the developer would have deleted by hand
  — each failed check is a SKIP, not a delete. `--dry-run` gives the
  developer a zero-risk preview before any actual run.

## Testing Decisions

**What makes a good test for this change.** This is a shell CLI that
orchestrates real `git` operations against real repo state, so the test
invariant is "real git, isolated fixture" — the same pattern the existing
`worktrees.bats` suite already uses (see
`scripts/__tests__/worktrees.bats` T1-T19, `setup_worktree_repo` helper).
A good test for cleanup is therefore a bats test that spins up a fresh
`git init -b main` repo under `$BATS_TEST_TMPDIR`, stages the merge/age/
worktree state under test, invokes the script, and asserts on (a) the
post-run repo state (branch present/absent, worktree dir present/absent),
(b) stdout/stderr messages (reason per skip, list of candidates under
dry-run), and (c) the exit code. Mocks of git are the wrong tool here —
they would hide the exact failure modes the feature is designed to guard
against (race with a dirty worktree, squash-merge not detected by
`is-ancestor` alone, etc.).

**Modules tested.** One module: the `cleanup` subcommand and its helpers
(classify, age check, merge check, dry-run path, env/flag precedence,
error table). The existing `create`/`remove`/`list` subcommands are not
touched and are not in scope — their existing T1-T19 coverage is
unchanged. The new tests live in the SAME bats file
(`scripts/__tests__/worktrees.bats`) to keep the lifecycle CLI's test
surface in one place and to reuse the `setup_worktree_repo` fixture and
the `test-helper.bash` assert helpers (`assert_output_contains`, etc.).

**Prior art.** `scripts/__tests__/worktrees.bats` (T1-T19 — the existing
lifecycle suite, real-isolated-repo fixture pattern),
`scripts/__tests__/session-log.bats` (bats + test-helper.bash convention),
`Makefile` target `test-shell` (how the suite is invoked in CI and
pre-work gates). The 9 acceptance scenarios from the interview are the
test list; every scenario maps to one bats `@test`.

**Coverage target (acceptance).** Nine scenarios, one bats `@test` each,
all under the existing `make test-shell` gate:

1. merged + old + worktree present and clean -> branch deleted AND linked
   worktree dir removed.
2. unmerged + old -> branch preserved, skip reason reported.
3. merged + young (below age window) -> branch preserved, skip reason
   reported.
4. merged + old + worktree dirty -> skip + continue scan + exit 0 (never
   lose work).
5. `--dry-run` -> lists would-be-deleted candidates, no side effects
   (branch and worktree both preserved).
6. exit codes: all-OK path -> exit 0; not-a-git-repo -> non-zero.
7. flag/env precedence: `--days 30` beats `WORKTREES_CLEANUP_DAYS=99`;
   env alone respected; neither -> default 0 (immediate post-merge
   cleanup).
8. linked worktree dir is removed when the branch it belonged to is
   deleted (the `merged+old+worktree-clean` path).
9. main-tree guard: never deletes the currently-checked-out branch; never
   considers `main`/`master` as candidates.

Plus the `make test-shell` target exits 0 with the new suite included.
