## Context

See `proposal.md` for motivation. This change adds one new subcommand
(`cleanup`) to the existing `scripts/worktrees.sh` lifecycle CLI and one
new bats suite in the existing `scripts/__tests__/worktrees.bats` file.
No module boundary changes, no new technology, no cross-cutting concern
— this is implementation-level design within a single existing shell
script.

Governing constraints (do not override in this design):

- `docs/dev-infra-audit/worktree-conventions.md` lines 172-179 (Cleanup
  policy): worktree removal is a post-merge step via
  `scripts/worktrees.sh remove`; the branch is kept for the rollback
  window (configurable, default 0); a dirty worktree is never removed
  without `--force`, and `--force` needs `WORKTREES_FORCE=1` (lanes
  must never set it). The cleanup subcommand MUST extend this policy
  consistently — the script remains the policy boundary.
- `docs/dev-infra-audit/worktree-conventions.md` lines 183-197 (DIA-096
  safe/destructive mapping): `git branch -d`/`-D` remain denied for
  lanes at the OpenCode permission config layer; the script enforces
  the same boundaries itself. Cleanup invocation is via the existing
  orchestrator-dispatched Teardown lane (step 5, post-merge) AND may
  also be run manually by the developer — no new lane-accessible
  destructive operation is introduced. The "script is the policy
  boundary" invariant on lines 193-197 MUST be preserved.

## Goals / Non-Goals

**Goals:**

- One new subcommand `cleanup` on the existing `worktrees.sh` CLI that
  performs a two-pass classify-then-act scan and applies the interview's
  action matrix.
- One new bats suite in the existing `scripts/__tests__/worktrees.bats`
  file, using the existing `setup_worktree_repo` isolated-git-repo
  fixture pattern. 9 scenarios, one bats `@test` each.
- Zero changes to `create` / `remove` / `list` contracts.
- Zero changes to DIA-096 (outer command gating, deny list, lane vs
  developer boundary).
- Zero network I/O (local git state only).
- Fail-safe per candidate: one bad candidate never aborts the rest.

**Non-Goals:**

- Remote-side cleanup (no `git fetch`, no `git push --delete`, no origin
  checks).
- Automatic scheduling (cron / CI trigger). Cleanup is invoked via the
  existing orchestrator-dispatched Teardown lane (worktree-conventions.md
  step 5, post-merge) AND may be run manually by the developer; the
  dispatch runs after a successful merge as a deliberate post-merge
  teardown step. A cron/CI trigger is a separate concern and would
  require its own spec.
- Handling of non-`feature/*` branches (release, hotfix, personal). Out
  of scope; the filter is a hard rule.
- Interactive selection UI (picker, confirm-per-branch prompt). The
  contract is "scan + report + act," driven by flags and env.

## Decisions

### D1: Single-file extension, not a new script

**Decision:** add `cmd_cleanup` + a small set of helpers to
`scripts/worktrees.sh` rather than creating `scripts/worktrees-cleanup.sh`.

**Rationale:** the subcommand is one lifecycle phase of the same CLI —
it reuses `resolve_worktree_path`, `path_from_branch`, the env-var
naming convention, the help/usage surface, and the exit-code contract
(0 / 1 / 2). Splitting it into a second script duplicates the helper
surface and the bats fixture. The interview confirmed this ("cleanup is
a NEW SUBCOMMAND of scripts/worktrees.sh — reuse helpers, one bats
suite, one lifecycle").

**Alternatives considered:**

- New script `scripts/worktrees-cleanup.sh` — rejected: duplicate
  helpers, duplicate bats setup, two entry points for what is one
  lifecycle.
- Python rewrite — rejected: the rest of the CLI is bash-3 compatible,
  the test harness is bats, and bash-3 compatibility is a contract
  (`scripts/worktrees.sh` header documents this).

### D2: Two-pass merge check (is-ancestor THEN tree-subset squash parity)

**Decision:** classify a branch as merged only when BOTH conditions
hold: (a) `git merge-base --is-ancestor <branch> main` returns true, OR
(b) the tree-subset squash-parity check passes: every file tracked on
the branch exists on `main` with identical content (`git ls-tree -r
--name-only <branch>`, then `git diff --quiet refs/heads/main <branch> --
<paths>`). The fast path is `is-ancestor` (because the tree-subset check
on a large tree is expensive); the subset check runs only when
`is-ancestor` is false, to catch squash-merged branches.

**Rationale:** `is-ancestor` alone misses squash-merged branches
(confirmed in interview). The tree-subset check is the exact squash
semantics ("nothing in the branch is absent from main"). A whole-tree
`git diff main <branch>` emptiness check would be correct only in a repo
where `main` never grows beyond one branch's content; in the realistic
post-batch state `main` already contains the squashed content of many
previously merged branches, so a whole-tree diff would misclassify a
genuinely squash-merged branch as unmerged. The short-circuit keeps the
common case (cleanly merged fast-forward or normal merge commit) fast
while closing the squash gap.

**Alternatives considered:**

- Whole-tree `git diff main <branch>` emptiness — rejected: requires the
  two trees to be IDENTICAL, so it fails once `main` has accumulated
  content from other squash merges (the realistic post-batch state).
- Custom cherry detection (`git cherry main <branch>`) — rejected:
  `cherry` has its own edge cases with rebases and reverts; the
  tree-subset check is the exact semantic the developer wants ("nothing
  in the branch is absent from main").

### D3: Age check via branch-tip commit date

**Decision:** use the branch-tip commit's committer date (`git log -1
--format=%ct <branch>`) and compare it to the configured window.

**Rationale:** the rollback window the policy refers to is the window
since the branch's last activity, not the window since its creation.
Committer date reflects the actual tip rewrite. For our squash-merge
workflow the tip is never rebased onto main, so committer and author
dates track the same developer action; the implementation reads `%ct`
(committer), and the bats fixtures set both dates identically, so the
choice is not observable in the tests.

**Alternatives considered:**

- Author date (`%at`) — not used: in this workflow (no rebase onto main)
  it tracks the same developer action as the committer date, so `%ct` —
  the actual tip-rewrite timestamp — is the more precise signal and is
  what the implementation already reads.
- Branch creation date — rejected: not directly queryable without
  reflog, and reflog is local+ephemeral.

### D4: Per-candidate fail-safe (not whole-run fail-fast)

**Decision:** any git operation failure on one candidate warns on
stderr, skips that candidate, and continues the scan. The whole run
aborts non-zero ONLY on the two pre-scan hard-abort conditions
(not-in-git-repo, no main branch).

**Rationale:** the scan is over many independent candidates; a transient
lock error or corrupted ref on one branch must not prevent cleanup of
the rest. The developer's mental model is "show me what you can safely
do and tell me what you could not." The interview confirmed this
("fail-safe per candidate — any git op failure -> SKIP + stderr
warning, continue scan").

**Alternatives considered:**

- Fail-fast on first error — rejected: hides progress on the rest of
  the candidates; the developer would have to rerun after every single
  failure.

### D5: No `--force` on cleanup; dirty worktree is always a skip

**Decision:** unlike `remove`, `cleanup` has no `--force` flag. A
candidate whose linked worktree is dirty is ALWAYS skipped (with a
`would-skip (worktree dirty)` report). The developer MUST use
`worktrees.sh remove --force` (with `WORKTREES_FORCE=1`) first if they
really want to discard the dirty work.

**Rationale:** `cleanup` is the automated, scan-many-candidates path —
the blast radius of an accidental force is too large here. The existing
`remove --force` path preserves the developer escape hatch for
individual dirty worktrees while keeping the invariant "cleanup never
loses work." The interview confirmed this (the dirty case is a SKIP,
never a delete).

**Alternatives considered:**

- Mirror `remove`'s `--force`/`WORKTREES_FORCE=1` pair on cleanup —
  rejected: the scan-many-candidates surface makes force too dangerous.
  Per-branch force via `remove` already exists.

### D6: Default window 0 days; flag > env > default precedence

**Decision:** default 0 days (immediate post-merge cleanup),
`WORKTREES_CLEANUP_DAYS` env var overrides to opt into a conservative
grace window, `--days N` flag overrides both. A non-integer `--days` is
a usage error (exit 2). Mirrors `WORKTREES_FORCE`/`--force` pattern on
`remove`.

**Rationale:** cleanup runs as post-merge teardown, so branches should
be deleted immediately after a successful merge, not after a 7-day
window. The merge-content check (the tree-subset squash-parity check)
plus the dirty-worktree protection are the real safety gates; age adds
only delay. The `--days` flag and the env var REMAIN for opt-in conservative
runs (e.g., `--days 30` for a 30-day grace window); only the default
changes. Consistency with the rest of the CLI is preserved (interview
confirmed the flag > env > default pattern).

**Alternatives considered:**

- Default 7 days (original interview answer) — rejected by the
  developer at Phase 3 confirmation: the 7-day window only delays the
  inevitable and lets merged branches drift in the repo; the safety
  gates are merge-verification + dirty-worktree skip, not age.

### D7: Invocation via orchestrator-dispatched Teardown lane (+ manual)

**Decision:** cleanup is invoked by the orchestrator as part of the
existing Teardown dispatch pattern (worktree-conventions.md step 5,
post-merge) AND may also be run manually by the developer. The teardown
dispatch today runs only `scripts/worktrees.sh remove`; with this
change it becomes `remove` THEN `cleanup`. No new dispatch contract, no
cron, no automatic scheduling.

**Rationale:** the Teardown step has been documented since DIA-100 but
never actually executed after the DIA-172/DIA-174 batches — the
operational gap the developer named in the Phase 3 review. Closing it
here (rather than introducing a separate "after-merge cleanup" lane)
keeps the worktree lifecycle in one dispatch pattern and reuses the
Teardown lane the orchestrator already knows how to invoke. The
developer escape hatch (manual invocation) is preserved so a lane that
cannot reach the orchestrator-dispatched teardown (e.g., a worktree
that needs special handling) can still be cleaned up by hand.

**DIA-096 interaction:** unchanged. `git branch -d`/`-D` remain denied
for lanes at the config layer; the permission config gates the OUTER
command (`bash scripts/worktrees.sh cleanup ...`), and the script
enforces its own boundaries internally — same invariant as `remove`
(worktree-conventions.md lines 193-197). The script is the policy
boundary; no new allow rule is added for lanes.

**Alternatives considered:**

- Developer-only invocation (original interview answer) — rejected by
  the developer at Phase 3 confirmation: the Teardown step was never
  being executed, and the cleanup subcommand was therefore dead code
  for the common post-merge case. Making cleanup part of the Teardown
  dispatch closes the gap without inventing a new lane.
- Cron / scheduled sweep — rejected: the branch is either safely
  merged (delete immediately) or it is not (the script skips). A sweep
  adds scheduling surface for no safety gain.

## Seams

Tests live at the same public boundaries the existing suite already
uses — no new seams are introduced:

1. **CLI entry point** (`worktrees.sh cleanup ...`) — seam for arg
   parsing, flag/env precedence, usage error, `--dry-run`, and the
   overall exit-code contract (scenarios in spec.md: main/master guard,
   checked-out skip, flag/env precedence, non-integer --days, all-ok
   exit 0, not-in-git-repo non-zero, no-main non-zero, dry-run).
2. **Per-candidate classification predicate** (merged? old? dirty?
   has-worktree?) — seam for the two-pass merge check, age check, and
   the action matrix (scenarios in spec.md: squash-merged detection,
   genuinely unmerged preservation, merged+old+worktree-clean path,
   merged+old+worktree-dirty skip, merged+young skip, unmerged+young
   silent skip).
3. **Stdout / stderr reporting channel** — seam for the per-skip
   reason messages and the dry-run listing (scenarios in spec.md:
   dirty-skip report, unmerged-skip report, young-skip report, dry-run
   listing).
4. **Post-run repo + filesystem state** — seam for "was the branch
   actually deleted," "was the linked worktree dir actually removed,"
   "was a dirty worktree preserved" (scenarios in spec.md: all six
   action-matrix outcomes, dry-run side-effect-free check).

All 9 acceptance scenarios live at these four seams, in the existing
`scripts/__tests__/worktrees.bats` file using the existing
`setup_worktree_repo` fixture and `test-helper.bash` assert helpers.

## Risks / Trade-offs

- **Risk: the tree-subset check is expensive on large trees.**
  Mitigation: run it only as the slow path when `is-ancestor` rejects;
  the common fast path stays O(1). If the slow path becomes a problem
  in very large repos, the mitigation is to cache the diff result per
  candidate (trivial future optimization, not preempted now — YAGNI).
- **Risk: concurrent cleanup vs. concurrent create.** A lane may be
  creating a worktree on a branch the cleanup scan is considering.
  Mitigation: the per-candidate fail-safe (D4) plus git's own lock
  file mean a race surfaces as a candidate skip with a stderr warning,
  not as lost work. The developer reruns cleanup; the branch will be
  young on the next pass and silently preserved.
- **Risk: squash-merge parity via the tree-subset check can be fooled by
  a branch that reverts its own changes before merge.** Mitigation: same
  semantics the developer already uses to decide "is this branch
  effectively merged" by eye — nothing is deleted that would surprise
  them. Documented in the `cleanup --help` output.
- **Trade-off: no remote checks = offline-safe but blind to
  origin-side deletions.** Accepted — remote reads add latency,
  break offline use, and the policy boundary is "local state is
  authoritative." A separate remote-gc command can be added later
  if needed (out of scope for this change).

## Migration Plan

1. Land the new subcommand + tests in a single commit; `make test-shell`
   must pass with the 9 new scenarios included.
2. No migration of existing state — cleanup is additive. The default
   window of 0 means an immediate first run will clean up every
   already-merged `feature/*` branch (which is the desired outcome:
   closes the DIA-172/DIA-174 post-merge drift).
3. Rollback: revert the commit; the pre-cleanup state is restored
   exactly (no schema, no persisted state).
4. Teardown dispatch update: the orchestrator Teardown dispatch pattern
   (worktree-conventions.md step 5) gains the `cleanup` step after
   `remove`. Documented in worktree-conventions.md alongside the new
   subcommand reference.
5. Developer notification: a one-line note in the next dev-standup that
   `worktrees.sh cleanup` exists; the existing `docs/dev-infra-audit/
worktree-conventions.md` Cleanup policy section is updated to
   reference it.

## Open Questions

None. All decisions that would affect scope, approach, or task
breakdown were resolved in the interview (DIA-177 Phase 3).
