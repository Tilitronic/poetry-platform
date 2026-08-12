#!/usr/bin/env bash
# worktrees.sh — worktree lifecycle CLI for the worktrees-only parallel dev
# model (DIA-100; DIA-073 option d, adopted by developer decision 2026-08-09).
#
# WHY: parallel OpenCode lanes need isolated checkouts on feature branches.
# The global worktrees skill (~/.config/opencode/skills/worktrees/SKILL.md)
# defines the ORCHESTRATION protocol (planning, ownership, integration,
# cleanup); this script is the mechanical layer — it turns the protocol's
# add/remove/list steps into one testable CLI so lanes and the developer
# execute identical, safe commands instead of ad-hoc git.
#
# Subcommands:
#   create <branch> [base]   create a worktree at .worktrees/<branch-stem>
#                            on a new branch <branch> (default base: main).
#                            Validates the branch name against the DIA-074
#                            convention (feature/<ticket>-<short-name>),
#                            refuses already-existing branches, and verifies
#                            .opencode/session/ isolation in the new worktree.
#   remove <branch|path>     remove a worktree. The branch is KEPT for the
#                            rollback window (cleanup after the window is a
#                            developer action — git branch -d/-D is denied
#                            for lanes, DIA-096). Refuses dirty/uncommitted
#                            worktrees unless --force.
#   list                     show active worktrees (path + HEAD + branch).
#
# Options:
#   remove: --force          force-remove a dirty worktree. DEVELOPER-ONLY:
#                            requires WORKTREES_FORCE=1 (lanes must never set
#                            it) because forced removal maps to DIA-096 denied
#                            destructive ops (git clean -f* / branch -D); see
#                            docs/dev-infra-audit/worktree-conventions.md.
#   -h, --help               show this help.
#
# Exit codes: 0 success; 1 runtime error (fail-loud on stderr); 2 usage error.
# Bash-3 compatible: no [[ ]], no associative arrays, no ${!var} (same
# contract as scripts/session-log). The script itself stays bash-3; the bats
# SUITE requires bash 4+ because test-helper.bash's assert helpers use [[ ]]
# (assert_output_contains / assert_output_not_contains).
# External deps: GNU coreutils `timeout` (bounds the best-effort remote check
# so an unreachable origin cannot block `create` — DIA-100 review finding).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
WORKTREES_DIR="${WORKTREES_DIR:-$ROOT/.worktrees}"
DEFAULT_BASE="${DEFAULT_BASE:-main}"

fail() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
usage: worktrees.sh <command> [options]

commands:
  create <branch> [base]   create a worktree at .worktrees/<branch-stem>
                           on new branch <branch> (base defaults to main)
  remove <branch|path>     remove a worktree; keeps the branch for the
                           rollback window
  list                     show active worktrees (path + HEAD + branch)

options:
  remove --force           force-remove a dirty worktree (developer-only;
                           requires WORKTREES_FORCE=1 — lanes never set it)
  -h, --help               show this help

branch convention (DIA-074): feature/<ticket>-<short-name>
  e.g. feature/DIA-100-worktree-lifecycle
EOF
  exit 2
}

# validate_branch <branch>: enforce the DIA-074 convention
# feature/<ticket>-<short-name>. Hard rules: must start with 'feature/' and
# the <name> part is a single path component of [A-Za-z0-9._-] (no extra
# slashes, no leading dash/dot — git ref rules). Soft warning when the name
# does not carry a DIA-<NNN>-<slug> ticket stem (deliberate ticket-less
# branches are rare).
validate_branch() {
  local branch="$1" stem
  case "$branch" in
    feature/*) ;;
    *) fail "branch '$branch' must start with 'feature/' (convention: feature/<ticket>-<short-name>, DIA-074)" ;;
  esac
  stem="${branch#feature/}"
  printf '%s' "$stem" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' || \
    fail "branch '$branch': the part after 'feature/' may contain only [A-Za-z0-9._-] and no extra slashes"
  if ! printf '%s' "$stem" | grep -Eq '^DIA-[0-9]+-[a-z0-9]+([-_][a-z0-9]+)*$'; then
    echo "warn: branch '$branch' does not match 'feature/DIA-<NNN>-<short-name>' (DIA-074); ticket-less branches should be rare and deliberate"
  fi
}

# path_from_branch <branch>: worktree path = .worktrees/<branch-with-slashes-
# as-dashes>. Flat naming keeps every lane a direct child of .worktrees/ and
# keeps list/remove lookups predictable.
path_from_branch() {
  local branch="$1"
  printf '%s' "$branch" | tr '/' '-'
}

# resolve_worktree_path <branch|path>: echo the worktree path for a target
# that is either an existing worktree path or a branch name (from
# `git worktree list --porcelain`). Fails loudly when nothing matches.
resolve_worktree_path() {
  local target="$1" line wtpath="" branch=""
  if [ -d "$target" ]; then
    if git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
      printf '%s' "$target"
      return 0
    fi
  fi
  while IFS= read -r line; do
    if [ -z "$line" ]; then
      wtpath=""
      branch=""
      continue
    fi
    case "$line" in
      worktree\ *) wtpath="${line#worktree }" ;;
      branch\ *) branch="${line#branch refs/heads/}" ;;
    esac
    if [ -n "$wtpath" ] && [ -n "$branch" ] && [ "$branch" = "$target" ]; then
      printf '%s' "$wtpath"
      return 0
    fi
  done < <(git worktree list --porcelain)
  fail "no worktree found for '$target' (checked existing paths and branches)"
}

# worktree_branch_at <path>: echo the branch name (without the refs/heads/
# prefix) of the worktree at <path>, from `git worktree list --porcelain`.
# Used by cmd_remove so the success message reports the REAL branch even when
# the user removed by worktree PATH (the path's basename is the branch with
# slashes converted to dashes and cannot be reversed losslessly).
worktree_branch_at() {
  local path="$1" line wtpath="" branch=""
  while IFS= read -r line; do
    if [ -z "$line" ]; then
      wtpath=""
      branch=""
      continue
    fi
    case "$line" in
      worktree\ *) wtpath="${line#worktree }" ;;
      branch\ *) branch="${line#branch refs/heads/}" ;;
    esac
    if [ -n "$wtpath" ] && [ -n "$branch" ] && [ "$wtpath" = "$path" ]; then
      printf '%s' "$branch"
      return 0
    fi
  done < <(git worktree list --porcelain)
  fail "no branch found for worktree at '$path' (detached HEAD?)"
}

cmd_create() {
  if [ $# -lt 1 ]; then
    usage
  fi
  case "$1" in
    -h | --help) usage ;;
  esac
  local branch="$1" base="${2:-$DEFAULT_BASE}" path
  validate_branch "$branch"
  path="$WORKTREES_DIR/$(path_from_branch "$branch")"

  # Refuse branches that already exist locally (git worktree add -b would
  # fail anyway; fail with a clearer message instead).
  if git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null; then
    fail "branch '$branch' already exists locally; pick a new branch or remove the old worktree"
  fi
  # Best-effort remote check (read-only; DIA-096 safe). Skipped silently when
  # origin is unreachable (offline): a local-only create stays possible.
  # `timeout 5` bounds the wait so a dead/unreachable origin cannot block
  # create for minutes (GNU coreutils; stderr already silenced below).
  if timeout 5 git ls-remote --heads origin 2>/dev/null | grep -qF -- "refs/heads/$branch"; then
    fail "branch '$branch' already exists on origin; pick a new branch"
  fi
  if [ -e "$path" ]; then
    fail "worktree path '$path' already exists; pick a new branch or remove the old worktree"
  fi

  echo "-> creating worktree for '$branch' at '$path' (base: $base)"
  git worktree add -b "$branch" "$path" "$base"

  # DIA-100 verification item (f): each worktree must have its own
  # .opencode/session/ dir (zero handoff coordination). Mechanism: git
  # worktree add produces a full separate working directory, .opencode/session/
  # is git-ignored (never shared/committed), and OpenCode writes session
  # state under <cwd>/.opencode/session/ — so every worktree is isolated by
  # construction. We materialize the dir (OpenCode creates it lazily) and
  # assert it is a real directory, not a symlink back into the main checkout.
  mkdir -p "$path/.opencode/session"
  if [ -L "$path/.opencode/session" ]; then
    fail "worktree created but .opencode/session is a symlink; isolation broken"
  fi
  if git -C "$path" check-ignore -q .opencode/session/; then
    echo "ok: .opencode/session/ is git-ignored in the worktree (isolated per worktree)"
  else
    echo "warn: .opencode/session/ is NOT git-ignored in the worktree; fix .gitignore"
  fi
  echo "ok: worktree created — branch '$branch' at '$path'"
}

cmd_remove() {
  local target="" force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --force) force=1 ;;
      -h | --help) usage ;;
      -*) fail "unknown option '$1' (see --help)" ;;
      *)
        if [ -n "$target" ]; then
          fail "too many arguments (see --help)"
        fi
        target="$1"
        ;;
    esac
    shift
  done
  if [ -z "$target" ]; then
    usage
  fi

  local path main_path dirty branch
  path="$(resolve_worktree_path "$target")"
  main_path="$(git rev-parse --show-toplevel)"
  if [ "$path" = "$main_path" ]; then
    fail "refusing to remove the main checkout ('$path')"
  fi
  branch="$(worktree_branch_at "$path")"

  dirty="$(git -C "$path" status --porcelain)"
  if [ "$force" != "1" ] && [ -n "$dirty" ]; then
    fail "worktree '$path' has uncommitted changes; commit or stash them first, or use --force (developer-only: WORKTREES_FORCE=1 — maps to DIA-096 denied destructive ops)"
  fi

  if [ "$force" = "1" ]; then
    # Lanes cannot force: the env guard is the barrier because git worktree
    # remove --force is NOT itself in the DIA-096 deny list (only git clean
    # -f* / git branch -D are). Agents must never set WORKTREES_FORCE=1.
    if [ "${WORKTREES_FORCE:-0}" != "1" ]; then
      fail "--force requires WORKTREES_FORCE=1 (developer-only; lanes must never set it — DIA-096)"
    fi
    echo "-> force-removing worktree '$path' (uncommitted changes will be lost)"
    git worktree remove --force "$path"
  else
    git worktree remove "$path"
  fi
  echo "ok: worktree at '$path' removed; branch '$branch' kept for the rollback window; after the window the developer deletes it (git branch -d/-D is denied for lanes, DIA-096)"
}

cmd_list() {
  git worktree list "$@"
}

main() {
  local cmd="${1:-}"
  if [ $# -lt 1 ]; then
    usage
  fi
  shift
  case "$cmd" in
    create) cmd_create "$@" ;;
    remove) cmd_remove "$@" ;;
    list) cmd_list "$@" ;;
    -h | --help | help) usage ;;
    *) fail "unknown command '$cmd' (see --help)" ;;
  esac
}

main "$@"
