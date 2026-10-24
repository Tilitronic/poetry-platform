## Context

See proposal.md for motivation. The opencode-docker launcher (`tools/opencode-docker/bin/opencode-docker`) currently mounts the host container engine socket into the container unconditionally. The launcher probes for sockets in order: rootless Podman (XDG_RUNTIME_DIR, /run/user/UID), then system Docker (/var/run/docker.sock). When a socket is found, it is mounted read-only (`:ro`) into the container at `/var/run/docker.sock`, and `DOCKER_HOST` is set.

Current behavior: if rootless Podman socket is detected but engine operations fail, the launcher silently falls back to system Docker (if found). This masks Podman configuration errors and prevents users from diagnosing issues.

Constraints:

- In-container git commit/push and mandatory hooks must work without restart or special flags (developer requirement)
- No `--with-engine` flag (rejected)
- System Docker fallback retained during migration (not removed immediately)
- Rootless Podman preferred over system Docker (probe order already correct)

## Goals / Non-Goals

**Goals:**

1. Enforce explicit fallback policy: Podman socket failure = fail with actionable diagnostics, NOT silent fallback to system Docker
2. Document socket authority model (rootless Podman vs system Docker risk difference)
3. Provide migration guide for Fedora and WSL
4. Add test coverage for socket selection logic
5. Establish readiness criteria for eventual system Docker fallback removal (separate follow-up ticket)

**Non-Goals:**

1. Remove system Docker fallback (separate follow-up ticket after 7 consecutive successful days)
2. Add `--with-engine` flag (rejected by developer)
3. Add telemetry/dashboard for migration tracking (no infrastructure, arbitrary thresholds not evidence-based)
4. Change probe order (already correct: Podman first, Docker fallback)
5. Add SELinux warnings (already handled via `--security-opt label=disable`)

## Decisions

### Decision 1: Podman socket failure = fail with diagnostics, not silent fallback

**Choice:** When rootless Podman socket is detected but engine operations fail, exit with actionable error message. Do NOT silently fall back to system Docker.

**Rationale:** Silent fallback masks Podman configuration errors. Users cannot diagnose why their Podman setup is not working. Explicit error messages enable users to fix Podman issues or consciously choose to remove Podman socket to trigger system Docker fallback.

**Alternatives considered:**

- Silent fallback to system Docker (current behavior): rejected because it masks errors
- Warning + fallback: rejected because users may ignore warnings and not fix Podman issues
- Retry logic: rejected because it adds complexity without solving the diagnosis problem

### Decision 2: System Docker fallback retained during migration

**Choice:** Keep system Docker fallback active when no rootless Podman socket is detected. Do NOT remove it immediately.

**Rationale:** Breaking change for users who have not migrated to rootless Podman. Migration requires time, documentation, and verification on both Fedora and WSL. Readiness criteria (7 consecutive successful days) must be met before removal.

**Alternatives considered:**

- Remove system Docker fallback immediately: rejected because it breaks users who have not migrated
- Add `--with-engine` flag: rejected because in-container git operations must work without special flags
- Telemetry-based deprecation: rejected because no telemetry infrastructure exists

### Decision 3: Documentation structure

**Choice:** Add three new sections to `tools/opencode-docker/README.md`:

1. "Container Engine Socket Access" - security model, socket authority
2. "Migration Guide" - Fedora and WSL installation steps
3. "Error Messages" - explanation of warning/error messages

**Rationale:** Centralizes socket-related documentation. Users can find security model, migration instructions, and error explanations in one place.

**Alternatives considered:**

- Separate `docs/migration-podman.md`: rejected because it splits documentation across multiple files
- Inline comments in launcher script: rejected because users do not read source code

### Decision 4: Test strategy

**Choice:** Use bats unit tests with mocked sockets (create fake socket files in temp directory). Verify launcher behavior for each socket state. Wire into `make test-shell`.

**Rationale:** Follows existing test patterns (`scripts/__tests__/verify-pre-commit.bats`, `scripts/__tests__/verify-pre-push.bats`). Host-runnable (no Docker daemon required). Mocked sockets enable testing all three socket states without requiring actual Podman/Docker installations.

**Alternatives considered:**

- Integration tests with real Podman/Docker: rejected because they require actual installations and are not host-runnable
- Manual testing only: rejected because it is not repeatable and does not catch regressions

## Risks / Trade-offs

**Risk 1: Podman socket failure breaks in-container git operations**

- **Mitigation:** Explicit error message guides user to fix Podman or remove socket to trigger system Docker fallback
- **Trade-off:** User must take action to fix Podman or remove socket (not silent fallback)

**Risk 2: System Docker fallback remains high-risk during migration**

- **Mitigation:** Warning message when using system Docker fallback, documentation explains risk difference
- **Trade-off:** Users who have not migrated continue to use system Docker (higher risk)

**Risk 3: Migration guide may be incomplete or incorrect**

- **Mitigation:** Platform verification evidence required pre-merge (Fedora + WSL)
- **Trade-off:** Developer must verify migration guide on both platforms before merge

**Risk 4: Test coverage may not catch all edge cases**

- **Mitigation:** Tests cover all three socket states (Podman found, Podman not found + Docker found, neither found)
- **Trade-off:** Tests use mocked sockets, which may not catch real-world socket issues

## Seams

**Public boundaries where tests will live:**

1. **Launcher script** (`tools/opencode-docker/bin/opencode-docker`):
   - Socket probe logic (lines 150-164)
   - Error handling for Podman socket failure
   - Warning messages for system Docker fallback

2. **Test file** (`scripts/__tests__/opencode-docker.bats` or existing test file):
   - Mocked socket creation (fake socket files in temp directory)
   - Launcher invocation with different socket states
   - Verification of error messages and warnings

3. **Documentation** (`tools/opencode-docker/README.md`, `tools/opencode-docker/AGENTS.md`):
   - "Container Engine Socket Access" section
   - "Migration Guide" section
   - "Error Messages" section

**Test seams:**

- Mocked sockets: create fake socket files in temp directory, verify launcher behavior
- Launcher invocation: run launcher with different socket states, verify error messages
- Documentation: verify sections exist and contain required content

## Migration Plan

**Phase 1: Implementation (this ticket)**

1. Modify launcher to fail with diagnostics when Podman socket fails (not silent fallback)
2. Add documentation sections to README.md and AGENTS.md
3. Add test coverage for socket selection logic
4. Verify on Fedora and WSL (platform verification evidence)
5. Merge

**Phase 2: Stability monitoring (7 consecutive days)**

1. Monitor for unresolved socket bugs
2. Verify all platform verification criteria passing
3. No telemetry or usage-percentage threshold (developer decision)

**Phase 3: Follow-up ticket (separate)**

1. Create follow-up ticket to remove system Docker fallback
2. Blocked by readiness criteria (7 consecutive successful days)
3. Implement fallback removal
4. Verify on Fedora and WSL
5. Merge

**Rollback strategy:**

- If issues arise after Phase 1 merge: revert commit, system Docker fallback returns to silent behavior
- If issues arise after Phase 3 merge: revert commit, system Docker fallback returns
- No data loss (launcher behavior only, no persistent state)

## Open Questions

None. All decisions resolved during interview.
