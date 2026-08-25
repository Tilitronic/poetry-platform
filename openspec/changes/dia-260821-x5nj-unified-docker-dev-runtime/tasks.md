# Tasks: Unified Docker Development Runtime

## Vertical Slices

### Slice 0: Hook Execution Model Inversion (P0 — Architectural Core)

**Goal:** Make the unified container the sole workspace for git commit, eliminating host delegation.

**Tasks:**

- [ ] **T0.1** Update `.husky/pre-commit` to execute directly inside container
  - Remove host-delegation logic (no `is_in_dev_container` / `container_running` branching)
  - Hook runs directly: `bash scripts/verify-pre-commit.sh`
  - Acceptance: Hook executes inside container without delegation
  - Depends on: none
  - Blocks: T0.3, T7.1

- [ ] **T0.2** Update `.husky/pre-push` to execute directly inside container
  - Remove host-delegation logic (no `is_in_dev_container` / `container_running` branching)
  - Hook runs directly: `bash scripts/verify-pre-push.sh`
  - Acceptance: Hook executes inside container without delegation
  - Depends on: none
  - Blocks: T0.4, T7.1

- [ ] **T0.3** Simplify `scripts/verify-pre-commit.sh`
  - Remove `is_in_dev_container()` function
  - Remove `container_running()` function
  - Remove `run_workspace()` branching
  - Hook now runs directly in container (no delegation)
  - Acceptance: Script simplified, no delegation logic
  - Depends on: T0.1
  - Blocks: T7.1

- [ ] **T0.4** Simplify `scripts/verify-pre-push.sh`
  - Remove `is_in_dev_container()` function
  - Remove `container_running()` function
  - Remove `run_workspace()` branching
  - Hook now runs directly in container (no delegation)
  - Acceptance: Script simplified, no delegation logic
  - Depends on: T0.2
  - Blocks: T7.1

- [ ] **T0.5** Update `AGENTS.md` §2.3 to reflect direct hook execution
  - Document that hooks now run inside the container, not on the host
  - Update pre-commit/pre-push hook documentation
  - Acceptance: Documentation updated
  - Depends on: T0.3, T0.4
  - Blocks: T7.1

- [ ] **T0.6** Create bats tests for direct hook execution model
  - File: `scripts/__tests__/direct-hooks.bats`
  - Mock git, verify hook executes directly (no delegation)
  - Acceptance: Tests pass without real container
  - Depends on: T0.3, T0.4
  - Blocks: T7.1

- [ ] **T0.7** Migrate `openspec init` from `bootstrap.py` to `dev-entrypoint.sh`
  - Add one-time init logic to `dev-entrypoint.sh` (conditional on first run)
  - Deprecate `bootstrap.py` (will be deleted in retirement phase)
  - Acceptance: `openspec init` runs from `dev-entrypoint.sh`
  - Depends on: none
  - Blocks: T8.6

- [ ] **T0.8** Add `openssh-client` to `Dockerfile.dev`
  - Required for SSH agent forwarding
  - Acceptance: `ssh` binary available in container
  - Depends on: none
  - Blocks: T1.2

- [ ] **T0.9** Remove Docker CLI from `Dockerfile.dev`
  - Delete lines 76-106 (Docker CLI apt-repo install)
  - Saves ~90MB
  - Acceptance: Docker CLI not in container, image size reduced
  - Depends on: none
  - Blocks: T1.1

- [ ] **T0.10** Add resource limits to `docker-compose.yml`
  - `deploy.resources.limits`: memory 8g, cpus 4
  - Developer-local override support via `docker-compose.override.yml`
  - Acceptance: Resource limits enforced
  - Depends on: none
  - Blocks: T7.1

- [ ] **T0.11** Mount host `~/.gitconfig` read-only
  - Add volume mount to `docker-compose.yml`: `~/.gitconfig:/home/dev/.gitconfig:ro`
  - Handle case where `~/.gitconfig` does not exist (optional mount)
  - Acceptance: Git identity configured from host
  - Depends on: none
  - Blocks: T7.1

### Slice 1: SSH Agent Forwarding Integration

**Goal:** Integrate SSH agent forwarding from `tools/opencode-docker` into `Dockerfile.dev` and `scripts/opencode-dev` with auto-detect.

**Tasks:**

- [ ] **T1.1** Create `scripts/opencode-dev` shell script (bash-3 compatible)
  - Auto-detect engine via `docker version` (contains "Podman" → podman, else → docker)
  - Auto-detect OS via `/proc/version` (contains "Microsoft"/"WSL" → wsl, else → native)
  - Select engine override (required): `docker-compose.<engine>.yml`
  - If os=wsl, also select OS overlay (optional): `docker-compose.wsl.yml`
  - Default behavior: `docker compose -f docker-compose.yml -f docker-compose.<engine>.yml [-f docker-compose.wsl.yml] up -d dev && docker compose exec dev bash`
  - Acceptance: Script exists, is executable, `--help` shows usage
  - Depends on: T0.9
  - Blocks: T1.2, T1.3, T1.4, T1.5, T2.1, T2.2, T2.3

- [ ] **T1.2** Add auto-detect SSH agent forwarding to `scripts/opencode-dev`
  - Auto-detect SSH agent socket (probe order: `$SSH_AUTH_SOCK` → `${XDG_RUNTIME_DIR}/keyring/ssh` → `${XDG_RUNTIME_DIR}/gcr/ssh`)
  - If found: mount read-only at `/tmp/ssh-agent.sock`, set `SSH_AUTH_SOCK=/tmp/ssh-agent.sock`
  - If not found: print warning, skip SSH forwarding
  - Add `--ssh-agent` flag (force forwarding even if probe fails)
  - Add `--no-ssh-agent` flag (disable forwarding even if probe succeeds)
  - Set `GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/tmp/known_hosts -o IdentityAgent=/tmp/ssh-agent.sock"`
  - Acceptance: Auto-detect works, flags override auto-detect, socket forwarding works on Fedora + WSL
  - Depends on: T0.8, T1.1
  - Blocks: T3.1

- [ ] **T1.3** Update `Dockerfile.dev` for SSH agent compatibility
  - Ensure `/tmp` is writable (for `known_hosts`)
  - No changes to entrypoint (deferred)
  - Acceptance: Container can write to `/tmp/known_hosts`
  - Depends on: T1.1
  - Blocks: T3.1

- [ ] **T1.4** Create mock-based bats tests for SSH agent auto-detect
  - File: `scripts/__tests__/opencode-dev.bats`
  - Mock `docker` command
  - Verify auto-detect probe order
  - Verify correct `docker compose exec` with SSH_AUTH_SOCK env
  - Verify socket mount syntax
  - Verify `--ssh-agent` and `--no-ssh-agent` flags
  - Acceptance: Tests pass without real container
  - Depends on: T1.2
  - Blocks: T3.1

- [ ] **T1.5** Document SSH agent forwarding in `docs/docker-dev.md`
  - Explain auto-detect mechanism
  - Document probe order
  - Document `--ssh-agent` and `--no-ssh-agent` flags
  - Acceptance: Documentation exists, explains mechanism
  - Depends on: T1.2
  - Blocks: T3.1

### Slice 2: Engine-Specific UID/GID Mapping

**Goal:** Create engine-specific compose overrides for UID/GID mapping (res040 §1-4).

**Tasks:**

- [ ] **T2.1** Create `docker-compose.podman.yml`
  - `userns_mode: keep-id` for Podman UID/GID mapping (res040 §2)
  - `security_opt: [label=disable]` for SELinux connectto denial (Fedora)
  - No duplication of volumes, ports, environment, secrets
  - Acceptance: `docker compose -f docker-compose.yml -f docker-compose.podman.yml config` validates
  - Depends on: T1.1
  - Blocks: T3.2, T6.1

- [ ] **T2.2** Create `docker-compose.rootless-docker.yml`
  - `user: "0:0"` for rootless Docker UID/GID mapping (res040 §1, §4)
  - Container UID 0 maps to host user; bind mounts/secrets writable/readable
  - No duplication of volumes, ports, environment, secrets
  - Acceptance: `docker compose -f docker-compose.yml -f docker-compose.rootless-docker.yml config` validates
  - Depends on: T1.1
  - Blocks: T3.2, T6.1

- [ ] **T2.3** Create `docker-compose.wsl.yml` (WSL-only overlay)
  - Minimal WSL-specific overrides (memory limits if needed, commented out by default)
  - Applied on top of engine override, not as a replacement
  - No duplication of volumes, ports, environment, secrets
  - Acceptance: `docker compose -f docker-compose.yml -f docker-compose.<engine>.yml -f docker-compose.wsl.yml config` validates
  - Depends on: T1.1
  - Blocks: T3.2

- [ ] **T2.4** Add `--engine` and `--os` flags to `scripts/opencode-dev`
  - `--engine=podman|docker` overrides auto-detected engine
  - `--os=wsl|native` overrides auto-detected OS
  - Acceptance: Flags override auto-detection
  - Depends on: T1.1
  - Blocks: T3.2

- [ ] **T2.5** Create mock-based bats tests for engine+OS detection
  - File: `scripts/__tests__/opencode-dev.bats` (extend)
  - Mock `docker version` output (with/without "Podman")
  - Mock `/proc/version` content (with/without "Microsoft"/"WSL")
  - Verify Podman detection → `docker-compose.podman.yml`
  - Verify Docker detection → `docker-compose.rootless-docker.yml`
  - Verify WSL detection → adds `docker-compose.wsl.yml`
  - Verify `--engine` and `--os` overrides
  - Acceptance: Tests pass without real engine/OS
  - Depends on: T2.4
  - Blocks: T3.2

- [ ] **T2.6** Document engine+OS detection in `docs/docker-dev.md`
  - Explain engine auto-detection mechanism
  - Explain OS auto-detection mechanism
  - Document `--engine` and `--os` overrides
  - Cite res040 for UID/GID mapping rationale
  - Acceptance: Documentation exists, explains mechanism
  - Depends on: T2.4
  - Blocks: T3.2

### Slice 3: Chromium Shared Memory

**Goal:** Configure Chromium `--shm-size=1g` for Playwright.

**Tasks:**

- [ ] **T3.1** Add `--shm-size=1g` to `scripts/opencode-dev`
  - Apply to `docker compose up -d dev` command
  - Acceptance: Container starts with 1GB shared memory
  - Depends on: T1.2, T1.3, T1.4, T1.5
  - Blocks: T4.1

- [ ] **T3.2** Verify `--shm-size=1g` works with engine overrides
  - Test with `docker-compose.podman.yml`
  - Test with `docker-compose.rootless-docker.yml`
  - Test with WSL overlay (`docker-compose.wsl.yml`) on top of each engine
  - Acceptance: Chromium launches without shared-memory errors on all combinations
  - Depends on: T2.1, T2.2, T2.3, T2.5, T2.6
  - Blocks: T4.1

- [ ] **T3.3** Document Chromium shm configuration in `docs/docker-dev.md`
  - Explain `--shm-size=1g` requirement
  - Acceptance: Documentation exists
  - Depends on: T3.1
  - Blocks: T4.1

### Slice 4: Command Modes

**Goal:** Add `--run-opencode` and `--test` flags.

**Tasks:**

- [ ] **T4.1** Add `--run-opencode` flag to `scripts/opencode-dev`
  - Launch `opencode` instead of `bash`
  - Command: `docker compose exec dev opencode`
  - Acceptance: Flag launches opencode
  - Depends on: T3.1, T3.2, T3.3
  - Blocks: T5.1

- [ ] **T4.2** Add `--test` flag to `scripts/opencode-dev`
  - Run `make test-infra` in container
  - Command: `docker compose exec dev make test-infra`
  - Acceptance: Flag runs test suite
  - Depends on: T3.1, T3.2, T3.3
  - Blocks: T5.1

- [ ] **T4.3** Create mock-based bats tests for command modes
  - File: `scripts/__tests__/opencode-dev.bats` (extend)
  - Verify `--run-opencode` launches opencode
  - Verify `--test` runs make test-infra
  - Verify container already running skips `up`
  - Acceptance: Tests pass without real container
  - Depends on: T4.1, T4.2
  - Blocks: T5.1

- [ ] **T4.4** Document command modes in `docs/docker-dev.md`
  - Explain `--run-opencode` flag
  - Explain `--test` flag
  - Acceptance: Documentation exists
  - Depends on: T4.1, T4.2
  - Blocks: T5.1

### Slice 5: PATH Exposure and Documentation

**Goal:** Expose `opencode-dev` via PATH and update documentation.

**Tasks:**

- [ ] **T5.1** Add PATH exposure in `dev-entrypoint.sh`
  - Ensure `scripts/` is in PATH or symlink `opencode-dev` to `/usr/local/bin/`
  - Acceptance: `opencode-dev` command available in container
  - Depends on: T4.1, T4.2, T4.3, T4.4
  - Blocks: T6.1

- [ ] **T5.2** Update `AGENTS.md` §6 "Project Ops Quick Reference"
  - Add `opencode-dev` as recommended launch method
  - Preserve `make opencode` and `docker compose exec dev bash` as compatible alternatives
  - Acceptance: Documentation updated
  - Depends on: T5.1
  - Blocks: T6.1

- [ ] **T5.3** Update `docs/docker-dev.md` with unified command
  - Replace `make opencode` references with `opencode-dev`
  - Preserve old commands as compatible alternatives
  - Acceptance: Documentation updated
  - Depends on: T5.1
  - Blocks: T6.1

### Slice 6: Contract Test and UID/GID Mapping Test

**Goal:** Create contract test verifying identical `opencode --version` and UID/GID mapping tests verifying res040 contract.

**Tasks:**

- [ ] **T6.1** Create `scripts/__tests__/unified-container-contract.bats`
  - Run `docker compose -f docker-compose.yml -f docker-compose.podman.yml exec dev opencode --version`
  - Run `docker compose -f docker-compose.yml -f docker-compose.rootless-docker.yml exec dev opencode --version`
  - Assert identical output (same version string)
  - Requires real containers running (not mock-based)
  - Acceptance: Test passes with both engine overrides, identical versions
  - Depends on: T5.1, T5.2, T5.3, T2.1, T2.2
  - Blocks: T7.1

- [ ] **T6.2** Create `scripts/__tests__/engine-override-uid.bats`
  - Podman override: verify bind-mounted file shows host UID inside container (res040 §2)
  - Rootless-Docker override: verify bind-mounted file shows root inside container (res040 §1)
  - Both strategies: verify container process can write to host-owned bind mounts
  - Both strategies: verify container process can read host-owned secrets
  - Requires real containers running (not mock-based)
  - Acceptance: Tests pass, UID mapping contract verified per res040
  - Depends on: T2.1, T2.2
  - Blocks: T7.1

- [ ] **T6.3** Add contract and UID tests to `make test-infra`
  - Update Makefile to include `unified-container-contract.bats` and `engine-override-uid.bats`
  - Acceptance: `make test-infra` runs both test files
  - Depends on: T6.1, T6.2
  - Blocks: T7.1

### Slice 7: Secrets Ownership Preflight and Keep-ID Recreation Verification

**Goal:** Implement preflight refusal for unsafe `secrets/` ownership/mode and verify keep-id recreation creates secret mountpoints, git index write succeeds, and API secret is readable only by intended dev process.

**Tasks:**

- [ ] **T7.0a** Create `scripts/check-secrets-ownership.sh`
  - Check `secrets/` owned by host rootless-Podman user (UID that `keep-id` maps)
  - Check each secret file is mode `0600`
  - Check no group/other read bits
  - If any check fails: print specific remediation (e.g., `chown <uid>:<gid> secrets/<file>`, `chmod 0600 secrets/<file>`) and exit non-zero
  - MUST NOT use `chown -R` or `chmod -R` — only explicit per-file operations
  - MUST NOT attempt automatic remediation — only print diagnostics and exit
  - Acceptance: Script exists, is executable, exits 0 on safe ownership/mode, exits 1 with diagnostics on unsafe
  - Depends on: T1.1
  - Blocks: T7.0b, T7.1

- [ ] **T7.0b** Integrate preflight into `scripts/opencode-dev`
  - Call `scripts/check-secrets-ownership.sh` before `docker compose up -d dev`
  - If preflight fails: print diagnostics and exit non-zero (do not start container)
  - Acceptance: `opencode-dev` refuses to start if `secrets/` ownership/mode is unsafe
  - Depends on: T7.0a
  - Blocks: T7.1

- [ ] **T7.0c** Create mock-based bats tests for preflight
  - File: `scripts/__tests__/check-secrets-ownership.bats`
  - Mock `stat` and `id` commands
  - Verify preflight passes when `secrets/` owned by host rootless-Podman user and all files mode `0600`
  - Verify preflight fails with actionable diagnostics when `secrets/` owned by wrong user
  - Verify preflight fails with actionable diagnostics when any secret file is not mode `0600`
  - Verify preflight fails with actionable diagnostics when any secret file has group/other read bits
  - Verify preflight script never uses `chown -R` or `chmod -R`
  - Acceptance: Tests pass without real container
  - Depends on: T7.0a
  - Blocks: T7.1

- [ ] **T7.0d** Create `scripts/__tests__/keep-id-recreation-verify.bats`
  - After Podman `keep-id` container start: verify secret mountpoints exist inside container
  - After Podman `keep-id` container start: verify git index write succeeds (container can write to `.git/`)
  - After Podman `keep-id` container start: verify API secret is readable only by intended dev process (verify mode/owner inside container)
  - Requires real Podman container running (not mock-based)
  - Acceptance: Tests pass with Podman engine
  - Depends on: T2.1
  - Blocks: T7.1

- [ ] **T7.0e** Add preflight and keep-id recreation tests to `make test-infra`
  - Update Makefile to include `check-secrets-ownership.bats` and `keep-id-recreation-verify.bats`
  - Acceptance: `make test-infra` runs both test files
  - Depends on: T7.0c, T7.0d
  - Blocks: T7.1

- [ ] **T7.0f** Document secrets ownership preflight in `docs/docker-dev.md`
  - Explain preflight refusal mechanism
  - Document ownership/mode requirements
  - Document remediation commands
  - Document avoid-chown-recursive safeguard
  - Acceptance: Documentation exists, explains mechanism
  - Depends on: T7.0b
  - Blocks: T7.1

### Slice 8: Acceptance Verification

**Goal:** Verify all acceptance criteria on both platforms.

**Tasks:**

- [ ] **T7.1** Run all existing gates on Fedora rootless Podman
  - `make test-infra`
  - `make test-config`
  - `make test-shell`
  - Pre-commit hook delegation
  - Pre-push hook delegation
  - Acceptance: All gates pass
  - Depends on: T6.1, T6.2
  - Blocks: T7.2

- [ ] **T7.2** Run all existing gates on WSL rootless Podman
  - `make test-infra`
  - `make test-config`
  - `make test-shell`
  - Pre-commit hook delegation
  - Pre-push hook delegation
  - Acceptance: All gates pass
  - Depends on: T7.1
  - Blocks: T7.3

- [ ] **T7.3** Verify SSH push on Fedora
  - Configure SSH agent on Fedora host
  - Run `opencode-dev --ssh-agent`
  - Execute `git push` to SSH remote from container
  - Acceptance: Push succeeds
  - Depends on: T7.1
  - Blocks: T7.4

- [ ] **T7.4** Verify SSH push on WSL
  - Configure SSH agent on WSL host
  - Run `opencode-dev --ssh-agent`
  - Execute `git push` to SSH remote from container
  - Acceptance: Push succeeds
  - Depends on: T7.2
  - Blocks: T7.5

- [ ] **T7.5** Verify Chromium on Fedora
  - Run `opencode-dev` on Fedora
  - Launch Playwright chromium
  - Acceptance: Chromium launches without shared-memory errors
  - Depends on: T7.1
  - Blocks: T7.6

- [ ] **T7.6** Verify Chromium on WSL
  - Run `opencode-dev` on WSL
  - Launch Playwright chromium
  - Acceptance: Chromium launches without shared-memory errors
  - Depends on: T7.2
  - Blocks: T7.7

- [ ] **T7.7** Verify `opencode --version` identical on both platforms
  - Run `opencode-dev --run-opencode` on Fedora
  - Run `opencode-dev --run-opencode` on WSL
  - Compare `opencode --version` output
  - Acceptance: Identical version strings
  - Depends on: T7.5, T7.6
  - Blocks: T8.1

### Slice 9: Retirement Preparation

**Goal:** Prepare for legacy launcher retirement after 3-day threshold.

**Related Tickets:**

- **DIA-260824-ifcf**: Persistent developer Git identity and config propagation for unified poetry-dev workstation (blocked by DIA-260821-m7vk)
- **DIA-260824-8k62**: Retire legacy tools/opencode-docker only after unified-runtime acceptance (blocked by all prerequisites)

**Tasks:**

- [ ] **T8.1** Collect acceptance evidence
  - Gate results from T7.1, T7.2
  - SSH push results from T7.3, T7.4
  - Chromium results from T7.5, T7.6
  - Version comparison from T7.7
  - Acceptance: Evidence collected and attached to ticket
  - Depends on: T7.7
  - Blocks: T8.2

- [ ] **T8.2** Start 3-day retirement countdown
  - Document start date
  - Both developers use unified container exclusively
  - Track any issues
  - Acceptance: 3 consecutive successful days
  - Depends on: T8.1
  - Blocks: T8.3

- [ ] **T8.3** Reviewer audit
  - Dispatch `@reviewer` for two-axis review (Standards + Spec fidelity)
  - Review unified container implementation
  - Acceptance: Reviewer approves
  - Depends on: T8.2
  - Blocks: T8.4

- [ ] **T8.4** ai-auditor audit
  - Dispatch `@ai-auditor` for config audit
  - Review compose overrides, command interface, documentation
  - Acceptance: ai-auditor approves
  - Depends on: T8.3
  - Blocks: T8.5

- [ ] **T8.5** Explicit developer confirmations
  - Fedora developer confirms unified container works
  - WSL developer confirms unified container works
  - Both confirm no issues during 3-day period
  - Acceptance: Both confirmations recorded
  - Depends on: T8.4
  - Blocks: T8.6

- [ ] **T8.6** Retire `tools/opencode-docker/` (DIA-260824-8k62)
  - Physical deletion of `tools/opencode-docker/` directory
  - Delete `bootstrap.py` (superseded by `dev-entrypoint.sh`)
  - Update documentation to remove legacy references
  - Acceptance: Legacy launcher removed
  - Depends on: T0.7, T8.5
  - Blocks: none

## Blocking Edges Summary

```
T0.1 → T0.3, T7.1
T0.2 → T0.4, T7.1
T0.3 → T0.5, T0.6, T7.1
T0.4 → T0.5, T0.6, T7.1
T0.5 → T7.1
T0.6 → T7.1
T0.7 → T8.6
T0.8 → T1.2
T0.9 → T1.1
T0.10 → T7.1
T0.11 → T7.1
T1.1 → T1.2, T1.3, T1.4, T1.5, T2.1, T2.2, T2.3, T7.0a
T1.2 → T1.4, T1.5, T3.1
T1.3 → T3.1
T1.4 → T3.1
T1.5 → T3.1
T2.1 → T3.2, T6.1, T6.2, T7.0d
T2.2 → T3.2, T6.1, T6.2
T2.3 → T3.2
T2.4 → T2.5, T2.6
T2.5 → T3.2
T2.6 → T3.2
T3.1 → T3.3, T4.1, T4.2
T3.2 → T4.1, T4.2
T3.3 → T4.1, T4.2
T4.1 → T4.3, T4.4, T5.1
T4.2 → T4.3, T4.4, T5.1
T4.3 → T5.1
T4.4 → T5.1
T5.1 → T5.2, T5.3, T6.1
T5.2 → T6.1
T5.3 → T6.1
T6.1 → T6.3, T7.1
T6.2 → T6.3
T6.3 → T7.1
T7.0a → T7.0b, T7.0c
T7.0b → T7.0f, T7.1
T7.0c → T7.0e
T7.0d → T7.0e
T7.0e → T7.1
T7.0f → T7.1
T7.1 → T7.2, T7.3, T7.5
T7.2 → T7.4, T7.6
T7.3 → T7.4
T7.4 → T7.5
T7.5 → T7.7
T7.6 → T7.7
T7.7 → T8.1
T8.1 → T8.2
T8.2 → T8.3
T8.3 → T8.4
T8.4 → T8.5
T8.5 → T8.6
```

## Critical Path

T0.9 → T1.1 → T1.2 → T1.4 → T3.1 → T4.1 → T4.3 → T5.1 → T6.1 → T6.3 → T0.1 → T0.3 → T0.5 → T7.1 → T7.2 → T7.4 → T7.6 → T7.7 → T8.1 → T8.2 → T8.3 → T8.4 → T8.5 → T0.7 → T8.6

## Parallel Opportunities

- T0.1, T0.2, T0.7, T0.8, T0.9, T0.10, T0.11 can run in parallel (Slice 0 foundation)
- T1.2, T1.3, T1.5 can run in parallel after T1.1
- T2.1, T2.2, T2.3 can run in parallel after T1.1
- T2.4, T2.5, T2.6 can run in parallel after T1.1
- T4.1, T4.2 can run in parallel after T3.1, T3.2, T3.3
- T6.1, T6.2 can run in parallel after T5.1, T5.2, T5.3, T2.1, T2.2
- T7.0a, T7.0d can run in parallel after T1.1, T2.1
- T7.0b, T7.0c can run in parallel after T7.0a
- T7.0e can run after T7.0c, T7.0d
- T7.3, T7.5 can run in parallel after T7.1
- T7.4, T7.6 can run in parallel after T7.2

## Implementation-Ready Ordered Slices

**Priority Order:**

1. **Slice 0 (P0)**: Hook execution model inversion — architectural core
2. **Slice 1 (P1)**: SSH agent forwarding — enables git push
3. **Slice 2 (P2)**: Engine-specific UID/GID mapping — enables Fedora + WSL
4. **Slice 3 (P3)**: Chromium shared memory — enables browser automation
5. **Slice 5 (P4)**: PATH exposure + docs — makes `opencode-dev` discoverable
6. **Slice 4 (P5)**: Command modes — convenience features
7. **Slice 6 (P6)**: Contract tests — validates unification
8. **Slice 7 (P7)**: Preflight + keep-id verify — security hardening
9. **Slice 8 (P8)**: Acceptance verification — final validation
10. **Slice 9 (P9)**: Retirement — cleanup
