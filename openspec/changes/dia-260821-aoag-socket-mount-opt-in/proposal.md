## Why

The opencode-docker launcher (`tools/opencode-docker/bin/opencode-docker`) mounts the host container engine socket into the container UNCONDITIONALLY (lines 150-164). A completed security check audit found this is the only auto-mount of the host docker/podman socket in the project (the base poetry-dev stack mounts none). An always-mounted engine socket is a least-privilege violation: any code running inside opencode-docker gains API authority over the host's containers. The fix is to make the mount opt-in (default off) behind an explicit `--with-engine` flag.

This change supersedes the earlier draft `dia-260821-aoag-container-engine-socket-security-hardening`, which rejected `--with-engine` before the audit concluded the socket must be opt-in by default. That draft's fallback-policy concern (Podman vs Docker silent fallback) is out of scope here.

## What Changes

- **Launcher** (`tools/opencode-docker/bin/opencode-docker`):
  - Add a default-OFF `-E/--with-engine` flag to the flag parser (~line 94).
  - Gate the SOCKET_MOUNT block (lines 150-164) on that flag: the socket is mounted read-only and `DOCKER_HOST` is set ONLY when `--with-engine` is passed.
  - When the flag is absent, print a clear warning that in-container `docker compose` and git hooks require `--with-engine` (replacing the generic "socket not found" warning).
  - Always export a sentinel env var `OPENCODE_DOCKER=1` into the container so the pre-commit hook can detect it is running inside opencode-docker.

- **Pre-commit hook** (`scripts/verify-pre-commit.sh`, DIA-121):
  - When running inside opencode-docker (detected via `OPENCODE_DOCKER=1`) and the engine socket is unreachable, fail with an actionable message instructing the developer to relaunch opencode-docker with `--with-engine` (instead of the misleading "dev container not running - start with 'make up'" message).

- **Tests** (`scripts/__tests__/opencode-docker.bats`, `scripts/__tests__/verify-pre-commit.bats`):
  - Launcher mounts the socket only with `--with-engine`; sentinel env present.
  - Hook inside opencode-docker without socket fails with `--with-engine` guidance; host-down path unchanged.

## Capabilities

### New Capabilities

- `opencode-docker-engine-socket-opt-in`: The contract for when the opencode-docker launcher mounts the host container engine socket (opt-in, default off) and how the pre-commit hook fails with actionable guidance when the socket is absent inside opencode-docker.

### Modified Capabilities

(None - no existing specs modified)

## Impact

- **Code**: `tools/opencode-docker/bin/opencode-docker` (flag parser + SOCKET_MOUNT gating + sentinel env), `scripts/verify-pre-commit.sh` (diagnostic guard)
- **Tests**: `scripts/__tests__/opencode-docker.bats`, `scripts/__tests__/verify-pre-commit.bats` (new cases, host-runnable, mocked sockets)
- **Documentation**: `tools/opencode-docker/README.md`, `tools/opencode-docker/AGENTS.md` (document `--with-engine`; update socket section)
- **Dependencies**: None (no new dependencies)
- **Systems**: opencode-docker launcher, in-container git commit/push hooks (DIA-121 delegation to poetry-dev)

## Alternatives considered

- Default-ON with `--no-engine` opt-out: rejected because it defeats the least-privilege hardening the audit mandates - the socket would still mount unless the developer remembers to opt out (Tier-1: this ticket's completed check audit).
- Keep socket always mounted (status quo): rejected because the audit identified the unconditional mount as the vulnerability; least-privilege requires opt-in (Tier-1: this ticket's completed check audit).
- Hook auto-relaunches opencode-docker with `--with-engine`: rejected because the hook runs INSIDE the opencode-docker container and cannot re-launch its own container; it would also surprise the developer (Tier-1: scripts/verify-pre-commit.sh lines 24-42 show the hook delegates via `docker compose exec dev`, it does not launch containers).
- Hook mounts the socket itself at runtime: rejected because a running container cannot bind-mount a host socket into itself; only `podman run` (the launcher) can, and the launcher already does so when `--with-engine` is set (Tier-1: wrapper's `podman run` line 233-255 is the only mount point).
- Status-quo / do nothing: rejected because the audit mandates the fix (Tier-1: this ticket's completed check audit).
  Chosen option: default-off `--with-engine` + hook diagnostic guard - because the audit (Tier-1) requires least-privilege opt-in and the only physically possible way to keep DIA-121 working is an actionable fail when the developer forgot to opt in.

## Testing Decisions

**What makes a good test for this change:**

- Tests must verify the launcher mounts the socket ONLY when `--with-engine` is passed, and never otherwise.
- Tests must verify the sentinel env `OPENCODE_DOCKER=1` is always exported.
- Tests must verify the hook fails with `--with-engine` guidance when inside opencode-docker without a socket, and unchanged `make up` guidance on the host.
- Tests must be host-runnable (no Docker daemon) using mocked sockets / fake docker, following the existing bats pattern.

**Modules to test:**

- `tools/opencode-docker/bin/opencode-docker` (flag parser, SOCKET_MOUNT gating)
- `scripts/verify-pre-commit.sh` (diagnostic guard)

**Prior art in the codebase:**

- `scripts/__tests__/opencode-docker.bats` (existing wrapper static-integrity tests)
- `scripts/__tests__/verify-pre-commit.bats` (existing hook context tests, mocked docker)
- `scripts/__tests__/ssh-agent-forward.bats` (existing opencode-docker socket-forward test pattern)

**Test strategy:**

- Extend the existing root `scripts/__tests__/*.bats` files (no new harness; the subproject Makefile only builds the image). Use mocked sockets and fake docker so tests run on the host without a daemon. Wire into `make test-shell` (already covers these bats files).

## Rollback Plan

**If issues arise after merge:**

1. Revert the launcher commit (flag + gating) and the hook commit (diagnostic guard).
2. Socket mount returns to unconditional (pre-change behavior).
3. No data loss (launcher/hook behavior only, no persistent state).
4. If only the hook guard causes trouble, revert just the hook commit; the launcher opt-in remains and developers who already use `--with-engine` are unaffected.
