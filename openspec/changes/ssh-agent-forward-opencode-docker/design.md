## Context

See `proposal.md` for motivation. The wrapper `tools/opencode-docker/bin/opencode-docker` already runs with `--userns=keep-id` (line 162) and `--security-opt label=disable` (line 167), which satisfy the two blockers for socket forwarding on Fedora + SELinux:

1. Unix-socket permissions: host uid 1000 → container uid 1000 via `keep-id`.
2. SELinux `connectto` denial: `label=disable` runs the container without SELinux confinement (acceptable trade-off: non-root uid 1000, read-only rootfs, `--cap-drop ALL`, no added privileges).

The existing `SOCKET_MOUNT` block (lines 139-153) provides the structural template: probe socket paths, mount the first found read-only, set env var, warn-and-continue when none found. The `SSH_MOUNT` block mirrors this exactly.

No `.sdd/` documents govern `tools/opencode-docker/` (the module is small enough that the wrapper script itself + this design document serve as the design authority).

## Goals / Non-Goals

**Goals:**

- Forward the host's SSH agent socket into the opencode-docker container **read-only** so `git push` to SSH remotes works from inside the container.
- Keys **never** leave the host: only the agent socket is mounted (no `~/.ssh` mount, no key file copy).
- Detection loop mirrors the `SOCKET_MOUNT` structure for consistency and testability.
- Warn-and-continue when no agent socket is found (container still launches; opencode itself works without git auth).
- Security-critical tests (TDD) prove the key material never enters the container.

**Non-Goals:**

- Does NOT touch `poetry-dev` (docker-compose dev service; its delegated gates are make/pnpm only, need no git auth).
- Does NOT touch `docker-compose.yml` or `dev-entrypoint.sh`.
- Does NOT add SSH key management, key generation, or key storage inside the container.
- Does NOT add interactive known_hosts management (the container's `/app` is read-only; see Decision D2 for the automated approach).

## Decisions

### D1: Mount target is `/tmp/ssh-agent.sock` (not `/ssh-agent.sock`)

**Rationale:** The rootfs is `--read-only` (line 163), so podman cannot create a mountpoint at `/ssh-agent.sock` (would require a Dockerfile change to `touch /ssh-agent.sock`). However, `/tmp` is a writable tmpfs (line 164: `--tmpfs /tmp:exec,size=512m`), so `/tmp/ssh-agent.sock` works without modifying the Dockerfile. This is the lazy path (YAGNI: no Dockerfile change needed).

**Alternatives considered:**

- `/ssh-agent.sock` mountpoint (requires Dockerfile `touch /ssh-agent.sock` → rejected: unnecessary Dockerfile change).
- Mount the socket at the same path as the host (e.g., `$SSH_AUTH_SOCK` → rejected: path may not exist in the container, and the container's `/tmp` is the standard ephemeral location).

### D2: `GIT_SSH_COMMAND="-o StrictHostKeyChecking=accept-new"` via EXTRA_ENV

**Recommendation: YES, include this.**

**Rationale:** The container's `/app` is read-only (line 163), so `~/.ssh/known_hosts` cannot be written. Without `GIT_SSH_COMMAND`, the first `git push` to a new host (e.g., `github.com`) would prompt for host key confirmation, which fails in a non-interactive container. `StrictHostKeyChecking=accept-new` auto-accepts new host keys on first connection (but rejects changed keys, preserving TOFU security). This is the standard pattern for CI/CD containers.

**Security trade-off:** `accept-new` trusts the first-seen host key (TOFU). If an attacker MITMs the first connection, they can inject a malicious host key. Mitigation: the developer's host already has `github.com` in `~/.ssh/known_hosts`; the container only needs to accept the same key. The risk is identical to the already-accepted docker-socket forwarding (DIA-164): a host resource forwarded into the container; the container already holds host container-management rights.

**Alternatives considered:**

- `StrictHostKeyChecking=no` (accept all, even changed keys → rejected: weaker security, no TOFU).
- Mount a pre-populated `known_hosts` file (requires Dockerfile change or host file → rejected: unnecessary complexity, `accept-new` is simpler).
- Interactive prompt (rejected: container is non-interactive).

### D3: Detection loop probes `$SSH_AUTH_SOCK`, then fallbacks

**Rationale:** Mirror the `SOCKET_MOUNT` loop structure (lines 140-150) for consistency. Probe order:

1. `$SSH_AUTH_SOCK` (the standard env var; most common case).
2. `${XDG_RUNTIME_DIR:-}/keyring/ssh` (GNOME keyring default).
3. `${XDG_RUNTIME_DIR:-}/gcr/ssh` (GNOME keyring alternative path).

Mount the first found socket read-only. If none found, warn to stderr and continue (warn-and-continue).

**Why not probe `/run/user/$(id -u)/keyring/ssh`?** The `SOCKET_MOUNT` loop probes `/run/user/$(id -u)/podman/podman.sock` as a fallback, but SSH agent sockets are less standardized. GNOME keyring typically uses `$XDG_RUNTIME_DIR/keyring/ssh` or `$SSH_AUTH_SOCK`. Adding more fallbacks increases complexity without clear benefit (YAGNI). If a user's SSH agent uses a non-standard path, they can set `SSH_AUTH_SOCK` manually.

### D4: Socket mount is read-only (`:ro`)

**Rationale:** Security. The container should never write to the host's SSH agent socket. Read-only mount ensures the container can only make sign-requests, not modify the socket state. This is identical to the `SOCKET_MOUNT` pattern (line 146: `-v "$sock:/var/run/docker.sock:ro"`).

### D5: Reuse `--userns=keep-id` + `--security-opt label=disable` (DIA-164 precedent)

**Rationale:** These two flags already solve the SELinux + unix-socket permission blockers. No additional flags needed. The security profile is identical to the already-accepted DIA-164 docker-socket forwarding (a host socket forwarded into the container; the container already holds host container-management rights).

### D6: Test seam is `scripts/__tests__/ssh-agent-forward.bats` (new file)

**Rationale:** The existing `scripts/__tests__/opencode-docker.bats` tests the `check-opencode-docker.sh` gate script, not the `bin/opencode-docker` wrapper itself. The SSH agent forwarding tests need to test the wrapper's `SSH_MOUNT` loop, which is a different concern. A new test file keeps concerns separated and avoids bloating `opencode-docker.bats`.

**Test strategy:** Follow the existing `test-helper.bash` mock patterns:

- Mock `SSH_AUTH_SOCK`, `XDG_RUNTIME_DIR` to simulate presence/absence of agent sockets.
- Create fake socket files in `$BATS_TEST_TMPDIR` to simulate real sockets.
- Mock `podman` to record the `podman run` invocation (follow the `mock_docker` pattern from `test-helper.bash` lines 78-100).
- Assert on the recorded `podman` command: check for `-v <socket>:/tmp/ssh-agent.sock:ro`, check for `-e SSH_AUTH_SOCK=/tmp/ssh-agent.sock`, check for absence of `-v ~/.ssh`.

**Security-critical assertions:**

1. `assert podman run command does NOT contain '-v' followed by '.ssh'` (proves no `~/.ssh` mount).
2. `assert podman run command contains '-v <socket>:/tmp/ssh-agent.sock:ro'` (proves socket mount is read-only).
3. `assert podman run command contains '-v <socket>:/tmp/ssh-agent.sock'` (proves mount target is a socket, not a key file).
4. `assert podman run command contains '-e SSH_AUTH_SOCK=/tmp/ssh-agent.sock'` (proves env var is set).
5. `assert wrapper exits 0 and prints warning when no socket found` (proves warn-and-continue).

## Seams

**S1: SSH_MOUNT detection loop (new seam)**

Location: `tools/opencode-docker/bin/opencode-docker` lines ~154-170 (after `SOCKET_MOUNT` block).

Public boundary: The `SSH_MOUNT` array and the `EXTRA_ENV` array are the public seams. Tests will inspect these arrays (or the recorded `podman run` command) to verify the mount is correct.

**S2: Test seam for mocking SSH agent sockets**

Location: `scripts/__tests__/ssh-agent-forward.bats` (new file).

Public boundary: The test file will use `$BATS_TEST_TMPDIR` to create fake socket files and mock environment variables (`SSH_AUTH_SOCK`, `XDG_RUNTIME_DIR`). The test will mock `podman` to record the invocation (follow `test-helper.bash` `mock_docker` pattern).

**S3: Documentation seam**

Location: `tools/opencode-docker/AGENTS.md` and `tools/opencode-docker/README.md`.

Public boundary: The documentation will describe the SSH agent forwarding feature, the no-agent warning, and the requirement that the host GNOME keyring/ssh-agent must be unlocked.

## Risks / Trade-offs

**R1: SELinux denial on SSH agent socket → Mitigation:** `--security-opt label=disable` (already present, DIA-164 precedent) disables SELinux confinement for the container, so no `connectto` denial. The security trade-off is acceptable (non-root uid 1000, read-only rootfs, `--cap-drop ALL`).

**R2: SSH agent socket path varies by desktop environment → Mitigation:** Detection loop probes the three most common paths (`$SSH_AUTH_SOCK`, `${XDG_RUNTIME_DIR}/keyring/ssh`, `${XDG_RUNTIME_DIR}/gcr/ssh`). If a user's SSH agent uses a non-standard path, they can set `SSH_AUTH_SOCK` manually. Warn-and-continue when no socket is found.

**R3: `GIT_SSH_COMMAND=accept-new` trusts first-seen host key (TOFU) → Mitigation:** The developer's host already has `github.com` in `~/.ssh/known_hosts`; the container only needs to accept the same key. The risk is identical to the already-accepted DIA-164 docker-socket forwarding. If the developer wants stricter security, they can mount a pre-populated `known_hosts` file (out of scope for this change; see Non-Goal).

**R4: Socket mount is read-only, but the container can still make sign-requests → Mitigation:** This is the intended behavior. The container can request the host's SSH agent to sign data (for `git push`), but cannot modify the socket state. This is identical to the docker-socket forwarding pattern (the container can make docker API calls, but the socket is read-only).

**R5: Test coverage does not prove the socket forwarding works end-to-end → Mitigation:** The tests are unit tests (mock `podman`, fake sockets). End-to-end verification (actual `git push` from the container) is a manual verification step (see `proposal.md` Verification section). The tests prove the wrapper constructs the correct `podman run` command; the manual verification proves the command works.

## Migration Plan

**Deploy:**

1. Merge the PR (adds `SSH_MOUNT` block to `bin/opencode-docker`, updates docs).
2. Developer rebuilds the container: `make build` in `tools/opencode-docker/`.
3. Developer relaunches: `bin/opencode-docker`.
4. Inside the container: `echo $SSH_AUTH_SOCK` should resolve to `/tmp/ssh-agent.sock`.
5. Inside the container: `ssh-add -l` should list the host's keys.
6. Inside the container: `git push` of a test branch should succeed (SSH remote).

**Rollback:**

- `git revert <commit-sha>` removes the `SSH_MOUNT` block and docs.
- No data migration, no breaking changes. The warn-and-continue behavior means the container still launches even if the SSH agent is not found.

## Open Questions

**Q1: Should the `SSH_MOUNT` loop probe `/run/user/$(id -u)/keyring/ssh` as an additional fallback?**

**Recommendation: NO.** GNOME keyring typically uses `$XDG_RUNTIME_DIR/keyring/ssh` or `$SSH_AUTH_SOCK`. Adding more fallbacks increases complexity without clear benefit (YAGNI). If a user's SSH agent uses a non-standard path, they can set `SSH_AUTH_SOCK` manually. The three paths probed (`$SSH_AUTH_SOCK`, `${XDG_RUNTIME_DIR}/keyring/ssh`, `${XDG_RUNTIME_DIR}/gcr/ssh`) cover the common cases.

**Q2: Should the test file be named `ssh-agent-forward.bats` or added to the existing `opencode-docker.bats`?**

**Recommendation: New file `ssh-agent-forward.bats`.** The existing `opencode-docker.bats` tests the `check-opencode-docker.sh` gate script, not the `bin/opencode-docker` wrapper itself. The SSH agent forwarding tests need to test the wrapper's `SSH_MOUNT` loop, which is a different concern. A new test file keeps concerns separated.

**Q3: Should the `GIT_SSH_COMMAND` env var be set unconditionally, or only when the SSH agent socket is found?**

**Recommendation: Unconditionally.** The `GIT_SSH_COMMAND` is needed regardless of whether the SSH agent is present (it controls how `git` handles host keys, not SSH agent forwarding). Setting it unconditionally simplifies the logic (no conditional `EXTRA_ENV` append). The env var is harmless when no SSH agent is present.
