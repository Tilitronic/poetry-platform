## Why

The `opencode-docker` launcher mounts the host container engine socket into the container unconditionally, with no explicit documentation of the security model or migration path from system Docker to rootless Podman. System Docker socket access grants full API authority over all containers in the system (not just the user's), while rootless Podman limits authority to the user's own containers. The launcher currently falls back silently from rootless Podman to system Docker when Podman socket operations fail, masking configuration errors and preventing users from diagnosing Podman issues. This change documents the security model, enforces explicit fallback policy (Podman failure = fail with diagnostics, not silent fallback), and establishes readiness criteria for eventual system Docker fallback removal.

## What Changes

- **Launcher behavior** (`tools/opencode-docker/bin/opencode-docker`):
  - Retain current probe order: rootless Podman first (XDG_RUNTIME_DIR, /run/user/UID), then system Docker fallback (/var/run/docker.sock)
  - When rootless Podman socket is detected but engine operations fail: fail with actionable Podman diagnostics (e.g., "Check podman socket status: systemctl --user status podman.socket"), do NOT silently fall back to system Docker
  - System Docker fallback remains active only when no rootless Podman socket is detected
  - No `--with-engine` flag (rejected: in-container git commit/push and mandatory hooks must work without restart or special flags)

- **Documentation** (`tools/opencode-docker/README.md`, `tools/opencode-docker/AGENTS.md`):
  - Add "Container Engine Socket Access" section: rootless Podman preferred, system Docker deprecated, socket authority model (`:ro` does not restrict API operations, only prevents socket file replacement)
  - Add "Migration Guide" section: instructions for Fedora and WSL (install rootless Podman, verify socket, SELinux workaround)
  - Add "Error Messages" section: explain warning/error messages for each socket state

- **Tests** (`scripts/__tests__/opencode-docker.bats` or existing test file):
  - Launcher finds rootless Podman socket when present
  - Launcher does NOT fall back to system Docker when Podman socket is detected but fails
  - Launcher falls back to system Docker only when no Podman socket is detected
  - Launcher emits warning when using system Docker fallback

- **Platform verification** (Fedora + WSL):
  - `docker compose ps` works via Podman socket
  - `git commit`, `git push` trigger hooks that delegate to poetry-dev via `docker compose exec dev`
  - `make test-infra` passes (exit 0)

- **Follow-up ticket** (separate, after 7 consecutive successful days):
  - Remove system Docker fallback after readiness criteria met on both platforms
  - Readiness: 7 consecutive days with no unresolved socket bugs, all platform verification passing

## Capabilities

### New Capabilities

- `container-engine-socket-selection`: Socket probe order, fallback policy, error handling, and documentation for the opencode-docker launcher's container engine socket selection logic.

### Modified Capabilities

(None - no existing specs modified)

## Impact

- **Code**: `tools/opencode-docker/bin/opencode-docker` (launcher script, ~10 lines changed for error handling)
- **Documentation**: `tools/opencode-docker/README.md`, `tools/opencode-docker/AGENTS.md` (new sections)
- **Tests**: `scripts/__tests__/opencode-docker.bats` or existing test file (new test cases)
- **Dependencies**: None (no new dependencies)
- **Systems**: opencode-docker launcher, in-container git operations (commit/push), pre-commit/pre-push hooks

## Alternatives considered

- **Default-off `--with-engine` flag**: Require explicit opt-in for socket mounting - rejected because in-container git commit/push and mandatory hooks must work without restart or special flags (developer requirement, interview Q3-Q4)
- **Remove system Docker fallback immediately**: Break users who have not migrated to rootless Podman - rejected because migration requires time and documentation (interview Q5-Q6)
- **Telemetry/dashboard for migration tracking**: Track usage percentage to determine deprecation trigger - rejected because no telemetry infrastructure exists and arbitrary thresholds are not evidence-based (interview Q9-Q10)
- **Host-side git operations**: Run git commit/push on host, not inside container - rejected because developer requires in-container git operations (interview Q4)
- **Status quo (silent fallback)**: Continue silent fallback from Podman to system Docker - rejected because it masks Podman configuration errors and prevents users from diagnosing issues (interview Q8)

Chosen option: Retain system Docker fallback during migration with explicit error handling (Podman failure = fail with diagnostics, not silent fallback) - because it preserves in-container git operations while enabling migration to rootless Podman with clear error messages and documented readiness criteria for eventual fallback removal.

## Testing Decisions

**What makes a good test for this change:**

- Tests must verify socket selection logic (probe order, fallback policy, error handling)
- Tests must be host-runnable (no Docker daemon required) using mocked sockets
- Tests must cover all three socket states: Podman found, Podman not found + Docker found, neither found
- Tests must verify error messages are actionable (contain diagnostics)

**Modules to test:**

- `tools/opencode-docker/bin/opencode-docker` (launcher script)
- Socket probe logic (lines 150-164)
- Error handling for Podman socket failure

**Prior art in the codebase:**

- `scripts/__tests__/verify-pre-commit.bats` (mocked Docker, host-runnable)
- `scripts/__tests__/verify-pre-push.bats` (mocked Docker, host-runnable)
- `scripts/__tests__/opencode-docker.bats` (if exists, follow same pattern)

**Test strategy:**

- Use bats unit tests with mocked sockets (create fake socket files in temp directory)
- Verify launcher behavior for each socket state
- Verify error messages contain actionable diagnostics
- Wire into `make test-shell` (existing test infrastructure)

## Rollback Plan

**If issues arise after merge:**

1. Revert the commit that adds explicit error handling (Podman failure = fail with diagnostics)
2. System Docker fallback returns to silent behavior
3. No breaking changes (launcher still works, just less strict error handling)

**Follow-up ticket rollback:**

- If system Docker fallback removal causes issues, revert the follow-up commit
- System Docker fallback returns
- No data loss (launcher behavior only, no persistent state)
