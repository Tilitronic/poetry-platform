# Tasks: Pre-push OMO tests run as root — permission-test and isolation fix

## 1. Pre-push delegation — run as dev

- **1.1 Edit `scripts/verify-pre-push.sh` host delegation to use `--user dev`**
  - Change line 61 from `docker compose -f "$ROOT/docker-compose.yml" exec -T dev bash -lc ...` to `docker compose -f "$ROOT/docker-compose.yml" exec -T --user dev dev bash -lc ...`.
  - One line; preserves `< /dev/null` stdin close, `VERIFY_PRE_PUSH_RUNNING=1` guard, and `container_running` warn+pass.
  - Acceptance: `grep -F 'exec -T --user dev dev' scripts/verify-pre-push.sh` matches; no `exec -T dev` without `--user` remains for the delegation path. `make test-shell` new assertion (1.2) passes.
  - Depends on: none
  - Blocks: 1.2, 3.1

- **1.2 Add bats static assertion for `--user dev` in the delegated command**
  - Extend `scripts/__tests__/verify-pre-push.bats` (or add `scripts/__tests__/verify-pre-push-user.bats` wired via `bats-wrapper.sh`) with a host-delegation test that mocks `is_in_dev_container=false` / `container_running=true` and asserts the `docker compose exec` string contains `--user dev`. Keep Docker mocked (no daemon).
  - Acceptance: `make test-shell` green including the new assertion; negative check (no `--user`-less `exec -T dev`) holds.
  - Depends on: 1.1
  - Blocks: 3.1, 3.2

## 2. OMO test isolation — unique sibling file (fourth test)

- **2.1 Rewrite sibling-directory test to use a unique temp sibling + finally cleanup**
  - Locate the test at `hook.test.ts:684` (`passes through sibling-directory targets outside root/worktree`) — currently `path.join(path.dirname(root), 'outside.txt')` / `/tmp/outside.txt`.
  - Change to a unique path: e.g., `const outside = path.join(os.tmpdir(), \`hook-outside-${Date.now()}-${Math.random().toString(36).slice(2)}.txt\`)`or`mkdtemp`sibling dir +`outside.txt`; write the file; wrap body in `try { ... asserts ... } finally { await rm(outside, { force: true }) }`(or`unlink`).
  - Imports: add `rm` (or `unlink`) from `node:fs/promises` and `os` if needed; keep `createTempDir`/`writeFixture` usage for `root`.
  - Acceptance: the test no longer writes to fixed `/tmp/outside.txt`; it passes on host and as `dev` in-container after the one-time `rm -f /tmp/outside.txt` cleanup; `make test-omo` green.
  - Depends on: none
  - Blocks: 3.1

## 3. OMO permission tests — root-independent error simulation (three tests)

- **3.1 Rewrite the three `chmod 000` tests to not rely on permission bits**
  - Locate all three via `grep -rn 'chmod.*000\|0o000' .opencode/oh-my-opencode-slim/src` — expected owners: `hook.test.ts:461` (`blocks internal guard errors`), plus the `records failures and continues` and `conflict staging failure` tests (may live in `operations.test.ts` / `skill-sync.test.ts` — locate before editing).
  - For each test, replace the `chmod 000` setup and `finally chmod 755` cleanup with one of: (a) `spyOn`/`mock` of `node:fs/promises` (`writeFile`/`mkdir`/`chmod`) to reject with `Object.assign(new Error('EACCES'), { code: 'EACCES' })` for the specific call under test, or (b) a UID-independent FS collision (e.g., `await writeFile(path.join(root,'locked'), 'file-not-dir')` then attempt `mkdir`/`writeFile` under `locked/child.txt` → `ENOTDIR`).
  - Keep the behavioral assertion (`rejects.toThrow('apply_patch internal error:')` or the staged-failure continuation assertion) and the `output.args.patchText` unchanged check where applicable.
  - Remove `chmod` from the three tests' imports if no longer needed elsewhere; do not alter production code (`hook/index.ts`, `operations.ts`).
  - Acceptance: no `chmod 000` / `0o000` remains in the three tests; all three pass both on host (`make test-omo`) and as `dev` (`docker compose exec -T --user dev dev bash -lc 'cd /workspace && make test-omo'`); the full OMO suite has no regressions.
  - Depends on: 1.1, 1.2, 2.1
  - Blocks: 3.2

## 4. Verification

- **4.1 One-time container cleanup of the stale fixed path**
  - Run `docker compose exec -T --user root dev rm -f /tmp/outside.txt` once. This removes the `root:root` file left by prior root runs that blocks `dev` verification. It is a manual one-off, not a code change.
  - Acceptance: `docker compose exec -T --user dev dev bash -lc 'ls -l /tmp/outside.txt' 2>&1` shows no such file.
  - Depends on: none
  - Blocks: 4.2

- **4.2 Verify OMO tests pass as dev and on host**
  - Run host `make test-omo` and `docker compose exec -T --user dev dev bash -lc 'cd /workspace && make test-omo'` (after 4.1 and after the code fixes in 1.1/2.1/3.1).
  - Acceptance: both green; never use `--no-verify`; `git push` re-runs OMO as `dev` (until `verify-pre-push.sh` is fixed, it re-runs as root — expected; post-fix push is `dev`).
  - Depends on: 1.1, 1.2, 2.1, 3.1, 4.1
  - Blocks: none

- **4.3 Verify pre-push gate no longer requires --no-verify**
  - Run `make test-shell` (includes 1.2 assertion) + manual `git push` to the branch (or `scripts/verify-pre-push.sh` invoked on host with container up) and confirm the verification ladder passes without `--no-verify`.
  - Acceptance: `scripts/verify-pre-push.sh` shows `==> make test-omo` running as `dev` and the push is not rejected by OMO permission-test failures.
  - Depends on: 1.1, 1.2, 3.1
  - Blocks: none

## Blocking Edges Summary

```
1.1 --> 1.2, 3.1
1.2 --> 3.1, 3.2
2.1 --> 3.1
3.1 --> 3.2 (4.2)
4.1 --> 4.2
1.1,1.2,2.1,3.1,4.1 --> 4.2
1.1,1.2,3.1 --> 4.3
```

## Critical Paths

- `1.1 -> 1.2 -> 3.1 -> 4.2` (host delegation + permission tests -> verification)
- `2.1 -> 3.1 -> 4.2` (isolation fix joins at permission-test verification)

## Parallel Opportunities

- 1.1, 2.1, and 4.1 can start immediately (no blockers).
- 1.2 starts after 1.1.
- 3.1 starts after 1.1 + 1.2 + 2.1 (needs the delegation fix and the isolation context located).
- 4.2 and 4.3 are independent final gates after their respective dependencies.

## Out of Scope

- No change to `Dockerfile.dev` / `docker-compose.yml` / image `USER` (handled by DIA-260824-a3mk).
- No `scripts/dev-stack.sh` (`make stack`) alignment — separate ticket.
- No new mock filesystem or whole-suite rewrite.
