# Tasks: Reproducible Zod runtime for lifecycle RED-B

**Governing ticket:** DIA-260912-h8o5 "tests-infra: reproducible runtime for undeclared zod import"

## 1. Declare the package-owned test dependency

- [x] 1.1 **Blockers: none.** Exact-pin the vendored Bun package's Zod development dependency at `4.3.6`, preserve the `^4.0.0` peer compatibility range, and generate the matching Bun lockfile. Acceptance: the package itself, without root-workspace dependency changes, declares the complete reproducible Zod resolution; no production or lifecycle test code changes.

## 2. Prove the isolated RED-B bootstrap

- [ ] 2.1 **Blockers: 1.1.** In a disposable worktree at the integrated RED fixed point, or a documented restored equivalent, run `bun install --frozen-lockfile` in the vendored package and then `bun run test:red-b`. Acceptance: the lifecycle RED tests execute and exit nonzero with the named `state: return-channel-pending` mismatch plus stopped-tombstone assertions; output has no Zod module-resolution error; no fallback install, override, current-worktree mutation, or `bun add` occurs.

## 3. Gate the lifecycle handoff

- [ ] 3.1 **Blockers: 2.1.** Record the isolated worktree revision, commands, exit statuses, named-test evidence, expected assertion evidence, and absence of Zod resolution failure. Acceptance: valid evidence unblocks only RED-B rerun and evidence review for DIA-260827-95fv; a passing or unexpected result fails closed and does not permit GREEN.
