# DIA-167 - test infra Phase 0: safety wins (author-studio fails loudly, flaky-pin tests removed, config gate hardened)

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-124 collided with origin/omo-slim-changes ticket DIA-148-test-infra-phase0-safety-wins.md (different ticket). Renumbered to DIA-167. This ticket duplicates remote DIA-148-test-infra-phase0-safety-wins.md (same work, renumbered on the remote lineage via bab080c); SUPERSEDED by the remote ticket. -->

<!-- CLOSED 2026-08-15 as same-scope duplicate of DIA-148 (CLOSED). Superseded; do not implement. -->

<!-- Ticket 1 of 4 from the approved test-refactoring plan (reviewed with
     mandatory corrections incorporated). Phase 0 - Safety Wins. Blocks
     DIA-169 (Phase 2). -->

---

id: DIA-167
title: "test infra Phase 0: safety wins (author-studio fails loudly, flaky-pin tests removed, config gate hardened)"
area: tests-infra
severity: Major
status: CLOSED
blocked_by: [] # blocks DIA-169
discovered:
source: baseline
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Phase 0 of the approved test-refactoring plan: remove fake-green tests and
hard-failing-by-misconfiguration gates, without breaking the turbo test run
for other packages.

### 1. author-studio test script fails loudly (MANDATORY CORRECTION applied)

`apps/author-studio/package.json` (line 13) currently has
`"test": "echo \"No test specified\" && exit 0"` — a fake-green test script
that masks missing coverage.

**MANDATORY CORRECTION (from review):** the exclusion must be specified
PER-PACKAGE — a per-package turbo config override (e.g. an
`apps/author-studio/turbo.json` that overrides the `test` task, or an
explicit `--filter` in the root test invocation that skips author-studio) —
NOT a blanket `exit 1` in the test script. A blanket `exit 1` would
cascade-fail the entire turbo test run for all packages.

The ADR 1 principle applies: a test script must run a real runner; empty
packages fail loudly AND turbo.json explicitly excludes them from the test
task. Concretely:

- Change the author-studio `test` script to fail loudly (exit non-zero with a
  clear message) when invoked directly.
- Configure turbo.json so the `test` task EXCLUDES author-studio per-package
  (per-package turbo override or `--filter`), so `pnpm test`/turbo test for
  other packages still passes and does not cascade-fail.
- Do NOT blanket-change other packages' test scripts to `exit 1`.

### 2. Delete docstring-pin tests (flake-on-doc-edit)

These tests assert the exact wording of module docstrings, so ANY doc edit
breaks CI — flake-on-doc-edit tests with no behavioral value:

- `apps/api-server/tests/test_auth.py` lines ~27-30:
  `test_docstring_declares_jwt_and_oauth_contract`. KEEP the import test
  (`test_module_is_importable_from_package_path`, line 21).
- `packages/analytics-pipeline/tests/test_smoke.py`: delete the docstring-pin
  tests at lines ~31-37 (`test_uow_docstring_declares_single_commit_contract`),
  ~40-44 (`test_numpy_calc_docstring_declares_analytics_core_contract`), and
  ~47-51 (`test_cron_docstring_declares_daemon_contract`). KEEP the import
  test at lines ~24-28 (`test_modules_import_from_namespace_package_path`).

### 3. phonetics-core test fixes

`packages/phonetics-core/src/atlas/load-atlas.test.ts`:

- Lines ~276-277: the async `await import('node:fs')` re-import inside the
  test body must become a top-level import (static imports only).
- Lines ~286-293: delete the pure-hash test (`content hash is deterministic
across atlas loads`) — it re-derives the same hash from the same buffer and
  adds no signal.

### 4. worktrees.bats timing flake

`scripts/__tests__/worktrees.bats` T13 (`worktrees: T13 create bounded when
origin unreachable`, lines ~218-231): reduce `FAKE_LS_REMOTE_SLEEP` from 20
to 8 so the internal `timeout 5` still kills the fake ls-remote well inside
the outer `timeout 12`, keeping the test fast and robust.

### 5. Makefile test-config validates docker-compose.yml

`make test-config` target (Makefile line ~176) currently validates OpenCode
JSONC, agent names, output contracts, and reviewer sections, but NOT
docker-compose.yml. Add `docker compose config --quiet` to the test-config
target so compose file drift fails the config gate.

## Verification

Acceptance criteria (all must hold):

- [ ] `apps/author-studio/package.json` test script fails loudly (non-zero
      exit) when run directly with a clear message.
- [ ] turbo `test` task still passes for all OTHER packages (no cascade
      failure) — the per-package exclusion mechanism is in place.
- [ ] No docstring-pin tests remain in `test_auth.py` or `test_smoke.py`;
      editing a module docstring no longer breaks CI.
- [ ] `load-atlas.test.ts` has no async `import()` inside test bodies and no
      pure-hash duplicate test; suite still green.
- [ ] `worktrees.bats` T13 passes with `FAKE_LS_REMOTE_SLEEP=8` and runs
      faster than before.
- [ ] `make test-config` passes with a valid docker-compose.yml and fails
      when docker-compose.yml is broken.

Per AGENTS.md 2.3.1, handoff must include verification evidence: exit codes

- summary lines for `pnpm test` (author-studio direct, fails loudly), turbo
  test for remaining packages (passes), `make test-python`, `make test-shell`,
  and `make test-config`.

## Fix

Applied 2026-08-12, landed in commit 84bdce3 (branch omo-slim-changes):

1. `apps/author-studio/package.json` test script: `exit 0` -> `exit 1` with a
   clear message; excluded from the turbo test task via
   `--filter=!author-studio` in the root `pnpm test` invocation (the ticket's
   sanctioned per-package exclusion mechanism — a per-package turbo.json
   cannot disable a task in turbo 2.x, so `--filter` is the correct
   mechanism). No blanket `exit 1` applied to other packages.
2. Deleted docstring-pin tests: `test_docstring_declares_jwt_and_oauth_contract`
   (test_auth.py), `test_uow_docstring_declares_single_commit_contract`,
   `test_numpy_calc_docstring_declares_analytics_core_contract`,
   `test_cron_docstring_declares_daemon_contract` (test_smoke.py). Import
   tests kept in both files.
3. `load-atlas.test.ts`: removed the two `await import('node:fs'/'node:path')`
   re-imports (both names already top-level imported) and deleted the
   pure-hash duplicate test.
4. `worktrees.bats` T13: `FAKE_LS_REMOTE_SLEEP` 20 -> 8 (comment updated).
5. Makefile `test-config`: added `docker compose config --quiet` as the first
   recipe line.

Verification evidence (exit codes + summary lines):

- `docker compose config --quiet` (host): exit 0.
- `docker compose -f broken.yml config --quiet`: exit 1 (negative check).
- author-studio direct test (`pnpm --filter author-studio test`): exit 1,
  message "author-studio has no test suite yet (DIA-167): excluded from the
  turbo test task; fails loudly by design".
- Root `pnpm test` (turbo test --filter=!author-studio): exit 0.
  "Tasks: 2 successful, 2 total"; phonetics-core 24 tests passed
  (load-atlas.test.ts), editor-engine 91 tests passed; 7 packages in scope,
  author-studio excluded, no cascade failure.
- `make test-config` recipe (host, make unavailable on host so the exact
  target recipe was run; container run confirmed the docker step is the only
  host-dependent one): exit 0. 24/24 config validators passed, agent-name
  cross-reference 24 passed, handoff 5 passed.
- `make test-shell` (in dev container): exit 0. 211 bats tests passed,
  including "worktrees: T13 create bounded when origin unreachable".
- api-server pytest: 1 passed (import test kept).
- analytics-pipeline pytest: 1 passed (import test kept).
- eslint on load-atlas.test.ts: exit 0. ruff on both changed py files: exit 0
  (All checks passed). prettier --check on changed md/json/ts: all clean.
- Lint-staged ran inside the pre-commit hook at commit time (exit 0).

Deviations from ticket (flagged, not silent):

- Per-package turbo override (apps/author-studio/turbo.json) NOT used: turbo
  2.x per-package turbo.json cannot exclude a package from a task; the
  ticket's alternative "--filter in the root test invocation" was used
  instead (root package.json test script).
- `apps/author-studio/AGENTS.md` command/known-gap comments updated from
  "(exit 0)" to reflect the new fail-loudly + exclusion behavior (doc
  consistency with the changed script).
- `docs/dev-infra-audit/tickets/README.md` and
  `scripts/__tests__/verify-pre-push.bats` show as modified but are
  pre-existing working-tree changes from plan authoring (DIA-166..170) and
  were NOT part of this commit.

## Re-verify

> To be filled at re-verify time.
