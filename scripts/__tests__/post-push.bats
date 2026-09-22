#!/usr/bin/env bats
# Unit tests for .husky/post-push (DIA-203).
#
# Strategy: same fixture approach as worktrees.bats -- a REAL isolated git
# repo under $BATS_TEST_TMPDIR with the script + hook copied in. The hook
# runs worktrees.sh cleanup --dry-run, so the fixture must have the same
# git state as the real repo (main branch, .gitignore, husky shim).

load test-helper

bats_require_minimum_version 1.5.0

# ---------------------------------------------------------------------------
# Helpers (duplicated from worktrees.bats -- both suites load test-helper.bash
# but these are suite-local, not shared)
# ---------------------------------------------------------------------------

seed_husky_shim() {
  local tree="$1"
  printf '\n.husky/_/\n' >> "$tree/.gitignore"
  git -C "$tree" add .gitignore
  git -C "$tree" commit -q -m "ignore husky shim dir"
  mkdir -p "$tree/.husky/_"
  cat > "$tree/.husky/_/husky.sh" <<'SHIM'
#!/usr/bin/env sh
echo "shim-marker-DIA-134"
SHIM
}

commit_with_age() {
  local checkout="$1" file="$2" content="$3" days_ago="$4" when
  when="$(date -d "$days_ago days ago" +%Y-%m-%dT%H:%M:%S)"
  printf '%s\n' "$content" > "$checkout/$file"
  git -C "$checkout" add "$file"
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git -C "$checkout" commit -q -m "add $file"
}

squash_merge_branch() {
  local tree="$1" branch="$2"
  git -C "$tree" checkout -q main
  git -C "$tree" merge -q --squash "$branch"
  git -C "$tree" commit -q -m "squash merge $branch"
}

# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

setup_post_push_repo() {
  local tree="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$tree/scripts" "$tree/.husky"
  cp "$SCRIPTS_DIR/worktrees.sh" "$tree/scripts/worktrees.sh"
  cp "$REPO_ROOT/.husky/post-push" "$tree/.husky/post-push"
  printf '.opencode/session/\n.worktrees/\n' > "$tree/.gitignore"
  if ! git -C "$tree" init -q -b main 2>/dev/null; then
    git -C "$tree" init -q
    git -C "$tree" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$tree" config user.email "bats@example.com"
  git -C "$tree" config user.name "bats test"
  git -C "$tree" add .gitignore
  git -C "$tree" commit -q -m init
  seed_husky_shim "$tree"
  echo "$tree"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "post-push: hook exits 0 on a clean tree (no stale state)" {
  tree="$(setup_post_push_repo)"

  # husky hooks run CWD = repo root; simulate that in the test
  run bash -c "cd '$tree' && bash .husky/post-push"

  assert_status 0
  assert_output_not_contains "stale branches/worktrees detected"
}

@test "post-push: hook prints warning when stale merged branches exist" {
  tree="$(setup_post_push_repo)"
  git -C "$tree" checkout -q -b feature/DIA-203-stale
  commit_with_age "$tree" stale.txt "stale" 10
  squash_merge_branch "$tree" feature/DIA-203-stale

  run bash -c "cd '$tree' && bash .husky/post-push"

  assert_status 0
  assert_output_contains "stale branches/worktrees detected"
  assert_output_contains "make worktree-gc"
  assert_output_contains "feature/DIA-203-stale"
  # dry-run: branch still exists
  run git -C "$tree" branch --list feature/DIA-203-stale
  assert_output_contains "feature/DIA-203-stale"
}

@test "post-push: hook prints warning when orphaned worktree dirs exist" {
  tree="$(setup_post_push_repo)"
  mkdir -p "$tree/.worktrees/orphan-dead"
  printf 'gitdir: /nonexistent/gitdir\n' > "$tree/.worktrees/orphan-dead/.git"

  run bash -c "cd '$tree' && bash .husky/post-push"

  assert_status 0
  assert_output_contains "stale branches/worktrees detected"
  # dry-run: dir still exists
  assert_file_exists "$tree/.worktrees/orphan-dead"
}

@test "post-push: hook never deletes anything (advisory only)" {
  tree="$(setup_post_push_repo)"
  git -C "$tree" checkout -q -b feature/DIA-203-merged
  commit_with_age "$tree" merged.txt "merged" 10
  squash_merge_branch "$tree" feature/DIA-203-merged
  mkdir -p "$tree/.worktrees/orphan-dead"
  printf 'gitdir: /nonexistent\n' > "$tree/.worktrees/orphan-dead/.git"

  run bash -c "cd '$tree' && bash .husky/post-push"

  assert_status 0
  run git -C "$tree" branch --list feature/DIA-203-merged
  assert_output_contains "feature/DIA-203-merged"
  assert_file_exists "$tree/.worktrees/orphan-dead"
}
