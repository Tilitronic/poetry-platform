## Purpose

Close the worktree-lifecycle loop: after the squash-merge + worktree
removal, the developer needs one command that safely deletes the
`feature/*` branches whose rollback window has elapsed, while skipping
anything that is still live, still unmerged, still young, or still dirty.

## ADDED Requirements

### Requirement: Cleanup subcommand on the lifecycle CLI

The `worktrees.sh` CLI SHALL expose a `cleanup` subcommand. It SHALL
operate only on `feature/*` local branches; `main`/`master` SHALL NOT be
candidates. The subcommand SHALL be a pure-local operation (no `git
fetch`, no remote reads).

#### Scenario: main/master never considered

- **WHEN** `cleanup` is invoked in a repo that has `main` and
  `feature/DIA-999-old` branches, both older than the window
- **THEN** only `feature/DIA-999-old` is considered; `main` is never a
  candidate (seam: CLI public entry point `worktrees.sh cleanup`).

#### Scenario: currently-checked-out branch skipped

- **WHEN** `cleanup` is run from a worktree whose current branch is a
  `feature/*` branch that would otherwise be a deletion candidate
- **THEN** the checked-out branch is skipped with a stderr warning and
  the scan continues (seam: CLI exit code + stderr channel).

### Requirement: Two-pass classification (merge check then age check)

The subcommand SHALL classify each `feature/*` local branch via a
two-pass scan. Pass 1 (merge check) SHALL use `git merge-base --is-ancestor
<branch> main` as a fast reject AND THEN `git diff main <branch>` emptiness
as the squash-merge parity check (because `is-ancestor` alone misses
squash-merged branches). Pass 2 (age check) SHALL use the branch-tip
commit date and compare it to the configured age window.

#### Scenario: squash-merged branch detected via diff emptiness

- **WHEN** a `feature/*` branch was squash-merged into `main` (so
  `is-ancestor` returns false but `git diff main <branch>` is empty)
- **THEN** the branch is classified as merged (seam: classification
  predicate).

#### Scenario: genuinely unmerged branch preserved

- **WHEN** a `feature/*` branch has commits that are not ancestors of
  `main` AND `git diff main <branch>` is non-empty
- **THEN** the branch is classified as unmerged (seam: classification
  predicate).

### Requirement: Age-window configuration with flag > env > default precedence

The age window SHALL default to 0 days (immediate post-merge cleanup —
the merge-content check plus the dirty-worktree protection are the
safety gates; age adds only delay). The user MAY opt into a conservative
grace window via the `WORKTREES_CLEANUP_DAYS` environment variable. The
user MAY override both via the `--days N` CLI flag. Precedence:
`--days N` > `WORKTREES_CLEANUP_DAYS` > default 0 (mirrors the
`WORKTREES_FORCE`/`--force` pattern on `remove`). A non-integer
`--days` value SHALL be a usage error (exit 2).

#### Scenario: flag beats env

- **WHEN** `WORKTREES_CLEANUP_DAYS=99` is set AND `cleanup --days 0` is
  invoked
- **THEN** the effective window is 0 days (flag wins) (seam: CLI arg
  parsing).

#### Scenario: env used when no flag

- **WHEN** `WORKTREES_CLEANUP_DAYS=30` is set AND no `--days` flag is
  passed
- **THEN** the effective window is 30 days (seam: CLI arg parsing).

#### Scenario: default used when neither set

- **WHEN** neither `WORKTREES_CLEANUP_DAYS` nor `--days` is set
- **THEN** the effective window is 0 days (every merged branch is
  eligible for immediate deletion) (seam: CLI arg parsing).

#### Scenario: non-integer --days is usage error

- **WHEN** `cleanup --days foo` is invoked
- **THEN** exit code is 2 and usage is printed to stderr (seam: CLI arg
  parsing).

### Requirement: Per-candidate action matrix

For each candidate the subcommand SHALL apply exactly one of the
following actions, in this order of precedence:

1. `unmerged + young` -> silent skip (active lane; no output).
2. `merged + young` -> skip with report (age below window).
3. `unmerged + old` -> skip with report (still has unmerged work).
4. `merged + old + worktree-dirty` -> skip with report
   `would-skip (worktree dirty)`.
5. `merged + old + worktree-clean` -> remove worktree THEN delete branch.
6. `merged + old + no worktree` -> delete branch (and the linked worktree
   dir if still present on disk).

#### Scenario: merged + old + no worktree deletes branch

- **WHEN** a `feature/*` branch is merged, older than the window, and has
  no linked worktree
- **THEN** the branch is deleted and the exit code reflects success
  (seam: CLI exit code + post-run repo state).

#### Scenario: merged + old + worktree-clean removes worktree then deletes

- **WHEN** a `feature/*` branch is merged, older than the window, and has
  a linked worktree that is clean
- **THEN** the worktree is removed first, THEN the branch is deleted;
  both the worktree directory and the branch are gone post-run (seam:
  CLI exit code + post-run repo state + post-run filesystem state).

#### Scenario: merged + old + worktree-dirty skips and reports

- **WHEN** a `feature/*` branch is merged, older than the window, and has
  a linked worktree with uncommitted changes
- **THEN** the branch is NOT deleted, the worktree is NOT removed, a
  `would-skip (worktree dirty)` message is emitted on stderr, and the
  scan continues to the next candidate (seam: stderr channel + CLI exit
  code 0).

#### Scenario: unmerged + old preserved with report

- **WHEN** a `feature/*` branch is unmerged and older than the window
- **THEN** the branch is preserved and a skip reason is reported (seam:
  stdout/stderr reporting channel).

#### Scenario: merged + young preserved with report

- **WHEN** a `feature/*` branch is merged but younger than the configured
  window (reachable only when an explicit window is set via `--days N`
  or `WORKTREES_CLEANUP_DAYS=N` with N > 0 — the default is 0 so
  merged branches are never "young" under the default)
- **THEN** the branch is preserved and a skip reason is reported (seam:
  stdout/stderr reporting channel).

#### Scenario: unmerged + young silent skip

- **WHEN** a `feature/*` branch is unmerged and younger than the window
- **THEN** the branch is preserved and no report is emitted for it
  (active lane — silent) (seam: stdout/stderr reporting channel).

### Requirement: Fail-safe per candidate

The subcommand SHALL NOT let a failure on one candidate abort the whole
scan. Any `git` operation failure on a single candidate SHALL be reported
on stderr as a warning, that candidate SHALL be skipped, and the scan
SHALL continue to the next candidate. The subcommand SHALL never delete a
branch or remove a worktree when any prerequisite check for that
candidate failed.

#### Scenario: per-candidate failure does not abort scan

- **WHEN** one candidate triggers a git failure during classification
- **THEN** that candidate is skipped with a stderr warning and the rest
  of the scan completes normally (seam: stderr channel + CLI exit code).

#### Scenario: concurrent lock failure is a skip, not a delete

- **WHEN** a candidate's git operation fails with a lock error (another
  process holds the git lock)
- **THEN** the candidate is skipped and reported on stderr; no delete is
  attempted (seam: stderr channel).

### Requirement: Exit-code contract

The subcommand SHALL exit 0 when the overall run completed successfully
— including runs where every candidate was intentionally skipped (dirty,
unmerged, young, checked-out). The subcommand SHALL exit non-zero ONLY on
hard-abort conditions: the working directory is not a git repository, or
no `main` branch exists in the repo.

#### Scenario: all-ok and all-intentionally-skipped runs exit 0

- **WHEN** `cleanup` runs to completion with any combination of
  successful deletes and intentional skips
- **THEN** exit code is 0 (seam: CLI exit code).

#### Scenario: not-a-git-repo exits non-zero

- **WHEN** `cleanup` is invoked outside any git repository
- **THEN** exit code is non-zero (seam: CLI exit code).

#### Scenario: no main branch exits non-zero

- **WHEN** `cleanup` is invoked in a repo that has no `main` branch
- **THEN** exit code is non-zero (seam: CLI exit code).

### Requirement: Dry-run mode

The subcommand SHALL accept a `--dry-run` flag. Under `--dry-run` the
subcommand SHALL list the candidates it would delete, with the same
reasons it would use, and SHALL make zero side effects (no branch
deletion, no worktree removal, no filesystem changes).

#### Scenario: dry-run lists would-be-deleted with no side effects

- **WHEN** `cleanup --dry-run` is invoked on a repo that has one merged
  and old `feature/*` branch
- **THEN** the branch is listed as a would-delete candidate AND the
  branch still exists post-run AND no worktree is removed (seam: CLI
  stdout + post-run repo state).

### Requirement: DIA-096 invariant preserved

The subcommand SHALL maintain the existing DIA-096 policy boundary:
`git branch -d`/`-D` remain denied for lanes at the OpenCode permission
config layer, and the cleanup script itself is the policy boundary (same
invariant as `remove` — the permission config gates the OUTER command,
so the script enforces its own boundaries; see
`docs/dev-infra-audit/worktree-conventions.md` lines 193-197). The
subcommand SHALL NOT introduce any new lane-accessible destructive
operation. Invocation is via the existing orchestrator-dispatched
Teardown lane (worktree-conventions.md step 5, post-merge) AND may also
be run manually by the developer.

#### Scenario: cleanup is orchestrator-dispatched teardown AND developer-runnable

- **WHEN** the orchestrator dispatches the Teardown lane after a
  successful merge AND the lane runs `bash scripts/worktrees.sh cleanup`
- **THEN** the outer command is gated by the same permission rule that
  gates `bash scripts/worktrees.sh remove` — no new allow rule is added
  for lanes, and the internal `git branch -d` remains denied at the
  config layer (the script's own safety gates — merge check,
  dirty-worktree skip — are the per-candidate protection) (seam:
  OpenCode permission config, unchanged).
