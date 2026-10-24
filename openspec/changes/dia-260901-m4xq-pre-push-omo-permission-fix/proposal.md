# Proposal: Pre-push OMO tests run as root — permission-test and isolation fix

## Why

`scripts/verify-pre-push.sh` line 61 delegates host pre-push checks via `docker compose exec -T dev ...` WITHOUT `--user dev`, so all six verification steps (`verify:format`, `verify:js`, `verify:js-tests`, `test-config`, `test-omo`, `verify:python`, `test-shell`) execute as root inside the `poetry-dev` container. The OMO suite (`make test-omo` -> `bun test` in `.opencode/oh-my-opencode-slim`) contains four tests that fail under this execution context:

- Three tests intentionally expect `EACCES` after `chmod 000` on a directory/file (`blocks internal guard errors`, `records failures and continues`, `conflict staging failure` patterns in `hook.test.ts` / `operations.test.ts` / `skill-sync.test.ts`). Root bypasses Unix permission checks, so the expected error never occurs and the tests fail — but only when run via the pre-push delegation. Direct host or `docker compose exec --user dev` runs hit the permission as intended and pass, masking the bug until push time.
- One test (`passes through sibling-directory targets outside root/worktree`) writes to a fixed sibling path `../outside.txt` resolved from a `mkdtemp` root (typically `/tmp/...` sibling). In the container that path resolves to `/tmp/outside.txt`, which is already `root:root` from a prior root-run; a subsequent `dev` run gets `EACCES` on the same fixed path — an isolation failure that is host-invisible.

The defect is filed as DIA-260901-m4xq. No `--no-verify` workaround is allowed (DIA-096). The push-time gate must run OMO tests as `dev`, and the tests themselves must be runnable both on host and in-container regardless of the caller UID, without relying on `chmod 000` to produce `EACCES`.

## What Changes

- **Fix 1 — Pre-push execution user (host delegation):** `scripts/verify-pre-push.sh` `run_workspace()` host branch (line 61) changes from `docker compose exec -T dev ...` to `docker compose exec -T --user dev dev ...`. One-line fix. All delegated steps then run as `dev`, matching the container's `USER dev` default and the Makefile's explicit `--user dev` pattern (DIA-260824-a3mk).
- **Fix 2 — Sibling-file isolation (fourth test):** In `.opencode/oh-my-opencode-slim/src/hooks/apply-patch/hook.test.ts` the `../outside.txt` test generates a unique sibling file via `mkdtemp`/`uniqueFile` (or `path.join(os.tmpdir(), `hook-outside-${random}.txt`)`) instead of the fixed `/tmp/outside.txt`, and removes it in a `finally` block. The stale fixture under `/tmp/outside.txt` is cleaned once via `docker compose exec -T --user root dev rm -f /tmp/outside.txt` before verification.
- **Fix 3 — Root-independent permission-error simulation (three tests):** Rewrite the three `chmod 000` tests so they do not rely on Unix permission denial. Patterns to use (pick one per test, prefer injection): mock `fs.writeFile`/`fs.mkdir`/`fs.chmod` to reject with `EACCES`, or create a filesystem conflict that fails independent of UID (e.g., file where directory expected, or a symlink/file collision that forces `ENOTDIR`/`EEXIST`). Remove `chmod 000` / `chmod 0o000` from the OMO test assertions; keep the behavioral assertion (hook blocks or records failures and continues).
- **Verification contract:** After fixes `docker compose exec -T --user dev dev bash -lc 'cd /workspace && make test-omo'` and host `make test-omo` both pass. `git push` re-runs OMO as `dev` until `verify-pre-push.sh` is fixed; post-fix push no longer requires `--no-verify`. One-time container cleanup of `/tmp/outside.txt` as root precedes the `dev` run.

## Capabilities

None — no spec-level capability changes. This is a dev-infra/OMO bug fix (pre-push execution context + test isolation). The change touches `scripts/verify-pre-push.sh` and `.opencode/oh-my-opencode-slim/src/hooks/apply-patch/hook.test.ts` (and sibling OMO test files for the three permission tests) only, with no public API/schema/state/FFI/protocol change. `.openspec.yaml` sets `skip_specs: true`.

## Impact

- Files: `scripts/verify-pre-push.sh` (1 line), `.opencode/oh-my-opencode-slim/src/hooks/apply-patch/hook.test.ts` (+ possibly `operations.test.ts` / `skill-sync.test.ts` for the other two permission tests — grep `chmod 000` to locate all three before editing).
- Affected gates: `verify-pre-push.sh` host delegation, `make test-omo`, `make test-shell` (indirect), `git push` hook.
- No image rebuild, no schema change, no persistent state. `make test-omo` now validates under both UIDs; `docker compose exec --user root rm /tmp/outside.txt` is a one-time manual cleanup, not a migration.
- Rollback: `git revert` the two-to-three files; re-create `/tmp/outside.txt` pollution by re-running OMO as root if needed to reproduce.

## Alternatives considered

- **A. Add `--user dev` to `verify-pre-push.sh` + rewrite tests to root-independent errors (CHOSEN):** fixes both the execution context and the test-design defect; tests become host- and container-runnable without UID-dependent behavior; matches the established `--user dev` pattern from DIA-260824-a3mk. Tier-1: `scripts/verify-pre-push.sh:61`, `hook.test.ts:684` fixed `outside.txt`, and `chmod 000` at `hook.test.ts:461`.
- **B. Only add `--user dev` and keep `chmod 000`:** rejected — tests would pass today but remain fragile: any future root execution (CI, manual `exec` without `--user dev`) re-breaks them; the test design claims host+container runnable but relies on non-root. Tier-1: diagnosis requires root-independent conflict.
- **C. Mock filesystem globally (memfs) for all OMO tests:** rejected — over-engineering for three tests; the ladder says inject/mock only where `EACCES` is expected, not replace the whole FS. One-line mock or file/dir collision is shorter.
- **D. Status-quo / `--no-verify`:** rejected — `AGENTS.md` section 2.3 forbids `--no-verify`; the push gate must pass without bypass. Tier-1: ticket Verification checklist.

Chosen option: A — minimal diff that fixes both the delegation bug and the test-design bug, with the existing `--user dev` pattern as prior art.

## Testing Decisions

What makes a good test for this change: a test that proves (1) the pre-push delegation runs as `dev` (not root), (2) the three formerly-`chmod 000` tests fail for a reason that does not depend on UID, and (3) the sibling-file test never collides on a fixed `/tmp` path.

Modules tested:

- `scripts/verify-pre-push.sh` host delegation — static assertion that the `docker compose exec` line contains `--user dev` (grep-based bats test, Docker mocked).
- `.opencode/oh-my-opencode-slim` OMO suite — `hook.test.ts` (and `operations.test.ts`/`skill-sync.test.ts` if they own the other permission tests) under `make test-omo`: the three rewritten permission tests inject/mock `EACCES` or create a UID-independent FS conflict; the sibling test uses a unique temp sibling and `finally` cleanup.

Prior art in the codebase:

- `scripts/__tests__/verify-pre-push.bats` already mocks `docker compose exec` / `is_in_dev_container` to test recursion guard and delegation (Tier-1: `scripts/__tests__/verify-pre-push.bats`). Add one assertion for `--user dev` in the delegated command string.
- `scripts/__tests__/opencode-launch-routing.bats` is the existing static `grep` guard for `--user dev` on `opencode` launchers — reuse the grep idiom for `verify-pre-push.sh`.
- `scripts/__tests__/compose-env.bats` / `compose-overrides.bats` show the Docker-mocked bats pattern to copy for the new assertion.
- OMO tests run via `bun test` (`make test-omo`) and use `createTempDir`/`writeFixture` helpers (`src/hooks/apply-patch/test-helpers.ts`) — the unique sibling fix should use `createTempDir` or `mkdtemp` + `finally` rm, matching that helper's pattern.

Primary gate: `make test-shell` (bats, Docker mocked, host-runnable) for the `verify-pre-push.sh` static check + `make test-omo` (bun, host and `docker compose exec --user dev` both). Secondary: `git push` hook integration (manual).
