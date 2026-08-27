## Context

See proposal.md - Why. The opencode-docker launcher (`tools/opencode-docker/bin/opencode-docker`) currently mounts the host container engine socket unconditionally in the SOCKET_MOUNT block (lines 150-164) and sets DOCKER_HOST. The base poetry-dev stack (docker-compose.yml / Dockerfile.dev) mounts NO docker socket - this launcher is the only auto-mount in the project (completed check audit, this ticket).

The pre-commit hook `scripts/verify-pre-commit.sh` (DIA-121) delegates `docker compose` to the poetry-dev container. When the developer commits from INSIDE opencode-docker, the hook runs inside opencode-docker and reaches the host engine through the mounted socket (the hook's `else` branch calls `docker compose -f ... exec -T dev`, and `is_in_dev_container` is false because the hostname is not `poetry-dev`). Making the mount default-off therefore breaks that delegation path unless the developer opts in.

Governing constraints:

- `tools/opencode-docker/AGENTS.md` (subproject) - documents the SSH-agent and socket-forward security model; the socket is mounted `:ro` and the container runs with `--security-opt label=disable`, `--cap-drop ALL`, `--read-only` rootfs.
- DIA-121 hook contract: the hook FAILS by default (D1) when the dev container is down, rather than silently skipping.
- No `.sdd/` document governs this subproject (it is a standalone wrapper, not a system module); the design authority is the subproject AGENTS.md plus the DIA-121 hook contract.

## Goals / Non-Goals

**Goals:**

1. Make the engine socket mount opt-in: default off, enabled only by `-E/--with-engine`.
2. Preserve existing socket-mount behavior (`:ro`, DOCKER_HOST, probe order) when the flag IS passed.
3. Keep the DIA-121 hook working and diagnosable: when the socket is absent inside opencode-docker, the hook fails with the exact remediation (relaunch with `--with-engine`).
4. Add host-runnable bats coverage for both the launcher gating and the hook guard.

**Non-Goals:**

1. Changing the socket probe order (rootless Podman first, then system Docker) - already correct.
2. Removing system Docker fallback - out of scope (separate concern from the superseded draft).
3. Changing the SSH-agent forward or any other mount.
4. Adding a new test harness inside `tools/opencode-docker` - the root `scripts/__tests__/*.bats` harness is reused.

## Decisions

### Decision 1: Default-off `-E/--with-engine` flag gates the socket mount

**Choice:** Add `-E/--with-engine` to the flag parser (default `WITH_ENGINE=0`). The SOCKET_MOUNT block runs its probe loop ONLY when `WITH_ENGINE=1`; otherwise `SOCKET_MOUNT` stays empty and a new warning tells the developer that in-container `docker compose` / git hooks need `--with-engine`.

**Rationale:** Least-privilege by default (the audit's mandate). The flag name follows the existing convention (`-w/--websearch`, `-S/--serve`, `-U/--update-config`). Default-off is the whole point of the hardening.

**Alternatives considered:**

- Default-on with `--no-engine` opt-out: rejected, defeats the hardening (Tier-1 audit).
- Keep unconditional: rejected, the vulnerability the audit found (Tier-1 audit).

### Decision 2: Sentinel env `OPENCODE_DOCKER=1` so the hook can tell contexts apart

**Choice:** The launcher always exports `OPENCODE_DOCKER=1` into the container (independent of the socket flag). The hook checks this var to distinguish "inside opencode-docker" from "on the host".

**Rationale:** Without the sentinel, the hook cannot tell "inside opencode-docker without socket" (needs `--with-engine` guidance) from "on host without container" (needs `make up` guidance) - both make `docker compose ps` fail. The sentinel makes the diagnostic precise.

**Alternatives considered:**

- Detect opencode-docker by hostname/image: rejected, hostname is not stable and the hook already keys on `poetry-dev`; an explicit sentinel is simpler and deterministic.
- Detect by presence of `/var/run/docker.sock`: rejected, that is exactly the thing we are making absent by default, so it cannot be the signal.

### Decision 3: Hook fails with actionable `--with-engine` guidance (not silent, not misleading)

**Choice:** In `verify-pre-commit.sh`, when `OPENCODE_DOCKER=1` and the engine socket is unreachable, exit 1 with a message: "Container engine socket not mounted. Relaunch opencode-docker with --with-engine to enable in-container git hooks / docker compose." The host-down path (no sentinel) keeps the existing "dev container not running - start with 'make up'" message.

**Rationale:** The hook cannot re-launch its own container or mount a socket at runtime (it runs inside opencode-docker; only `podman run` mounts). The only physically possible way to keep DIA-121 working is: developer opts in at launch, and the hook gives the precise remediation when they forgot. This preserves DIA-121's fail-by-default contract (D1) while fixing the misleading message.

**Alternatives considered:**

- Hook auto-relaunches opencode-docker: rejected, impossible from inside the container (Tier-1: hook source).
- Hook mounts the socket itself: rejected, a running container cannot bind-mount a host socket into itself (Tier-1: wrapper's podman run is the only mount point).
- Silent skip of the hook when socket missing: rejected, violates DIA-121 D1 (a commit-time gate must not silently pass).

## Risks / Trade-offs

**Risk 1: Developer forgets `--with-engine` and a commit from inside opencode-docker fails.**

- Mitigation: the hook's new message states the exact relaunch command; the launcher's startup warning also reminds them. Trade-off: one extra flag to remember, but only when hooks/docker are needed.

**Risk 2: Existing docs tell users the socket "just works".**

- Mitigation: update `tools/opencode-docker/README.md` and `AGENTS.md` socket sections to document `--with-engine`. Trade-off: doc churn.

**Risk 3: A test that mocks `podman` drifts from the real run line.**

- Mitigation: assert on the specific `-v ...docker.sock:ro` token and the `DOCKER_HOST` env, not the whole command; follow the existing `mock_docker` pattern. Trade-off: mock tests may miss real-podman quirks (acceptable; the behavior is simple arg-gating).

## Seams

**Public boundaries where tests will live (pre-agreed with the user):**

1. **Launcher flag + gating** (`tools/opencode-docker/bin/opencode-docker`):
   - Flag parser (~line 94): `-E/--with-engine` sets `WITH_ENGINE=1`.
   - SOCKET_MOUNT block (lines 150-164): probe loop runs only when `WITH_ENGINE=1`; otherwise empty + new warning.
   - Sentinel env: `OPENCODE_DOCKER=1` always exported via `EXTRA_ENV`.
   - Test seam: mock `podman` captures the run args; assert `-v ...docker.sock:ro` present ONLY with `--with-engine`, and `OPENCODE_DOCKER=1` always present.

2. **Hook diagnostic guard** (`scripts/verify-pre-commit.sh`):
   - New branch: `if [ "$OPENCODE_DOCKER" = 1 ] && socket unreachable` -> exit 1 with `--with-engine` guidance.
   - Test seam: reuse `mock_docker` + fake hostname; set `OPENCODE_DOCKER=1` and make `docker compose ps` fail -> assert exit 1 + message contains `--with-engine`. Host-down path (no sentinel) asserts unchanged `make up` message.

3. **Test files** (reused harness, no new harness):
   - `scripts/__tests__/opencode-docker.bats`: new launcher-gating cases (mocked podman, mocked sockets).
   - `scripts/__tests__/verify-pre-commit.bats`: new hook-guard cases (mocked docker, sentinel set).

**Test seams summary:** mocked `podman`/`docker` + mocked socket files in temp dirs; host-runnable; wired into `make test-shell` (already covers these bats files). No new test infrastructure in `tools/opencode-docker` (its Makefile only builds the image).

## Migration Plan

**Phase 1: Implement (this ticket)**

1. Launcher: add `-E/--with-engine`, gate SOCKET_MOUNT, add sentinel env + new warning.
2. Hook: add diagnostic guard.
3. Tests: extend the two bats files.
4. Docs: update README.md + AGENTS.md socket sections.
5. Validate: `openspec validate dia-260821-aoag-socket-mount-opt-in` and `make test-shell`.
6. Merge.

**Rollback strategy:**

- Revert launcher commit and/or hook commit. Socket returns to unconditional; no persistent state. If only the hook guard is reverted, developers already using `--with-engine` are unaffected.

## Open Questions

None. All three interview decisions (flag name + default, hook resolution, test harness) are resolved above.
