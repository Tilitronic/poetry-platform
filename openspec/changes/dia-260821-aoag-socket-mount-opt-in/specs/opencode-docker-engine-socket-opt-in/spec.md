## Purpose

Governs when the opencode-docker launcher mounts the host container engine socket, making it opt-in (default off) for least-privilege, and how the pre-commit hook fails with actionable guidance when the socket is absent inside opencode-docker.

## ADDED Requirements

### Requirement: Engine socket is opt-in (default off)

The opencode-docker launcher SHALL NOT mount the host container engine socket into the container unless `-E/--with-engine` is explicitly passed. When the flag is passed, the launcher SHALL mount the socket read-only at `/var/run/docker.sock` and SHALL set `DOCKER_HOST=unix:///var/run/docker.sock`, preserving the existing probe order (rootless Podman first, then system Docker).

#### Scenario: Launch without --with-engine

- **WHEN** the developer launches opencode-docker without `-E/--with-engine`
- **THEN** the launcher does not mount any host container engine socket into the container

#### Scenario: Launch with --with-engine

- **WHEN** the developer launches opencode-docker with `-E/--with-engine` and a socket is present
- **THEN** the launcher mounts the socket read-only at `/var/run/docker.sock` and sets `DOCKER_HOST`

### Requirement: Sentinel env identifies the opencode-docker context

The launcher SHALL always export `OPENCODE_DOCKER=1` into the container, independent of the `--with-engine` flag, so that in-container tooling can distinguish the opencode-docker context from the host.

#### Scenario: Launcher always sets the sentinel

- **WHEN** the launcher starts the container, with or without `--with-engine`
- **THEN** the container environment contains `OPENCODE_DOCKER=1`

### Requirement: Clear warning when the socket is omitted

When `-E/--with-engine` is not passed, the launcher SHALL print a warning to stderr stating that in-container `docker compose` and git hooks require `--with-engine`, instead of a generic "socket not found" warning.

#### Scenario: Launch without --with-engine warns about the flag

- **WHEN** the launcher runs without `--with-engine`
- **THEN** it prints a warning that mentions `--with-engine` as the way to enable in-container docker compose and git hooks

### Requirement: Pre-commit hook fails with actionable guidance inside opencode-docker without a socket

The pre-commit hook (`scripts/verify-pre-commit.sh`) SHALL, when running inside opencode-docker (detected via `OPENCODE_DOCKER=1`) and the container engine socket is unreachable, fail with a message instructing the developer to relaunch opencode-docker with `--with-engine`. The hook SHALL NOT silently skip the gate.

#### Scenario: Hook inside opencode-docker without socket

- **WHEN** a git commit runs the pre-commit hook inside opencode-docker and no engine socket is mounted
- **THEN** the hook exits non-zero with a message containing `--with-engine`

#### Scenario: Hook on host with container down

- **WHEN** a git commit runs the pre-commit hook on the host and the dev container is down
- **THEN** the hook exits non-zero with the existing "dev container not running - start with 'make up'" message (unchanged)
