## Purpose

Forwards the host's SSH agent socket into the opencode-docker container read-only so `git push` to SSH remotes works from inside the container, without copying key material into the container.

## ADDED Requirements

### Requirement: SSH agent socket detection

The wrapper SHALL detect the host's SSH agent socket by probing, in order: `$SSH_AUTH_SOCK`, `${XDG_RUNTIME_DIR:-}/keyring/ssh`, `${XDG_RUNTIME_DIR:-}/gcr/ssh`. The wrapper SHALL mount the first found socket into the container.

#### Scenario: SSH_AUTH_SOCK is set

- **WHEN** the host environment has `SSH_AUTH_SOCK` set to a valid socket path
- **THEN** the wrapper mounts that socket into the container at `/tmp/ssh-agent.sock`

#### Scenario: SSH_AUTH_SOCK unset, GNOME keyring socket exists

- **WHEN** `SSH_AUTH_SOCK` is unset AND `${XDG_RUNTIME_DIR:-}/keyring/ssh` exists as a socket
- **THEN** the wrapper mounts `${XDG_RUNTIME_DIR:-}/keyring/ssh` into the container at `/tmp/ssh-agent.sock`

#### Scenario: SSH_AUTH_SOCK unset, GCR socket exists

- **WHEN** `SSH_AUTH_SOCK` is unset AND `${XDG_RUNTIME_DIR:-}/keyring/ssh` does not exist AND `${XDG_RUNTIME_DIR:-}/gcr/ssh` exists as a socket
- **THEN** the wrapper mounts `${XDG_RUNTIME_DIR:-}/gcr/ssh` into the container at `/tmp/ssh-agent.sock`

### Requirement: SSH agent socket mount is read-only

The wrapper SHALL mount the SSH agent socket with the `:ro` (read-only) flag. The container MUST NOT be able to write to the host's SSH agent socket.

#### Scenario: Socket mount has read-only flag

- **WHEN** the wrapper constructs the `podman run` command
- **THEN** the mount option for the SSH agent socket MUST contain `:ro`

#### Scenario: No write access to host socket

- **WHEN** the container attempts to write to `/tmp/ssh-agent.sock`
- **THEN** the write operation MUST fail (socket is read-only)

### Requirement: SSH_AUTH_SOCK env var set inside container

The wrapper SHALL set `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` inside the container via the `EXTRA_ENV` array when the SSH agent socket is found.

#### Scenario: SSH_AUTH_SOCK is propagated

- **WHEN** the wrapper finds an SSH agent socket on the host
- **THEN** the `podman run` command MUST include `-e SSH_AUTH_SOCK=/tmp/ssh-agent.sock`

#### Scenario: SSH_AUTH_SOCK inside container resolves correctly

- **WHEN** the container starts with SSH agent forwarding enabled
- **THEN** `echo $SSH_AUTH_SOCK` inside the container MUST output `/tmp/ssh-agent.sock`

### Requirement: No key material mounted into container

The wrapper MUST NOT mount `~/.ssh` or any SSH key file into the container. Only the agent socket is forwarded. Keys MUST remain on the host.

#### Scenario: No ~/.ssh mount

- **WHEN** the wrapper constructs the `podman run` command
- **THEN** the command MUST NOT contain any `-v` flag referencing `.ssh` or SSH key files (e.g., `id_rsa`, `id_ed25519`, `*.pub`)

#### Scenario: No key file copy

- **WHEN** the wrapper runs
- **THEN** no SSH key material (private or public keys) is copied into the container filesystem

### Requirement: Warn-and-continue when no agent socket found

The wrapper SHALL print a warning to stderr when no SSH agent socket is found, and MUST still launch the container (exit 0). The warn-and-continue behavior ensures opencode itself works even without git auth.

#### Scenario: No agent socket, container still launches

- **WHEN** `SSH_AUTH_SOCK` is unset AND no fallback socket paths exist
- **THEN** the wrapper prints a warning to stderr AND exits 0 AND the container launches without SSH agent forwarding

#### Scenario: Warning message is descriptive

- **WHEN** no SSH agent socket is found
- **THEN** the warning message MUST mention that `git push` will not work AND suggest checking that the host SSH agent is running AND unlocked

### Requirement: Mount target is /tmp/ssh-agent.sock

The wrapper SHALL mount the SSH agent socket at `/tmp/ssh-agent.sock` inside the container. The mount target MUST be a socket path, not a key file path.

#### Scenario: Mount target is /tmp/ssh-agent.sock

- **WHEN** the wrapper mounts the SSH agent socket
- **THEN** the mount target path inside the container MUST be `/tmp/ssh-agent.sock`

#### Scenario: /tmp is writable tmpfs

- **WHEN** the container starts
- **THEN** `/tmp` MUST be a writable tmpfs (per the existing `--tmpfs /tmp:exec,size=512m` flag)

### Requirement: GIT_SSH_COMMAND set for read-only rootfs

The wrapper SHALL set `GIT_SSH_COMMAND="-o StrictHostKeyChecking=accept-new"` via the `EXTRA_ENV` array. This allows the container to accept new host keys without writing to the read-only `/app` filesystem.

#### Scenario: GIT_SSH_COMMAND is set

- **WHEN** the wrapper constructs the `podman run` command
- **THEN** the command MUST include `-e GIT_SSH_COMMAND=-o StrictHostKeyChecking=accept-new`

#### Scenario: First connection to new host succeeds

- **WHEN** the container connects to an SSH host for the first time (e.g., `github.com`)
- **THEN** the connection MUST succeed without interactive host key confirmation (TOFU: accept-new trusts first-seen key)

### Requirement: Reuse DIA-121 security flags

The wrapper SHALL reuse the existing `--userns=keep-id` and `--security-opt label=disable` flags (DIA-121 precedent). These flags satisfy the unix-socket permissions and SELinux `connectto` denial blockers for socket forwarding.

#### Scenario: keep-id flag present

- **WHEN** the wrapper constructs the `podman run` command
- **THEN** the command MUST include `--userns=keep-id`

#### Scenario: label=disable flag present

- **WHEN** the wrapper constructs the `podman run` command
- **THEN** the command MUST include `--security-opt label=disable`

### Requirement: Documentation updated

The `tools/opencode-docker/AGENTS.md` and `tools/opencode-docker/README.md` SHALL document the SSH agent forwarding feature, including the no-agent warning and the requirement that the host GNOME keyring/ssh-agent must be unlocked.

#### Scenario: AGENTS.md documents SSH agent forwarding

- **WHEN** a developer reads `tools/opencode-docker/AGENTS.md`
- **THEN** the document MUST describe the SSH agent forwarding feature AND the no-agent warning

#### Scenario: README documents host agent requirement

- **WHEN** a developer reads `tools/opencode-docker/README.md`
- **THEN** the document MUST mention that the host SSH agent must be running AND unlocked for `git push` to work
