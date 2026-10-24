## 1. Launcher Error Handling

- [ ] 1.1 Modify launcher to fail with actionable diagnostics when rootless Podman socket is detected but engine operations fail. Launcher SHALL exit with error message containing "Check podman socket status: systemctl --user status podman.socket" and SHALL NOT silently fall back to system Docker. Acceptance: when Podman socket exists but `docker compose ps` fails, launcher exits with error (not fallback). Blocks: 2.1, 3.1, 4.1

- [ ] 1.2 Add warning message when launcher uses system Docker fallback (no Podman socket detected). Warning SHALL contain "System Docker socket provides full API access to all containers in the system. Please migrate to rootless Podman." Acceptance: when no Podman socket found but system Docker found, launcher emits warning to stderr. Blocks: 2.1, 3.1, 4.1

- [ ] 1.3 Verify launcher behavior for all three socket states: (a) Podman found, (b) Podman not found + Docker found, (c) neither found. Acceptance: launcher uses Podman when found, falls back to Docker only when Podman not found, emits warning when neither found. Blocks: 2.1, 3.1, 4.1

## 2. Documentation

- [ ] 2.1 Add "Container Engine Socket Access" section to `tools/opencode-docker/README.md`. Section SHALL explain: `:ro` does not restrict API operations, socket access = full API authority, rootless Podman = user's containers only, system Docker = all containers (higher risk). Acceptance: section exists, explains security model, references interview decisions. Depends on: 1.1, 1.2, 1.3. Blocks: 3.1, 4.1

- [ ] 2.2 Add "Migration Guide" section to `tools/opencode-docker/README.md`. Section SHALL provide: Fedora installation steps, WSL installation steps, socket verification (`systemctl --user status podman.socket`), SELinux workaround (`--security-opt label=disable` already implemented). Acceptance: section exists, provides step-by-step instructions for both platforms. Depends on: 1.1, 1.2, 1.3. Blocks: 3.1, 4.1

- [ ] 2.3 Add "Error Messages" section to `tools/opencode-docker/README.md`. Section SHALL explain: warning when using system Docker fallback, error when Podman socket fails, warning when no socket found. Acceptance: section exists, explains each error message and user action required. Depends on: 1.1, 1.2, 1.3. Blocks: 3.1, 4.1

- [ ] 2.4 Update `tools/opencode-docker/AGENTS.md` with "Container Engine Socket Security" section. Section SHALL reference README.md sections and explain socket authority model. Acceptance: section exists, references README.md. Depends on: 1.1, 1.2, 1.3. Blocks: 3.1, 4.1

## 3. Tests

- [ ] 3.1 Add bats unit tests to `scripts/__tests__/opencode-docker.bats` (or existing test file) verifying socket selection logic. Tests SHALL cover: (a) launcher finds Podman socket when present, (b) launcher does NOT fall back to system Docker when Podman socket fails, (c) launcher falls back to system Docker when no Podman socket found, (d) launcher emits warning when using system Docker fallback. Tests SHALL use mocked sockets (fake socket files in temp directory). Acceptance: all tests pass (`make test-shell` exit 0). Depends on: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4. Blocks: 4.1

## 4. Platform Verification

- [ ] 4.1 Verify on Fedora with rootless Podman: `docker compose ps` works (exit 0), `git commit` triggers pre-commit hook that delegates to poetry-dev (exit 0), `git push` triggers pre-push hook that delegates to poetry-dev (exit 0), `make test-infra` passes (exit 0). Acceptance: all commands succeed on Fedora with rootless Podman. Depends on: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 3.1. Blocks: 4.2

- [ ] 4.2 Verify on WSL with rootless Podman: `docker compose ps` works (exit 0), `git commit` triggers pre-commit hook that delegates to poetry-dev (exit 0), `git push` triggers pre-push hook that delegates to poetry-dev (exit 0), `make test-infra` passes (exit 0). Acceptance: all commands succeed on WSL with rootless Podman. Depends on: 4.1. Blocks: 5.1

## 5. Pre-Merge Evidence

- [ ] 5.1 Collect pre-merge evidence: launcher-test results (bats tests pass), documentation diff (README.md and AGENTS.md updated), Fedora confirmation (all platform verification passing), WSL confirmation (all platform verification passing). Acceptance: evidence collected and attached to ticket. Depends on: 4.2. Blocks: 6.1

## 6. Follow-Up Ticket

- [ ] 6.1 Create follow-up ticket to remove system Docker fallback after 7 consecutive successful days on both platforms. Ticket SHALL be blocked by readiness criteria: 7 consecutive days with no unresolved socket bugs, all platform verification passing. Acceptance: follow-up ticket created with blocked_by on readiness criteria. Depends on: 5.1
