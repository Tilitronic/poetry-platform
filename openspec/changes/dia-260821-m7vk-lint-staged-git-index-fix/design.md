## Context

See proposal.md — Why. The pre-commit gate (DIA-094) is blocked for developers with UID ≠ 1000 due to a UID mismatch at the mount boundary. The fix must:

1. Align container UID with host UID via `.env` + `build.args`.
2. Migrate ownership of named volumes (`pnpm_store`, `dev_state`, `dev_cache`) and the `.git/` bind mount in the entrypoint.
3. Provide a bats unit test that verifies the fix without requiring a full container build.
4. Document `make clean` as the rollback path.

Constraints:

- `Dockerfile.dev` already has `ARG USER_UID=1000` / `ARG USER_GID=1000` (L21-22) — no changes needed to the Dockerfile itself.
- `dev-entrypoint.sh` already has a chown pattern at L72 (`chown -R dev:dev /home/dev/.local/share/opencode`) — the fix extends this pattern.
- `docker-compose.yml` already uses `.env` for other configuration (e.g., `POSTGRES_USER`, `POSTGRES_PASSWORD`) — the pattern is established.
- Bats tests already exist in `scripts/__tests__/` and use `POETRY_WORKSPACE` override for isolation (see `scripts/__tests__/guards-home-qualt.bats`).

## Goals / Non-Goals

**Goals:**

- Enable commits from the dev container for developers with any UID (not just 1000).
- Preserve backward compatibility: developers with UID 1000 (default) see no change.
- Provide automated verification (bats unit test) that catches regressions.
- Document a clear rollback path (`make clean`) for the rare case where permissions break.

**Non-Goals:**

- Fix SELinux `:z` label issues (out of scope for non-SELinux hosts; deferred).
- Add integration tests in `make test-infra` (bats unit tests are sufficient; deferred).
- Create a `repair-permissions.sh` script (YAGNI; `make clean` is sufficient; deferred).
- Auto-inject UID via Makefile (over-engineering; `.env` + `build.args` is sufficient).
- Change the pre-commit gate behavior (DIA-094 hard-fail remains unchanged).

## Decisions

### D1: UID/GID injection via `.env` + `build.args`

**Decision**: Add `USER_UID` and `USER_GID` to `.env.example` with a comment instructing developers to run `id -u` / `id -g`. Add `build.args` to `docker-compose.yml` to forward these values to `Dockerfile.dev`.

**Rationale**:

- Compose reads `.env` automatically — no Makefile changes needed.
- `Dockerfile.dev` already has `ARG USER_UID` / `ARG USER_GID` — no Dockerfile changes needed.
- Fallback `1000` in `build.args` preserves backward compatibility for developers who do not update `.env`.
- Self-documenting: `.env.example` with a comment tells developers what to do.

**Alternatives considered**:

- Makefile auto-injection: rejected as over-engineering (compose already reads `.env`).
- Static default 1000: rejected because it breaks macOS/WSL2 developers with UID ≠ 1000.

### D2: Entrypoint ownership migration for volumes and `.git/`

**Decision**: Extend `dev-entrypoint.sh` chown (currently scoped to `/home/dev/.local/share/opencode` at L72) to cover:

- `/workspace/.git` (bind mount, owned by host user)
- `/workspace/node_modules` (named volume `pnpm_store`)
- `/home/dev/.local/share` (named volume `dev_state`)
- `/home/dev/.cache` (named volume `dev_cache`)

**Rationale**:

- The chown pattern already exists at L72 — extending it is 4 lines of code.
- Entrypoint runs as root before `gosu dev` — infrastructure is ready.
- One-time cost at boot (seconds, not minutes).
- Does not touch `pgdata` (postgres volume, isolated, postgres has its own UID).

**Alternatives considered**:

- Entrypoint chown `.git` only (without UID alignment): rejected as fragile (chown on bind mount can conflict with host filesystem) and breaks multi-developer setups.
- `make clean` as the only migration path: rejected as destructive (wipes postgres data, pnpm cache).
- No volume migration: rejected because it causes silent failures (pnpm, opencode state become unwritable).

### D3: Bats unit test with `POETRY_WORKSPACE` override

**Decision**: Add a bats test in `scripts/__tests__/` that:

1. Creates a temporary workspace with a mock `.git/` directory.
2. Sets `POETRY_WORKSPACE` to the temp workspace.
3. Runs `verify-pre-commit.sh` with a mock `lint-staged` that attempts to write to `.git/index`.
4. Verifies that the write succeeds (no permission errors).

**Rationale**:

- Bats tests already exist in `scripts/__tests__/` and use `POETRY_WORKSPACE` override for isolation.
- Does not require Docker daemon (faster CI, local runs).
- Covers the root cause (UID mismatch → write failure) without full integration.

**Alternatives considered**:

- Integration test in `make test-infra`: rejected as slower (requires Docker daemon) and unnecessary (bats covers the root cause).
- Manual smoke test: rejected as not automated and easy to skip.

### D4: Document `make clean` as rollback path

**Decision**: Add a troubleshooting section to `docs/docker-dev.md` documenting `make clean && make up` as the rollback path for permission errors after UID changes.

**Rationale**:

- `make clean` already exists and is documented.
- The fix is narrow (UID alignment + chown), so the probability of breakage is low.
- If chown in entrypoint fails, `make clean` is the only guaranteed recovery path (manually chowning volumes is harder).

**Alternatives considered**:

- `repair-permissions.sh` script: rejected as premature optimization (YAGNI).
- No rollback plan: rejected because it leaves developers without guidance.

## Risks / Trade-offs

**[Risk] Developer forgets to add `USER_UID`/`USER_GID` to `.env`** → Mitigation: fallback `1000` in `build.args` preserves existing behavior. If the developer's host UID ≠ 1000, the pre-commit gate will fail with the same error as before, and the troubleshooting docs will guide them to add `USER_UID` to `.env`.

**[Risk] Entrypoint chown fails (permission denied on volume)** → Mitigation: `|| true` in the chown command prevents the entrypoint from crashing. The developer sees a warning and can run `make clean` to recover.

**[Risk] `make clean` wipes postgres data** → Mitigation: documented as destructive in `docs/docker-dev.md`. Developers are warned before running it.

**[Trade-off] One-time chown cost at boot** → Acceptable: seconds, not minutes. Only happens when volumes are first mounted or after UID changes.

**[Trade-off] No integration test in `make test-infra`** → Acceptable: bats unit tests cover the root cause. Integration tests can be added later if edge cases emerge.

## Migration Plan

**Deploy**:

1. Developer adds `USER_UID=$(id -u)` and `USER_GID=$(id -g)` to `.env` (one-time).
2. Developer runs `make clean && make up` to rebuild the image with the new UID.
3. Entrypoint chowns volumes and `.git/` on first boot.
4. Developer can now commit from the container without permission errors.

**Rollback**:

1. Developer runs `make clean && make up` to restore the pre-fix state (wipes volumes, including postgres data).
2. Developer removes `USER_UID`/`USER_GID` from `.env` (optional, fallback `1000` will be used).

**Backward compatibility**:

- Developers with UID 1000 (default) see no change.
- Developers with UID ≠ 1000 must add `USER_UID`/`USER_GID` to `.env` and rebuild.

## Open Questions

None. All questions were resolved in the interview (Q1-Q5).

**Deferred (not blocking, can be follow-up)**:

- SELinux `:z` label investigation (if issues emerge on RHEL/Fedora).
- Integration test in `make test-infra` (if bats tests do not cover edge cases).
- `repair-permissions.sh` script (if developers frequently encounter permission errors).
