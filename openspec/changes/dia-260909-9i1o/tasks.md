# Tasks: Consolidate budget-gate Bats fixture setup

Campaign ticket: DIA-260909-9i1o

This is a narrow expand-contract test-fixture refactor. Each slice changes a
shared primitive and its consumers together, then proves parity at the
existing Bats seams. No `.sdd/` dependency applies.

## 1. Establish parity and share fixture construction

- [ ] 1.1 Record the pre-change contract for both affected budget-gate Bats suites. Blockers: none. Acceptance: both suites run with their current test names, assertions, exit codes, output expectations, environment behavior, and fixture semantics recorded as the parity baseline.

- [ ] 1.2 Consolidate manifest writing, campaign-ticket seeding, and Git initialization into the existing shared Bats helper, then migrate only equivalent setup from both suites. Blockers: 1.1. Acceptance: each suite retains its own tree shape, commits, scenario data, and assertions; the manifest baseline count remains explicit; both affected suites pass with the recorded contract.

## 2. Share invocation plumbing without changing scenarios

- [ ] 2.1 Consolidate the hook-mode and range-mode gate invocation plumbing into narrow shared wrappers, then migrate the equivalent call sites. Blockers: 1.2. Acceptance: callers preserve current manifest, ticket-directory, plugin-root, optional environment, working-directory, and range-argument behavior; both affected suites pass with unchanged observable results.

## 3. Verify and make rollback-safe

- [ ] 3.1 Verify the completed refactor. Blockers: 2.1. Acceptance: both affected Bats suites pass, `make test-shell` passes, and the implementation changes only the two suites plus their existing shared helper; no production budget-gate behavior, test behavior, ticket, OpenCode configuration, changelog, or memory artifact changes.

- [ ] 3.2 Finalize as one reversible refactor commit. Blockers: 3.1. Acceptance: the commit carries the campaign ticket ID and can be reverted as one unit to restore suite-local setup if parity verification ever fails.

<!-- ownership: substance: developer; structure: AI; interview_depth: compressed -->
