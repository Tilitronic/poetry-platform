# Design: Pre-push OMO tests run as root — execution-context and test-isolation fix

## Governing Constraints

- `AGENTS.md` section 2.4 — dev-infra changes >~20 lines require OpenSpec; `design.md` must include test strategy + rollback plan. This change is ~5-30 lines across `scripts/verify-pre-push.sh` + OMO tests; spec is required per ticket workflow.
- `AGENTS.md` section 6 — container gates (DIA-094): pre-push verification must not silently pass when the dev container is down, and must not use `--no-verify`. The fix preserves the DIA-094 `container_running` warn+pass and the six-step `run_workspace` ladder.
- `.sdd/dev-infra/architecture.md` governs parallel-dev and container lifecycle, but does not govern `verify-pre-push.sh` execution user; no ADR is violated. The authoritative pattern for `--user dev` is DIA-260824-a3mk (Makefile + `scripts/opencode-dev` + `dev-entrypoint` self-healing chown).
- `architecture.md` (app-domain) does not govern dev-infra; the change is pure infra/test isolation with `skip_specs: true`.
- No governing constraint is violated. No new module boundary or technology decision — escalation to `@architector` is not required.

## Context

`scripts/verify-pre-push.sh` is the husky pre-push hook's verification gate. On the host it delegates each step via `docker compose exec -T dev bash -lc "cd /workspace && <cmd>"` (line 61). The OMO suite (`make test-omo` -> `bun test` in `.opencode/oh-my-opencode-slim`) is one of those steps. The suite's hook tests under `src/hooks/apply-patch/` exercise `createApplyPatchHook` and intentionally trigger I/O errors to assert the hook's `blocked`/`internal error` behavior. Three tests do so by `chmod 000` on a directory/file and expecting `EACCES`; a fourth test asserts sibling-directory traversal for `../outside.txt` is passed through, writing to a sibling `outside.txt` via `path.dirname(root)` (line 684) — which on `mkdtemp('/tmp/apply-patch-hook-')` resolves to `/tmp/outside.txt`.

Root bypasses `chmod 000` (Unix `DAC_OVERRIDE`), so the three permission tests never see `EACCES` when `verify-pre-push.sh` runs them as root — they fail under `git push` but pass under host `make test-omo` and under `docker compose exec --user dev`. The sibling test's fixed path is not temp-unique; after a root run leaves `/tmp/outside.txt` as `root:root`, a `dev` run gets unexpected `EACCES` on the same path. One-time cleanup as root (`rm -f /tmp/outside.txt`) is required before the `dev` run can succeed post-fix.

## Goals / Non-Goals

**Goals:**

- Host pre-push delegation runs all steps as `dev` (`--user dev`), so OMO permission tests see the `EACCES` they expect without root bypass, and `git push` no longer requires `--no-verify`.
- Three `chmod 000` tests become UID-independent: they inject/mock `EACCES` or create a filesystem conflict that fails regardless of UID, and no longer rely on permission bits.
- Sibling-file test uses a unique temp sibling and `finally` cleanup, so it never collides on `/tmp/outside.txt` across UIDs or successive runs.
- OMO tests pass both on host (`make test-omo`) and in-container as `dev` (`docker compose exec -T --user dev dev bash -lc 'cd /workspace && make test-omo'`).

**Non-Goals:**

- Changing OMO product logic (`hook/index.ts`, `operations.ts`, etc.) — test-only fix.
- Changing `verify-pre-push.sh` step order, recursion guard, or DIA-094 container-down behavior.
- Adding a new mock filesystem or rewriting the entire OMO suite.
- Retiring `tools/opencode-docker/` or aligning `scripts/dev-stack.sh` (`make stack`) — separate tickets.

## Decisions

**D1 — Add `--user dev` to `verify-pre-push.sh` host delegation (line 61).** Change `docker compose exec -T dev` to `docker compose exec -T --user dev dev`. One line, zero new state. Rationale: matches the established `--user dev` pattern from DIA-260824-a3mk and Makefile `test-python`/`shell` targets; makes the six delegated steps run as the container's `USER dev` default. Alternative: leave as root and keep `chmod 000` — rejected (fragile; any future root execution re-breaks). Alternative: add `user:` to `docker-compose.yml` — rejected by ai-specialist validation (would make PID1 non-root and defeat entrypoint chown in the log-permission fix).

**D2 — Unique sibling file for the `../outside.txt` test.** Replace fixed `path.join(path.dirname(root), 'outside.txt')` with a unique path: e.g., `path.join(os.tmpdir(), `hook-outside-${Date.now()}-${Math.random().toString(36).slice(2)}.txt`)` or a `mkdtemp` sibling directory + `outside.txt`, and wrap the test body in `try { ... } finally { await rm(outside, { force: true }) }`. Rationale: reuse existing `createTempDir`/`mkdtemp` helper already in `test-helpers.ts` instead of inventing a new fixture. Alternative: keep fixed path and `chmod 777` the cleanup — rejected (race on concurrent `make test-omo` runs).

**D3 — Root-independent error injection for the three permission tests.** Rewrite each `chmod 000` test to not depend on permission bits. Preferred patterns (shortest diff first): (a) spy/mock `node:fs/promises` `writeFile`/`mkdir`/`chmod` to `reject(new Error with code EACCES)` for the specific call under test, (b) create a UID-independent FS collision — e.g., `writeFixture(root, 'locked', 'file-not-dir')` then attempt `mkdir(locked/child.txt)` which fails with `ENOTDIR`, or `symlink` to a non-existent target. Keep the behavioral assertion (`rejects.toThrow('apply_patch internal error:')` or the `records failures and continues` / `conflict staging` assertion). Remove `chmod 000` and the `finally chmod 755` cleanup. Rationale: mock is the minimal change where the production code under test is the fs call; collision is the minimal change where no mock harness is desired. Alternative: `memfs` global mock — rejected (over-engineering; three tests only).

**D4 — No `USER` directive change in `Dockerfile.dev` / `docker-compose.yml`.** The fix does not alter the image's default user; it only adds `--user dev` at delegation time, consistent with the post-DIA-260824-a3mk model where the image default is root but `make` targets use `--user dev`. Verification does not require `make build`.

**D5 — One-time `/tmp/outside.txt` cleanup.** Before the first `dev` verification run, clean the stale root-owned file: `docker compose exec -T --user root dev rm -f /tmp/outside.txt`. This is a manual one-off, not a migration; the new unique-path test makes it unnecessary thereafter.

## Risks / Trade-offs

- **R1 Forgetting `--user dev` on a future `verify-pre-push.sh` step** -> Mitigation: static bats assertion greps the `exec` line for `--user dev`; fails `make test-shell` if the flag is dropped. Cheap grep guard (prior art: `opencode-launch-routing.bats`).
- **R2 Mock brittleness (mocking the wrong `fs` import)** -> Mitigation: mock `node:fs/promises` at the import the production code actually uses (`apply-patch/hook` imports from `node:fs/promises` via `operations.ts`); keep the mock scoped to the single test with `afterEach` restore / `vi.spyOn` or `bun:test mock`.
- **R3 `ENOTDIR`/`EEXIST` collision changes error message contract** -> Mitigation: assert the hook's `internal error` / `blocked` throw, not the exact errno string; the hook normalizes FS errors to `apply_patch internal error:`.
- **R4 Concurrent test runs collide on `/tmp`** -> Mitigation: unique temp path per test (D2) with `finally` rm; `createTempDir` already uses `mkdtemp` which is atomic.

## Seams

### Seam 1: Pre-push host delegation — execution user

- **Location:** `scripts/verify-pre-push.sh:run_workspace()` host branch (line 61: `docker compose exec -T dev ...`)
- **Contract:** when `is_in_dev_container` is false and `container_running` is true, every delegated `<cmd>` runs as `dev` (`--user dev`); stdin is closed (`< /dev/null`); `VERIFY_PRE_PUSH_RUNNING=1` recursion guard is set; warn+pass when container is down.
- **Test:** `scripts/__tests__/verify-pre-push.bats` — host-delegation test greps the `exec` invocation string for `--user dev` (Docker mocked, no daemon). Existing recursion-guard and container-down tests remain green.

### Seam 2: OMO hook — permission-error handling (formerly `chmod 000`)

- **Location:** `.opencode/oh-my-opencode-slim/src/hooks/apply-patch/hook.test.ts` (and `operations.test.ts` / `skill-sync.test.ts` where the other two permission tests live — locate via `grep -rn 'chmod 000'`)
- **Contract:** when the hook's underlying FS operation for an `Add File: locked/child.txt` (or staging) fails with `EACCES` (now injected via mock or UID-independent collision), the hook rejects with `apply_patch internal error:` and leaves `output.args.patchText` unchanged; sibling tests (`records failures and continues`, `conflict staging failure`) exercise their respective error paths.
- **Test:** `make test-omo` (`bun test` in `.opencode/oh-my-opencode-slim`) — the three rewritten tests use `spy/mock` or `ENOTDIR` collision and assert the same `rejects.toThrow` / continuation behavior; they pass both on host and as `dev` in-container. No `chmod 000` remains in the three tests.

### Seam 3: OMO hook — sibling-directory traversal isolation

- **Location:** `.opencode/oh-my-opencode-slim/src/hooks/apply-patch/hook.test.ts:684` (`path.join(path.dirname(root), 'outside.txt')`)
- **Contract:** a patch targeting `../outside.txt` (sibling of the worktree root) is passed through without rewrite; the test's sibling file is unique per invocation and removed in `finally`; the hook does not leak the sibling file into the worktree.
- **Test:** same OMO suite — the `passes through sibling-directory targets outside root/worktree` test uses a unique sibling path and `finally` cleanup; manual one-time `rm -f /tmp/outside.txt` as root precedes the first `dev` verification.

## Test Strategy

### Primary gate — `make test-shell` (bats, Docker mocked, host-runnable)

- **New assertion in `scripts/__tests__/verify-pre-push.bats`** (or a small `verify-pre-push-user.bats` wired into `test-shell` via `bats-wrapper.sh`): mock `docker`/`is_in_dev_container`/`container_running` for the host-delegation path and assert the `docker compose exec` string contains `--user dev`. Include a negative check that `exec -T dev` without `--user` is absent. Prior art: `scripts/__tests__/verify-pre-push.bats` already mocks the host branch and asserts the delegated command.
- **Limitation:** static string check, not runtime UID assertion — supplemented by the OMO gates below.

### Primary gate — `make test-omo` (bun, host and `docker compose exec --user dev`)

- **Host:** `make test-omo` (runs `bun test` via `scripts/opencode-dev` or bare `bun`).
- **In-container as dev:** `docker compose exec -T --user dev dev bash -lc 'cd /workspace && make test-omo'` — must be green without the `/tmp/outside.txt` pollution (run `docker compose exec -T --user root dev rm -f /tmp/outside.txt` once before).
- **Coverage:** the three rewritten permission tests (mock/collision) + the unique-sibling test + the remaining OMO suite (no regressions). The three tests must not contain `chmod 000`.

### Secondary gate — `make test-config` / `git push` integration

- `make test-config` stays green (no change to config).
- Manual `git push` to the branch re-runs `scripts/verify-pre-push.sh` as the hook; with the fix it delegates as `dev` and OMO tests pass without `--no-verify`.

## Migration Plan

### Deploy

1. One-time container cleanup: `docker compose exec -T --user root dev rm -f /tmp/outside.txt` (removes stale root-owned file from prior root runs).
2. Edit `scripts/verify-pre-push.sh:61` to add `--user dev` to the `docker compose exec` invocation.
3. Edit `.opencode/oh-my-opencode-slim/src/hooks/apply-patch/hook.test.ts` (and any sibling OMO file owning the other two `chmod 000` tests — locate via `grep -rn 'chmod 000' .opencode/oh-my-opencode-slim/src`): rewrite the three permission tests to mock/inject `EACCES` or use a UID-independent FS collision; rewrite the `../outside.txt` test to use a unique temp sibling + `finally` rm.
4. Verify host `make test-omo` green; verify `docker compose exec -T --user dev dev bash -lc 'cd /workspace && make test-omo'` green; verify `make test-shell` green (new bats assertion for `--user dev`).

### Rollback Plan

- `git revert` the 2-3 files (`scripts/verify-pre-push.sh`, `hook.test.ts`, plus any sibling OMO test file touched). No image rebuild, no schema change, no persistent state. Worst case if the flag is dropped: `git push` re-runs OMO as root and the three tests revert to their root-bypass failure — never data loss. Trivially reversible.

### Open Questions

None — the developer diagnosis is the interview transcript and the fix is developer-specified.
