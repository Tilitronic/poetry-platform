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
#                            refuses already-existing branches, verifies
#                            .opencode/session/ isolation in the new worktree,
#                            and materializes the .husky/_ shim (DIA-134 S1).
#   remove <branch|path>     remove a worktree. The branch is KEPT for the
#                            rollback window (cleanup after the window is a
#                            developer action — git branch -d/-D is denied
#                            for lanes, DIA-096). Refuses dirty/uncommitted
#                            worktrees unless --force.
#   cleanup [--days N] [--dry-run]
#                            delete merged feature/* branches whose rollback
#                            window elapsed (DIA-137). Merge-verified against
#                            main (is-ancestor fast path, tree-subset check
#                            for squash parity); dirty linked worktrees are
#                            ALWAYS skipped; the default window is 0 days
#                            (immediate post-merge teardown). Local state
#                            only — no fetch, no remote reads.
#   list                     show active worktrees (path + HEAD + branch).
#
# Options:
#   remove: --force          force-remove a dirty worktree. DEVELOPER-ONLY:
#                            requires WORKTREES_FORCE=1 (lanes must never set
#                            it) because forced removal maps to DIA-096 denied
#                            destructive ops (git clean -f* / branch -D); see
#                            docs/dev-infra-audit/worktree-conventions.md.
#   cleanup: --days N        age window in days. Precedence (DIA-137 D6):
#                            --days flag > WORKTREES_CLEANUP_DAYS env var >
#                            default 0. Non-integer --days is a usage error.
#   cleanup: --dry-run       list would-be-deleted candidates only; zero
#                            side effects (no branch deletion, no worktree
#                            removal).
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

warn() {
  echo "warn: $*" >&2
}

usage() {
  cat >&2 <<'EOF'
usage: worktrees.sh <command> [options]

commands:
  create <branch> [base]   create a worktree at .worktrees/<branch-stem>
                           on new branch <branch> (base defaults to main)
  remove <branch|path>     remove a worktree; keeps the branch for the
                           rollback window
  cleanup [--days N] [--dry-run]
                           delete merged feature/* branches whose rollback
                           window elapsed (default 0 days: immediate)
  list                     show active worktrees (path + HEAD + branch)

options:
  remove --force           force-remove a dirty worktree (developer-only;
                           requires WORKTREES_FORCE=1 — lanes never set it)
  cleanup --days N         age window in days; flag beats
                           WORKTREES_CLEANUP_DAYS env, which beats default 0
  cleanup --dry-run        list would-be-deleted candidates; no side effects
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
    echo "warn: branch '$branch' stem does not match 'DIA-<NNN>-<lowercase-kebab-case>' (DIA-074); ticket-less branches should be rare and deliberate, uppercase/mixed-case stems should be rare"
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

# worktree_path_for_branch <branch>: echo the linked-worktree path of
# <branch>, or nothing when the branch has no linked worktree (DIA-137).
# Returns 0 in both cases (empty output = no worktree); returns 1 ONLY when
# `git worktree list` itself fails — the caller treats that as a candidate
# error (D4 fail-safe), never as "no worktree", so a failed lookup can never
# lead to a branch delete.
worktree_path_for_branch() {
  local branch="$1" porcelain line wtpath="" wtbranch=""
  porcelain="$(git worktree list --porcelain 2>/dev/null)" || return 1
  while IFS= read -r line; do
    if [ -z "$line" ]; then
      wtpath=""
      wtbranch=""
      continue
    fi
    case "$line" in
      worktree\ *) wtpath="${line#worktree }" ;;
      branch\ *) wtbranch="${line#branch refs/heads/}" ;;
    esac
    if [ -n "$wtpath" ] && [ -n "$wtbranch" ] && [ "$wtbranch" = "$branch" ]; then
      printf '%s' "$wtpath"
      return 0
    fi
  done <<EOF
$porcelain
EOF
  return 0
}

# branch_tree_in_main <branch>: squash-parity check (D2 slow path). Returns
# 0 when every file tracked on <branch> exists in main with identical
# content -- the branch's own changes are contained in main. Returns 1 when
# any branch file is missing from main or differs (genuinely unmerged);
# returns 128 when a git op fails (caller: fail-safe skip, never a delete).
# WHY NOT a plain `git diff main <branch>` emptiness check: that only passes
# when the two TREES are identical, and in the realistic post-batch state
# main already contains the squashed content of many previously merged
# branches -- so a whole-tree diff would misclassify a genuinely
# squash-merged branch as unmerged. The subset check is the exact squash
# semantics: "nothing on the branch is absent from main", independent of
# main-only content from other merges.
branch_tree_in_main() {
  local branch="$1" paths rc=0
  paths="$(git ls-tree -r --name-only "$branch" 2>/dev/null)" || return 128
  if [ -z "$paths" ]; then
    # empty branch tree: nothing on the branch is missing from main
    return 0
  fi
  git diff --quiet refs/heads/main "$branch" -- $paths 2>/dev/null || rc=$?
  # rc: 0 = subset (merged), 1 = differs (unmerged), 128 = git error
  return "$rc"
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

  # DIA-134 S1 (DD1): husky shim materialization. `git worktree add` does NOT
  # deliver .husky/_ (the husky v9 scaffolding dir is git-ignored; only the
  # tracked .husky/pre-commit + .husky/pre-push hooks come over), so a fresh
  # worktree would silently bypass the pre-commit hook (DIA-094). Copy the
  # already-materialized shim from the main tree: plain filesystem copy, NOT
  # `husky install` (side effects: mutates core.hooksPath, needs husky on
  # PATH) and NOT a symlink (would break the worktree-isolation invariant).
  # Fail loudly when the main tree has no shim to copy -- no silent bypass.
  if [ ! -d "$ROOT/.husky/_" ]; then
    fail 'husky is not installed in the main tree; run `husky install` before creating worktrees'
  fi
  # mkdir -p first: `cp -R src/_ dst/` FLATTENS the copy when dst/ does not
  # exist (it creates dst/ with src's contents directly), so the .husky/ dir
  # must exist before the copy or husky.sh would land at .husky/husky.sh
  # instead of .husky/_/husky.sh.
  mkdir -p "$path/.husky"
  cp -R "$ROOT/.husky/_" "$path/.husky/"
  # Post-copy assertion (DD1 / AC 1.1): .husky/_ must be a REAL directory in
  # the worktree -- a symlink would break isolation, a missing dir means the
  # copy failed. `test -d` alone would pass a symlink to a real dir, so the
  # -L check closes that gap.
  if [ -L "$path/.husky/_" ] || [ ! -d "$path/.husky/_" ]; then
    fail "worktree created but .husky/_ is not a real directory; husky shim broken"
  fi

  # DIA-100 verification item (f): each worktree must have its own
  # .opencode/session/ dir (zero handoff coordination). Mechanism: git
  # worktree add produces a full separate working directory, .opencode/session/
  # is git-ignored (never shared/committed), and OpenCode writes session
  # state under <cwd>/.opencode/session/ — so every worktree is isolated by
  # construction. We materialize the dir (OpenCode creates it lazily) and
  # assert it is a real directory, not a symlink back into the main checkout.
  mkdir -p "$path/.opencode/session"
  # Defense-in-depth (DIA-100 review finding): check BOTH the leaf and the
  # parent dir. mkdir -p follows a symlinked .opencode, so testing only the
  # leaf would miss a redirect of the whole dir. bash-3 compatible ([ -L ]).
  if [ -L "$path/.opencode" ] || [ -L "$path/.opencode/session" ]; then
    fail "worktree created but .opencode (or .opencode/session) is a symlink; isolation broken"
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
    # Lanes cannot force: direct `git worktree remove --force/-f` is denied as
    # an agent tool call (DIA-117 config deny in .opencode/opencode.jsonc).
    # The WORKTREES_FORCE=1 env guard remains the primary barrier for the
    # scripted path - the script runs the force-remove as an internal
    # subprocess, which OpenCode does not gate (developer terminal unaffected).
    # Agents must never set WORKTREES_FORCE=1.
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

# ---------------------------------------------------------------------------
# cleanup (DIA-137): post-merge teardown that deletes merged feature/*
# branches. Two-pass classify-then-act scan, local git state only.
#
# Globals (set by cmd_cleanup before the candidate loop):
#   CLEANUP_WINDOW  age window in days (0 = delete immediately)
#   CLEANUP_NOW     epoch at run start (age check baseline)
#   DRY_RUN         1 = list would-be-deleted candidates only, no side effects
#   CURRENT_HEAD    currently-checked-out branch of the main tree ("" if
#                   detached) — never a candidate
# ---------------------------------------------------------------------------

# cleanup_candidate <branch>: classify one feature/* branch against main and
# act per the action matrix (openspec spec: "Per-candidate action matrix"):
#   1. unmerged + young          -> silent skip (active lane)
#   2. merged + young            -> skip with report
#   3. unmerged + old            -> skip with report
#   4. merged + old + dirty wt   -> skip with report (never loses work, D5)
#   5. merged + old + clean wt   -> remove worktree THEN delete branch
#   6. merged + old + no wt      -> delete branch (+ leftover dir on disk)
# Returns 0 for handled-and-intentional-skips; 1 when a git operation on this
# candidate FAILED (D4 fail-safe: cmd_cleanup records it, scan continues).
# Every per-candidate git call is guarded (`|| rc=$?` / `if !`) so a broken
# ref or lock error skips ONE candidate instead of aborting the run under
# `set -euo pipefail`.
cleanup_candidate() {
  local branch="$1" rc=0 tip="" wtpath="" wtdir="" dirty=""
  local merged=0 old=0

  # Main-tree guard: the branch the main checkout is on can never be deleted
  # (git refuses); warn on stderr and let the scan continue (T28). Checked
  # BEFORE classification so no git op runs on the protected branch.
  if [ -n "$CURRENT_HEAD" ] && [ "$branch" = "$CURRENT_HEAD" ]; then
    warn "skipping checked-out branch '$branch' (the main tree is on it)"
    return 0
  fi

  # Pass 1 -- merge check (D2). Fast path: is-ancestor against main. Slow
  # path (only when not an ancestor): squash-parity via branch_tree_in_main
  # (tree-subset), which catches squash-merged branches whose commits are
  # NOT ancestors of main. Exit 1 from either check is the legit "not
  # merged" answer; 128 (or anything else) is a real git failure -> fail-safe
  # skip. refs/heads/main is explicit so an origin/main remote cannot shadow
  # the local branch.
  git merge-base --is-ancestor "$branch" refs/heads/main >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    merged=1
  elif [ "$rc" -eq 1 ]; then
    if branch_tree_in_main "$branch"; then
      merged=1
    elif [ "$?" -eq 128 ]; then
      warn "skipping '$branch' (merge check failed: 'git diff main $branch' errored)"
      return 1
    fi
  else
    warn "skipping '$branch' (merge check failed: 'git merge-base --is-ancestor $branch main' errored)"
    return 1
  fi

  # Pass 2 -- age check (D3): branch-tip commit date vs the window. A tip
  # older than now - N*86400 is "old"; the default window 0 makes every
  # past-dated tip eligible (immediate post-merge teardown, D6).
  rc=0
  tip="$(git log -1 --format=%ct "$branch" 2>/dev/null)" || rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$tip" ]; then
    warn "skipping '$branch' (cannot read branch tip date)"
    return 1
  fi
  if [ "$tip" -le "$(( CLEANUP_NOW - CLEANUP_WINDOW * 86400 ))" ]; then
    old=1
  fi

  # Matrix rows 1-3: non-deletable candidates. Dry-run reports NOTHING for
  # these (only would-delete candidates are listed -- the window-precedence
  # tests assert preserved branches are absent from dry-run output).
  if [ "$merged" -ne 1 ] && [ "$old" -ne 1 ]; then
    return 0 # unmerged + young: silent (active lane)
  fi
  if [ "$merged" -eq 1 ] && [ "$old" -ne 1 ]; then
    [ "$DRY_RUN" = "1" ] || echo "skipped: $branch (merged but below the $CLEANUP_WINDOW-day window)"
    return 0
  fi
  if [ "$merged" -ne 1 ]; then
    [ "$DRY_RUN" = "1" ] || echo "skipped: $branch (unmerged; content not on main)"
    return 0
  fi

  # Matrix rows 4-6: merged + old. Locate the linked worktree (if any).
  wtpath="$(worktree_path_for_branch "$branch")" || {
    warn "skipping '$branch' (cannot read worktree list)"
    return 1
  }

  if [ -n "$wtpath" ]; then
    rc=0
    dirty="$(git -C "$wtpath" status --porcelain 2>/dev/null)" || rc=$?
    if [ "$rc" -ne 0 ]; then
      warn "skipping '$branch' (cannot check worktree status at '$wtpath')"
      return 1
    fi
    if [ -n "$dirty" ]; then
      # Row 4: cleanup has no --force (D5); a dirty worktree is ALWAYS a
      # skip. Report on stdout (names branch + path); never deletes.
      [ "$DRY_RUN" = "1" ] || echo "would-skip (worktree dirty): $branch ($wtpath)"
      return 0
    fi
    # Row 5: clean linked worktree -> remove it FIRST (git refuses to delete
    # a checked-out branch), then delete the branch below.
    if [ "$DRY_RUN" = "1" ]; then
      echo "would-remove: worktree '$wtpath' (branch '$branch')"
    else
      if ! git worktree remove "$wtpath" >/dev/null 2>&1; then
        warn "skipping '$branch' (failed to remove worktree at '$wtpath')"
        return 1
      fi
      echo "removed: worktree '$wtpath' (branch '$branch')"
    fi
  else
    # Row 6: no linked worktree. A leftover (unregistered) worktree dir may
    # still exist on disk from an earlier `remove`; clear it too (T27).
    wtdir="$WORKTREES_DIR/$(path_from_branch "$branch")"
    if [ -d "$wtdir" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        echo "would-remove: leftover worktree dir '$wtdir'"
      else
        if ! rm -rf "$wtdir"; then
          warn "skipping '$branch' (failed to remove leftover worktree dir '$wtdir')"
          return 1
        fi
        echo "removed: leftover worktree dir '$wtdir'"
      fi
    fi
  fi

  # Branch deletion. -D (not -d) is deliberate: the two-pass merge check
  # above already verified the branch content is on main, and -d's own merge
  # check would refuse squash-merged branches (not an ancestor of HEAD or an
  # upstream). Internal deletion is self-governed -- the script is the policy
  # boundary (DIA-096 gates the OUTER command, worktree-conventions.md).
  if [ "$DRY_RUN" = "1" ]; then
    echo "would-delete: branch '$branch' (merged into main)"
    return 0
  fi
  if ! git branch -D "$branch" >/dev/null 2>&1; then
    warn "skipping '$branch' (branch deletion failed)"
    return 1
  fi
  echo "deleted: branch '$branch'"
  return 0
}

cmd_cleanup() {
  local days="" dry_run=0
  # Flag parsing mirrors cmd_remove: --days N and --dry-run in ANY order,
  # positional args rejected, -h/--help -> usage (exit 2).
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry_run=1 ;;
      --days)
        shift
        if [ $# -lt 1 ]; then
          usage
        fi
        days="$1"
        ;;
      -h | --help) usage ;;
      -*) fail "unknown option '$1' (see --help)" ;;
      *) fail "too many arguments (see --help)" ;;
    esac
    shift
  done

  # Window precedence (D6): --days flag > WORKTREES_CLEANUP_DAYS env >
  # default 0. A non-integer window is a usage error (exit 2); so is a
  # leading-zero value like '008' -- bash arithmetic would read it as octal
  # and abort the whole script under set -euo pipefail ("008: value too
  # great for base") instead of the spec-mandated exit 2 + usage (F1
  # regression: reject at parse time, never reach the $(( )) computation).
  CLEANUP_WINDOW="${days:-${WORKTREES_CLEANUP_DAYS:-0}}"
  case "$CLEANUP_WINDOW" in
    '' | *[!0-9]* | 0[0-9]*) usage ;;
  esac
  DRY_RUN="$dry_run"

  # Hard-abort preconditions (exit-code contract): not a git repo or no main
  # branch -> non-zero. These are the ONLY whole-run aborts; per-candidate
  # failures skip and continue (D4).
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    fail "not a git repository (cleanup requires a repo with a 'main' branch)"
  fi
  if ! git rev-parse --verify --quiet refs/heads/main >/dev/null 2>&1; then
    fail "no 'main' branch found; cleanup deletes merged feature/* branches against main"
  fi

  CLEANUP_NOW="$(date +%s)"
  CURRENT_HEAD=""
  if git symbolic-ref -q HEAD >/dev/null 2>&1; then
    CURRENT_HEAD="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
  fi

  local branch had_error=0
  # Candidates are local feature/* branches only: the refs/heads/feature/
  # prefix excludes main/master by construction, and enumeration is pure
  # local state (no fetch, no remote reads).
  while IFS= read -r branch; do
    [ -n "$branch" ] || continue
    if ! cleanup_candidate "$branch"; then
      had_error=1
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads/feature/)

  # Exit-code contract: 0 when every candidate was handled or intentionally
  # skipped; non-zero when any candidate hit a git error (broken ref, lock).
  exit "$had_error"
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
    cleanup) cmd_cleanup "$@" ;;
    list) cmd_list "$@" ;;
    -h | --help | help) usage ;;
    *) fail "unknown command '$cmd' (see --help)" ;;
  esac
}

main "$@"
