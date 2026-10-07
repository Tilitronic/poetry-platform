# Proposal: Reproducible Zod runtime for lifecycle RED-B

**Governing ticket:** DIA-260912-h8o5 "tests-infra: reproducible runtime for undeclared zod import"

**Gate:** DIA-104 mandatory full interview. Trigger: cross-cutting test-infrastructure and lifecycle verification. No waiver or override.

**Ownership:** substance: developer; structure: AI; interview_depth: full; interview_reason: Developer confirmed Q1-Q10 before synthesis.

## Why

The vendored `oh-my-opencode-slim` package imports `zod`, but its test runtime is not reproducible from a clean worktree because the package lacks a committed Bun lockfile and does not exact-pin the development dependency. This blocks trustworthy RED-B evidence for DIA-260827-95fv because a module-resolution failure can prevent the lifecycle test body from executing.

## What Changes

- Exact-pin `zod` at `4.3.6` in `.opencode/oh-my-opencode-slim` `devDependencies` while retaining its `^4.0.0` peer range.
- Commit the generated Bun lockfile as the only dependency receipt for the vendored package.
- Verify from a disposable worktree rooted at the integrated RED commits, using `bun install --frozen-lockfile` followed by the narrow `test:red-b` script over the task-lifecycle and task-session-manager seams.
- Require the named RED-B test to execute and fail with the expected `state: return-channel-pending` assertion, without a Zod module-resolution error.
- Fail closed on install failure, a passing focused test, or any unexpected failure. A successful check unblocks only RED-B rerun and evidence review for DIA-260827-95fv, never GREEN.

## Capabilities

No OpenSpec capability delta is created. This is a package-local dependency reproducibility repair and a one-off verification procedure; it changes neither product behavior nor the DIA-260827-95fv lifecycle contract. `skip_specs: true` is set in `.openspec.yaml`.

## Impact

- **Affected files:** `.opencode/oh-my-opencode-slim/package.json` and its generated Bun lockfile only.
- **Affected verification:** the existing `src/utils/task-lifecycle.test.ts` and `src/hooks/task-session-manager/index.test.ts` RED seams.
- **Dependencies:** `zod` becomes exact at `4.3.6` for development; no new dependency is introduced.
- **Non-goals:** no production code change, no lifecycle test assertion change, no root workspace change, no fallback install or dependency override, and no GREEN work for DIA-260827-95fv.
- **Governing references:** `architecture.md`; no `.sdd/` documents exist in this checkout. `.opencode/oh-my-opencode-slim/AGENTS.md` identifies Bun and `zod` as the package test/runtime stack.
- **Rollback:** revert the manifest and Bun lockfile together. The clean-worktree command then remains blocked; do not substitute a manual install or proceed to lifecycle GREEN work.

## Testing Decisions

The valuable check is a clean dependency restore plus execution of only the two integrated lifecycle RED seams. It must prove the named test body reached the expected assertion mismatch for `return-channel-pending`; a nonzero exit caused by missing `zod`, a passing test, or another failure is invalid evidence. A narrow `test:red-b` package script makes that receipt repeatable without adding a test framework.

## Alternatives considered

- **Exact package-local pin plus committed Bun lockfile (chosen):** uses the existing Bun runner and records the resolved dependency graph. Evidence: developer interview Q3-Q5; Tier-1 `.opencode/oh-my-opencode-slim/package.json` declares Bun testing and Zod imports.
- **Add `zod` at the root pnpm workspace:** rejected because the vendored package owns the imports and its Bun test runtime. Evidence: developer interview Q1 and Q8; Tier-1 root `package.json` workspaces include only `apps/*` and `packages/*`.
- **Run the entire package suite:** rejected because it obscures the dependency receipt with unrelated tests. The developer subsequently approved a narrow `test:red-b` package script for the two integrated lifecycle seams.
- **Fallback install, dependency override, or manually add Zod in the current worktree:** rejected because it would not prove the lockfile is reproducible and could mask the blocker. Evidence: developer interview Q4 and Q9.
- **Status-quo / do nothing:** rejected because module resolution can prevent RED-B from reaching its lifecycle assertion. Evidence: developer interview Q1, Q5, and Tier-1 `.opencode/memory/lessons.md` DIA-260912-h8o5 entry.

Chosen option: exact package-local pin plus generated Bun lockfile, because a frozen clean-worktree install is the smallest reproducible proof that RED-B reaches the intended lifecycle assertion.
