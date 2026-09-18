# Proposal: dia-100-worktree-lifecycle

> **Status:** implemented (retrospective spec)
> **Scope:** dev-infra (worktree lifecycle CLI + bats suite + conventions doc + .gitignore entries)
> **Predecessor tickets:**
>
> - `docs/dev-infra-audit/tickets/DIA-100-git-worktrees-parallel-dev.md` (OPEN -> FIXED -- this change documents the fix)
> - `docs/dev-infra-audit/tickets/DIA-073-handoff-coordination-session-ids.md` (CLOSED -- option d adopted, developer decision 2026-08-09)
> - `docs/dev-infra-audit/tickets/DIA-074-ticket-filenames-descriptors.md` (branch naming convention source)
> - `docs/dev-infra-audit/tickets/DIA-096-git-push-permission-policy.md` (CLOSED -- safe/destructive mapping governs this change)
>   **Implementation commits:** `a387f72` (feat: lifecycle CLI + conventions), `44865c3` (fix: review findings), `8cd270d` (docs: ticket evidence)
>   **Escalation:** none -- dev-infra within existing module boundaries (per AGENTS.md section 2.4). Section 10 (AI Devtools Modernization Workflow) is N/A: the script is pure dev-infra, not AI-tooling config.
>   **Architecture gap (flagged, follow-up):** `.sdd/dev-infra/architecture.md` does not exist yet. This change documents the parallel-dev model's architecture decisions but does not author the SDD (permission rules block .sdd/ writes from the OpenSpec Architect role; @architector dispatch blocked by subagent depth limit). The drafted SDD content is provided in the spec report for manual creation. The gap is not a blocker for this spec.

## Motivation

Parallel OpenCode lanes need isolated checkouts on feature branches so multiple agents (or the developer + an agent) can work simultaneously without stepping on each other's working directory. The DIA-073 investigation evaluated four parallel-dev options (Docker containers, tmux sessions, separate clones, worktrees) and recommended option d (worktrees-only), adopted by developer decision on 2026-08-09.

The global worktrees skill at `~/.config/opencode/skills/worktrees/SKILL.md` defines the orchestration protocol (planning, ownership, cleanup, `.slim/worktrees.json` metadata) but deliberately leaves the project-specific mechanics open:

- branch naming convention (skill default is `omos/<slug>`; this repo uses `feature/<ticket>-<short-name>` per DIA-074)
- worktree location (skill default is `.slim/worktrees/<slug>`; this repo uses `.worktrees/`)
- a testable CLI for create/remove/list (the skill prescribes commands, not scripts)
- merge strategy choice (squash-merge)
- conflict escalation criteria
- the DIA-096 safe/destructive mapping
- an orchestrator dispatch template

This change (DIA-100) implements those project-specific mechanics: the lifecycle CLI (`scripts/worktrees.sh`), the 16-case bats suite (`scripts/__tests__/worktrees.bats`), the conventions doc (`docs/dev-infra-audit/worktree-conventions.md`), and the `.gitignore` entries (`.worktrees/` + `.opencode/session/`).

## Approach

A standalone bash-3 compatible CLI (`scripts/worktrees.sh`, 273 lines) with three subcommands (`create`, `remove`, `list`), a 16-case bats suite using real isolated git repos under `$BATS_TEST_TMPDIR` (FAKE-mock for `ls-remote` only), a conventions doc capturing the operational layer (branch naming, worktree location, merge workflow with worked example, conflict escalation, cleanup policy, DIA-096 mapping, session isolation, orchestrator dispatch templates), and `.gitignore` entries for `.worktrees/` and `.opencode/session/`.

The script wraps real `git worktree` commands with safety guards:

- `create` validates the branch name (DIA-074 convention), refuses existing branches (local + best-effort remote with `timeout 5`), creates the worktree, materializes `.opencode/session/`, and verifies isolation.
- `remove` resolves the target (accepts branch name OR worktree path), refuses dirty worktrees unless `--force`, requires `WORKTREES_FORCE=1` for force (DIA-096 lane barrier), refuses the main checkout, and ALWAYS keeps the branch (rollback window).
- `list` forwards args to `git worktree list`.

## Scope

### In scope

1. **Lifecycle CLI -- `scripts/worktrees.sh`** (273 lines, new file, executable, bash-3 compatible). Three subcommands: `create <branch> [base]`, `remove <branch|path> [--force]`, `list`. Exit codes: 0 success, 1 runtime error (fail-loud on stderr), 2 usage error. 14 exit-1 paths, 6 exit-2 paths, 2 warn-level (exit 0) outputs.
2. **bats suite -- `scripts/__tests__/worktrees.bats`** (264 lines, new file). 16 cases (T1-T16) using real isolated git repos under `$BATS_TEST_TMPDIR`. FAKE-mock for `ls-remote` only (T12, T13 -- fake git binary intercepts `ls-remote` calls, delegates everything else to the real git).
3. **Conventions doc -- `docs/dev-infra-audit/worktree-conventions.md`** (227 lines, new file). Branch naming, worktree location, lifecycle CLI, squash-merge workflow with worked example, conflict escalation criteria, cleanup policy, DIA-096 safe/destructive mapping, session isolation mechanism, orchestrator dispatch templates.
4. **.gitignore entries** -- `.worktrees/` and `.opencode/session/` (the latter under the existing `.opencode/session/` rule; the former added as a DIA-100 section).
5. **`scripts/__tests__/bats-wrapper.sh`** -- added `worktrees.sh` to the bash -n syntax-check allowlist.

### Out of scope (by ruling, Q1)

- **`docs/dev-infra-audit/tickets/README.md` row + rollup** -- the file carries uncommitted DIA-158 edits from another lane; not committed per no-other-lane-files rule.
- **Verification items (a)-(e)** -- require active worktree lane adoption (orchestrator-dispatched creation, safe-push from worktree, reviewer-in-worktree, squash-merge, post-merge cleanup). Item (f) (session isolation) is verified by the throwaway-worktree trace and bats T1.
- **DIA-085 / ana011 parallel-session protocol** -- claim/heartbeat/resume protocol for 2+ parallel orchestrator sessions. Designed but not yet implemented; orthogonal to the lifecycle CLI.
- **`.slim/worktrees.json` state file** -- the global skill prescribes it; the project has not adopted it. Orthogonal to the CLI.
- **`.sdd/dev-infra/architecture.md`** -- flagged as a follow-up (permission rules block .sdd/ writes from this role; @architector dispatch blocked by subagent depth limit). The drafted SDD content is provided in the spec report for manual creation.

## Design authority (.sdd/) reference

**No `.sdd/` document governs dev-infra YET.** The project's design authority layer (`architecture.md` + `.sdd/`) describes system architecture (editor, workers, contracts, cloud), not developer tooling. The only files under `.sdd/` today are `.sdd/README.md` (three-layer model) and `.sdd/dia-redispatch-cycle/architecture.md` (5-ADR seed for the cycle-management protocol). No `.sdd/dev-infra/architecture.md` exists.

**Architecture gap flag:** this change reveals the need for `.sdd/dev-infra/architecture.md` to capture the parallel-dev model's architecture decisions (worktrees-only model, branch naming, squash-merge, DIA-096 mapping, session isolation). The gap is documented in this proposal and the drafted SDD content is provided in the spec report for manual creation. The gap is not a blocker for this spec (dev-infra is within existing module boundaries per AGENTS.md section 2.4; the conventions doc + lifecycle CLI are self-documenting for the current surface).

## Rollback plan

Every artifact added by this change is independently revertable.

| Artifact                                                     | Revert                          |
| ------------------------------------------------------------ | ------------------------------- |
| `scripts/worktrees.sh`                                       | Delete file                     |
| `scripts/__tests__/worktrees.bats`                           | Delete file                     |
| `docs/dev-infra-audit/worktree-conventions.md`               | Delete file                     |
| `.gitignore` (`.worktrees/` section)                         | `git checkout` to prior version |
| `scripts/__tests__/bats-wrapper.sh` (worktrees.sh allowlist) | `git checkout` to prior version |

All rollbacks are file deletions or `git checkout` to prior versions. No existing production code, Dockerfile.dev, or `.mise.toml` content is modified. Rollback restores prior `test-shell` behavior (worktrees.bats absent, worktrees.sh absent from bats-wrapper allowlist) -- the pre-change live-state. No data migrations. No side effects on running services.

## Testing Decisions

> Per `openspec/config.yaml`: "Include a Testing Decisions section that states what makes a good test for this change, which modules will be tested, and the prior art in the codebase."

### What makes a good test here

This is dev-infra -- the test verifies **lifecycle safety and convention enforcement**, not business logic. A good test is one that:

- fails loudly when a safety guard is bypassed (e.g., main checkout removal, dirty worktree removal without force, lane-settable force)
- passes quietly when the happy path succeeds
- uses REAL git operations (not FAKE-mock for the whole script) because the script wraps real `git worktree` commands and the safety guards depend on real git state

The FAKE-mock invariant is preserved for `ls-remote` only (T12, T13) because the best-effort remote check needs a controllable network response.

### 16-case matrix (T1-T16)

- **Location:** `scripts/__tests__/worktrees.bats`
- **Pattern:** real isolated git repo under `$BATS_TEST_TMPDIR` (NOT FAKE-mock for the whole script). `setup_worktree_repo()` creates a fresh throwaway git repo with `git init -b main`, one empty commit, and the script copied in. Every git invocation operates on the fixture repo, never the real repo.
- **FAKE-mock for ls-remote only:** `mock_git_ls_remote()` plants a fake `git` binary on PATH that intercepts `ls-remote` calls (for T12 remote-exists check, T13 unreachable-origin timeout test) and delegates everything else to the real git.

| Case | Scenario                                                                                         | Exit |
| ---- | ------------------------------------------------------------------------------------------------ | ---- |
| T1   | create -> exit 0, worktree dir + branch + isolated .opencode/session                             | 0    |
| T2   | create invalid branch (no feature/ prefix) -> exit 1                                             | 1    |
| T3   | create duplicate local branch -> exit 1                                                          | 1    |
| T4   | list shows branch + worktree path                                                                | 0    |
| T5   | remove by branch -> exit 0, dir gone, branch KEPT (rollback window)                              | 0    |
| T6   | remove dirty worktree (no --force) -> exit 1, worktree survives                                  | 1    |
| T7   | remove --force without WORKTREES_FORCE=1 -> exit 1 (lane cannot force)                           | 1    |
| T8   | remove --force with WORKTREES_FORCE=1 -> exit 0, dir gone                                        | 0    |
| T9   | remove unknown target -> exit 1                                                                  | 1    |
| T10  | no command -> usage error (exit 2)                                                               | 2    |
| T11  | remove refuses the main checkout path -> exit 1                                                  | 1    |
| T12  | create refuses branch that exists on origin (fake git ls-remote)                                 | 1    |
| T13  | create bounded when origin unreachable (fake ls-remote sleeps; script's internal timeout 5 caps) | 0    |
| T14  | remove by worktree PATH -> exit 0 + message shows path AND branch                                | 0    |
| T15  | create --help -> usage (exit 2), not a branch-name error                                         | 2    |
| T16  | list forwards args to git worktree list (--porcelain works)                                      | 0    |

- **Runs under:** `make test-shell` (via bats-wrapper auto-discovery).

### What we explicitly do NOT test

- Throwaway branches pushed to origin (T1-T16 never push; verification items a-e require active worktree lane adoption).
- `.slim/worktrees.json` state file (not adopted by the project).
- DIA-085/ana011 parallel-session coordination (not yet implemented).
- Real `git ls-remote` against a real origin (FAKE-mock only; network access not required for tests).

### Prior art in the codebase

- **Real-git fixture pattern:** the bats suite uses real `git init` + `git worktree add` under `$BATS_TEST_TMPDIR` (NOT FAKE-mock for the whole script). This is unique to the worktrees suite -- other bats suites (check-tools.bats, check-pin-sync.bats) use FAKE-mock throughout.
- **FAKE-mock for specific subcommands:** `mock_git_ls_remote()` intercepts only `ls-remote`, delegates everything else to the real git. Pattern reused from other bats suites that mock specific tools.
- **Test-helper.bash shared helpers:** the worktrees suite defines its own `setup_worktree_repo()` helper (not promoted to test-helper.bash because it's specific to the worktrees suite -- other suites don't need real git repos).
- **bats-wrapper `bash -n` allowlist pattern:** existing `scripts/__tests__/bats-wrapper.sh` lines 20-38.

### Test risk and mitigation

**Risk:** the test fixture uses real `git worktree add`, which may fail on systems without worktree support (ancient git versions). **Mitigation:** the dev container has a modern git (Dockerfile.dev installs git via apt); tests run inside the container.

**Risk:** the FAKE-mock for ls-remote may not perfectly simulate a real origin. **Mitigation:** the fake intercepts only `ls-remote` and delegates everything else to the real git, so the simulation is limited to the specific subcommand under test. T12 tests the "branch exists on origin" path; T13 tests the "unreachable origin" path (with the script's internal `timeout 5` capping the wait).
