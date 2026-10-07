# container-engine-socket-selection Specification

## Purpose

Defines the socket probe order, fallback policy, and error handling for the opencode-docker launcher's container engine socket selection logic. Ensures rootless Podman is preferred over system Docker, with explicit error handling when Podman socket operations fail.

## Requirements

### Requirement: Socket probe order

The launcher SHALL probe for container engine sockets in the following order:

1. Rootless Podman socket at `$XDG_RUNTIME_DIR/podman/podman.sock`
2. Rootless Podman socket at `/run/user/$UID/podman/podman.sock`
3. System Docker socket at `/var/run/docker.sock`

The first socket found SHALL be used for all container engine operations.

#### Scenario: Rootless Podman socket found at XDG_RUNTIME_DIR

- **WHEN** `$XDG_RUNTIME_DIR/podman/podman.sock` exists and is a socket
- **THEN** launcher uses this socket for container engine operations
- **AND** launcher does NOT probe for system Docker socket

#### Scenario: Rootless Podman socket found at /run/user/UID

- **WHEN** `$XDG_RUNTIME_DIR/podman/podman.sock` does NOT exist
- **AND** `/run/user/$UID/podman/podman.sock` exists and is a socket
- **THEN** launcher uses this socket for container engine operations
- **AND** launcher does NOT probe for system Docker socket

#### Scenario: System Docker socket fallback

- **WHEN** no rootless Podman socket is found
- **AND** `/var/run/docker.sock` exists and is a socket
- **THEN** launcher uses system Docker socket for container engine operations
- **AND** launcher emits warning: "System Docker socket provides full API access to all containers in the system. Please migrate to rootless Podman."

#### Scenario: --with-engine requested but no socket found

- **WHEN** `--with-engine` flag is passed
- **AND** no rootless Podman socket is found
- **AND** no system Docker socket is found
- **THEN** launcher emits warning that the engine socket was requested but is unavailable (e.g. "Container engine socket not mounted (default-off). In-container 'docker compose' and git pre-commit hooks that delegate to the dev container require it - relaunch opencode-docker with --with-engine to enable.")
- **AND** launcher continues execution (opencode works without docker; only commit hooks need it)

### Requirement: Engine socket opt-in (default off)

The launcher SHALL NOT mount the host container engine socket unless the `-E` / `--with-engine` flag is passed. Engine access is deliberately disabled by default (this is not an error condition) to enforce least privilege: an always-mounted engine socket would let any code inside opencode-docker gain API authority over the host's containers.

#### Scenario: No --with-engine flag (default)

- **WHEN** `--with-engine` flag is NOT passed
- **THEN** launcher does NOT probe for any container engine socket
- **AND** launcher emits a warning that engine access is deliberately disabled (not an error) and that in-container `docker compose` / git pre-commit hooks require `--with-engine`
- **AND** launcher continues execution

#### Scenario: --with-engine requested, socket found

- **WHEN** `--with-engine` flag is passed
- **AND** a rootless Podman or system Docker socket is found (per the probe order above)
- **THEN** launcher mounts the socket read-only and sets `DOCKER_HOST` (existing probe-order behavior preserved)
- **AND** launcher always exports the `OPENCODE_DOCKER=1` sentinel so in-container hooks can distinguish opencode-docker from the host

### Requirement: Podman socket failure handling

When a rootless Podman socket is detected but engine operations fail, the launcher SHALL fail with actionable diagnostics and SHALL NOT silently fall back to system Docker.

#### Scenario: Podman socket detected but docker compose fails

- **WHEN** rootless Podman socket is detected
- **AND** `docker compose ps` fails with error
- **THEN** launcher exits with error message: "Rootless Podman socket found at <path>, but docker compose failed. Check podman socket status: systemctl --user status podman.socket"
- **AND** launcher does NOT fall back to system Docker socket
- **AND** launcher does NOT continue execution

#### Scenario: Podman socket detected but permission denied

- **WHEN** rootless Podman socket is detected
- **AND** container engine API calls fail with permission denied
- **THEN** launcher exits with error message: "Rootless Podman socket found at <path>, but permission denied. Check podman socket permissions and SELinux policy."
- **AND** launcher does NOT fall back to system Docker socket

### Requirement: Socket authority documentation

The launcher documentation SHALL explain the security model for container engine socket access, including:

- `:ro` mount option does NOT restrict API operations (only prevents socket file replacement)
- Socket access = full API authority over containers
- Rootless Podman = authority limited to user's own containers
- System Docker = authority over all containers in system (higher risk)

#### Scenario: README documents socket authority

- **WHEN** user reads `tools/opencode-docker/README.md`
- **THEN** "Container Engine Socket Access" section explains socket authority model
- **AND** section explains `:ro` does not restrict API operations
- **AND** section explains rootless Podman vs system Docker risk difference

### Requirement: Migration guide documentation

The launcher documentation SHALL provide migration instructions for rootless Podman on Fedora and WSL, including:

- Installation steps for rootless Podman
- Socket verification steps (`systemctl --user status podman.socket`)
- SELinux workaround (`--security-opt label=disable` already implemented)

#### Scenario: README provides Fedora migration guide

- **WHEN** user reads `tools/opencode-docker/README.md`
- **THEN** "Migration Guide" section provides Fedora installation steps
- **AND** section provides socket verification steps
- **AND** section provides SELinux workaround

#### Scenario: README provides WSL migration guide

- **WHEN** user reads `tools/opencode-docker/README.md`
- **THEN** "Migration Guide" section provides WSL installation steps
- **AND** section provides socket verification steps

### Requirement: Test coverage for socket selection

Automated tests SHALL verify socket selection logic, including:

- Launcher finds rootless Podman socket when present
- Launcher does NOT fall back to system Docker when Podman socket is detected but fails
- Launcher falls back to system Docker only when no Podman socket is detected
- Launcher emits warning when using system Docker fallback

#### Scenario: Tests verify Podman socket selection

- **WHEN** test suite runs `scripts/__tests__/opencode-docker.bats`
- **THEN** test verifies launcher finds rootless Podman socket when present
- **AND** test verifies launcher does NOT fall back to system Docker when Podman socket fails
- **AND** test verifies launcher falls back to system Docker when no Podman socket found
- **AND** test verifies launcher emits warning when using system Docker fallback

### Requirement: Platform verification evidence

Pre-merge evidence SHALL include verification on both Fedora and WSL platforms:

- `docker compose ps` works via Podman socket
- `git commit`, `git push` trigger hooks that delegate to poetry-dev
- `make test-infra` passes (exit 0)

#### Scenario: Fedora platform verification

- **WHEN** developer runs verification on Fedora with rootless Podman
- **THEN** `docker compose ps` returns container list (exit 0)
- **AND** `git commit` triggers pre-commit hook that delegates to poetry-dev (exit 0)
- **AND** `git push` triggers pre-push hook that delegates to poetry-dev (exit 0)
- **AND** `make test-infra` passes (exit 0)

#### Scenario: WSL platform verification

- **WHEN** developer runs verification on WSL with rootless Podman
- **THEN** `docker compose ps` returns container list (exit 0)
- **AND** `git commit` triggers pre-commit hook that delegates to poetry-dev (exit 0)
- **AND** `git push` triggers pre-push hook that delegates to poetry-dev (exit 0)
- **AND** `make test-infra` passes (exit 0)
