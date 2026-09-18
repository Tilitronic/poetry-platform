## 1. Launcher flag and socket gating

- [ ] 1.1 Add `-E/--with-engine` flag to the flag parser (default `WITH_ENGINE=0`) and always export sentinel env `OPENCODE_DOCKER=1` into the container via `EXTRA_ENV`. (blocking: none)
- [ ] 1.2 Gate the SOCKET_MOUNT block (lines 150-164) on `WITH_ENGINE`: when set, run the existing probe loop (mount `:ro` + set `DOCKER_HOST`); when unset, leave `SOCKET_MOUNT` empty and print a warning that in-container `docker compose` / git hooks require `--with-engine` (replacing the generic "socket not found" warning). (blocking: 1.1)

Acceptance: launching without `--with-engine` yields no `-v ...docker.sock` in the podman run args and prints the `--with-engine` warning; launching with `--with-engine` mounts the socket `:ro` and sets `DOCKER_HOST` (existing behavior preserved); `OPENCODE_DOCKER=1` is present in both runs.

## 2. Pre-commit hook diagnostic guard

- [ ] 2.1 In `scripts/verify-pre-commit.sh`, add a guard: when `OPENCODE_DOCKER=1` and the engine socket is unreachable (`docker compose ps` fails), exit 1 with a message instructing the developer to relaunch opencode-docker with `--with-engine`. The host-down path (no sentinel) keeps the existing "dev container not running - start with 'make up'" message. (blocking: 1.1)

Acceptance: hook inside opencode-docker without socket exits 1 with a message containing `--with-engine`; hook on host with container down still exits 1 with "make up" (unchanged); hook with socket present delegates as before.

## 3. Tests (bats, host-runnable, mocked)

- [ ] 3.1 Add cases to `scripts/__tests__/opencode-docker.bats`: with mocked `podman` + mocked socket, the launcher mounts `-v ...docker.sock:ro` ONLY when `--with-engine` is passed, and `OPENCODE_DOCKER=1` is always in the run env. (blocking: 1.1, 1.2)
- [ ] 3.2 Add cases to `scripts/__tests__/verify-pre-commit.bats`: with `OPENCODE_DOCKER=1` and mocked docker that fails `ps`, the hook exits 1 with `--with-engine` guidance; the host-down path (no sentinel) still exits 1 with "make up". (blocking: 2.1)

Acceptance: `make test-shell` passes for the new cases; no Docker daemon required.

## 4. Documentation

- [ ] 4.1 Update `tools/opencode-docker/README.md` and `AGENTS.md` socket sections to document `--with-engine` (opt-in, default off) and the hook guidance. (blocking: 1.1, 1.2)

Acceptance: docs state the socket is opt-in via `--with-engine` and that in-container hooks need it.
