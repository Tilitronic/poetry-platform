## Why

Pre-commit hook `lint-staged` fails with `could not write index` when committing from the dev container on hosts where the user UID differs from the container's hardcoded UID 1000. The root cause is a UID mismatch at the mount boundary: `.git/` is owned by the host user, but the container's `dev` user (UID 1000) cannot write to it. `git config --system safe.directory` (DIA-185) bypasses git's ownership check but does not grant write permissions. This blocks all commits from the container, violating the hard pre-commit gate (DIA-094).

## What Changes

- **UID/GID alignment**: pass host UID/GID from `.env` into `docker-compose.yml` `build.args`, which are forwarded to `Dockerfile.dev` `ARG USER_UID`/`USER_GID` (already present, currently hardcoded to 1000).
- **Entrypoint ownership migration**: extend `dev-entrypoint.sh` chown (currently scoped to `/home/dev/.local/share/opencode` only) to cover the three named volumes: `pnpm_store` (mounted at `/workspace/node_modules`), `dev_state` (mounted at `/home/dev/.local/share`), `dev_cache` (mounted at `/home/dev/.cache`). Also chown `/workspace/.git` to handle the bind mount.
- **`.env.example` update**: add `USER_UID=1000` and `USER_GID=1000` with a comment instructing developers to run `id -u` / `id -g`.
- **Troubleshooting docs**: add a section to `docs/docker-dev.md` documenting `make clean` as the rollback path for permission errors after UID changes.
- **Bats unit test**: add a test in `scripts/__tests__/` that verifies `verify-pre-commit.sh` succeeds when the mock workspace `.git/` is owned by a different UID than the container user, using the existing `POETRY_WORKSPACE` override.

## Capabilities

### New Capabilities

None. This is a dev-infra repair — no new user-facing or system-level capabilities.

### Modified Capabilities

None. No spec-level behavior changes. The pre-commit gate (DIA-094) behavior is unchanged; only the underlying permission model is fixed.

**Note**: This change is pure tooling/config/docs. No spec-level behavior changes. `skip_specs: true` is set in `.openspec.yaml`.

## Impact

- **Affected files**: `docker-compose.yml`, `dev-entrypoint.sh`, `.env.example`, `docs/docker-dev.md`, `scripts/__tests__/` (new bats test).
- **Affected systems**: dev container build and runtime. No impact on app services (author-studio, api-server, publishing-platform), postgres, or CI/CD pipelines (fallback UID 1000 preserves existing behavior).
- **Dependencies**: no new dependencies. Uses existing `Dockerfile.dev` `ARG USER_UID`/`USER_GID` mechanism.
- **Breaking changes**: none. Developers with UID 1000 (default) see no change. Developers with UID ≠ 1000 must add `USER_UID`/`USER_GID` to `.env` (one-time) and run `make clean && make up` to rebuild the image.
- **Rollback**: `make clean && make up` restores the pre-fix state (wipes volumes, including postgres data — documented as destructive).

## Alternatives considered

- **Entrypoint chown `.git` only (Q1 alternative)**: chown `/workspace/.git` in `dev-entrypoint.sh` without UID alignment. Rejected because it is fragile (chown on bind mount can conflict with host filesystem) and breaks multi-developer setups (different developers with different UIDs would fight over ownership). Evidence: Tier-1 (DIA-260821-m7vk interview Q1 decision).
- **`lint-staged` `GIT_INDEX_FILE` workaround (Q1 alternative)**: redirect `lint-staged` to write a temporary index file in `/tmp` instead of `.git/`. Rejected because it leaves the root cause (UID mismatch) unresolved and creates edge cases (index not synchronized with `.git/` during parallel operations). Evidence: Tier-1 (DIA-260821-m7vk interview Q1 decision).
- **`make clean` as the only migration path (Q2 alternative)**: require `make clean` after UID changes instead of entrypoint chown. Rejected because it is destructive (wipes postgres data, pnpm cache) and creates friction. Evidence: Tier-1 (DIA-260821-m7vk interview Q2 decision).
- **No volume migration (Q2 alternative)**: do not chown volumes after UID changes. Rejected because it causes silent failures (pnpm, opencode state become unwritable). Evidence: Tier-1 (DIA-260821-m7vk interview Q2 decision).
- **Integration test in `make test-infra` (Q3 alternative)**: add a full integration test that runs the container and verifies `lint-staged` succeeds. Rejected because it is slower (requires Docker daemon) and bats unit tests with `POETRY_WORKSPACE` override already cover the root cause. Evidence: Tier-1 (DIA-260821-m7vk interview Q3 decision).
- **Manual smoke test (Q3 alternative)**: document a manual verification step instead of automated tests. Rejected because it is not automated and easy to skip. Evidence: Tier-1 (DIA-260821-m7vk interview Q3 decision).
- **`repair-permissions.sh` script (Q4 alternative)**: create a non-destructive script to fix permissions without `make clean`. Rejected as premature optimization (YAGNI) — the fix is narrow, and `make clean` is sufficient for the rare case where permissions break. Evidence: Tier-1 (DIA-260821-m7vk interview Q4 decision).
- **No rollback plan (Q4 alternative)**: do not document a rollback path. Rejected because it leaves developers without guidance when things break. Evidence: Tier-1 (DIA-260821-m7vk interview Q4 decision).
- **Makefile auto-injection of UID (Q5 alternative)**: have the Makefile automatically inject `USER_UID=$(shell id -u)` into `docker compose build`. Rejected as over-engineering — compose already reads `.env` automatically, and the Makefile would become the only entry point (breaking direct `docker compose up`). Evidence: Tier-1 (DIA-260821-m7vk interview Q5 decision).
- **Static default UID 1000 (Q5 alternative)**: do not change the build mechanism, keep UID hardcoded to 1000. Rejected because it breaks macOS/WSL2 developers with UID ≠ 1000. Evidence: Tier-1 (DIA-260821-m7vk interview Q5 decision).
- **Status-quo / do nothing**: leave the pre-commit gate broken for developers with UID ≠ 1000. Rejected because it blocks commits, violating the hard pre-commit gate (DIA-094) and preventing development work.

**Chosen option**: UID/GID alignment via `.env` + `build.args` + entrypoint ownership migration — because it eliminates the root cause (UID mismatch at the mount boundary), prevents future permission-related breakages, and uses existing infrastructure (`Dockerfile.dev` `ARG USER_UID`/`USER_GID`, entrypoint chown pattern at L72).

## Testing Decisions

**What makes a good test for this change**: a test that verifies the root cause (UID mismatch → write failure) is fixed, without requiring a full container build or Docker daemon.

**Modules tested**: `scripts/verify-pre-commit.sh` (the pre-commit hook that invokes `lint-staged`).

**Prior art**: existing bats tests in `scripts/__tests__/` use the `POETRY_WORKSPACE` override to test shell scripts in isolation (see `scripts/__tests__/guards-home-qualt.bats` for the pattern).

**Test strategy**: bats unit test that:

1. Creates a temporary workspace with a mock `.git/` directory owned by UID 1000.
2. Sets `POETRY_WORKSPACE` to the temp workspace.
3. Runs `verify-pre-commit.sh` with `USER_UID=1001` (simulating the container user).
4. Verifies that `lint-staged` (mocked or stubbed) can write to `.git/index` without permission errors.

**What is NOT tested**: full integration with real `lint-staged` + eslint/prettier (deferred to manual verification). SELinux `:z` label behavior (out of scope for non-SELinux hosts).
