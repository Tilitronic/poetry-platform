# Tasks: dia-100-worktree-lifecycle

> **Proposal:** `openspec/changes/dia-100-worktree-lifecycle/proposal.md`
> **Design:** `openspec/changes/dia-100-worktree-lifecycle/design.md`
> **Predecessor tickets:** DIA-100 "git worktrees for parallel dev sessions" (FIXED), DIA-073 "handoff coordination" (CLOSED, option d adopted), DIA-074 "ticket filenames descriptors" (branch naming source), DIA-096 "git push permission policy" (CLOSED, safe/destructive mapping)
> **Implementation commits:** `a387f72` (feat: lifecycle CLI + conventions), `44865c3` (fix: review findings), `8cd270d` (docs: ticket evidence)
> **Mode:** retrospective spec -- tasks describe what WAS implemented, not what WILL BE. Verification evidence references actual commit hashes and test results.
> **Workflow:** per `openspec/config.yaml`, each task is a vertical slice. Since this is retrospective, the slices document the implementation order.
> **Routing:** AGENTS.md section 2.4 -> `@reviewer` (two-axis: Standards + Spec fidelity). Section 10 is N/A (script is pure dev-infra, not AI-tooling config).

## Dependency graph

```
T1 -- worktrees.sh core + .gitignore + bats-wrapper allowlist
 |  creates scripts/worktrees.sh (273L, new, bash-3 compatible)
 |  creates .gitignore .worktrees/ section
 |  extends scripts/__tests__/bats-wrapper.sh (worktrees.sh allowlist)
 |  three subcommands: create, remove, list
 |  functions: validate_branch, path_from_branch, resolve_worktree_path,
 |             worktree_branch_at, cmd_create, cmd_remove, cmd_list
 |  exit codes: 0/1/2 (14 exit-1 paths, 6 exit-2 paths, 2 warn-level outputs)
 |
 |  verification: bash -n scripts/worktrees.sh (exit 0)
 |                bash scripts/worktrees.sh --help (exit 2, usage)
 |                bash scripts/worktrees.sh create --help (exit 2, usage)
 |                DIA-074 branch validation (manual test: invalid branch -> exit 1)
 |
 |  ┌────────────────────────────────────────────────────────────────────────────┐
 |  |  T2 depends on T1 (script must exist before its bats suite runs)           |
 |  └────────────────────────────────────────────────────────────────────────────┘
 v
T2 -- worktrees.bats T1-T16 (16-case suite)
 |  creates scripts/__tests__/worktrees.bats (264L, new)
 |  real isolated git repo fixture under $BATS_TEST_TMPDIR (setup_worktree_repo)
 |  FAKE-mock for ls-remote only (mock_git_ls_remote)
 |  16 cases: T1-T16 (see proposal.md Testing Decisions for full matrix)
 |
 |  verification: make test-shell (exit 0; worktrees.bats T1-T16 all ok)
 |                bash scripts/__tests__/bats-wrapper.sh (bash -n on worktrees.sh)
 |
 |  ┌────────────────────────────────────────────────────────────────────────────┐
 |  |  T3 depends on T1 + T2 (conventions doc references the script + tests)    |
 |  └────────────────────────────────────────────────────────────────────────────┘
 v
T3 -- worktree-conventions.md + DIA-100 ticket update
    creates docs/dev-infra-audit/worktree-conventions.md (227L, new)
    updates docs/dev-infra-audit/tickets/DIA-100-git-worktrees-parallel-dev.md
    (status OPEN -> FIXED, Fix section populated, verification evidence)

    verification: conventions doc exists + readable
                  DIA-100 ticket status == FIXED
                  openspec validate dia-100-worktree-lifecycle (exit 0)
```

**Critical path:** T1 -> T2 -> T3 (linear). Each slice is sized for one fresh context window. T1 is the narrowest (just the script + minimal wiring); T2 adds the behavioral coverage; T3 adds the operational contract + ticket closure.

**Rationale for three slices (not one, not more):**

- **Not one slice:** the script (T1) is testable without the bats suite; the bats suite (T2) is testable without the conventions doc; the conventions doc (T3) is the final operational layer. Three slices allow each to be verified in isolation.
- **Not more slices:** each slice is already the narrowest coherent unit. Splitting T1 further (e.g., `create` subcommand alone) would create a slice that is not demoable on its own (a script with only `create` is incomplete). Splitting T2 (e.g., T1-T8 then T9-T16) would create artificial boundaries (the bats file is one logical unit). Splitting T3 (conventions doc separate from ticket update) would separate tightly-coupled changes (the conventions doc is what documents the fix; the ticket update references it).

**Retrospective note:** the actual implementation (commit `a387f72`) delivered T1 + T2 + T3 in a single commit. Commit `44865c3` applied review findings (ls-remote timeout, docs drift, remove message). Commit `8cd270d` recorded the implementation commit hash in the ticket evidence. The task slices above reflect the logical decomposition, not the commit history.

---

## T1 -- worktrees.sh core + .gitignore + bats-wrapper allowlist

**Blockers:** none
**Vertical slice:** the lifecycle CLI + .gitignore entries + bats-wrapper allowlist. After T1, `bash -n scripts/worktrees.sh` exits 0, and `bash scripts/worktrees.sh --help` exits 2 (usage).
**Routing:** AGENTS.md section 2.4 -> `@reviewer` (two-axis: Standards + Spec fidelity)
**Commit:** `a387f72` (part of the initial feat commit)

### Sub-steps (implementation order within the slice)

**Sub-step (a): Scaffold `scripts/worktrees.sh`**

- New file, executable, 273 lines, bash-3 compatible.
- Shebang: `#!/usr/bin/env bash`. Header comment describing the script's purpose (DIA-100, DIA-073 option d), subcommands, exit codes, bash-3 compatibility constraint, external deps (GNU coreutils `timeout`).
- `set -euo pipefail`.
- Resolve `ROOT` (same pattern as `scripts/session-log`: `$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)`).
- `WORKTREES_DIR="${WORKTREES_DIR:-$ROOT/.worktrees}"`, `DEFAULT_BASE="${DEFAULT_BASE:-main}"`.
- `fail()` function: echoes `error: $*` to stderr, exits 1.
- `usage()` function: echoes usage to stderr, exits 2.

**Sub-step (b): Implement `validate_branch`**

- Enforces DIA-074 convention: `feature/<ticket>-<short-name>`.
- Hard rules: must start with `feature/`, stem must match `[A-Za-z0-9][A-Za-z0-9._-]*`.
- Soft warning when stem doesn't match `DIA-<NNN>-<short-name>` pattern.

**Sub-step (c): Implement `path_from_branch`**

- Converts branch slashes to dashes: `feature/DIA-100-foo` -> `.worktrees/feature-DIA-100-foo`.

**Sub-step (d): Implement `resolve_worktree_path`**

- Resolves a target (branch name or worktree path) to the actual worktree path.
- Algorithm: check if target is a directory + valid git dir; else scan `git worktree list --porcelain` for matching branch.

**Sub-step (e): Implement `worktree_branch_at`**

- Returns the branch name of the worktree at `<path>`.
- Scans `git worktree list --porcelain`.

**Sub-step (f): Implement `cmd_create`**

- Validates branch name, refuses existing branches (local + best-effort remote with `timeout 5`), creates the worktree, materializes `.opencode/session/`, verifies isolation (not a symlink, is git-ignored).

**Sub-step (g): Implement `cmd_remove`**

- Resolves target, refuses main checkout, resolves branch name, refuses dirty worktrees unless `--force`, requires `WORKTREES_FORCE=1` for force, removes the worktree, keeps the branch.

**Sub-step (h): Implement `cmd_list` + `main`**

- `cmd_list`: forwards args to `git worktree list`.
- `main`: dispatches to subcommand handlers, handles `-h`/`--help`/`help`.

**Sub-step (i): Edit `.gitignore`**

- Add `.worktrees/` section (worktree directories, DIA-100).

**Sub-step (j): Edit `scripts/__tests__/bats-wrapper.sh`**

- Add `"$ROOT/scripts/worktrees.sh"` to the `bash -n` syntax-check allowlist.

**Sub-step (k): Verification**

1. `bash -n scripts/worktrees.sh` -- syntax check. Exit 0 required.
2. `bash scripts/worktrees.sh --help` -- usage. Exit 2 required.
3. `bash scripts/worktrees.sh create --help` -- usage. Exit 2 required (not a branch-name error).
4. DIA-074 branch validation: `bash scripts/worktrees.sh create DIA-100-test` -> exit 1 with `error: branch 'DIA-100-test' must start with 'feature/'`.
5. Visual inspection: bash-3 compliance grep: `grep -nE 'declare -A|\$\{!|\[\[ |\*\*|printf -v' scripts/worktrees.sh` returns no matches.
6. Line count: `wc -l scripts/worktrees.sh` -> 273 lines.

### Acceptance criteria (T1)

1. `scripts/worktrees.sh` exists, is executable, is bash-3 compatible.
2. `bash -n scripts/worktrees.sh` exits 0.
3. `bash scripts/worktrees.sh --help` exits 2 with usage message.
4. `bash scripts/worktrees.sh create DIA-100-test` exits 1 with `error: branch 'DIA-100-test' must start with 'feature/'`.
5. `.gitignore` has a `.worktrees/` section.
6. `scripts/__tests__/bats-wrapper.sh` syntax-checks `scripts/worktrees.sh` via `bash -n`.
7. Script is under 280 lines (273 actual).

### Verification evidence (T1, retrospective)

- Implementation commit: `a387f72` (feat: lifecycle CLI + conventions).
- `bash -n scripts/worktrees.sh` exit 0 (verified at implementation time).
- Line count: 273 lines (verified at implementation time).
- Bash-3 compliance: no bash-4+ constructs (verified at implementation time).

---

## T2 -- worktrees.bats T1-T16 (16-case suite)

**Blockers:** T1 (script must exist before the bats suite runs)
**Vertical slice:** the 16-case bats suite. After T2, `make test-shell` passes with worktrees.bats T1-T16 all ok.
**Routing:** AGENTS.md section 2.4 -> `@reviewer` (two-axis: Standards + Spec fidelity)
**Commit:** `a387f72` (part of the initial feat commit)

### Sub-steps

**Sub-step (a): Implement `setup_worktree_repo`**

- Creates a fresh isolated git repo under `$BATS_TEST_TMPDIR/repo` with `git init -b main`, one empty commit, and the script copied in.
- Echoes the tree root.

**Sub-step (b): Implement `mock_git_ls_remote`**

- Plants a fake `git` binary on PATH that intercepts `ls-remote` calls (configurable via `FAKE_LS_REMOTE_OUTPUT`, `FAKE_LS_REMOTE_SLEEP`, `FAKE_LS_REMOTE_EXIT`) and delegates everything else to the real git binary.

**Sub-step (c): Write T1-T16**

- T1: create happy path (exit 0, worktree dir + branch + isolated .opencode/session).
- T2: create invalid branch (no feature/ prefix) -> exit 1.
- T3: create duplicate local branch -> exit 1.
- T4: list shows branch + worktree path.
- T5: remove by branch -> exit 0, dir gone, branch KEPT (rollback window).
- T6: remove dirty worktree (no --force) -> exit 1, worktree survives.
- T7: remove --force without WORKTREES_FORCE=1 -> exit 1 (lane cannot force).
- T8: remove --force with WORKTREES_FORCE=1 -> exit 0, dir gone.
- T9: remove unknown target -> exit 1.
- T10: no command -> usage error (exit 2).
- T11: remove refuses the main checkout path -> exit 1.
- T12: create refuses branch that exists on origin (fake git ls-remote).
- T13: create bounded when origin unreachable (fake ls-remote sleeps; internal timeout 5).
- T14: remove by worktree PATH -> exit 0 + message shows path AND branch.
- T15: create --help -> usage (exit 2), not a branch-name error.
- T16: list forwards args to git worktree list (--porcelain works).

**Sub-step (d): Verification**

1. `make test-shell` -- exit 0. worktrees.bats T1-T16 all ok.
2. Test count delta: baseline -> baseline+16.
3. `bash scripts/__tests__/bats-wrapper.sh` -- `bash -n` on worktrees.sh passes.

### Acceptance criteria (T2)

1. `scripts/__tests__/worktrees.bats` exists with 16 `@test` blocks (T1-T16).
2. Every test uses the real-git fixture (setup_worktree_repo) under `$BATS_TEST_TMPDIR`.
3. T12 and T13 use FAKE-mock for `ls-remote` only (mock_git_ls_remote).
4. T1-T16 cover every branch: create happy path, branch validation, duplicate rejection, remove happy path, dirty refusal, force barrier, main protection, list, help.
5. `make test-shell` exits 0 with +16 cases.

### Verification evidence (T2, retrospective)

- Implementation commit: `a387f72` (feat: lifecycle CLI + conventions).
- `make test-shell` exit 0 (verified at implementation time, suite 204 ok including worktrees.bats T1-T16).
- Test count: 16 cases in worktrees.bats.

---

## T3 -- worktree-conventions.md + DIA-100 ticket update

**Blockers:** T1 + T2 (script + tests must exist before conventions doc references them)
**Vertical slice:** the conventions doc + DIA-100 ticket update. After T3, the conventions doc exists and the DIA-100 ticket is FIXED.
**Routing:** AGENTS.md section 2.4 -> `@reviewer` (two-axis: Standards + Spec fidelity)
**Commits:** `a387f72` (conventions doc), `8cd270d` (ticket evidence), `44865c3` (review findings applied to script + conventions)

### Sub-steps

**Sub-step (a): Write `docs/dev-infra-audit/worktree-conventions.md`**

- 227 lines, new file.
- Sections: purpose, relationship to worktrees skill, branch naming (DIA-074), worktree location (.worktrees/), lifecycle CLI, merge workflow (squash-merge with worked example), conflict escalation criteria, cleanup policy, DIA-096 safe/destructive mapping, OpenCode interaction (.opencode/session isolation), orchestrator dispatch pattern.

**Sub-step (b): Update DIA-100 ticket**

- `docs/dev-infra-audit/tickets/DIA-100-git-worktrees-parallel-dev.md`: status OPEN -> FIXED.
- Fix section populated: investigation findings, deliverables, verification evidence.
- Verification item (f) marked as verified.
- Verification items (a)-(e) deferred to workflow-adoption time.
- `updated` date set to closure date.

**Sub-step (c): Apply review findings (commit `44865c3`)**

- `timeout 5` on `git ls-remote` (DIA-100 review finding: bound the wait for unreachable origin).
- Docs drift fix in conventions doc.
- Remove message improvement (report the resolved branch, not the dashed path).

**Sub-step (d): Verification**

1. Conventions doc exists + readable.
2. DIA-100 ticket status == FIXED.
3. `openspec validate dia-100-worktree-lifecycle` exit 0 (coder lane).

### Acceptance criteria (T3)

1. `docs/dev-infra-audit/worktree-conventions.md` exists with all sections.
2. Conventions doc references DIA-074 (branch naming), DIA-096 (safe/destructive mapping), DIA-100 (lifecycle CLI).
3. Conventions doc includes a worked example for squash-merge workflow.
4. DIA-100 ticket status == FIXED with populated Fix section.
5. DIA-100 verification item (f) (session isolation) marked as verified.
6. DIA-100 verification items (a)-(e) deferred to workflow-adoption time.

### Verification evidence (T3, retrospective)

- Implementation commit: `a387f72` (conventions doc), `44865c3` (review findings), `8cd270d` (ticket evidence).
- Conventions doc: 227 lines, all sections present.
- DIA-100 ticket: status FIXED, Fix section populated, verification evidence added.

---

## Out of scope for these tasks

- **`docs/dev-infra-audit/tickets/README.md` row + rollup** -- deferred (file carries uncommitted DIA-158 edits from another lane).
- **Verification items (a)-(e)** -- require active worktree lane adoption (orthogonal to the lifecycle CLI).
- **DIA-085/ana011 parallel-session protocol** -- not yet implemented (orthogonal to the lifecycle CLI).
- **`.slim/worktrees.json` state file** -- not adopted by the project (orthogonal to the lifecycle CLI).
- **`.sdd/dev-infra/architecture.md`** -- flagged as follow-up (permission rules block .sdd/ writes from this role; @architector dispatch blocked by subagent depth limit). Drafted content provided in spec report for manual creation.
- **Section 10 routing** -- N/A (script is pure dev-infra, not AI-tooling config).

## Verification gate summary

| Gate                                           | When          | Required                                                                                     |
| ---------------------------------------------- | ------------- | -------------------------------------------------------------------------------------------- |
| `bash -n scripts/worktrees.sh`                 | T1 sub-step k | Exit 0 (syntax valid, bash-3 compatible)                                                     |
| `bash scripts/worktrees.sh --help`             | T1 sub-step k | Exit 2 (usage)                                                                               |
| DIA-074 branch validation                      | T1 sub-step k | `create DIA-100-test` exits 1 with `error: branch 'DIA-100-test' must start with 'feature/'` |
| Bash-3 compliance grep                         | T1 sub-step k | No matches for `declare -A\|\$\{!\|\[\[ \|\*\*\|printf -v`                                   |
| Line count of script                           | T1 sub-step k | 273 lines                                                                                    |
| `make test-shell`                              | T2 sub-step d | Exit 0; worktrees.bats T1-T16 all ok (16 cases)                                              |
| `bash scripts/__tests__/bats-wrapper.sh`       | T2 sub-step d | `bash -n` on worktrees.sh passes                                                             |
| Conventions doc exists                         | T3 sub-step d | `docs/dev-infra-audit/worktree-conventions.md` readable, 227 lines                           |
| DIA-100 ticket status                          | T3 sub-step d | `status: FIXED`, Fix section populated, verification evidence added                          |
| `openspec validate dia-100-worktree-lifecycle` | T3 sub-step d | Exit 0 (coder lane)                                                                          |
