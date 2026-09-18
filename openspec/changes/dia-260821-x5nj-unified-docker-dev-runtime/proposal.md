# Proposal: Unified Docker Development Runtime for Fedora and WSL

## Problem Statement

Two developers (Fedora Linux host and WSL host) require the same development runtime, but the project currently ships divergent Dockerfiles with version drift:

- `Dockerfile.dev` (root): OpenCode 1.18.18, 352 lines, full dev workstation with Rust toolchain, language servers, OMO plugin cache
- `tools/opencode-docker/Dockerfile`: OpenCode 1.18.4, 226 lines, lighter wrapper focused on SSH agent forwarding

This causes irreproducible behavior between entry points and violates the user constraint that both developers get the same dev runtime.

## User Constraint

Both developers (Fedora Linux and WSL) must have the same development runtime. Only small engine-specific and OS-specific settings may differ.

## Chosen Direction (Option A — Engine-Specific Overrides)

**ONE unified image (`Dockerfile.dev`) + ONE base compose (`docker-compose.yml`) + engine-specific compose overrides + optional OS-specific compose overrides + unified launch command (`opencode-dev`)**

Decision `engine-specific-overrides-selected` logged for DIA-260821-x5nj.

### Interview Decisions (DIA-260824-iirx)

The following architectural decisions were confirmed through mandatory grilling:

1. **`unified-runtime-option-A-selected`**: Direct in-container Git hooks (not host delegation). Hooks execute inside poetry-dev, eliminating the split-brain architecture.
2. **`unified-entrypoint-dev-entrypoint-sh-selected`**: `dev-entrypoint.sh` as sole entrypoint. Migrate `openspec init` from `bootstrap.py`, retire `bootstrap.py` in legacy removal phase.
3. **`unified-runtime-no-engine-socket-selected`**: NO Docker/Podman socket mounted. Infrastructure orchestration remains host-side explicit mode.
4. **`unified-runtime-serve-mode-enabled`**: YES serve mode integration. `--serve` flag for remote access (Tailscale/Android).
5. **`unified-runtime-resource-limits-selected`**: 8g memory, 4 CPUs (with developer-local override support).
6. **`unified-runtime-gitconfig-readonly-mount-selected`**: Mount host `~/.gitconfig` read-only for git identity.
7. **`unified-runtime-auto-ssh-agent-selected`**: Auto-detect SSH agent with graceful degradation. Warning if absent, explicit `--ssh-agent` / `--no-ssh-agent` overrides.
8. **`unified-runtime-remove-docker-cli-selected`**: Remove Docker CLI and Compose plugin from socketless poetry-dev (~90MB savings).
9. **`unified-runtime-project-husky-selected`**: Husky as project devDependency, provision via `pnpm exec` after dependency installation.
10. **`unified-runtime-split-config-gate-selected`**: Static config checks run in poetry-dev, Compose engine resolution is explicit host-side or CI gate.
11. **`unified-runtime-three-day-retirement-selected`**: Retire `tools/opencode-docker` after 3 consecutive successful poetry-dev days plus required reviews and confirmations.
12. **`unified-runtime-five-hardening-acceptance-items-approved`**: Secrets least privilege, real rootless Docker UID acceptance, clean-HOME preset/auth pin verification, SSH-agent safety, migration rollback compatibility.

## Secure Secrets Ownership Prerequisite (Option A)

Decision `secure-secrets-ownership-option-a-selected` logged for DIA-260821-x5nj.

Before applying Podman `keep-id`, the host must satisfy a minimal permission prerequisite for `secrets/`:

- `secrets/` directory and each secret file MUST be owned by the host rootless-Podman user (the UID that `keep-id` maps into the container)
- Each secret file MUST remain mode `0600` (owner read/write only)
- No broad read permission (no group/other read bits)
- `secrets/` MUST NOT be tracked by Git (already in `.gitignore`)
- Current SSH-agent separation MUST be preserved (SSH socket forwarding is orthogonal to secret ownership)

### Preflight Refusal

The launch command MUST refuse to start the container if ownership or mode is unsafe, with actionable diagnostics:

- Check `secrets/` ownership matches host rootless-Podman user
- Check each secret file is mode `0600`
- Check no group/other read bits
- If any check fails: print specific remediation (e.g., `chown <uid>:<gid> secrets/<file>`, `chmod 0600 secrets/<file>`) and exit non-zero

### Verification

After keep-id recreation, verify:

1. Secret mountpoints are created successfully inside the container
2. Git index write succeeds (container can write to `.git/` bind mount)
3. API secret is readable only by the intended dev process (no broad read)

### Rollback / Avoid-chown-Recursive Safeguards

- Preflight script MUST NOT use `chown -R` or `chmod -R` on `secrets/` — only explicit per-file operations
- If preflight fails, the script MUST NOT attempt automatic remediation — only print diagnostics and exit
- Rollback: revert ownership/mode changes manually; no automated chown rollback

### Rationale

- Eliminates version drift immediately by unifying on `Dockerfile.dev`
- Engine-specific overrides address the root cause of UID/GID mapping differences between Podman and rootless Docker (res040): Podman uses `keep-id`, rootless Docker uses `user: "0:0"` to map container UID 0 to the host user
- WSL-specific settings (if any) are orthogonal to engine and applied as a separate overlay
- Single `Dockerfile.dev` and single base `docker-compose.yml` remain the source of truth
- `opencode-dev` detects engine (podman vs docker) and OS (WSL vs native), selects matching overrides
- Trivial rollback: revert to separate Dockerfiles

### Alternatives Considered

1. **OS-only overrides (previous design)**: `docker-compose.fedora.yml` and `docker-compose.wsl.yml`. Rejected because it conflates OS with engine — a WSL host can run either Podman or Docker, and the UID mapping strategy is engine-specific, not OS-specific (res040 §1-3).

2. **Runtime detection (no per-host files)**: Entrypoint detects engine at runtime. Rejected as unnecessary complexity — compose overrides are the standard Docker pattern and more debuggable.

3. **Status quo (keep separate Dockerfiles)**: Rejected because version drift already exists (1.18.18 vs 1.18.4) and causes irreproducible behavior.

## Scope

### First-Release Integration

Integrate from `tools/opencode-docker` into `Dockerfile.dev`:

- **Direct in-container Git hooks**: hooks execute inside poetry-dev (no host delegation)
- **SSH agent forwarding**: auto-detect host SSH agent, mount read-only, graceful degradation
- **Engine-specific UID/GID mapping** via compose overrides:
  - Podman override: `userns_mode: keep-id` + `security_opt: [label=disable]` (SELinux)
  - Rootless-Docker override: `user: "0:0"` (container UID 0 maps to host user per res040 §1)
- **Chromium `--shm-size=1g`** for shared memory
- **Serve mode**: `--serve` flag for remote access (Tailscale/Android)
- **Resource limits**: 8g memory, 4 CPUs (with developer-local override)
- **Git identity**: mount host `~/.gitconfig` read-only
- **Entrypoint unification**: `dev-entrypoint.sh` as sole entrypoint, migrate `openspec init` from `bootstrap.py`
- **Static config validation**: run inside container (prettier, eslint, typecheck, JSONC validation)
- **Docker CLI removal**: remove `docker-ce-cli` + `docker-compose-plugin` (~90MB savings)
- **NO engine socket**: infrastructure orchestration remains host-side explicit mode
- Optional WSL-only overlay (applied on top of engine override when WSL detected)

### Deferred to Future Iterations

- `--read-only --tmpfs /tmp:exec` (Dockerfile.dev explicitly not read-only by design)
- Static Docker CLI bundles (apt-repo install works with fallback)
- Multi-stage build optimization (`collect-runtime-deps.sh`)

## Acceptance Criteria

1. All existing gates pass on both platforms (Fedora + WSL, each with their selected engine):
   - `make test-infra` (host-side)
   - `make test-config` (host-side or CI)
   - `make test-shell`
   - Pre-commit/pre-push hooks execute directly inside container (no delegation)
2. SSH agent forwarding works for `git push` on both platforms (auto-detect)
3. Chromium launches without shared-memory errors on both platforms
4. `opencode --version` identical for both engine overrides
5. Engine detection correctly selects Podman or rootless-Docker override
6. WSL detection applies WSL overlay on top of selected engine override
7. Bind mounts and secrets are writable/readable under both engine strategies (res040 §1-4)
8. Preflight refusal: `opencode-dev` refuses to start if `secrets/` ownership or mode is unsafe, with actionable diagnostics
9. Keep-id recreation verification: secret mountpoints created, git index write succeeds, API secret readable only by intended dev process
10. Avoid-chown-recursive safeguard: preflight script never uses `chown -R` or `chmod -R` on `secrets/`
11. Resource limits enforced: 8g memory, 4 CPUs (with developer-local override)
12. Git identity configured: host `~/.gitconfig` mounted read-only
13. Serve mode works: `--serve` flag enables remote access (Tailscale/Android)
14. Docker CLI removed from container (~90MB savings)
15. NO engine socket mounted (minimal attack surface)

## Retirement Threshold

Retain `tools/opencode-docker/` unchanged for:

- 3 consecutive successful days for both developers
- Plus reviewer audit
- Plus ai-auditor audit
- Plus explicit confirmations from both developers

Immediate rollback available if unified container shows problems.

## Rollback Plan

1. Preserve `tools/opencode-docker/` unchanged throughout the process
2. Use its existing command directly for rollback
3. Rollback unified changes via `git revert` + remove new engine-specific compose override files (`docker-compose.podman.yml`, `docker-compose.rootless-docker.yml`, `docker-compose.wsl.yml`)
4. Physical deletion of `tools/opencode-docker/` only after retirement threshold met

## Test Strategy

### Mock-Based Unit Tests

`scripts/__tests__/opencode-dev.bats` — verify command behavior without launching containers:

- Default behavior (no flags): `docker compose up -d dev && docker compose exec dev bash`
- Auto-detect SSH agent: probe order (`$SSH_AUTH_SOCK` → `${XDG_RUNTIME_DIR}/keyring/ssh` → `${XDG_RUNTIME_DIR}/gcr/ssh`), mount read-only if found, warning if not
- `--ssh-agent` forces SSH forwarding (override auto-detect)
- `--no-ssh-agent` disables SSH forwarding (override auto-detect)
- `--run-opencode` launches `opencode` instead of `bash`
- `--test` runs `make test-infra` (host-side)
- `--serve` launches in serve mode (remote access)
- If container already running, skip `up` and execute `exec`
- Engine detection: mock `docker version` output containing "Podman" vs not
- OS detection: mock `/proc/version` containing "Microsoft"/"WSL" vs not
- Correct override file selection per engine+OS combination

### Contract Test

`scripts/__tests__/unified-container-contract.bats` — verify identical `opencode --version` for both engine overrides:

- Run `docker compose exec dev opencode --version` for `docker-compose.podman.yml`
- Run `docker compose exec dev opencode --version` for `docker-compose.rootless-docker.yml`
- Assert identical output (same version string)
- Added to `make test-infra` as part of acceptance gate

### UID/GID Mapping Tests

`scripts/__tests__/engine-override-uid.bats` — verify bind mount ownership under each engine strategy:

- Podman override: bind-mounted file shows host UID inside container (keep-id semantics, res040 §2)
- Rootless-Docker override: bind-mounted file shows root inside container (UID 0 maps to host user, res040 §1)
- Both strategies: container process can write to host-owned bind mounts

### Real Acceptance Verification

On started containers (Fedora + WSL, each with their selected engine), prove:

- `opencode --version` is identical
- Bind mounts are writable
- Secrets are readable
- Mock tests do NOT prove runtime versions or UID mapping behavior

## Implementation Approach

- `scripts/opencode-dev` shell script (bash-3 compatible, per ADR 8)
- PATH exposure via `dev-entrypoint.sh`
- Engine detection: `docker version` output (contains "Podman" → podman, else → docker)
- OS detection: `/proc/version` (contains "Microsoft" or "WSL" → wsl)
- Override selection: engine override required, OS override optional (applied on top if WSL)
- Optional `--engine=podman|docker` and `--os=wsl|native` overrides for manual selection
- Documentation updates: `docs/docker-dev.md`, `AGENTS.md` §6
- Preserve `make opencode` and `docker compose exec dev bash` as compatible alternatives
- Evidence base: `knowledge/res040-docker-rootless-uid-compatibility/res040-docker-rootless-uid-compatibility-conspect.md`

## Deliverables

This ticket delivers:

- OpenSpec artifacts (proposal, design, tasks, specs)
- Decision record with evidence-backed comparison
- Compatibility evidence for Fedora + WSL
- Rollback plan
- Contract-test specification

This ticket does NOT deliver:

- Dockerfile modifications
- Compose file modifications
- Implementation code
- Container changes

Implementation follows in a separate ticket.
