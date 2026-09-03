## Why

The developer works inside `tools/opencode-docker` and needs to `git push` from the container to SSH remotes (private GitHub repos, the repo's SSH remotes). Today the container has no SSH agent access, so any push requiring SSH auth fails. The wrapper already runs with `--userns=keep-id` and `--security-opt label=disable` (DIA-164), which satisfy the two blockers for socket forwarding on Fedora + SELinux (unix-socket permissions via keep-id, SELinux connectto denial via label=disable). Research confirmed the recipe: forward the host's SSH agent socket into the container read-only, with keys never leaving the host.

## What Changes

- Add an `SSH_MOUNT` detection loop in `tools/opencode-docker/bin/opencode-docker` (after the existing `SOCKET_MOUNT` block ~line 153), mirroring its structure: probe `$SSH_AUTH_SOCK`, fallbacks to `${XDG_RUNTIME_DIR:-}/keyring/ssh` and `${XDG_RUNTIME_DIR:-}/gcr/ssh`, mount the first found socket **read-only** at `/tmp/ssh-agent.sock` (the rootfs is `--read-only` but `/tmp` is a writable tmpfs per line 164).
- Set `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` via the existing `EXTRA_ENV` array.
- Warn-and-continue when no socket is found (the container still launches; opencode itself works without git auth).
- Optionally add `GIT_SSH_COMMAND="-o StrictHostKeyChecking=accept-new"` via `EXTRA_ENV` (known_hosts on read-only `/app` cannot be written; the container needs a way to accept new host keys without user interaction).
- Documentation: `tools/opencode-docker/AGENTS.md` option header + README note about the no-agent warning and the requirement that the host GNOME keyring/ssh-agent must be unlocked.

**SECURITY REQUIREMENT (verbatim from developer, 2026-08-13):**

> "це має бути секюрно, бо це SSH ключ, і я не хочу, щоб він кудись вилився в контейнер, чи в git, чи ще кудись, в публічний доступ"
>
> Translation: This must be secure because it's an SSH key; I don't want it to leak into the container, into git, or anywhere else, into public access.

**Acceptance criteria:**

1. `git push` of a test branch from inside `opencode-docker` succeeds (SSH remote).
2. `ssh-add -l` from inside the container lists the host's keys (proves socket forwarding works).
3. Keys NEVER leave the host: no `~/.ssh` mount, no key file copy, only the agent socket is forwarded.
4. The socket mount is **read-only** (container cannot write to the host socket).
5. The mount target is `/tmp/ssh-agent.sock` (a socket, not a key file).
6. When the host has no agent running, the wrapper prints a documented no-agent warning and still starts the container (warn-and-continue).
7. When the host has an agent running, `SSH_AUTH_SOCK` inside the container resolves to `/tmp/ssh-agent.sock`.

## Capabilities

### New Capabilities

- `ssh-agent-forward`: Forward the host's SSH agent socket into the opencode-docker container read-only so `git push` to SSH remotes works from inside the container. Keys never leave the host; only the agent socket is mounted (read-only) at `/tmp/ssh-agent.sock`. Detection loop mirrors the existing `SOCKET_MOUNT` block structure. Warn-and-continue when no agent socket is found. Security profile identical to the already-accepted DIA-164 docker-socket forwarding (a host socket forwarded into the container; the container already holds host container-management rights via the DIA-164 docker.sock mount).

### Modified Capabilities

(none — no existing specs in `openspec/specs/`)

## Impact

- **Code:** `tools/opencode-docker/bin/opencode-docker` wrapper script (~181 lines → ~200 lines with SSH_MOUNT block).
- **Docs:** `tools/opencode-docker/AGENTS.md` (option header for SSH agent forwarding), `tools/opencode-docker/README.md` (note about no-agent warning and host agent requirement).
- **Dependencies:** None (uses existing podman/docker socket forwarding pattern from DIA-164).
- **Systems:** Only `opencode-docker` (the `podman run` wrapper). Does NOT touch `poetry-dev` (docker-compose dev service; its delegated gates are make/pnpm only, need no git auth). Does NOT touch `docker-compose.yml` or `dev-entrypoint.sh`.

## Testing Decisions

**What makes a good test for this change:**

Tests are **security-critical**: they must prove the key material never enters the container. The tests must verify:

1. No `~/.ssh` mount (assert: the podman run command does NOT contain `-v ~/.ssh`).
2. Socket mount is read-only (assert: the mount options include `:ro`).
3. Mount target is the socket not a key file (assert: the mount target is `/tmp/ssh-agent.sock`, not a `.pub` or private key path).
4. Warn-and-continue on absent socket (assert: when `SSH_AUTH_SOCK` is unset and fallbacks don't exist, the wrapper prints a warning to stderr and exits 0, not 1).
5. Detection loop finds the socket when present (assert: when `SSH_AUTH_SOCK` is set, the wrapper mounts it at `/tmp/ssh-agent.sock` and sets `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` via EXTRA_ENV).

**Which modules will be tested:**

- `tools/opencode-docker/bin/opencode-docker` (the wrapper script itself).
- The new `SSH_MOUNT` detection loop (extracted into a testable function or tested via bats with mocked environment variables).

**Prior art in the codebase:**

- `tools/opencode-docker/tests/` (if it exists; follow the existing test structure).
- `scripts/tests/` (bats tests for shell scripts; follow the existing mock patterns, e.g., `test-helper.bash` if it exists).
- The existing `SOCKET_MOUNT` block is a structural template: the `SSH_MOUNT` loop should mirror it exactly, so tests can mirror the SOCKET_MOUNT tests (if they exist).

**Test strategy:**

- **TDD (test-first, per AGENTS.md §2.2 and developer directive):** Write the security-critical tests FIRST (before implementing the SSH_MOUNT block), then implement to make them pass.
- **Test framework:** bats (Bash Automated Testing System) — the project uses bats for shell script tests.
- **Test environment:** Mock `SSH_AUTH_SOCK`, `XDG_RUNTIME_DIR`, and podman/docker commands to simulate the presence/absence of agent sockets.
- **Test location:** `tools/opencode-docker/tests/test-ssh-agent.bats` (new file) or add to existing test file if one exists.

## Rollback Plan

This change is low-risk and easily reversible:

- **Git revert:** `git revert <commit-sha>` removes the SSH_MOUNT block and docs.
- **No data migration:** The change only adds a new optional mount; no existing data or configuration is modified.
- **No breaking changes:** The warn-and-continue behavior means the container still launches even if the SSH agent is not found; existing workflows are unaffected.

If the implementation causes issues (e.g., SELinux denials, socket permission errors), the revert is immediate and complete.
