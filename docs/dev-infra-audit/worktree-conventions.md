# Worktree Conventions — Parallel Dev Model (DIA-100)

Status: adopted (developer decision 2026-08-09, DIA-073 option d; implemented
per DIA-100).

## Purpose

This document is the project's operational layer for the worktrees-only
parallel dev model. It defines the deltas that make the generic protocol
concrete for this repo: branch naming, worktree location, lifecycle CLI,
merge strategy, conflict escalation, cleanup policy, and the orchestrator
dispatch pattern.

## Relationship to the worktrees skill

The global skill at `~/.config/opencode/skills/worktrees/SKILL.md` is the
orchestration protocol: pre-flight checklist, user-confirmation requirements,
lane planning/ownership, integration and cleanup phases. It is NOT duplicated
here. This document (and `scripts/worktrees.sh`) implement the project-specific
mechanics the skill deliberately leaves open:

- branch naming convention (skill default is `omos/<slug>`; this repo uses
  `feature/<ticket>-<short-name>` per DIA-074);
- worktree location (skill default is `.slim/worktrees/<slug>`; this repo uses
  `.worktrees/`);
- a testable CLI for create/remove/list (the skill prescribes commands, not
  scripts);
- merge strategy (squash-merge), conflict escalation criteria, and the
  DIA-096 safe/destructive mapping.

## Branch naming convention

Branches follow DIA-074's human-readable naming: `feature/<ticket>-<short-name>`
where `<ticket>` is the DIA id and `<short-name>` is a short kebab-case
descriptor of the work.

Examples:

- `feature/DIA-100-worktree-lifecycle`
- `feature/DIA-106-rust-analyzer-container-setup`

Rules enforced by `scripts/worktrees.sh create`:

- Must start with `feature/`.
- The part after `feature/` is a single path component of `[A-Za-z0-9._-]`
  (no extra slashes, no leading dash/dot).
- A warning is printed when the name does not match
  `DIA-<NNN>-<short-name>` — ticket-less branches should be rare and
  deliberate.

## Worktree location

Worktrees live under `.worktrees/` at the repo root (git-ignored; matches the
existing `tools/opencode-docker/.worktrees/` precedent). Path mapping:
branch slashes become dashes, so every lane is a direct child:

```text
feature/DIA-100-worktree-lifecycle  ->  .worktrees/feature-DIA-100-worktree-lifecycle
```

Do not create worktrees as siblings of the repo root, and do not use the
generic skill's `.slim/worktrees/` path here — `.worktrees/` is the repo
convention.

## Lifecycle CLI

One script, four subcommands (`scripts/worktrees.sh`; `make test-shell`
covers it via `scripts/__tests__/worktrees.bats`):

```bash
bash scripts/worktrees.sh create feature/DIA-100-worktree-lifecycle [base]
bash scripts/worktrees.sh list
bash scripts/worktrees.sh remove feature/DIA-100-worktree-lifecycle
bash scripts/worktrees.sh cleanup [--days N] [--dry-run]
```

- `create` validates the branch name, refuses existing branches (local +
  best-effort remote), creates the worktree, materializes and verifies
  `.opencode/session/` isolation, and prints the worktree path.
- `remove` refuses dirty/unmerged worktrees unless `--force`. The branch is
  ALWAYS kept (rollback window).
- `cleanup` (DIA-177) deletes merged `feature/*` branches after the rollback
  window. Merge-verified against main (is-ancestor fast path, tree-subset
  squash parity); a dirty linked worktree is ALWAYS skipped (no `--force` on
  cleanup); the default window is 0 days (immediate post-merge teardown).
  Flags/env: `--days N` > `WORKTREES_CLEANUP_DAYS` env > default 0;
  `--dry-run` lists would-be-deleted candidates with zero side effects.
- `list` shows active worktrees via `git worktree list`.

Exit codes: 0 success, 1 runtime error, 2 usage error.

Host prerequisites: the script is bash-3 compatible (runs on stock macOS
bash 3.2), but `create` bounds its best-effort remote check with GNU
coreutils `timeout` — install coreutils (e.g. `brew install coreutils`) on
macOS so `timeout` exists, or an unreachable origin can block `create` for
minutes. The bats suite itself requires bash 4+ (test-helper.bash's assert
helpers use `[[ ]]`).

## Merge workflow (squash-merge) — worked example

Strategy: **squash-merge to main after review**. Rationale:

- Parallel lanes produce many small WIP commits; squash keeps main linear and
  readable — one logical change per ticket.
- Only the developer pushes to main (DIA-096), so preserving per-lane commit
  history on main has no lane-facing benefit.
- Rebase-merge would require the lane to force-push after rebasing against a
  moving main — force-push is denied for lanes (DIA-096). Squash-merge avoids
  that coordination entirely.
- A squash commit on main is a single revertable unit (clean rollback).

Worked example (ticket `DIA-100`):

```bash
# 1. Orchestrator dispatches @coder to create the lane (see dispatch pattern)
bash scripts/worktrees.sh create feature/DIA-100-worktree-lifecycle
#    -> worktree at .worktrees/feature-DIA-100-worktree-lifecycle on
#       branch feature/DIA-100-worktree-lifecycle
#       (path_from_branch converts slashes to dashes and does NOT strip the
#       feature/ prefix, so the path keeps it: feature-DIA-100-...)

# 2. Lane works inside the worktree; commits locally; pushes the feature branch
#    (safe per DIA-096):
git push -u origin feature/DIA-100-worktree-lifecycle

# 3. Reviewer reviews (in the worktree context or from the pushed branch).

# 4. Developer (ONLY the developer pushes to main — DIA-096) squashes:
git checkout main && git pull
git merge --squash feature/DIA-100-worktree-lifecycle
git commit -m "feat(infra): <summary> (DIA-100)"
git push origin main

# 5. Orchestrator dispatches @coder to teardown: `remove` THEN `cleanup`
#    (DIA-177). `remove` drops the worktree dir (branch kept for rollback);
#    `cleanup` verifies the branch content is on main and deletes the branch
#    (plus any leftover worktree dir on disk). Lanes never run either form
#    of `git branch -d` directly — the script is the policy boundary:
bash scripts/worktrees.sh remove feature/DIA-100-worktree-lifecycle
bash scripts/worktrees.sh cleanup

# 6. Merge verification is the cleanup gate, not age: `cleanup` checks
#    is-ancestor OR tree-subset against main (squash parity — a squash-merge
#    does NOT mark the branch as merged, and step 6 of the old flow's plain
#    `git branch -d` would fail: not an ancestor). Under the default 0-day
#    window the branch is deleted immediately after the squash; `--days N`
#    opts into a conservative grace window:
git branch -d feature/DIA-100-worktree-lifecycle   # fails: not an ancestor
bash scripts/worktrees.sh cleanup --days 30        # conservative window
```

Rollback window: under the default 0-day cleanup window the branch is
deleted immediately after a verified squash-merge (DIA-177) — the merge
verification (is-ancestor or tree-subset against main) plus the
dirty-worktree skip are the safety gates, not age. Opt-in conservative runs
(`--days N` / `WORKTREES_CLEANUP_DAYS=N`) keep the branch for a grace
period so the developer can still recover from a bad squash with
`git checkout feature/... && git cherry-pick` or a new merge. Deletion
remains a script-governed action — lanes never run `git branch -d`/-D
directly (DIA-096).

## Conflict escalation criteria

A lane that hits a merge conflict runs `git merge main` inside its worktree,
then classifies:

Resolve in-lane (simple) — ALL of:

- the conflict is confined to hunks in files/regions the lane owns (its own
  additions), or
- the other side's changes are clearly unrelated (different files, or
  different functions in the same file), or
- the conflict is pure formatting/whitespace with no semantic overlap, and
- the total conflict count is 3 hunks or fewer, and
- the lane can state the intent of BOTH sides.

Escalate to the developer (complex) — ANY of:

- both sides changed the same function, data model, or business rule, and the
  correct resolution needs domain judgment about which behavior wins;
- any conflict in generated/derived artifacts: `pnpm-lock.yaml`, `uv.lock`,
  `package.json` pins, `.mise.toml`, Dockerfile ARGs, migration files;
- more than 3 conflict hunks;
- the lane cannot explain the other side's intent (e.g. a refactor it does
  not understand);
- resolving would mean reverting or choosing between two deliberate features.

Escalation protocol: STOP resolving; leave the worktree in the conflicted
state (do not force-resolve, do not `git checkout -- .`); hand the developer
a summary of the conflict hunks and both sides' intent via the normal handoff.

## Cleanup policy

- Worktree removal happens after the squash-merge (step 5 above) via
  `scripts/worktrees.sh remove`, then `scripts/worktrees.sh cleanup` (DIA-177)
  verifies the branch content is on main and deletes the branch — the
  default 0-day window deletes immediately after a successful merge.
- The branch is kept only while the configured window is open (opt-in via
  `--days N` / `WORKTREES_CLEANUP_DAYS=N`); deletion is script-governed,
  never lane-run directly (`git branch -d`/`-D` is denied for lanes, DIA-096).
- A dirty worktree is never removed without `--force`, and `--force` is
  developer-only: it requires `WORKTREES_FORCE=1`, which lanes must never
  set. `cleanup` has NO `--force`: a candidate with a dirty linked worktree
  is always skipped (`would-skip (worktree dirty)`), so a scan can never
  lose work. The env guard exists because `git worktree remove --force` is
  not itself in the DIA-096 deny list — only `git clean -f*` and
  `git branch -D` are. The script is the policy boundary.

## DIA-096 safe/destructive mapping

| Operation                              | Lane-accessible     | Enforced by                                                     |
| -------------------------------------- | ------------------- | --------------------------------------------------------------- |
| `git worktree add` / `remove` (clean)  | yes                 | config (not denied) + script                                    |
| `git push -u origin <feature-branch>`  | yes                 | config allow (DIA-096)                                          |
| `git worktree remove --force`          | no (developer only) | script env guard `WORKTREES_FORCE=1`                            |
| `git branch -d` / `-D`                 | no                  | config deny (`git branch -D *`) + script never invokes deletion |
| `git clean -f*`, force-push, main push | no                  | config deny (DIA-096)                                           |

Note: the OpenCode permission config gates agent tool calls on the OUTER
command (`bash scripts/worktrees.sh ...`), not on the git commands the script
runs internally. The script therefore enforces the same boundaries itself —
that is why `remove` refuses dirty worktrees and why `--force` needs the env
guard. Keep this invariant when editing the script.

## OpenCode interaction: .opencode/session isolation

Each worktree gets its own `.opencode/session/` dir by construction: git
worktree produces a separate working directory, `.opencode/session/` is
git-ignored (never committed or shared), and OpenCode writes session state
under `<cwd>/.opencode/session/`. No handoff coordination between parallel
lanes is needed. `create` materializes the dir and asserts it is a real
directory, not a symlink into the main checkout. Verified by the DIA-100
verification checklist item (f).

## Orchestrator dispatch pattern

Dispatch to `@coder` (lane: worktree lifecycle, DIA-100). Creation:

```text
Task: create the worktree lane for <ticket>.
1. Run: bash scripts/worktrees.sh create feature/DIA-<NNN>-<short-name>
2. Confirm the worktree path .worktrees/<branch-with-dashes>/ exists and
   that .opencode/session/ exists inside it (isolation verified).
3. Report the worktree path + branch. Do NOT push the branch yet unless
   instructed.
```

Teardown:

```text
Task: teardown the worktree lane for <ticket> after its squash-merge.
1. Verify the branch was merged to main (or the merge was explicitly
   waived).
2. Run: bash scripts/worktrees.sh remove feature/DIA-<NNN>-<short-name>
3. Confirm the worktree dir is gone and the branch still exists (rollback
   window). Report both.
```

Never remove a dirty worktree as a lane; never set WORKTREES_FORCE=1. If the
worktree is dirty, hand off to the developer.
