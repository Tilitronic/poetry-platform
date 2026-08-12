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
  export FAKE_LS_REMOTE_SLEEP=20

  # Outer timeout 12 bounds the whole test; the script's internal
  # `timeout 5 git ls-remote` must kill the hanging fake (~5s) so create
  # completes well under 12s. Without the internal timeout this test would
  # take 20s and the outer timeout would kill it -> status 124 -> RED.
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
