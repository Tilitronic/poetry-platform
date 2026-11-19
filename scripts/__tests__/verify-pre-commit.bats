#!/usr/bin/env bats
# Unit tests for scripts/verify-pre-commit.sh (the husky pre-commit autofix
# gate). Mirrors the verify-pre-push.bats contexts, with one deliberate
# difference (D1): when the dev container is down the pre-commit hook FAILS —
# a commit-time autofix gate that silently passes would not be "maximum
# automatic linting" — so the developer must start the stack or use
# `git commit --no-verify` to bypass explicitly.
#
# Three execution contexts are exercised without ever touching a real
# container, a real npx, or a real commit:
#   1. host + container running -> delegates lint-staged via `docker compose exec`
#   2. host + container down    -> exit 1 with a clear "dev container not running"
#   3. inside the container     -> runs `npx lint-staged --allow-empty` directly
#
# DIA-261119-85dy adds a linked-worktree dimension on top of contexts 1 and 3
# (see the section comment below). The only real git commit any case performs
# is the throwaway `git commit -m init` inside that fixture repo.

load test-helper

setup() {
  mock_docker
  # Hermetic engine selection (DIA-260909-9api precedent): an inherited
  # COMPOSE_ENGINE would reroute the adapter past the docker fake these tests
  # assert on. Unset it; engine-specific coverage lives in container-engine.bats.
  unset COMPOSE_ENGINE
  # Hermetic host-context (DIA-071, 2026-08-12): fake hostname keeps every
  # non-direct test in the HOST + container-running delegation path even when
  # the suite runs inside poetry-dev; isolated POETRY_COMMANDS_DIR keeps the
  # /home/qualt guard hermetic. See setup_hermetic_host_context in
  # test-helper.bash. The dedicated "runs lint-staged directly" test shadows
  # the fake hostname with its own poetry-dev fake.
  setup_hermetic_host_context
}

# ---------------------------------------------------------------------------
# DIA-261119-85dy: lint-staged cwd must follow the COMMITTING worktree
# ---------------------------------------------------------------------------
# When git runs the hook for a commit made in a linked worktree it exports
# GIT_INDEX_FILE pointing at that worktree's index. lint-staged unsets
# GIT_DIR but not GIT_INDEX_FILE, so running it from the hardcoded /workspace
# (the MAIN worktree) evaluates that index against the wrong tree and dies
# with "Unstaged changes could not be restored due to a merge conflict!".
# Required behavior pinned by the cases at the bottom of this file: the
# lint-staged invocation's cwd (and therefore its file view) is the committing
# worktree's top level; main-worktree behavior stays /workspace.

# make_linked_worktree: hermetic fixture = main repo + one linked worktree
# (the scripts/worktrees.sh layout, at a temp path). The fixture tracks
# scripts/guards/home-qualt.sh because the hook sources that file from
# `git rev-parse --show-toplevel`, so a run whose cwd is the linked worktree
# resolves the worktree copy. Uses the shared budget_git_init (hermetic repo
# init + test identity in test-helper.bash). Echoes the worktree's git
# toplevel -- the anchor the required behavior names.
make_linked_worktree() {
  local main="$BATS_TEST_TMPDIR/wt-main"
  local linked="$BATS_TEST_TMPDIR/wt-linked"
  mkdir -p "$main/scripts/guards"
  cp "$REPO_ROOT/scripts/guards/home-qualt.sh" "$main/scripts/guards/"
  budget_git_init "$main"
  git -C "$main" add scripts
  git -C "$main" commit -q -m init
  git -C "$main" worktree add -q -b bats-linked "$linked" main
  git -C "$linked" rev-parse --show-toplevel
}

# install_container_fakes: the in-container execution context of the "runs
# lint-staged directly" test - a fake hostname answering poetry-dev
# (is_in_dev_container -> direct path) plus a recording `npx` that logs the
# cwd it was invoked from and the GIT_INDEX_FILE it inherited, instead of
# linting. Temp HOME + .bash_profile keep run_workspace's `bash -lc` login
# shell from re-prepending a host profile over the fake npx (DIA-071 /
# DIA-119 mirrors of that test). Deliberately does NOT set POETRY_WORKSPACE:
# these cases exercise the hook's own workspace resolution.
install_container_fakes() {
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat > "$bindir/hostname" <<'FAKEHOSTNAME'
#!/usr/bin/env bash
echo "poetry-dev"
FAKEHOSTNAME
  cat > "$bindir/npx" <<'FAKENPX'
#!/usr/bin/env bash
# DIA-261119-85dy seam: record where lint-staged would run (cwd = the file
# view the staged index is evaluated against) plus the inherited index path.
printf 'npx cwd=%s git_index=%s args=%s\n' "$PWD" "${GIT_INDEX_FILE:-}" "$*" >> "${NPX_LOG:?NPX_LOG not set}"
exit 0
FAKENPX
  chmod +x "$bindir/hostname" "$bindir/npx"
  export PATH="$bindir:$PATH"
  export NPX_LOG="$BATS_TEST_TMPDIR/npx.log"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  printf 'export PATH="%s:$PATH"\n' "$bindir" > "$HOME/.bash_profile"
}

@test "verify-pre-commit: delegates lint-staged to the dev container when on the host" {
  export FAKE_DOCKER_SERVICES="dev"
  # DIA-261119-85dy: the delegated cd target is the COMMITTING repository's
  # top level, resolved exactly the way the fixed hook resolves WORKSPACE
  # (git rev-parse --show-toplevel from the invoking cwd) - so this case is
  # context-aware: /workspace when the suite runs from the main worktree,
  # the worktree path when it runs from a linked worktree. Never hardcoded.
  local expected_ws
  expected_ws="$(git rev-parse --show-toplevel)"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  assert_output_contains "delegating to dev container"
  assert_output_contains "autofix passed"
  # the full delegated command, including the --allow-empty flag; the inner cd
  # target is escaped-quoted so a space-containing WORKSPACE stays one argument
  assert_file_contains "$FAKE_DOCKER_LOG" "cd \"$expected_ws\" && npx lint-staged --allow-empty"
}

@test "verify-pre-commit: passes --allow-empty so empty commits are not blocked" {
  export FAKE_DOCKER_SERVICES="dev"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  # --allow-empty is part of every lint-staged invocation (E1: a commit with
  # no staged files must not fail the hook)
  assert_file_contains "$FAKE_DOCKER_LOG" "lint-staged --allow-empty"
}

@test "verify-pre-commit: blocks the commit when the dev container is down" {
  export FAKE_DOCKER_SERVICES="postgres"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 1
  assert_output_contains "dev container not running"
  # fail-by-default: lint-staged must never be delegated when the stack is down
  run grep -c "compose exec" "$FAKE_DOCKER_LOG"
  [ "$output" = "0" ]
}

@test "verify-pre-commit: runs lint-staged directly when already inside the dev container" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat > "$bindir/hostname" <<'FAKEHOSTNAME'
#!/usr/bin/env bash
echo "poetry-dev"
FAKEHOSTNAME
  cat > "$bindir/npx" <<'FAKENPX'
#!/usr/bin/env bash
printf 'npx %s\n' "$*" >> "${NPX_LOG:?NPX_LOG not set}"
exit 0
FAKENPX
  chmod +x "$bindir/hostname" "$bindir/npx"
  export PATH="$bindir:$PATH"
  export NPX_LOG="$BATS_TEST_TMPDIR/npx.log"
  export POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws"
  # run_workspace uses `bash -lc`, a login shell that sources ~/.profile, which
  # prepends $VOLTA_HOME/bin and would shadow our fake npx with the real one.
  # A temp HOME keeps the login shell clean so the fake npx is exercised.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$POETRY_WORKSPACE" "$HOME"
  # DIA-119 (symmetric fix): the temp-HOME guard is the single defense against
  # a host login profile (~/.profile prepends $VOLTA_HOME/bin) shadowing the
  # fake npx with the real one, which then runs real lint-staged and errors in
  # this empty sandbox (npx ENOENT / lint-staged fetch, or "not a git
  # directory"). Seed an importer manifest + a local lint-staged stub (logging
  # to NPX_LOG exactly like the fake) so real npx resolves the stub from
  # node_modules/.bin and the outcome no longer depends on which npx resolves.
  cat > "$POETRY_WORKSPACE/package.json" <<EOF
{"name":"verify-pre-commit-sandbox","private":true}
EOF
  mkdir -p "$POETRY_WORKSPACE/node_modules/.bin"
  cat > "$POETRY_WORKSPACE/node_modules/.bin/lint-staged" <<'FAKELS'
#!/usr/bin/env bash
# F2: adaptive stub - log via "$*" (real npx invokes us with only the args
# after the binary name, so rebuild the full command from $0; the fake npx
# receives the whole command and logs the same line). Arg drift is detected.
printf 'npx %s\n' "$(basename "$0") $*" >> "${NPX_LOG:?NPX_LOG not set}"
exit 0
FAKELS
  chmod +x "$POETRY_WORKSPACE/node_modules/.bin/lint-staged"
  # DIA-071: Debian-style hosts reset PATH unconditionally in /etc/profile for
  # login shells, which would drop the fake bindir above; a temp ~/.bash_profile
  # that re-prepends it keeps the fake npx hermetic (mirror of the
  # verify-pre-push "runs steps directly" test).
  printf 'export PATH="%s:$PATH"\n' "$bindir" > "$HOME/.bash_profile"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  assert_output_contains "running inside dev container"
  assert_output_contains "autofix passed"
  assert_file_contains "$NPX_LOG" "lint-staged --allow-empty"
  # docker must never be invoked from inside the container
  [ ! -s "$FAKE_DOCKER_LOG" ]
}

@test "verify-pre-commit: delegates a workspace path with spaces as one cd argument" {
  export FAKE_DOCKER_SERVICES="dev"
  export POETRY_WORKSPACE="$BATS_TEST_TMPDIR/ws with spaces"
  mkdir -p "$POETRY_WORKSPACE"

  run bash "$SCRIPTS_DIR/verify-pre-commit.sh"

  assert_status 0
  # the delegated log must preserve the space-containing path as ONE quoted cd
  # argument — an unquoted $WORKSPACE would split it at the first space (D2)
  assert_file_contains "$FAKE_DOCKER_LOG" "cd \"$POETRY_WORKSPACE\" &&"
}

@test "verify-pre-commit: sources the shared home-qualt guard and calls it, with no inline definition" {
  # F-6 (DIA-139): the /home/qualt grep behavior is canonical in
  # guards-home-qualt.bats; the hook only needs to source the helper and
  # call the function. Assert the wiring statically (batch-D grep pattern).
  # The source line must exist, the call site must remain, and the inline
  # function definition must be gone.
  run grep -F 'scripts/guards/home-qualt.sh' "$SCRIPTS_DIR/verify-pre-commit.sh"
  assert_status 0
  run grep -xF 'guard_no_home_qualt' "$SCRIPTS_DIR/verify-pre-commit.sh"
  assert_status 0
  run grep -F 'guard_no_home_qualt()' "$SCRIPTS_DIR/verify-pre-commit.sh"
  assert_status 1
}

@test "verify-pre-commit: runs lint-staged from the committing linked-worktree top level" {
  local linked wt_index
  linked="$(make_linked_worktree)"
  # the index git exports for a commit made in the linked worktree
  wt_index="$(git -C "$linked" rev-parse --absolute-git-dir)/index"
  install_container_fakes

  # same cwd + env git gives the hook for a linked-worktree commit
  run env GIT_INDEX_FILE="$wt_index" bash -c "cd '$linked' && exec bash '$SCRIPTS_DIR/verify-pre-commit.sh'"

  assert_status 0
  assert_output_contains "running inside dev container"
  assert_output_contains "autofix passed"
  # required: lint-staged's cwd (its file view) is the COMMITTING worktree's
  # top level, so cwd and GIT_INDEX_FILE describe the same tree
  assert_file_contains "$NPX_LOG" "npx cwd=$linked"
  # ... and never the hardcoded /workspace main worktree (the defect)
  run grep -cF "npx cwd=/workspace" "$NPX_LOG"
  [ "$output" = "0" ]
}

@test "verify-pre-commit: keeps lint-staged at /workspace when committing from the main worktree" {
  install_container_fakes

  # main-worktree context: hook cwd is the repo root (what git hands it)
  run bash -c "cd '$REPO_ROOT' && exec bash '$SCRIPTS_DIR/verify-pre-commit.sh'"

  assert_status 0
  assert_output_contains "running inside dev container"
  assert_output_contains "autofix passed"
  # unchanged behavior: the main worktree still runs lint-staged at /workspace
  assert_file_contains "$NPX_LOG" "npx cwd=/workspace"
}

@test "verify-pre-commit: host dispatch still runs exactly one lint-staged invocation for a linked-worktree commit" {
  local linked
  linked="$(make_linked_worktree)"
  export FAKE_DOCKER_SERVICES="dev"

  run bash -c "cd '$linked' && exec bash '$SCRIPTS_DIR/verify-pre-commit.sh'"

  assert_status 0
  assert_output_contains "delegating to dev container"
  # one delegated lint-staged only: worktree-aware resolution must not add a
  # second invocation on top of the delegation
  run grep -c "lint-staged" "$FAKE_DOCKER_LOG"
  [ "$output" = "1" ]
}

@test "verify-pre-commit: host dispatch delegates lint-staged from the linked-worktree top level" {
  local linked
  linked="$(make_linked_worktree)"
  export FAKE_DOCKER_SERVICES="dev"

  run bash -c "cd '$linked' && exec bash '$SCRIPTS_DIR/verify-pre-commit.sh'"

  assert_status 0
  assert_output_contains "delegating to dev container"
  # required: the delegated command's cd target (the lint-staged cwd inside
  # the container) is the committing worktree top level, not /workspace. The
  # "delegates lint-staged to the dev container when on the host" case pins
  # the `cd "<ws>" && npx lint-staged --allow-empty` shape, so only the
  # workspace operand is at stake here.
  assert_file_contains "$FAKE_DOCKER_LOG" "cd \"$linked\" && npx lint-staged --allow-empty"
}
