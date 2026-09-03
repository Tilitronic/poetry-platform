# Delta Spec: Unified Dev Container

## ADDED Requirements

### Requirement: Unified Development Image

The project SHALL use a single `Dockerfile.dev` at the repository root as the authoritative development image for all platforms.

#### Scenario: Single Source of Truth

**Given** the project has one unified `Dockerfile.dev` at the repository root
**When** a developer builds the development container
**Then** the container includes:

- OpenCode CLI (single version, no drift)
- Node.js 24, pnpm, bun, uv, mise, snip
- Python 3 + uv for FastAPI api-server
- Rust toolchain (for stress-lang-core WASM builds)
- Playwright (chromium) + crawl4ai for browser automation
- Language servers (TypeScript, Pyright, YAML, rust-analyzer)
- OMO plugin cache (pre-populated)

**And** both Fedora Linux and WSL developers use the same image.

#### Scenario: Version Consistency

**Given** the unified container is built from `Dockerfile.dev`
**When** a developer runs `opencode --version` inside the container
**Then** the version matches the OPENCODE_VERSION ARG in `Dockerfile.dev`
**And** both Fedora and WSL developers see the same version.

### Requirement: Engine-Specific Compose Overrides

The project SHALL provide engine-specific compose override files containing only engine-specific UID/GID mapping strategies. The base `docker-compose.yml` SHALL remain the single source of truth for volumes, ports, environment, and secrets. Evidence: `knowledge/res040-docker-rootless-uid-compatibility/res040-docker-rootless-uid-compatibility-conspect.md`.

#### Scenario: Podman Engine Override

**Given** the container engine is Podman (detected via `docker version` containing "Podman")
**When** `opencode-dev` selects the Podman override
**Then** it runs `docker compose -f docker-compose.yml -f docker-compose.podman.yml up -d dev`
**And** the container starts with:

- `userns_mode: keep-id` for UID/GID mapping (res040 §2: host UID:GID maps to same values inside container)
- `security_opt: [label=disable]` for SELinux compatibility (Fedora)

**And** the base `docker-compose.yml` configuration (volumes, ports, environment, secrets) is preserved
**And** host-owned bind mounts appear with host UID inside the container (res040 §2).

#### Scenario: Rootless Docker Engine Override

**Given** the container engine is rootless Docker (detected via `docker version` not containing "Podman")
**When** `opencode-dev` selects the rootless-Docker override
**Then** it runs `docker compose -f docker-compose.yml -f docker-compose.rootless-docker.yml up -d dev`
**And** the container starts with:

- `user: "0:0"` for UID/GID mapping (res040 §1: container UID 0 maps to host user in rootless Docker)

**And** the base `docker-compose.yml` configuration is preserved
**And** host-owned bind mounts appear as root-owned inside the container but are writable (res040 §1).

#### Scenario: WSL Overlay (Optional)

**Given** the host OS is WSL (detected via `/proc/version` containing "Microsoft" or "WSL")
**When** `opencode-dev` detects WSL
**Then** it applies `docker-compose.wsl.yml` on top of the selected engine override
**And** the command becomes `docker compose -f docker-compose.yml -f docker-compose.<engine>.yml -f docker-compose.wsl.yml up -d dev`
**And** WSL-specific settings (if any) are merged
**And** the base `docker-compose.yml` and engine override configurations are preserved.

#### Scenario: Override Validation

**Given** compose override files exist
**When** a developer runs `docker compose -f docker-compose.yml -f docker-compose.<engine>.yml [-f docker-compose.wsl.yml] config`
**Then** the merged configuration validates without errors
**And** no configuration is duplicated between base and override files.

### Requirement: Unified Launch Command

The project SHALL provide a `scripts/opencode-dev` shell script (bash-3 compatible) that auto-detects the engine and OS, and launches the unified container.

#### Scenario: Default Launch

**Given** the `opencode-dev` command is available
**When** a developer runs `opencode-dev` with no flags
**Then** the command auto-detects the engine (Podman or Docker)
**And** auto-detects the OS (WSL or native)
**And** starts the container if not running with the appropriate overrides
**And** opens an interactive bash shell (`docker compose exec dev bash`).

#### Scenario: Engine Auto-Detection

**Given** the `opencode-dev` command is running
**When** it checks the container engine
**Then** it runs `docker version`
**And** if output contains "Podman", engine=podman
**And** otherwise, engine=docker
**And** it selects `docker-compose.<engine>.yml`.

**Note:** `docker version` (not `docker --version`) is used because the project's immutable mock supports `version`; both Docker and Podman output remain distinguishable.

#### Scenario: OS Auto-Detection

**Given** the `opencode-dev` command is running
**When** it checks the host OS
**Then** it reads `/proc/version`
**And** if content contains "Microsoft" or "WSL", os=wsl
**And** otherwise, os=native
**And** if os=wsl, it also selects `docker-compose.wsl.yml`.

#### Scenario: Engine Override

**Given** the `opencode-dev` command is running
**When** a developer runs `opencode-dev --engine=podman`
**Then** the command uses `docker-compose.podman.yml` regardless of auto-detection
**And** the override takes precedence.

#### Scenario: OS Override

**Given** the `opencode-dev` command is running
**When** a developer runs `opencode-dev --os=wsl`
**Then** the command uses `docker-compose.wsl.yml` regardless of auto-detection
**And** the overlay is applied on top of the selected engine override.

#### Scenario: SSH Agent Forwarding

**Given** the `opencode-dev` command is running
**When** a developer runs `opencode-dev --ssh-agent`
**Then** the command probes for SSH agent socket in order:

1. `$SSH_AUTH_SOCK`
2. `${XDG_RUNTIME_DIR}/keyring/ssh`
3. `${XDG_RUNTIME_DIR}/gcr/ssh`

**And** forwards the socket to `/tmp/ssh-agent.sock` in the container (read-only)
**And** sets `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` in the container
**And** sets `GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/tmp/known_hosts -o IdentityAgent=/tmp/ssh-agent.sock"`
**And** prints a warning if no socket is found (opencode still works).

#### Scenario: Run OpenCode Mode

**Given** the `opencode-dev` command is running
**When** a developer runs `opencode-dev --run-opencode`
**Then** the command launches `opencode` instead of `bash`
**And** executes `docker compose exec dev opencode`.

#### Scenario: Test Mode

**Given** the `opencode-dev` command is running
**When** a developer runs `opencode-dev --test`
**Then** the command runs `make test-infra` in the container
**And** executes `docker compose exec dev make test-infra`.

#### Scenario: Container Already Running

**Given** the dev container is already running
**When** a developer runs `opencode-dev`
**Then** the command skips `docker compose up -d dev`
**And** directly executes the appropriate `docker compose exec` command.

### Requirement: SSH Agent Integration

The unified container SHALL support SSH agent forwarding for `git push` operations to SSH remotes.

#### Scenario: Socket Forwarding

**Given** the unified container is running with `--ssh-agent`
**When** a developer executes `git push` to an SSH remote
**Then** the container forwards the sign request to the host's SSH agent
**And** the push succeeds
**And** the private keys never leave the host.

#### Scenario: Known Hosts

**Given** the unified container is running with `--ssh-agent`
**When** a developer connects to a new SSH host
**Then** the host key is added to `/tmp/known_hosts` (writable tmpfs)
**And** subsequent connections to the same host use the cached key
**And** the known_hosts file is discarded when the container stops.

### Requirement: Chromium Shared Memory

The unified container SHALL allocate sufficient shared memory for Playwright chromium.

#### Scenario: Shared Memory Allocation

**Given** the unified container is starting
**When** the container runtime allocates shared memory
**Then** the container receives `--shm-size=1g` (1GB shared memory)
**And** Playwright chromium can launch without shared-memory errors.

### Requirement: Contract Test

The project SHALL provide a contract test verifying identical `opencode --version` across both engine overrides.

#### Scenario: Version Consistency Check

**Given** both engine override files exist
**When** the contract test runs
**Then** it executes `docker compose -f docker-compose.yml -f docker-compose.podman.yml exec dev opencode --version`
**And** it executes `docker compose -f docker-compose.yml -f docker-compose.rootless-docker.yml exec dev opencode --version`
**And** it asserts the output is identical (same version string).

#### Scenario: Contract Test Integration

**Given** the contract test exists at `scripts/__tests__/unified-container-contract.bats`
**When** a developer runs `make test-infra`
**Then** the contract test is included in the test suite
**And** it requires real containers running (not mock-based).

### Requirement: UID/GID Mapping Contract Test

The project SHALL provide a UID/GID mapping test verifying the res040 contract for both engine strategies.

#### Scenario: Podman keep-id Semantics

**Given** the Podman engine override is active
**When** a bind-mounted file owned by the host user is accessed inside the container
**Then** the file shows the host UID inside the container (res040 §2: keep-id maps host UID:GID to same values)
**And** the container process can write to the file.

#### Scenario: Rootless Docker user 0:0 Semantics

**Given** the rootless-Docker engine override is active
**When** a bind-mounted file owned by the host user is accessed inside the container
**Then** the file shows root ownership inside the container (res040 §1: container UID 0 maps to host user)
**And** the container process (running as UID 0) can write to the file.

#### Scenario: Secret Readability

**Given** either engine override is active
**When** a host-owned secret is accessed inside the container
**Then** the container process can read the secret
**And** the secret content is intact.

#### Scenario: UID Test Integration

**Given** the UID/GID mapping test exists at `scripts/__tests__/engine-override-uid.bats`
**When** a developer runs `make test-infra`
**Then** the UID test is included in the test suite
**And** it requires real containers running (not mock-based).

### Requirement: Backward Compatibility

The unified container SHALL preserve existing launch commands as compatible alternatives.

#### Scenario: Legacy Commands

**Given** the unified container is implemented
**When** a developer runs `make opencode`
**Then** the command continues to work as before
**And** it launches the unified container.

#### Scenario: Direct Compose Exec

**Given** the unified container is implemented
**When** a developer runs `docker compose exec dev bash`
**Then** the command continues to work as before
**And** it opens a bash shell in the unified container.

### Requirement: Legacy Launcher Preservation

The `tools/opencode-docker/` directory SHALL remain unchanged during the unified container implementation.

#### Scenario: Legacy Launcher Unchanged

**Given** the unified container is implemented
**When** a developer accesses `tools/opencode-docker/`
**Then** the directory is unchanged from before the unified container
**And** `tools/opencode-docker/bin/opencode-docker` continues to work
**And** it can be used for immediate rollback.

#### Scenario: Retirement Threshold

**Given** the unified container has been deployed
**When** 7 consecutive days pass with both developers using it successfully
**And** reviewer audit passes
**And** ai-auditor audit passes
**And** both developers provide explicit confirmation
**Then** `tools/opencode-docker/` may be physically deleted.

### Requirement: Rollback

The unified container implementation SHALL support immediate rollback.

#### Scenario: Immediate Rollback

**Given** the unified container shows problems
**When** a developer needs to rollback
**Then** they can use `tools/opencode-docker/bin/opencode-docker` directly
**Or** they can `git revert` the implementation commits
**And** remove the new engine-specific compose override files (`docker-compose.podman.yml`, `docker-compose.rootless-docker.yml`, `docker-compose.wsl.yml`)
**And** the legacy launcher remains functional.

### Requirement: Secrets Ownership Preflight

The unified container SHALL refuse to start if `secrets/` ownership or mode is unsafe, with actionable diagnostics. Decision: `secure-secrets-ownership-option-a-selected`.

#### Scenario: Safe Ownership and Mode

**Given** the `opencode-dev` command is running
**When** it checks `secrets/` ownership and mode
**Then** it verifies `secrets/` is owned by the host rootless-Podman user (UID that `keep-id` maps)
**And** it verifies each secret file is mode `0600`
**And** it verifies no group/other read bits
**And** if all checks pass, it proceeds to start the container.

#### Scenario: Unsafe Ownership

**Given** the `opencode-dev` command is running
**When** it checks `secrets/` ownership
**Then** if `secrets/` is not owned by the host rootless-Podman user
**And** it prints specific remediation (e.g., `chown <uid>:<gid> secrets/<file>`)
**And** it exits non-zero without starting the container.

#### Scenario: Unsafe Mode

**Given** the `opencode-dev` command is running
**When** it checks secret file modes
**Then** if any secret file is not mode `0600`
**And** it prints specific remediation (e.g., `chmod 0600 secrets/<file>`)
**And** it exits non-zero without starting the container.

#### Scenario: Avoid-chown-Recursive Safeguard

**Given** the preflight script is running
**When** it checks or remediates ownership/mode
**Then** it MUST NOT use `chown -R` or `chmod -R` on `secrets/`
**And** it MUST use only explicit per-file operations
**And** it MUST NOT attempt automatic remediation — only print diagnostics and exit.

#### Scenario: SSH-Agent Separation Preserved

**Given** the preflight script is running
**When** it checks `secrets/` ownership and mode
**Then** it MUST NOT interfere with SSH-agent socket forwarding
**And** SSH-agent separation is preserved (orthogonal to secret ownership).

### Requirement: Keep-ID Recreation Verification

The unified container SHALL verify that Podman `keep-id` recreation creates secret mountpoints, git index write succeeds, and API secret is readable only by intended dev process.

#### Scenario: Secret Mountpoints Created

**Given** the Podman engine override is active with `keep-id`
**When** the container starts
**Then** secret mountpoints are created successfully inside the container
**And** the container process can access the mounted secrets.

#### Scenario: Git Index Write Succeeds

**Given** the Podman engine override is active with `keep-id`
**When** the container starts
**Then** the container process can write to the `.git/` bind mount
**And** git index operations succeed.

#### Scenario: API Secret Readable Only by Intended Dev Process

**Given** the Podman engine override is active with `keep-id`
**When** the container starts
**Then** the API secret is readable only by the intended dev process
**And** no broad read permission exists (verify mode/owner inside container).

#### Scenario: Keep-ID Recreation Test Integration

**Given** the keep-id recreation verification test exists at `scripts/__tests__/keep-id-recreation-verify.bats`
**When** a developer runs `make test-infra`
**Then** the keep-id recreation test is included in the test suite (Podman engine only)
**And** it requires real Podman container running (not mock-based).

## Constraints

### Constraint: Bash-3 Compatibility

The `scripts/opencode-dev` command MUST use bash-3 compatible syntax (per ADR 8 in `.sdd/dev-infra/architecture.md`).

### Constraint: No Configuration Duplication

Compose override files MUST NOT duplicate volumes, ports, environment, or secrets from the base `docker-compose.yml`.

### Constraint: Engine-Specific UID Mapping

The UID/GID mapping strategy MUST be engine-specific, not OS-specific. Podman uses `keep-id` (res040 §2); rootless Docker uses `user: "0:0"` (res040 §1). Evidence: `knowledge/res040-docker-rootless-uid-compatibility/res040-docker-rootless-uid-compatibility-conspect.md`.

### Constraint: WSL Overlay is Orthogonal to Engine

WSL-specific settings MUST be applied as a separate overlay on top of the selected engine override, not as a replacement. A WSL host can run either Podman or Docker.

### Constraint: Mock Tests Do Not Prove Runtime Versions or UID Mapping

Mock-based bats tests verify command behavior but do NOT prove runtime version consistency or UID mapping behavior. Real acceptance verification on started containers is required.

### Constraint: Planning-Only (This Ticket)

This ticket delivers OpenSpec artifacts only. No Dockerfile, compose, or config files are modified. Implementation follows in a separate ticket.

### Constraint: Secrets Ownership Preflight

The preflight script MUST NOT use `chown -R` or `chmod -R` on `secrets/` — only explicit per-file operations. The preflight script MUST NOT attempt automatic remediation — only print diagnostics and exit. Rollback: revert ownership/mode changes manually; no automated chown rollback.

### Constraint: SSH-Agent Separation

The preflight script MUST NOT interfere with SSH-agent socket forwarding. SSH-agent separation is preserved (orthogonal to secret ownership).

### Constraint: No Broad Read Permission

Each secret file MUST remain mode `0600` (owner read/write only). No group/other read bits. `secrets/` MUST NOT be tracked by Git (already in `.gitignore`).

## Test Seams

### Mock-Based Unit Tests

**File:** `scripts/__tests__/opencode-dev.bats`

**Coverage:**

- Default behavior (no flags)
- `--ssh-agent` flag
- `--run-opencode` flag
- `--test` flag
- Engine auto-detection (mock `docker version` with/without "Podman")
- OS auto-detection (mock `/proc/version` with/without "Microsoft"/"WSL")
- `--engine` override
- `--os` override
- Correct override file selection per engine+OS combination
- Container already running (skip `up`)

**Pattern:** Mock `docker` command; verify correct compose invocation with engine+OS overrides.

**Limitation:** Does NOT verify runtime behavior, version consistency, or UID mapping.

### UID/GID Mapping Tests

**File:** `scripts/__tests__/engine-override-uid.bats`

**Coverage:**

- Podman override: bind-mounted file shows host UID inside container (res040 §2)
- Rootless-Docker override: bind-mounted file shows root inside container (res040 §1)
- Both strategies: container process can write to host-owned bind mounts
- Both strategies: container process can read host-owned secrets

**Pattern:** Requires real containers running (not mock-based). Verifies the UID mapping contract from res040.

**Integration:** Added to `make test-infra` as acceptance gate.

### Contract Test

**File:** `scripts/__tests__/unified-container-contract.bats`

**Coverage:**

- Identical `opencode --version` for both engine overrides

**Pattern:** Requires real containers running (not mock-based).

**Integration:** Added to `make test-infra` as acceptance gate.

### Secrets Ownership Preflight Tests

**File:** `scripts/__tests__/check-secrets-ownership.bats`

**Coverage:**

- Preflight passes when `secrets/` owned by host rootless-Podman user and all files mode `0600`
- Preflight fails with actionable diagnostics when `secrets/` owned by wrong user
- Preflight fails with actionable diagnostics when any secret file is not mode `0600`
- Preflight fails with actionable diagnostics when any secret file has group/other read bits
- Preflight script never uses `chown -R` or `chmod -R` (verify by code inspection or mock)

**Pattern:** Mock `stat` and `id` commands; verify preflight logic and diagnostic output.

**Limitation:** Does NOT verify runtime behavior — only preflight logic.

### Keep-ID Recreation Verification Tests

**File:** `scripts/__tests__/keep-id-recreation-verify.bats`

**Coverage:**

- After Podman `keep-id` container start: secret mountpoints exist inside container
- After Podman `keep-id` container start: git index write succeeds (container can write to `.git/`)
- After Podman `keep-id` container start: API secret is readable only by intended dev process (verify mode/owner inside container)

**Pattern:** Requires real Podman container running (not mock-based). Verifies the keep-id recreation contract.

**Integration:** Added to `make test-infra` as acceptance gate (Podman engine only).

### Real Acceptance Verification

**Platforms:** Fedora (Podman or Docker) + WSL (Podman or Docker)

**Checks:**

1. All existing gates pass
2. SSH push works
3. Chromium launches
4. `opencode --version` identical
5. Bind mounts writable under selected engine strategy (res040 §1-4)
6. Secrets readable under selected engine strategy
7. Preflight refusal works: unsafe `secrets/` ownership/mode causes `opencode-dev` to exit with actionable diagnostics
8. Keep-id recreation verification: secret mountpoints created, git index write succeeds, API secret readable only by intended dev process (Podman engine)

**Evidence:** Collected and attached to implementation ticket.
