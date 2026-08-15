#!/usr/bin/env bats
# Unit tests for scripts/worktrees.sh (seam: lifecycle CLI, DIA-100).
#
# Strategy: unlike the Docker-mocked suites, worktrees.sh wraps REAL git
# commands (git worktree add/remove/list), so the FAKE-mock invariant is
# implemented by creating a REAL throwaway git repository inside
# $BATS_TEST_TMPDIR and copying the script into it. The repo fixture is
# fully isolated: `git init -b main` + one empty commit on main; the script
# derives ROOT from its own location, so every git invocation operates on
# the fixture repo, never the real repo.
#
# Cases:
#   T1  create -> exit 0, worktree dir + branch + isolated .opencode/session
#   T2  create invalid branch (no feature/ prefix) -> exit 1
#   T3  create duplicate local branch -> exit 1
#   T4  list shows branch + worktree path
#   T5  remove by branch -> exit 0, dir gone, branch KEPT (rollback window)
#   T6  remove dirty worktree (no --force) -> exit 1, worktree survives
#   T7  remove --force without WORKTREES_FORCE=1 -> exit 1 (lane cannot force)
#   T8  remove --force with WORKTREES_FORCE=1 -> exit 0, dir gone
#   T9  remove unknown target -> exit 1
#   T10 no command -> usage error (exit 2)
#   T11 remove refuses the main checkout path -> exit 1
#   T12 create refuses branch that exists on origin (fake git ls-remote)
#   T13 create bounded when origin unreachable (fake ls-remote sleeps; the
#       script's internal `timeout 5` caps the wait)
#   T14 remove by worktree PATH -> exit 0 + message shows path AND branch
#   T15 create --help -> usage (exit 2), not a branch-name error
#   T16 list forwards args to git worktree list (--porcelain works)
#   T17 create materializes .husky/_ in the worktree (husky shim, DIA-134)
#   T18 create fails loudly when the main tree has no .husky/_ (DD1)
#   T19 create's .husky/_ copy is a real directory, not a symlink (DD1)
#   T20 cleanup merged+old + clean linked worktree -> branch deleted, worktree dir removed
#   T21 cleanup unmerged preserved (old reported, young silent); worktrees survive
#   T22 cleanup merged+young preserved (below explicit window) with report
#   T23 cleanup merged+old dirty worktree -> skip + warn + scan continues + exit 0
#   T24 cleanup --dry-run lists would-be-deleted candidates, zero side effects
#   T25 cleanup exit codes: all-OK/skipped -> 0; candidate error / outside repo -> non-zero
#   T26 cleanup window precedence: --days flag > WORKTREES_CLEANUP_DAYS > default 0
#   T27 cleanup deletes branch AND leftover worktree dir on disk
#   T28 cleanup main-tree guard: checked-out candidate skipped, main/master never touched
#   T29 cleanup --days leading-zero value (008) is a usage error (exit 2),
#       never a bash arithmetic abort (F1 regression)
#   T30 cleanup per-candidate non-128 non-1 git failure (mocked `git diff`
#       exits 2) -> stderr warning + fail-safe skip + branch preserved +
#       run-level non-zero exit + scan continues (DIA-177 re-review F1)

load test-helper

bats_require_minimum_version 1.5.0

# setup_worktree_repo: fresh isolated git repo with the script copied in.
# Echoes the tree root.
setup_worktree_repo() {
  local tree="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$tree/scripts"
  cp "$SCRIPTS_DIR/worktrees.sh" "$tree/scripts/worktrees.sh"
  printf '.opencode/session/\n.worktrees/\n' > "$tree/.gitignore"
  if ! git -C "$tree" init -q -b main 2>/dev/null; then
    git -C "$tree" init -q
    git -C "$tree" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$tree" config user.email "bats@example.com"
  git -C "$tree" config user.name "bats test"
  # Commit the .gitignore so worktree checkouts carry it (mirrors the real
  # repo, where .gitignore is tracked — check-ignore in the worktree depends
  # on it).
  git -C "$tree" add .gitignore
  git -C "$tree" commit -q -m init
  # DIA-134 S1 (DD1): a husky-installed main tree HAS .husky/_ -- that is the
  # create step's copy source. Seed it so every create-success test (T1-T16)
  # runs against a realistic main tree; T18 removes it explicitly to exercise
  # the fail-loud absent-source path.
  seed_husky_shim "$tree"
  echo "$tree"
}

# mock_git_ls_remote: plants a fake `git` on PATH that intercepts ONLY
# `ls-remote` calls and delegates everything else to the real git binary
# (captured before the PATH prepend). Used to exercise the best-effort remote
# check in `create` without a network:
#   FAKE_LS_REMOTE_OUTPUT   canned ls-remote stdout (default: empty)
#   FAKE_LS_REMOTE_SLEEP    seconds the fake sleeps before answering
#                           (simulates an unreachable origin that hangs)
mock_git_ls_remote() {
  local real_git bindir
  real_git="$(command -v git)"
  bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat > "$bindir/git" <<FAKEGIT
#!/usr/bin/env bash
if [ "\${1:-}" = "ls-remote" ]; then
  if [ -n "\${FAKE_LS_REMOTE_SLEEP:-}" ]; then
    sleep "\$FAKE_LS_REMOTE_SLEEP"
  fi
  printf '%s\n' "\${FAKE_LS_REMOTE_OUTPUT:-}"
  exit "\${FAKE_LS_REMOTE_EXIT:-0}"
fi
exec "$real_git" "\$@"
FAKEGIT
  chmod +x "$bindir/git"
  PATH="$bindir:$PATH"
  export PATH
}

# mock_git_diff_exit_on_branch <code> <branch>: plants a fake `git` on PATH
# that intercepts `git diff` calls whose argument list contains <branch>
# (exiting with <code>) and delegates everything else -- including diffs on
# other branches -- to the real git binary. Matching on the BRANCH argument
# (not a filename) is deliberate: a squash-merged branch's tree contains
# every file main had at branch time, so a filename discriminator would also
# hit sibling branches and the fail-safe would skip them too (T30 first
# attempt). Used to exercise the cleanup fail-safe for a per-candidate git
# FAILURE that is neither the legit "unmerged" answer (exit 1) nor the
# documented git error code (exit 128) -- e.g. exit 2, a usage/parse error --
# while letting other candidates' diffs succeed so the test can prove the
# scan continues. The spec requires ANY git operation failure on one
# candidate to warn on stderr, skip that candidate, and continue the scan
# (spec.md "Fail-safe per candidate"; DIA-177 re-review finding 1).
mock_git_diff_exit_on_branch() {
  local code="$1" branch="$2" real_git bindir
  real_git="$(command -v git)"
  bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat > "$bindir/git" <<FAKEGIT
#!/usr/bin/env bash
if [ "\${1:-}" = "diff" ]; then
  for arg in "\$@"; do
    if [ "\$arg" = "$branch" ]; then
      echo "mock: git diff on '$branch' forced to exit $code" >&2
      exit $code
    fi
  done
fi
exec "$real_git" "\$@"
FAKEGIT
  chmod +x "$bindir/git"
  PATH="$bindir:$PATH"
  export PATH
}

# seed_husky_shim <tree>: pre-populate .husky/_ in the fixture repo so `create`
# has a copy source (mirrors a main tree after `husky install`). The dir is
# git-ignored (appended to the fixture .gitignore) so `git worktree add` does
# NOT deliver it to the new worktree -- the worktree gets .husky/_ ONLY if
# worktrees.sh copies it (the S1 shim under test, DIA-134). The marker file's
# content is the independent source of truth for the copy-fidelity assertions.
seed_husky_shim() {
  local tree="$1"
  printf '\n.husky/_/\n' >> "$tree/.gitignore"
  git -C "$tree" add .gitignore
  git -C "$tree" commit -q -m "ignore husky shim dir"
  mkdir -p "$tree/.husky/_"
  cat > "$tree/.husky/_/husky.sh" <<'SHIM'
#!/usr/bin/env sh
# DIA-134 fixture marker: proves a verbatim copy, not a git checkout.
echo "shim-marker-DIA-134"
SHIM
}

# ---------------------------------------------------------------------------
# DIA-137 cleanup-suite helpers. Same invariant as T1-T19: REAL git against a
# fresh isolated fixture repo under $BATS_TEST_TMPDIR -- no git mocks, because
# the failure modes under test (squash parity, dirty worktrees, broken refs)
# live in real git behavior.
# ---------------------------------------------------------------------------

# commit_with_age <checkout> <file> <content> <days_ago>: write <file> and
# commit it in <checkout> (a repo checkout or a linked worktree) with BOTH
# author and committer dates set <days_ago> days in the past. The DIA-137 age
# check reads the branch-tip commit date (design D3); setting both dates keeps
# the tests agnostic to whether the implementation reads author (%at) or
# committer (%ct).
commit_with_age() {
  local checkout="$1" file="$2" content="$3" days_ago="$4" when
  when="$(date -d "$days_ago days ago" +%Y-%m-%dT%H:%M:%S)"
  printf '%s\n' "$content" > "$checkout/$file"
  git -C "$checkout" add "$file"
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git -C "$checkout" commit -q -m "add $file"
}

# squash_merge_into_main <tree> <branch>: emulate the project's squash-merge
# workflow -- the branch's changes land on main WITHOUT a merge commit, so the
# branch is NOT an ancestor of main (`is-ancestor` fails) but `git diff main
# <branch>` is empty. This is exactly the squash-parity gap the two-pass merge
# check exists for (design D2). Leaves <tree> checked out on main.
squash_merge_into_main() {
  local tree="$1" branch="$2"
  git -C "$tree" checkout -q main
  git -C "$tree" merge -q --squash "$branch"
  git -C "$tree" commit -q -m "squash merge $branch"
}

# wt_path <branch>: worktree path stem for a branch (slashes as dashes),
# mirroring path_from_branch in worktrees.sh.
wt_path() {
  printf '%s' "$1" | tr '/' '-'
}

# make_merged_old_worktree <tree> <branch> <days_ago>: full realistic path --
# script `create` (linked worktree), one dated commit on the branch, then a
# squash-merge onto main. Leaves a CLEAN linked worktree on <branch> and the
# main checkout on main. (matrix row: merged + old + worktree-clean)
make_merged_old_worktree() {
  local tree="$1" branch="$2" days_ago="$3"
  local wt="$tree/.worktrees/$(wt_path "$branch")"
  bash "$tree/scripts/worktrees.sh" create "$branch" >/dev/null
  commit_with_age "$wt" "$(wt_path "$branch").txt" "content-$branch" "$days_ago"
  squash_merge_into_main "$tree" "$branch"
}

# make_merged_old_branch <tree> <branch> <days_ago>: branch with NO worktree,
# one dated commit, squash-merged onto main. (matrix row: merged + old + no
# worktree)
make_merged_old_branch() {
  local tree="$1" branch="$2" days_ago="$3"
  git -C "$tree" checkout -q -b "$branch"
  commit_with_age "$tree" "$(wt_path "$branch").txt" "content-$branch" "$days_ago"
  squash_merge_into_main "$tree" "$branch"
}

# make_unmerged_worktree <tree> <branch> <days_ago>: script-created worktree,
# one dated commit, NO merge onto main. (matrix row: unmerged, with a linked
# worktree)
make_unmerged_worktree() {
  local tree="$1" branch="$2" days_ago="$3"
  local wt="$tree/.worktrees/$(wt_path "$branch")"
  bash "$tree/scripts/worktrees.sh" create "$branch" >/dev/null
  commit_with_age "$wt" "$(wt_path "$branch").txt" "content-$branch" "$days_ago"
  git -C "$tree" checkout -q main
}

@test "worktrees: T1 create -> exit 0 + worktree dir + branch + isolated .opencode/session" {
  tree="$(setup_worktree_repo)"

  run bash "$tree/scripts/worktrees.sh" create feature/DIA-100-test

  assert_status 0
  assert_output_contains "ok: worktree created — branch 'feature/DIA-100-test'"
  assert_file_exists "$tree/.worktrees/feature-DIA-100-test"
  assert_file_exists "$tree/.worktrees/feature-DIA-100-test/.opencode/session"
  assert_output_contains "ok: .opencode/session/ is git-ignored in the worktree"
  # branch exists locally
  run git -C "$tree" branch --list feature/DIA-100-test
  assert_output_contains "feature/DIA-100-test"
}

@test "worktrees: T2 create invalid branch (no feature/ prefix) -> exit 1" {
  tree="$(setup_worktree_repo)"

  run bash "$tree/scripts/worktrees.sh" create DIA-100-test

  assert_status 1
  assert_output_contains "must start with 'feature/'"
  assert_file_not_exists "$tree/.worktrees/feature-DIA-100-test"
}

@test "worktrees: T3 create duplicate local branch -> exit 1" {
  tree="$(setup_worktree_repo)"
  git -C "$tree" branch feature/DIA-100-existing

  run bash "$tree/scripts/worktrees.sh" create feature/DIA-100-existing

  assert_status 1
  assert_output_contains "already exists locally"
}

@test "worktrees: T4 list shows branch + worktree path" {
  tree="$(setup_worktree_repo)"
  bash "$tree/scripts/worktrees.sh" create feature/DIA-100-test >/dev/null

  run bash "$tree/scripts/worktrees.sh" list

  assert_status 0
  assert_output_contains ".worktrees/feature-DIA-100-test"
  assert_output_contains "feature/DIA-100-test"
}

@test "worktrees: T5 remove by branch -> exit 0 + dir gone + branch KEPT" {
  tree="$(setup_worktree_repo)"
  bash "$tree/scripts/worktrees.sh" create feature/DIA-100-test >/dev/null

  run bash "$tree/scripts/worktrees.sh" remove feature/DIA-100-test

  assert_status 0
  assert_file_not_exists "$tree/.worktrees/feature-DIA-100-test"
  # branch survives the teardown (rollback window policy)
  run git -C "$tree" branch --list feature/DIA-100-test
  assert_output_contains "feature/DIA-100-test"
}

@test "worktrees: T6 remove dirty worktree without --force -> exit 1 + worktree survives" {
  tree="$(setup_worktree_repo)"
  bash "$tree/scripts/worktrees.sh" create feature/DIA-100-test >/dev/null
  touch "$tree/.worktrees/feature-DIA-100-test/uncommitted.txt"

  run bash "$tree/scripts/worktrees.sh" remove feature/DIA-100-test

  assert_status 1
  assert_output_contains "has uncommitted changes"
  assert_file_exists "$tree/.worktrees/feature-DIA-100-test/uncommitted.txt"
}

@test "worktrees: T7 remove --force without WORKTREES_FORCE=1 -> exit 1 (lane cannot force)" {
  tree="$(setup_worktree_repo)"
  bash "$tree/scripts/worktrees.sh" create feature/DIA-100-test >/dev/null
  touch "$tree/.worktrees/feature-DIA-100-test/uncommitted.txt"

  run bash "$tree/scripts/worktrees.sh" remove --force feature/DIA-100-test

  assert_status 1
  assert_output_contains "requires WORKTREES_FORCE=1"
  assert_file_exists "$tree/.worktrees/feature-DIA-100-test/uncommitted.txt"
}

@test "worktrees: T8 remove --force with WORKTREES_FORCE=1 -> exit 0 + dir gone (developer-only path)" {
  tree="$(setup_worktree_repo)"
  bash "$tree/scripts/worktrees.sh" create feature/DIA-100-test >/dev/null
  touch "$tree/.worktrees/feature-DIA-100-test/uncommitted.txt"

  run env WORKTREES_FORCE=1 bash "$tree/scripts/worktrees.sh" remove --force feature/DIA-100-test

  assert_status 0
  assert_file_not_exists "$tree/.worktrees/feature-DIA-100-test"
}

@test "worktrees: T9 remove unknown target -> exit 1" {
  tree="$(setup_worktree_repo)"

  run bash "$tree/scripts/worktrees.sh" remove feature/DIA-100-never-created

  assert_status 1
  assert_output_contains "no worktree found"
}

@test "worktrees: T10 no command -> usage error (exit 2)" {
  tree="$(setup_worktree_repo)"

  run bash "$tree/scripts/worktrees.sh"

  assert_status 2
  assert_output_contains "usage: worktrees.sh"
}

@test "worktrees: T11 remove refuses the main checkout path -> exit 1" {
  tree="$(setup_worktree_repo)"

  run bash "$tree/scripts/worktrees.sh" remove "$tree"

  assert_status 1
  assert_output_contains "refusing to remove the main checkout"
}

@test "worktrees: T12 create refuses branch that exists on origin (fake ls-remote listing)" {
  tree="$(setup_worktree_repo)"
  mock_git_ls_remote
  FAKE_LS_REMOTE_OUTPUT="$(printf '0a1b2c3d4e5f\trefs/heads/feature/DIA-100-existing')"
  export FAKE_LS_REMOTE_OUTPUT

  run bash "$tree/scripts/worktrees.sh" create feature/DIA-100-existing

  assert_status 1
  assert_output_contains "already exists on origin"
  assert_file_not_exists "$tree/.worktrees/feature-DIA-100-existing"
}

@test "worktrees: T13 create bounded when origin unreachable (fake ls-remote sleeps; internal timeout 5)" {
  tree="$(setup_worktree_repo)"
  mock_git_ls_remote
  export FAKE_LS_REMOTE_SLEEP=8

  # Outer timeout 12 bounds the whole test; the script's internal
  # `timeout 5 git ls-remote` must kill the hanging fake (~5s) so create
  # completes well under 12s. Without the internal timeout this test would
  # take 8s and the outer timeout would kill it -> status 124 -> RED.
  run timeout 12 bash "$tree/scripts/worktrees.sh" create feature/DIA-100-slow

  assert_status 0
  assert_file_exists "$tree/.worktrees/feature-DIA-100-slow"
}

@test "worktrees: T14 remove by worktree path -> exit 0 + message shows path AND branch" {
  tree="$(setup_worktree_repo)"
  bash "$tree/scripts/worktrees.sh" create feature/DIA-100-test >/dev/null

  run bash "$tree/scripts/worktrees.sh" remove "$tree/.worktrees/feature-DIA-100-test"

  assert_status 0
  assert_file_not_exists "$tree/.worktrees/feature-DIA-100-test"
  # the message must report the resolved branch (with slash), not echo the path
  assert_output_contains ".worktrees/feature-DIA-100-test"
  assert_output_contains "branch 'feature/DIA-100-test' kept for the rollback window"
}

@test "worktrees: T15 create --help -> usage (exit 2), not a branch-name error" {
  tree="$(setup_worktree_repo)"

  run bash "$tree/scripts/worktrees.sh" create --help

  assert_status 2
  assert_output_contains "usage: worktrees.sh"
  assert_output_not_contains "must start with 'feature/'"
}

@test "worktrees: T16 list forwards args to git worktree list (--porcelain works)" {
  tree="$(setup_worktree_repo)"
  bash "$tree/scripts/worktrees.sh" create feature/DIA-100-test >/dev/null

  run bash "$tree/scripts/worktrees.sh" list --porcelain

  assert_status 0
  assert_output_contains "branch refs/heads/feature/DIA-100-test"
}

@test "worktrees: T17 create materializes .husky/_ in the worktree" {
  tree="$(setup_worktree_repo)"

  run bash "$tree/scripts/worktrees.sh" create feature/DIA-134-test

  assert_status 0
  # .husky/_ exists in the new worktree as a REAL directory. git worktree add
  # cannot deliver it (git-ignored in the fixture, mirroring the real repo),
  # so only the S1 copy step can satisfy this (DD1: copy, not install).
  run test -d "$tree/.worktrees/feature-DIA-134-test/.husky/_"
  assert_status 0
  # content matches the main tree's .husky/_ (verbatim copy of the shim)
  assert_file_contains "$tree/.worktrees/feature-DIA-134-test/.husky/_/husky.sh" "shim-marker-DIA-134"
}

@test "worktrees: T18 create fails loudly when the main tree has no .husky/_" {
  tree="$(setup_worktree_repo)"
  # setup_worktree_repo now seeds .husky/_ (a husky-installed main tree is the
  # realistic default); strip it so this test owns the absent-source case.
  rm -rf "$tree/.husky"

  run bash "$tree/scripts/worktrees.sh" create feature/DIA-134-test

  # DD1 fail-loud contract: no silent bypass when the copy source is absent.
  assert_status 1
  assert_output_contains "husky is not installed in the main tree; run \`husky install\` before creating worktrees"
}

@test "worktrees: T19 create's .husky/_ copy is a real directory, not a symlink" {
  tree="$(setup_worktree_repo)"

  run bash "$tree/scripts/worktrees.sh" create feature/DIA-134-test

  assert_status 0
  # AC: test -L must return false -- DD1 rejects a symlink into the main tree
  # (it would break the worktree-isolation invariant).
  run test -L "$tree/.worktrees/feature-DIA-134-test/.husky/_"
  assert_status 1
  # and the target must be a real directory: a missing .husky/_ would make
  # test -L trivially false, so the -d assertion is the existence guard.
  run test -d "$tree/.worktrees/feature-DIA-134-test/.husky/_"
  assert_status 0
}

@test "worktrees: T20 cleanup merged+old with clean linked worktree -> branch deleted AND worktree dir removed" {
  tree="$(setup_worktree_repo)"
  make_merged_old_worktree "$tree" feature/DIA-137-merged 10

  # Post-merge teardown path (D7/R2): the orchestrator dispatches this as
  # the Teardown lane after a successful merge (remove THEN cleanup); the
  # same CLI surface is developer-runnable. Under the default 0-day window
  # (D6/R1) a 10-day-old merged branch is immediately eligible.
  run bash "$tree/scripts/worktrees.sh" cleanup

  # merged + old + worktree-clean: remove the worktree first, THEN delete the
  # branch (matrix row 5). Post-run BOTH the branch and the worktree dir are gone.
  assert_status 0
  run git -C "$tree" branch --list feature/DIA-137-merged
  assert_output_not_contains "feature/DIA-137-merged"
  assert_file_not_exists "$tree/.worktrees/feature-DIA-137-merged"
}

@test "worktrees: T21 cleanup unmerged preserved: old reported, young silent; worktrees survive (explicit --days 30 window)" {
  tree="$(setup_worktree_repo)"
  # unmerged + old (40d > 30d window) -> skip with report
  make_unmerged_worktree "$tree" feature/DIA-137-old 40
  # active-lane branch: unmerged AND younger than the window -> silent skip.
  # Reachable only with an explicit window: under the default 0 days every
  # positive-age branch is "old" (D6/R1), so no branch is ever "young".
  git -C "$tree" checkout -q -b feature/DIA-137-young
  commit_with_age "$tree" young-unmerged.txt "young" 3
  git -C "$tree" checkout -q main

  run bash "$tree/scripts/worktrees.sh" cleanup --days 30

  assert_status 0
  # unmerged + old: preserved with a report that names the candidate
  assert_output_contains "feature/DIA-137-old"
  # unmerged + young: preserved with NO report (silent skip, active lane)
  assert_output_not_contains "feature/DIA-137-young"
  run git -C "$tree" branch --list feature/DIA-137-old
  assert_output_contains "feature/DIA-137-old"
  run git -C "$tree" branch --list feature/DIA-137-young
  assert_output_contains "feature/DIA-137-young"
  assert_file_exists "$tree/.worktrees/feature-DIA-137-old"
}

@test "worktrees: T22 cleanup merged+young preserved (below explicit --days 30 window) with report" {
  tree="$(setup_worktree_repo)"
  # squash-merged but the branch tip is only 3 days old -- inside the
  # explicit 30-day window. Under the default 0-day window (D6/R1) a merged
  # branch is never "young", so this preservation case needs --days 30.
  git -C "$tree" checkout -q -b feature/DIA-137-young
  commit_with_age "$tree" young-merged.txt "young" 3
  squash_merge_into_main "$tree" feature/DIA-137-young

  run bash "$tree/scripts/worktrees.sh" cleanup --days 30

  assert_status 0
  # age below window -> preserved, skip reason reported (names the candidate)
  assert_output_contains "feature/DIA-137-young"
  run git -C "$tree" branch --list feature/DIA-137-young
  assert_output_contains "feature/DIA-137-young"
}

@test "worktrees: T23 cleanup merged+old dirty worktree -> skip + warn + scan continues + exit 0" {
  tree="$(setup_worktree_repo)"
  make_merged_old_worktree "$tree" feature/DIA-137-dirty 10
  # second clean candidate proves the scan continues past the dirty skip
  make_merged_old_branch "$tree" feature/DIA-137-clean 10
  # uncommitted work inside the linked worktree (untracked file -> dirty)
  printf 'uncommitted\n' > "$tree/.worktrees/feature-DIA-137-dirty/wip.txt"

  run bash "$tree/scripts/worktrees.sh" cleanup

  # dirty worktree is ALWAYS a skip (no --force on cleanup, D5); never loses work
  assert_status 0
  assert_output_contains "would-skip (worktree dirty)"
  run git -C "$tree" branch --list feature/DIA-137-dirty
  assert_output_contains "feature/DIA-137-dirty"
  assert_file_exists "$tree/.worktrees/feature-DIA-137-dirty/wip.txt"
  # scan continued: the clean candidate was still deleted
  run git -C "$tree" branch --list feature/DIA-137-clean
  assert_output_not_contains "feature/DIA-137-clean"
}

@test "worktrees: T24 cleanup --dry-run lists would-be-deleted candidates, zero side effects" {
  tree="$(setup_worktree_repo)"
  make_merged_old_worktree "$tree" feature/DIA-137-wt 10
  make_merged_old_branch "$tree" feature/DIA-137-nwt 10

  run bash "$tree/scripts/worktrees.sh" cleanup --dry-run

  # both merged+old candidates are listed; actions carry the 'would' prefix
  assert_status 0
  assert_output_contains "feature/DIA-137-wt"
  assert_output_contains "feature/DIA-137-nwt"
  assert_output_contains "would"
  # zero side effects: branches AND the linked worktree dir all survive
  run git -C "$tree" branch --list feature/DIA-137-wt
  assert_output_contains "feature/DIA-137-wt"
  run git -C "$tree" branch --list feature/DIA-137-nwt
  assert_output_contains "feature/DIA-137-nwt"
  assert_file_exists "$tree/.worktrees/feature-DIA-137-wt"
}

@test "worktrees: T25 cleanup exit codes: all-OK/skipped -> 0; candidate error / outside repo -> non-zero" {
  # (a) mix of one delete + two intentional skips (dirty, unmerged) -> exit 0
  tree="$(setup_worktree_repo)"
  make_merged_old_branch "$tree" feature/DIA-137-del 10
  make_merged_old_worktree "$tree" feature/DIA-137-dirty 10
  printf 'wip\n' > "$tree/.worktrees/feature-DIA-137-dirty/wip.txt"
  make_unmerged_worktree "$tree" feature/DIA-137-unmerged 10

  run bash "$tree/scripts/worktrees.sh" cleanup

  assert_status 0
  run git -C "$tree" branch --list feature/DIA-137-del
  assert_output_not_contains "feature/DIA-137-del"
  run git -C "$tree" branch --list feature/DIA-137-dirty
  assert_output_contains "feature/DIA-137-dirty"
  run git -C "$tree" branch --list feature/DIA-137-unmerged
  assert_output_contains "feature/DIA-137-unmerged"

  # (b) outside a git repo -> non-zero (hard-abort precondition; NOT a
  # CLI-dispatch error -- the cleanup subcommand must exist and fail on the
  # repo precondition, not on command dispatch)
  norepo="$BATS_TEST_TMPDIR/norepo"
  mkdir -p "$norepo/scripts"
  cp "$SCRIPTS_DIR/worktrees.sh" "$norepo/scripts/worktrees.sh"
  run bash "$norepo/scripts/worktrees.sh" cleanup
  [ "$status" -ne 0 ] || { echo "expected non-zero exit outside a git repo, got 0" >&2; return 1; }
  assert_output_not_contains "unknown command"

  # (c) per-candidate git failure (broken ref -> bad object) -> stderr warning
  # + SKIP + scan continues + non-zero exit (candidate error, per the exit
  # contract: non-zero if ANY candidate error). Loose ref write: update-ref
  # refuses nonexistent objects, so write the ref file directly.
  mkdir -p "$tree/.git/refs/heads/feature"
  printf 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n' > "$tree/.git/refs/heads/feature/DIA-137-broken"
  make_merged_old_branch "$tree" feature/DIA-137-good 10

  run bash "$tree/scripts/worktrees.sh" cleanup

  [ "$status" -ne 0 ] || { echo "expected non-zero exit after a candidate git failure" >&2; return 1; }
  # the failed candidate is reported (the warning names it)...
  assert_output_contains "feature/DIA-137-broken"
  # ...and the scan continued: the good candidate was still deleted
  run git -C "$tree" branch --list feature/DIA-137-good
  assert_output_not_contains "feature/DIA-137-good"
}

@test "worktrees: T26 cleanup window precedence: --days flag > WORKTREES_CLEANUP_DAYS > default 0" {
  tree="$(setup_worktree_repo)"
  # 40d tip distinguishes a 30-day window (40 > 30 -> eligible) from env 99
  # (40 < 99 -> preserved); 3d tip is young under any 30/99 window but is
  # eligible under the default 0. Same repo serves all three via --dry-run.
  make_merged_old_branch "$tree" feature/DIA-137-old 40
  make_merged_old_branch "$tree" feature/DIA-137-recent 3

  # (c) neither env nor flag -> default 0 days (D6/R1): every merged branch
  # is a would-delete candidate, including the 3-day-old.
  run bash "$tree/scripts/worktrees.sh" cleanup --dry-run
  assert_status 0
  assert_output_contains "feature/DIA-137-old"
  assert_output_contains "feature/DIA-137-recent"

  # (b) env only -> env wins over default: WORKTREES_CLEANUP_DAYS=30 widens
  # the window so the 3-day-old is preserved (default 0 would delete it).
  run env WORKTREES_CLEANUP_DAYS=30 bash "$tree/scripts/worktrees.sh" cleanup --dry-run
  assert_status 0
  assert_output_contains "feature/DIA-137-old"
  assert_output_not_contains "feature/DIA-137-recent"

  # (a) flag beats env: --days 30 wins over WORKTREES_CLEANUP_DAYS=99. The
  # 40-day-old IS listed -> the effective window is 30, not 99 (under env-99
  # alone 40 < 99 would preserve it); the 3-day-old is preserved (< 30).
  run env WORKTREES_CLEANUP_DAYS=99 bash "$tree/scripts/worktrees.sh" cleanup --dry-run --days 30
  assert_status 0
  assert_output_contains "feature/DIA-137-old"
  assert_output_not_contains "feature/DIA-137-recent"
}

@test "worktrees: T27 cleanup deletes branch AND leftover worktree dir on disk" {
  tree="$(setup_worktree_repo)"
  # full lifecycle: create -> merge -> remove (branch kept, worktree dir gone),
  # then the dir reappears as stale leftover state. The merged+old+no-worktree
  # act path must delete the branch AND clear the leftover dir (matrix row 6:
  # "and the linked worktree dir if still present on disk").
  make_merged_old_worktree "$tree" feature/DIA-137-stale 10
  bash "$tree/scripts/worktrees.sh" remove feature/DIA-137-stale >/dev/null
  mkdir -p "$tree/.worktrees/feature-DIA-137-stale"
  touch "$tree/.worktrees/feature-DIA-137-stale/leftover.txt"

  run bash "$tree/scripts/worktrees.sh" cleanup

  assert_status 0
  run git -C "$tree" branch --list feature/DIA-137-stale
  assert_output_not_contains "feature/DIA-137-stale"
  assert_file_not_exists "$tree/.worktrees/feature-DIA-137-stale"
}

@test "worktrees: T28 cleanup main-tree guard: checked-out candidate skipped with warn, main/master never touched" {
  tree="$(setup_worktree_repo)"
  # merged+old candidate that is ALSO the currently-checked-out branch
  git -C "$tree" checkout -q -b feature/DIA-137-guard
  commit_with_age "$tree" guard.txt "guard" 10
  squash_merge_into_main "$tree" feature/DIA-137-guard
  git -C "$tree" checkout -q feature/DIA-137-guard
  # a second real candidate (branched from MAIN, not from the guard branch)
  # proves the scan continues past the checked-out skip
  git -C "$tree" checkout -q -b feature/DIA-137-other main
  commit_with_age "$tree" other.txt "other" 10
  squash_merge_into_main "$tree" feature/DIA-137-other
  git -C "$tree" checkout -q feature/DIA-137-guard
  git -C "$tree" branch master main

  run bash "$tree/scripts/worktrees.sh" cleanup

  assert_status 0
  # the checked-out candidate is skipped with a stderr warning naming it
  assert_output_contains "feature/DIA-137-guard"
  run git -C "$tree" branch --list feature/DIA-137-guard
  assert_output_contains "feature/DIA-137-guard"
  # scan continued: the other candidate was deleted
  run git -C "$tree" branch --list feature/DIA-137-other
  assert_output_not_contains "feature/DIA-137-other"
  # main/master are never candidates and never touched
  run git -C "$tree" branch --list main
  assert_output_contains "main"
  run git -C "$tree" branch --list master
  assert_output_contains "master"
}

@test "worktrees: T29 cleanup --days '008' is a usage error, not an arithmetic abort (F1 regression)" {
  tree="$(setup_worktree_repo)"
  make_merged_old_branch "$tree" feature/DIA-137-old 10

  # F1 regression: '008' passes the digit-only case pattern, but bash
  # arithmetic reads a leading zero as octal and aborts the whole script
  # under set -euo pipefail ("008: value too great for base") instead of the
  # spec-mandated clean exit 2 + usage on stderr. Leading-zero windows are
  # usage errors, like non-integers; '--days 0' stays valid (default).
  run bash "$tree/scripts/worktrees.sh" cleanup --days 008

  assert_status 2
  assert_output_contains "usage: worktrees.sh"
  # no arithmetic abort and no partial side effects: the branch survives
  run git -C "$tree" branch --list feature/DIA-137-old
  assert_output_contains "feature/DIA-137-old"
}

@test "worktrees: T30 cleanup non-128 non-1 git failure -> stderr warning + skip + run non-zero + scan continues" {
  tree="$(setup_worktree_repo)"
  # Two merged+old branches. Only feature/DIA-137-err's file hits a mocked
  # `git diff` that exits 2 (usage/parse error -- neither the legit
  # "unmerged" answer 1 nor the documented git-error code 128). The
  # spec-mandated fail-safe (F1): warn on stderr, skip THAT candidate,
  # continue the scan; run-level exit non-zero signals the partial failure
  # (exit-code contract).
  make_merged_old_branch "$tree" feature/DIA-137-err 10
  make_merged_old_branch "$tree" feature/DIA-137-ok 10
  mock_git_diff_exit_on_branch 2 "feature/DIA-137-err"

  run bash "$tree/scripts/worktrees.sh" cleanup

  # run-level non-zero: a per-candidate git failure was recorded
  [ "$status" -ne 0 ] || { echo "expected non-zero exit after a non-128 git failure" >&2; return 1; }
  # the failed candidate is warned about on stderr (spec: reported)...
  assert_output_contains "feature/DIA-137-err"
  assert_output_contains "merge check failed"
  # ...and preserved (never a delete on a failed prerequisite check)
  run git -C "$tree" branch --list feature/DIA-137-err
  assert_output_contains "feature/DIA-137-err"
  # the scan continued: the unaffected merged+old candidate was deleted
  run git -C "$tree" branch --list feature/DIA-137-ok
  assert_output_not_contains "feature/DIA-137-ok"
}
