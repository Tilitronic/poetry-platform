## 1. Arg parsing and hard-abort preconditions

- [ ] 1.1 Implement `cleanup` argument parsing (flag `--days N`, flag
      `--dry-run`, positional args rejected, non-integer `--days` is a
      usage error exit 2) and the hard-abort preconditions (not-in-git-repo
      -> non-zero exit; no `main` branch -> non-zero exit). Resolution
      order for the age window: `--days N` > `WORKTREES_CLEANUP_DAYS` >
      default 0.

  **Blocking edges:** none.

  **Acceptance criteria (user perspective):**
  - `worktrees.sh cleanup --days foo` prints usage on stderr and exits
    2; no other side effects.
  - Running cleanup outside a git repo exits non-zero with a clear
    stderr message.
  - Running cleanup in a repo with no `main` branch exits non-zero
    with a clear stderr message.
  - With neither env nor flag set, the effective window is 0 days
    (immediate post-merge cleanup; observable via a `--dry-run`
    invocation on a fixture repo — the listing reflects the 0-day
    window, so every merged branch is a candidate).
  - With `WORKTREES_CLEANUP_DAYS=30` and no flag, the effective
    window is 30 days.
  - With both env and `--days 30` set, the flag wins (effective
    window 30).
  - `make test-shell` still passes (no regressions to the existing
    `create`/`remove`/`list` suite).

  **One-context-window sizing:** arg parsing + two precondition
  checks + 5 bats tests (~100 lines of bash, ~120 lines of bats).

## 2. Candidate enumeration with main-tree and checked-out guards

- [ ] 2.1 Enumerate local `feature/*` branches as candidates; exclude
      `main`/`master` unconditionally; when the currently-checked-out
      branch is a `feature/*` candidate, skip it with a stderr warning and
      continue the scan.

  **Blocking edges:** depends on 1.1 (pre-scan guards must be in
  place before enumeration runs against the repo).

  **Acceptance criteria (user perspective):**
  - A repo with only `main` and no `feature/*` branches reports no
    candidates and exits 0.
  - A repo with `main`, `master`, and one `feature/*` candidate
    considers only the `feature/*` branch; `main` and `master` are
    never listed.
  - Running cleanup from a worktree whose current branch is a
    `feature/*` candidate produces a stderr warning for that branch
    and continues the scan (does not abort).
  - `make test-shell` still passes.

  **One-context-window sizing:** one enumeration helper + one guard
  helper + 3 bats tests (~80 lines of bash, ~90 lines of bats).

## 3. Two-pass merge-check predicate (squash parity)

- [ ] 3.1 Implement the merge predicate: `git merge-base --is-ancestor
<branch> main` fast path, then (only when that fails)
      `git diff main <branch>` emptiness as the squash-merge parity
      check. Integrate with candidate enumeration so each candidate is
      labeled `merged` or `unmerged` and an `unmerged` candidate is
      handled per the matrix (old: skip+report; young: silent skip).

  **Blocking edges:** depends on 2.1 (needs candidate enumeration +
  main-tree guard up).

  **Acceptance criteria (user perspective):**
  - A fast-forward merged branch is classified `merged`.
  - A normal merge-commit branch is classified `merged`.
  - A squash-merged branch (where `is-ancestor` returns false but
    `git diff main <branch>` is empty) is classified `merged`.
  - A genuinely unmerged branch is classified `unmerged`.
  - `unmerged + young` is silently skipped (no output for that
    candidate).
  - `unmerged + old` is skipped with a report message.
  - `make test-shell` still passes.

  **One-context-window sizing:** one classify helper + 5 bats tests
  (~90 lines of bash, ~140 lines of bats; squash fixture needs a
  deliberate `merge --squash` setup).

## 4. Action matrix: the act paths

- [ ] 4.1 Implement the act paths of the matrix for candidates that
      are `merged + old`: (a) no linked worktree -> delete branch (+
      remove linked worktree dir if still present on disk); (b) linked
      worktree present and clean -> remove worktree then delete branch;
      (c) linked worktree present and dirty -> SKIP with
      `would-skip (worktree dirty)` report, continue scan.

  **Blocking edges:** depends on 3.1 (needs the merge + age labels
  on each candidate).

  **Acceptance criteria (user perspective):**
  - A `merged + old` branch with no linked worktree is deleted; the
    branch no longer exists post-run.
  - A `merged + old` branch with a linked worktree that is clean has
    the worktree removed first, THEN the branch deleted; both are
    gone post-run.
  - A `merged + old` branch with a linked dirty worktree is skipped,
    the worktree is preserved, the branch is preserved, and a
    `would-skip (worktree dirty)` message is emitted on stderr; the
    scan continues to the next candidate.
  - `merged + young` branch (any worktree state) is preserved and a
    skip reason is reported.
  - `make test-shell` still passes.

  **One-context-window sizing:** act-path helpers + dirty-worktree
  detection + 5 bats tests (~150 lines of bash, ~180 lines of bats;
  dirty-worktree test needs to stage a change inside the linked
  worktree before invoking cleanup).

## 5. Per-candidate fail-safe + exit-code contract

- [ ] 5.1 Wrap each candidate's classify + act path in a per-candidate
      fail-safe: any git operation failure on one candidate warns on
      stderr, skips that candidate, and continues the scan. The overall
      run exits 0 when the scan completes (including all-intentionally-
      skipped runs). The run exits non-zero ONLY on the hard-abort
      preconditions from 1.1 (not-in-git-repo, no-main).

  **Blocking edges:** depends on 4.1 (fail-safe wraps the act paths).

  **Acceptance criteria (user perspective):**
  - When one candidate triggers a git failure mid-scan, that
    candidate is skipped with a stderr warning and the rest of the
    scan completes normally.
  - A concurrent-lock failure on one candidate is treated as a
    candidate skip (not a delete), stderr-warned, scan continues.
  - A run where every candidate was intentionally skipped (dirty /
    unmerged / young / checked-out) exits 0.
  - A run with a mix of successful deletes and intentional skips
    exits 0.
  - `make test-shell` still passes.

  **One-context-window sizing:** fail-safe wrapper + 3 bats tests
  (~80 lines of bash, ~130 lines of bats; one test injects a broken
  ref to simulate a candidate failure).

## 6. Dry-run mode

- [ ] 6.1 Implement `--dry-run`: run the full classify + act decision
      tree, but replace every act path with a report of what would
      happen. Zero side effects (no branch deletion, no worktree
      removal, no filesystem changes).

  **Blocking edges:** depends on 4.1 (dry-run short-circuits the act
  paths). Does NOT depend on 5.1 — fail-safe wrapping is orthogonal
  to dry-run.

  **Acceptance criteria (user perspective):**
  - With one `merged + old + no-worktree` candidate, `--dry-run`
    lists it as a would-delete candidate AND the branch still exists
    post-run.
  - With one `merged + old + worktree-clean` candidate, `--dry-run`
    lists it as a would-delete candidate AND the worktree directory
    still exists post-run AND the branch still exists post-run.
  - With one dirty-worktree candidate, `--dry-run` reports the
    would-skip reason; no filesystem changes.
  - `make test-shell` still passes.

  **One-context-window sizing:** dry-run branch through the act
  paths + 3 bats tests (~60 lines of bash, ~120 lines of bats).

## 7. Help surface + documentation update

- [ ] 7.1 Update `worktrees.sh --help` and the file-header comment to
      document the new `cleanup` subcommand (flags, env var, matrix, exit
      codes). Update `docs/dev-infra-audit/worktree-conventions.md`
      "Cleanup policy" section (lines 172-179) to reference the new
      subcommand; do NOT modify the DIA-096 mapping table (lines 183-197)
      — it remains unchanged.

  **Blocking edges:** depends on 4.1, 5.1, 6.1 (the surface is
  stable only once the behavior is finalized).

  **Acceptance criteria (user perspective):**
  - `worktrees.sh --help` lists `cleanup` with a one-line summary
    and mentions `--days`, `--dry-run`, `WORKTREES_CLEANUP_DAYS`.
  - `worktrees.sh cleanup --help` shows the full cleanup usage
    including the matrix and exit-code contract.
  - The worktree-conventions.md Cleanup policy section names the
    new subcommand; the DIA-096 mapping table is byte-identical to
    its pre-change state.
  - `make test-shell` still passes (documentation changes do not
    break anything; the new bats suite runs as part of the existing
    target).

  **One-context-window sizing:** help text + header comment +
  worktree-conventions.md diff + smoke test (~40 lines of bash /
  docs, no new bats tests — coverage already in 1.1-6.1).
