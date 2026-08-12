# Design: dia-100-worktree-lifecycle

> **Proposal:** `openspec/changes/dia-100-worktree-lifecycle/proposal.md`
> **Predecessor tickets:** DIA-100 "git worktrees for parallel dev sessions" (FIXED), DIA-073 "handoff coordination" (CLOSED, option d adopted), DIA-074 "ticket filenames descriptors" (branch naming source), DIA-096 "git push permission policy" (CLOSED, safe/destructive mapping)
> **Implementation commits:** `a387f72`, `44865c3`, `8cd270d`
> **Scope:** dev-infra only -- no system architecture decisions, no `.sdd/` escalation required (gap flagged as follow-up), no section 10 routing.

## Approach

This change stays within the existing dev-infra module boundary. It replicates the de-facto contract established by prior dev-infra scripts (`scripts/session-log`, `scripts/check-tools.sh`, `scripts/check-pin-sync.sh`): a standalone bash-3 compatible CLI, wired into `make test-shell` via the bats-wrapper auto-discovery, with a bats suite using real isolated git repos (NOT FAKE-mock for the whole script) plus FAKE-mock for `ls-remote` only. No new module is introduced, no cross-cutting technology decision is made, `architecture.md` is not affected.

### Governing contracts

- **DIA-073 option d (worktrees-only parallel model):** developer decision 2026-08-09. Each lane is a separate git worktree on a feature branch, rooted at `.worktrees/<branch-with-dashes>/`.
- **DIA-074 (branch naming):** `feature/<ticket>-<short-name>`. Enforced by `validate_branch` in the script.
- **DIA-096 (safe/destructive mapping):** the script enforces the same boundaries as the permission config. `remove --force` requires `WORKTREES_FORCE=1` (lane barrier). Branch deletion is developer-only (script never invokes `git branch -d/-D`).

### Patterns reused (no new patterns introduced)

- **Bash-3 compatibility:** same contract as `scripts/session-log` (no `[[ ]]`, no associative arrays, no `${!var}`, no `**`, no `printf -v`).
- **Standalone CLI with subcommands:** mirrors `scripts/session-log` (subcommands: `render`, `validate`, etc.). The worktrees CLI has three subcommands: `create`, `remove`, `list`.
- **Exit code contract:** 0 success, 1 runtime error (fail-loud on stderr), 2 usage error. Same shape as `scripts/check-pin-sync.sh` (which adds exit 2 for INFRA).
- **`fail-loud` pattern:** every non-zero exit preceded by `error: <message>` on stderr. No bare `exit N`.
- **`ok:`/`warn:`/`->` prefix pattern:** mirrors `scripts/check-tools.sh` (ok: for success, warn: for soft issues, -> for progress).
- **bats-wrapper `bash -n` allowlist:** mirrors existing entries for `check-tools.sh`, `check-pin-sync.sh`, etc.
- **Real-git fixture pattern (NEW for this suite):** the bats suite uses real `git init` + `git worktree add` under `$BATS_TEST_TMPDIR`, not FAKE-mock for the whole script. This is unique to the worktrees suite because the script wraps real git worktree commands and the safety guards depend on real git state. FAKE-mock is preserved for `ls-remote` only (T12, T13).

## Files changed

| File                                           | Change                                                                                                                                                                                                                                                                                                                           | Notes                                                                                                                                                         |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `scripts/worktrees.sh`                         | **New file** (273 lines) -- bash-3 compatible, `set -euo pipefail`, standalone lifecycle CLI. Subcommands: `create`, `remove`, `list`. Functions: `validate_branch`, `path_from_branch`, `resolve_worktree_path`, `worktree_branch_at`, `cmd_create`, `cmd_remove`, `cmd_list`, `fail`, `usage`, `main`. Exit codes: 0/1/2.      | DIA-074 branch validation, DIA-096 force barrier, .opencode/session isolation verification, timeout 5 on ls-remote.                                           |
| `scripts/__tests__/worktrees.bats`             | **New file** (264 lines) -- 16 cases (T1-T16). Real isolated git repo fixture under `$BATS_TEST_TMPDIR` via `setup_worktree_repo()`. FAKE-mock for `ls-remote` only via `mock_git_ls_remote()`.                                                                                                                                  | Covers every branch: create happy path, branch validation, duplicate rejection, remove happy path, dirty refusal, force barrier, main protection, list, help. |
| `docs/dev-infra-audit/worktree-conventions.md` | **New file** (227 lines) -- operational conventions for the parallel-dev model. Sections: purpose, relationship to worktrees skill, branch naming, worktree location, lifecycle CLI, merge workflow (worked example), conflict escalation, cleanup policy, DIA-096 mapping, OpenCode interaction, orchestrator dispatch pattern. | Self-documenting operational layer for the parallel-dev model.                                                                                                |
| `.gitignore`                                   | **Extended** -- added `.worktrees/` section (worktree directories, DIA-100). `.opencode/session/` already covered by the existing `.opencode/session/` rule.                                                                                                                                                                     | `.worktrees/` is a new top-level section; `.opencode/session/` rule unchanged.                                                                                |
| `scripts/__tests__/bats-wrapper.sh`            | **Extended** -- added `"$ROOT/scripts/worktrees.sh"` to the `bash -n` syntax-check allowlist.                                                                                                                                                                                                                                    | Pure allowlist edit; no other logic change.                                                                                                                   |

### Files NOT changed (by ruling)

- **`~/.config/opencode/skills/worktrees/SKILL.md`** -- the skill defines the orchestration protocol; this change implements the project-specific mechanics. The skill is referenced, not duplicated.
- **`opencode.jsonc` / `oh-my-opencode-slim.jsonc` / `.opencode/agents/*.md` / `.opencode/skills/*/SKILL.md`** -- not touched. Section 10 routing is N/A.
- **`.sdd/`** -- no new document authored (gap flagged in proposal, drafted content provided in spec report for manual creation).
- **`docs/dev-infra-audit/tickets/README.md`** -- deferred (carries uncommitted DIA-115 edits from another lane).
- **`DIA-100` ticket** -- already updated (status OPEN -> FIXED, Fix section populated, verification evidence added) by commits `a387f72`, `44865c3`, `8cd270d`. Not modified by this spec.

## Data flow

### create subcommand

```
bash scripts/worktrees.sh create feature/DIA-100-foo [base]
    |
    +-- validate_branch("feature/DIA-100-foo")
    |       |
    |       +-- must start with 'feature/' -> fail (exit 1)
    |       +-- stem must match [A-Za-z0-9][A-Za-z0-9._-]* -> fail (exit 1)
    |       +-- soft warn if stem doesn't match DIA-<NNN>-<slug> pattern
    |
    +-- path_from_branch("feature/DIA-100-foo") -> ".worktrees/feature-DIA-100-foo"
    |
    +-- check local branch doesn't exist (git rev-parse --verify refs/heads/...)
    |       +-- exists -> fail (exit 1)
    |
    +-- best-effort remote check (timeout 5 git ls-remote --heads origin)
    |       +-- branch exists on origin -> fail (exit 1)
    |       +-- timeout / unreachable -> skip silently (offline mode)
    |
    +-- check worktree path doesn't exist on disk
    |       +-- exists -> fail (exit 1)
    |
    +-- git worktree add -b "feature/DIA-100-foo" ".worktrees/feature-DIA-100-foo" "main"
    |
    +-- mkdir -p ".worktrees/feature-DIA-100-foo/.opencode/session"
    |
    +-- check .opencode/session is not a symlink
    |       +-- is symlink -> fail (exit 1, "isolation broken")
    |
    +-- check .opencode/session is git-ignored in the worktree
    |       +-- not ignored -> warn (exit 0, "fix .gitignore")
    |       +-- ignored -> ok (exit 0)
    |
    +-- ok: worktree created -- branch 'feature/DIA-100-foo' at '.worktrees/feature-DIA-100-foo'
```

### remove subcommand

```
bash scripts/worktrees.sh remove <target> [--force]
    |
    +-- resolve_worktree_path(<target>)
    |       |
    |       +-- if target is a directory AND a valid git dir -> return target as path
    |       +-- else scan `git worktree list --porcelain` for matching branch
    |       +-- no match -> fail (exit 1, "no worktree found")
    |
    +-- get main checkout path (git rev-parse --show-toplevel)
    |       +-- target == main -> fail (exit 1, "refusing to remove the main checkout")
    |
    +-- worktree_branch_at(<path>) -> branch name (for success message)
    |       +-- no branch found (detached HEAD?) -> fail (exit 1)
    |
    +-- check dirty (git -C <path> status --porcelain)
    |       +-- dirty AND force != 1 -> fail (exit 1, "has uncommitted changes")
    |
    +-- if force == 1:
    |       +-- check WORKTREES_FORCE env var
    |       |       +-- != 1 -> fail (exit 1, "requires WORKTREES_FORCE=1")
    |       +-- git worktree remove --force <path>
    |   else:
    |       +-- git worktree remove <path>
    |
    +-- ok: worktree at '<path>' removed; branch '<branch>' kept for the rollback window; ...
```

### list subcommand

```
bash scripts/worktrees.sh list [args...]
    |
    +-- git worktree list [args...]
    (passes all remaining args through to git worktree list)
```

## Function contracts

### `validate_branch <branch>`

Enforces the DIA-074 convention: `feature/<ticket>-<short-name>`. Hard rules:

- must start with `feature/`
- the part after `feature/` is a single path component of `[A-Za-z0-9][A-Za-z0-9._-]*` (no extra slashes, no leading dash/dot)
- soft warning when the stem doesn't match `DIA-<NNN>-<short-name>` (ticket-less branches should be rare and deliberate)

### `path_from_branch <branch>`

Converts branch slashes to dashes for the worktree path: `feature/DIA-100-foo` -> `.worktrees/feature-DIA-100-foo`. Keeps the `feature-` prefix (does not strip it).

### `resolve_worktree_path <branch|path>`

Resolves a target (either a branch name or a worktree path) to the actual worktree path. Algorithm:

1. If the target is an existing directory AND a valid git dir, return it.
2. Otherwise, scan `git worktree list --porcelain` for a worktree whose branch matches the target.
3. No match -> fail (exit 1).

### `worktree_branch_at <path>`

Returns the branch name (without `refs/heads/` prefix) of the worktree at `<path>`. Used by `cmd_remove` so the success message reports the REAL branch even when the user removed by path (the path's basename is the branch with slashes converted to dashes and cannot be reversed losslessly).

### `cmd_create <branch> [base]`

Creates a worktree for `<branch>` at `.worktrees/<branch-with-dashes>` on base `<base>` (default: main). Validates branch name, refuses existing branches (local + best-effort remote with `timeout 5`), creates the worktree, materializes `.opencode/session/`, verifies isolation (not a symlink, is git-ignored).

### `cmd_remove <target> [--force]`

Removes a worktree. Accepts either a branch name or a worktree path. Refuses dirty worktrees unless `--force`. `--force` requires `WORKTREES_FORCE=1` (DIA-096 lane barrier). Refuses the main checkout. ALWAYS keeps the branch (rollback window).

### `cmd_list [args...]`

Forwards all args to `git worktree list`.

## Seams

> Per `openspec/config.yaml`: "Include a Seams section listing the pre-agreed public boundaries where tests will live. Prefer existing seams; propose new ones only at the highest level necessary."

| Seam                                                                 | What it is                                                                                                                                                                                                                   | Test location                                         | Test type                                                                                            |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Lifecycle CLI** (`scripts/worktrees.sh`)                           | Bash-3 compatible, three subcommands (create/remove/list), exit codes 0/1/2, 14 exit-1 paths + 6 exit-2 paths + 2 warn-level outputs.                                                                                        | `scripts/__tests__/worktrees.bats` (16 cases, T1-T16) | Real isolated git repo fixture under `$BATS_TEST_TMPDIR`; FAKE-mock for `ls-remote` only (T12, T13). |
| **bats-wrapper allowlist** (`scripts/__tests__/bats-wrapper.sh`)     | `bash -n` syntax-check loop for `worktrees.sh`.                                                                                                                                                                              | Invoked by `make test-shell` via bats-wrapper.        | Implicit: if the syntax check fails, `test-shell` fails before any bats run.                         |
| **.gitignore entries**                                               | `.worktrees/` and `.opencode/session/` rules.                                                                                                                                                                                | Visual review by `@reviewer` (Standards axis).        | No automation by design; .gitignore is a declarative file.                                           |
| **Conventions doc** (`docs/dev-infra-audit/worktree-conventions.md`) | Operational layer for the parallel-dev model. Branch naming, worktree location, lifecycle CLI, merge workflow (worked example), conflict escalation, cleanup policy, DIA-096 mapping, session isolation, dispatch templates. | Visual review by `@reviewer` (Standards axis).        | Markdown; no automation by design. The doc is the operational contract for lanes and the developer.  |

### Test seam -- the real-git fixture pattern

The worktrees bats suite uses a unique test pattern:

- `setup_worktree_repo()` -- creates a fresh isolated git repo under `$BATS_TEST_TMPDIR/repo` with `git init -b main`, one empty commit, and the script copied in. Every git invocation operates on the fixture repo, never the real repo.
- `mock_git_ls_remote()` -- plants a fake `git` binary on PATH that intercepts `ls-remote` calls (with configurable output, sleep, and exit code via env vars `FAKE_LS_REMOTE_OUTPUT`, `FAKE_LS_REMOTE_SLEEP`, `FAKE_LS_REMOTE_EXIT`) and delegates everything else to the real git binary.

This is different from the FAKE-mock pattern used by other bats suites (check-tools.bats, check-pin-sync.bats) because the worktrees script wraps real `git worktree` commands, and the safety guards depend on real git state (branch existence, worktree state, dirty detection). FAKE-mock for the whole script would require mocking `git worktree add/remove/list` -- which would test the mock, not the real behavior.

### New seams vs. existing seams

- **Lifecycle CLI + bats suite** -- **new seam**. Justified: the lifecycle CLI is a new dev-infra tool with unique safety requirements (DIA-096 mapping, main checkout protection, session isolation verification). It needs its own bats suite with its own fixture pattern.
- **bats-wrapper allowlist** -- **existing seam extended**. Pure allowlist edit.
- **.gitignore** -- **existing seam extended**. New section added.
- **Conventions doc** -- **new seam**. Justified: the doc is the operational contract for the parallel-dev model. It needs its own file (not merged into AGENTS.md or architecture.md because it's dev-infra specific, not system-wide).

## Design constraints and trade-offs

### Why a standalone script (not extending the worktrees skill)

- **Separation of concerns:** the skill defines the orchestration protocol (planning, ownership, cleanup). The script implements the mechanics. Mixing them conflates protocol with mechanics.
- **Testability:** the script is a bash-3 CLI testable via bats. The skill is a Markdown file with instructions, not testable.
- **Repo-specific:** the branch naming convention, worktree location, and merge strategy are project-specific. The skill is global (shared across repos). The script + conventions doc are the project's delta from the skill's defaults.
- **Confirmed interview ruling (Q4):** skill=protocol, script=mechanics, conventions=project deltas.

### Why bash-3 compatible

- **macOS compatibility:** macOS ships with bash 3.2 by default. Developers on macOS should be able to run the script without installing bash 4+.
- **Pattern reuse:** mirrors `scripts/session-log` (bash-3 compatible for the same reason).
- **No need for bash-4+ features:** the script's data model is simple (branch names, paths, flags). Associative arrays, `[[ ]]`, `${!var}` indirection are not needed.

### Why the branch is kept on remove (rollback window)

- **Recovery from bad squash:** if the squash-merge to main is broken, the developer can recover with `git checkout feature/... && git cherry-pick` or a new merge. Without the branch, recovery requires reflog archaeology.
- **DIA-096 alignment:** `git branch -d/-D` is denied for lanes. The script never invokes branch deletion. The developer deletes the branch after the rollback window.
- **Low cost:** keeping a branch is a negligible storage cost (a ref, not a full copy of the worktree).

### Why `WORKTREES_FORCE=1` env guard (not just `--force` flag)

- **DIA-096 mapping:** `git worktree remove --force` is not itself in the DIA-096 deny list (only `git clean -f*` and `git branch -D` are denied). But the script treats it as developer-only because it maps to the same destructive intent (forced removal of uncommitted work).
- **Lane barrier:** lanes cannot set env vars (permission config + convention). The env guard is a stronger barrier than a flag (which a lane could accidentally pass).
- **Explicit intent:** the developer must deliberately set `WORKTREES_FORCE=1` to force-remove. This prevents accidents.

### Why `timeout 5` on `git ls-remote`

- **Unreachable origin bounded:** if origin is unreachable (offline, DNS failure, firewall), `git ls-remote` hangs for minutes (default TCP timeout). The `timeout 5` bounds the wait to 5 seconds.
- **Offline mode:** when origin is unreachable, the check is silently skipped (local-only create stays possible). The `timeout` command returns 124 on timeout, which the script catches and treats as "skip the remote check."
- **GNU coreutils:** `timeout` is part of GNU coreutils, available on Linux and macOS (via `brew install coreutils`). The dev container has it.

### Why real-git fixture (not FAKE-mock for the whole script)

- **Safety guards depend on real git state:** the script's safety guards (branch existence check, worktree state check, dirty detection, main checkout protection) depend on real git state. FAKE-mock for the whole script would test the mock, not the real behavior.
- **Test fidelity:** real `git worktree add/remove` exercises the real git code paths. The bats suite verifies the script's behavior on real git operations.
- **FAKE-mock preserved for ls-remote only:** the `ls-remote` check is the only network-dependent operation. FAKE-mock for `ls-remote` (T12, T13) is sufficient to test the remote-exists and unreachable-origin paths without requiring network access.

### Why .opencode/session isolation (not shared session)

- **Zero coordination:** each worktree has its own `.opencode/session/` directory by construction (git worktree produces a separate working directory, `.opencode/session/` is git-ignored). Parallel lanes can run independent OpenCode sessions without sharing state.
- **DIA-085/ana011 not needed (yet):** the parallel-session coordination protocol (claim/heartbeat/resume) is designed but not implemented. For the current parallel-dev model (each lane is a separate worktree with its own session), coordination is not needed.
- **Symlink check:** the script verifies `.opencode/session/` is a real directory, not a symlink back into the main checkout. This catches accidental symlinks that would break isolation.
