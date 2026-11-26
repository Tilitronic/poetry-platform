# Implementation Tasks

## 1. Test Infrastructure & Security-Critical Tests (TDD RED Phase)

- [ ] 1.1 Create test file `scripts/__tests__/ssh-agent-forward.bats` with test infrastructure
  - **Acceptance criteria:** Test file exists, loads `test-helper.bash`, can be run via `bats scripts/__tests__/ssh-agent-forward.bats` (even if all tests fail initially).
  - **Worktree:** `feature/dia133-test-infra` (independent, no blocking edges)
  - **Vertical slice:** Test file scaffold + helper functions for mocking SSH agent sockets + fake podman recorder. Demo: `bats` runs the file (tests fail with "not implemented" or assertion failures, but the test infrastructure works).

- [ ] 1.2 Write security-critical test: no ~/.ssh mount
  - **Acceptance criteria:** Test asserts the `podman run` command does NOT contain any `-v` flag referencing `.ssh` or SSH key files (`id_rsa`, `id_ed25519`, `*.pub`). Test fails initially (RED).
  - **Worktree:** `feature/dia133-security-tests` (depends on 1.1, blocking edge: 1.1 must complete first)
  - **Vertical slice:** One test case proving no key material is mounted. Demo: test fails with "assertion failed: podman run contains .ssh mount" (expected, since SSH_MOUNT not implemented yet).

- [ ] 1.3 Write security-critical test: socket mount is read-only
  - **Acceptance criteria:** Test asserts the `podman run` command contains `-v <socket>:/tmp/ssh-agent.sock:ro` (the `:ro` flag is present). Test fails initially (RED).
  - **Worktree:** Same worktree as 1.2 (both are security tests, same file).
  - **Vertical slice:** One test case proving the socket mount is read-only. Demo: test fails with "assertion failed: mount does not contain :ro" (expected, since SSH_MOUNT not implemented yet).

- [ ] 1.4 Write security-critical test: mount target is socket, not key file
  - **Acceptance criteria:** Test asserts the mount target is `/tmp/ssh-agent.sock` (a socket path), not a `.pub` or private key path. Test fails initially (RED).
  - **Worktree:** Same worktree as 1.2/1.3.
  - **Vertical slice:** One test case proving the mount target is a socket. Demo: test fails with "assertion failed: mount target is not /tmp/ssh-agent.sock" (expected).

- [ ] 1.5 Write test: warn-and-continue when no socket found
  - **Acceptance criteria:** Test mocks `SSH_AUTH_SOCK` unset + no fallback sockets exist, asserts the wrapper exits 0 AND prints a warning to stderr mentioning "git push" AND "SSH agent". Test fails initially (RED).
  - **Worktree:** Same worktree as 1.2/1.3/1.4.
  - **Vertical slice:** One test case proving warn-and-continue behavior. Demo: test fails with "wrapper exited 1 instead of 0" or "warning message not found" (expected).

- [ ] 1.6 Write test: detection loop finds socket when present
  - **Acceptance criteria:** Test mocks `SSH_AUTH_SOCK` set to a fake socket, asserts the wrapper mounts it at `/tmp/ssh-agent.sock` AND sets `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` via EXTRA_ENV. Test fails initially (RED).
  - **Worktree:** Same worktree as 1.2/1.3/1.4/1.5.
  - **Vertical slice:** One test case proving the detection loop works. Demo: test fails with "SSH_AUTH_SOCK not set in podman run command" (expected).

**Blocking edges:** 1.2 depends on 1.1; 1.3/1.4/1.5/1.6 depend on 1.2 (all in same worktree, sequential within the worktree).

**Worktree isolation:** All tests (1.2-1.6) are in the same worktree (`feature/dia133-security-tests`) because they all modify the same file (`scripts/__tests__/ssh-agent-forward.bats`). They cannot be parallelized across worktrees (file conflict). Within the worktree, they are sequential (each test builds on the previous).

## 2. SSH_MOUNT Detection Loop Implementation (TDD GREEN Phase)

- [ ] 2.1 Implement SSH_MOUNT detection loop in `bin/opencode-docker`
  - **Acceptance criteria:** The wrapper probes `$SSH_AUTH_SOCK`, `${XDG_RUNTIME_DIR:-}/keyring/ssh`, `${XDG_RUNTIME_DIR:-}/gcr/ssh` in order, mounts the first found socket read-only at `/tmp/ssh-agent.sock`, sets `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` via EXTRA_ENV, and prints a warning to stderr when no socket is found (warn-and-continue, exit 0). All tests from 1.2-1.6 pass (GREEN).
  - **Worktree:** `feature/dia133-ssh-mount` (depends on 1.1-1.6, blocking edge: all tests must exist first)
  - **Vertical slice:** SSH_MOUNT block added to wrapper, all security-critical tests pass. Demo: `bats scripts/__tests__/ssh-agent-forward.bats` exits 0 (all tests pass).

**Blocking edges:** 2.1 depends on 1.6 (all tests must be written first).

**Worktree isolation:** 2.1 modifies `tools/opencode-docker/bin/opencode-docker` (no conflict with test worktree). Can be implemented in a separate worktree after tests exist.

## 3. GIT_SSH_COMMAND & Known_Hosts Handling

- [ ] 3.1 Add GIT_SSH_COMMAND to EXTRA_ENV
  - **Acceptance criteria:** The wrapper sets `GIT_SSH_COMMAND="-o StrictHostKeyChecking=accept-new"` via EXTRA_ENV (unconditionally, not conditional on SSH agent presence). Test added to `scripts/__tests__/ssh-agent-forward.bats` asserts the `podman run` command contains `-e GIT_SSH_COMMAND=-o StrictHostKeyChecking=accept-new`. Test passes (GREEN).
  - **Worktree:** `feature/dia133-git-ssh-command` (depends on 2.1, blocking edge: SSH_MOUNT must exist first)
  - **Vertical slice:** GIT_SSH_COMMAND env var added, test passes. Demo: `bats scripts/__tests__/ssh-agent-forward.bats` exits 0 (all tests pass, including the new GIT_SSH_COMMAND test).

**Blocking edges:** 3.1 depends on 2.1 (SSH_MOUNT must exist before GIT_SSH_COMMAND is added).

**Worktree isolation:** 3.1 modifies `tools/opencode-docker/bin/opencode-docker` (same file as 2.1, but 2.1 must complete first). Can be implemented in the same worktree as 2.1 (sequential) or a new worktree after 2.1 merges.

## 4. Documentation Updates

- [ ] 4.1 Update `tools/opencode-docker/AGENTS.md` with SSH agent forwarding section
  - **Acceptance criteria:** `AGENTS.md` includes a section describing the SSH agent forwarding feature, the no-agent warning, and the requirement that the host GNOME keyring/ssh-agent must be unlocked.
  - **Worktree:** `feature/dia133-docs` (independent, no blocking edges, can be parallel with 1.1-3.1)
  - **Vertical slice:** Documentation updated. Demo: `grep -i "ssh agent" tools/opencode-docker/AGENTS.md` finds the new section.

- [ ] 4.2 Update `tools/opencode-docker/README.md` with SSH agent requirement
  - **Acceptance criteria:** `README.md` mentions that the host SSH agent must be running and unlocked for `git push` to work from the container.
  - **Worktree:** Same worktree as 4.1 (both are docs, same worktree).
  - **Vertical slice:** Documentation updated. Demo: `grep -i "ssh agent" tools/opencode-docker/README.md` finds the new mention.

**Blocking edges:** None (independent, can be parallel with any other task).

**Worktree isolation:** 4.1-4.2 modify only documentation files (no conflict with test or implementation worktrees). Can be parallelized with 1.1-3.1.

## 5. Integration Verification (Manual End-to-End Test)

- [ ] 5.1 Manual verification: rebuild container and test git push
  - **Acceptance criteria:** Developer rebuilds the container (`make build` in `tools/opencode-docker/`), launches it (`bin/opencode-docker`), and verifies: (a) `echo $SSH_AUTH_SOCK` inside the container outputs `/tmp/ssh-agent.sock`, (b) `ssh-add -l` lists the host's keys, (c) `git push` of a test branch succeeds (SSH remote), (d) `ssh -T git@github.com` returns the authenticated greeting.
  - **Worktree:** N/A (manual verification, not a worktree task).
  - **Vertical slice:** End-to-end verification. Demo: all four checks pass.

- [ ] 5.2 Manual verification: test warn-and-continue behavior
  - **Acceptance criteria:** Developer stops the host SSH agent (or unsets `SSH_AUTH_SOCK`), launches `bin/opencode-docker`, and verifies: (a) the wrapper prints a warning to stderr mentioning "git push" and "SSH agent", (b) the container still launches (exit 0), (c) inside the container, `echo $SSH_AUTH_SOCK` is unset or empty.
  - **Worktree:** N/A (manual verification).
  - **Vertical slice:** Warn-and-continue verification. Demo: warning printed, container launches, SSH_AUTH_SOCK unset inside container.

**Blocking edges:** 5.1-5.2 depend on 2.1 and 3.1 (implementation must be complete before manual verification).

**Worktree isolation:** N/A (manual tasks, no worktree).

## Worktree Isolation Matrix

| Task    | Worktree                         | Files Modified                                                                          | Can Parallel?                  | Blocking Edges              |
| ------- | -------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------ | --------------------------- |
| 1.1     | `feature/dia133-test-infra`      | `scripts/__tests__/ssh-agent-forward.bats` (new)                                        | YES (independent)              | None                        |
| 1.2-1.6 | `feature/dia133-security-tests`  | `scripts/__tests__/ssh-agent-forward.bats`                                              | NO (depends on 1.1, same file) | 1.1 → 1.2 → 1.3/1.4/1.5/1.6 |
| 2.1     | `feature/dia133-ssh-mount`       | `tools/opencode-docker/bin/opencode-docker`                                             | NO (depends on 1.6)            | 1.6 → 2.1                   |
| 3.1     | `feature/dia133-git-ssh-command` | `tools/opencode-docker/bin/opencode-docker`, `scripts/__tests__/ssh-agent-forward.bats` | NO (depends on 2.1)            | 2.1 → 3.1                   |
| 4.1-4.2 | `feature/dia133-docs`            | `tools/opencode-docker/AGENTS.md`, `tools/opencode-docker/README.md`                    | YES (independent)              | None                        |
| 5.1-5.2 | N/A (manual)                     | N/A                                                                                     | NO (depends on 2.1, 3.1)       | 2.1, 3.1 → 5.1, 5.2         |

**Parallel execution plan:**

- **Wave 1 (parallel):** 1.1 (test infra) + 4.1-4.2 (docs) — no file conflicts.
- **Wave 2 (sequential within worktree):** 1.2 → 1.3/1.4/1.5/1.6 (all security tests in same worktree).
- **Wave 3 (after Wave 2 merges):** 2.1 (SSH_MOUNT implementation).
- **Wave 4 (after Wave 3 merges):** 3.1 (GIT_SSH_COMMAND).
- **Wave 5 (after Wave 4 merges):** 5.1-5.2 (manual verification).

**Rationale for worktree boundaries:**

- 1.1 and 4.1-4.2 can be parallel because they modify different files (tests vs docs).
- 1.2-1.6 must be in the same worktree because they all modify the same file (`ssh-agent-forward.bats`). They are sequential within the worktree (each test builds on the previous).
- 2.1 must wait for 1.6 because TDD requires tests to exist before implementation (RED → GREEN).
- 3.1 must wait for 2.1 because GIT_SSH_COMMAND is added after SSH_MOUNT (logical dependency).
- 5.1-5.2 are manual verification tasks that require the implementation to be complete.

## Context Window Sizing

Each task is sized to fit a single fresh context window:

- **1.1:** ~50 lines of test infrastructure (helper functions, fake podman recorder).
- **1.2-1.6:** ~100 lines of test cases (5 tests, ~20 lines each).
- **2.1:** ~20 lines of SSH_MOUNT detection loop (mirrors SOCKET_MOUNT structure).
- **3.1:** ~5 lines of GIT_SSH_COMMAND env var + ~20 lines of test case.
- **4.1-4.2:** ~50 lines of documentation (2 files, ~25 lines each).
- **5.1-5.2:** Manual verification (no code, just commands).

All tasks fit comfortably within a single context window (typically 8K-32K tokens).
