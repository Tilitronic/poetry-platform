## Context

The dev container (`poetry-dev`) runs as non-root user `dev` (UID 1000) via the `USER ${USER_UID}:${USER_GID}` directive in Dockerfile.dev (line 340). The container mounts a named volume `dev_state:/home/dev/.local/share` (docker-compose.yml line 48). When Docker first mounts a named volume, it copies the image's directory contents, but the volume's root directory ownership may be root. OpenCode creates the `log/` subdirectory lazily on first run, and if the parent directory is root-owned, the dev user cannot write to it, causing `PermissionDenied opening /home/dev/.local/share/opencode/log/opencode.log`.

**Real root cause (empirical diagnosis):** The healthcheck is exonerated. The actual root cause is that when someone runs `opencode` as root (via `scripts/opencode-dev` or manual `docker compose exec` without `--user dev`), OpenCode creates/opens the log file as root, which re-owns it. This happens because:

- The entrypoint's one-shot chown runs at container start
- But if someone later runs `opencode` as root (bypassing the entrypoint's gosu dev), OpenCode opens the log file as root, changing its ownership
- Subsequent `make opencode` (which runs as dev) then fails with PermissionDenied

The fix requires:

1. The entrypoint to run as root to chown the directory, then drop privileges to dev before exec'ing the command
2. Self-healing: the chown must run before every OpenCode launch (not just at container start) to repair ownership if OpenCode was previously run as root
3. Explicit dev-user routing for all OpenCode launchers (scripts/opencode-dev, scripts/dev-stack.sh, Makefile targets)
4. Healthcheck-as-dev defense in depth to prevent the healthcheck from re-owning the log file

This changes the container's default user from dev to root, requiring explicit `--user dev` flags in Makefile exec commands.

**Constraints:**

- Must work with both Docker and rootless Podman (Fedora developers use `--userns=keep-id`)
- Must not break existing Makefile targets or developer workflows
- Must be minimal and follow established Docker patterns
- Must prevent future regressions where someone runs `opencode` as root

## Goals / Non-Goals

**Goals:**

- Fix the PermissionDenied error so `make opencode` starts OpenCode successfully
- Ensure the fix works with both Docker and rootless Podman
- Maintain the current developer experience (Makefile targets run as dev user)
- Follow Docker best practices for privilege dropping (gosu)
- Self-healing: repair ownership before every OpenCode launch (not just at container start)
- Prevent future regressions where someone runs `opencode` as root
- Healthcheck-as-dev defense in depth

**Non-Goals:**

- Do not change OpenCode application logic or the log format
- Do not change the Docker gate (DIA-094) or the config-change workflow
- Do not add a new dependency or wrapper service to manage the log file
- Do not change which user runs OpenCode (stays dev)
- Do not touch unrelated container files; scope is strictly the log path ownership/creation
- Do not create a VS Code devcontainer (deferred to separate ticket)
- Do not retire `tools/opencode-docker/` (deferred to separate ticket)

## Decisions

### Decision 1: Remove USER directive from Dockerfile.dev

**Choice:** Remove `USER ${USER_UID}:${USER_GID}` at line 340.

**Rationale:** The entrypoint must run as root to chown root-owned directories. With the USER directive, the entrypoint runs as dev and cannot chown. Removing it makes the container's default user root, allowing the entrypoint to perform the chown.

**Alternatives considered:**

- Keep USER directive and use a separate root init script: Rejected — over-engineering, two-stage init, more complex.
- Use `su` or `runuser` in the entrypoint without removing USER: Rejected — the entrypoint would still run as dev and cannot chown root-owned files.

### Decision 2: Use gosu for privilege dropping

**Choice:** Install `gosu` from Debian repo and use `exec gosu dev "$@"` in the entrypoint.

**Rationale:** gosu is the de facto standard for Docker containers that need to run init tasks as root then drop to a non-root user. It's signal-safe (important for `tini` PID 1 zombie reaping), simple syntax, well-tested, and ~100KB from the Debian repo.

**Alternatives considered:**

- `su -c`: Rejected — complex quoting, signal handling issues, not designed for this use case.
- `runuser`: Rejected — less common in Docker, similar complexity to `su`.
- Remove USER directive + `su -s /bin/bash dev -c "$*"`: Rejected — verbose, error-prone, signal handling issues.

### Decision 3: Self-healing chown scope

**Choice:** Chown `/home/dev/.local/share/opencode` to dev:dev before every command in dev-entrypoint.sh (not just at container start). This ensures that even if OpenCode was previously run as root (which re-owns the log file), subsequent launches repair the ownership.

**Rationale:** The real root cause is that running `opencode` as root re-owns the log file, defeating a one-shot chown at container start. The self-healing approach ensures that every OpenCode launch (via the entrypoint) repairs the ownership before running OpenCode. This is more robust than a one-shot chown because it handles the case where someone runs `opencode` as root after the container has started.

**Alternatives considered:**

- One-shot chown at container start only: Rejected — does not handle the case where someone runs `opencode` as root after the container has started.
- Chown entire `/home/dev/.local/share`: Rejected — broader than necessary, could mask other issues.
- Chown `/home/dev/.local/share/opencode/log`: Rejected — the log directory may not exist yet (OpenCode creates it lazily), so chowning the parent is safer.

### Decision 4: No `services.dev.user` override in docker-compose.yml

**Choice:** Do not add `user: "1000:1000"` or `user: "${UID}:${GID}"` to the dev service in docker-compose.yml.

**Rationale:** AI-specialist validation confirmed this would make PID1 (entrypoint) run as non-root, defeating the chown. The validated minimal model is: remove Dockerfile USER, entrypoint runs as root, performs narrow chown, then `exec gosu dev "$@"`. Compose service has no `user:` directive.

**Alternatives considered:**

- `user: "1000:1000"` in docker-compose.yml: Rejected by ai-specialist — makes PID1 non-root, defeats chown.
- `user: "${UID}:${GID}"` in docker-compose.yml: Rejected — requires host UIDs to match container UIDs (pre-existing mismatch issue).

### Decision 5: Explicit `--user dev` flags in Makefile (non-opencode targets) + root entrypoint routing for opencode

**Choice:** Add `--user dev` to each non-opencode `docker compose exec` command in the Makefile (shell, dev, install, test-python, test-harness). For the `opencode` target, use `docker compose exec -it --user root dev /usr/local/bin/dev-entrypoint.sh opencode` — the entrypoint runs as root, performs the self-healing chown, then drops to dev via gosu.

**Rationale:** After removing the USER directive, the container's default user becomes root. Non-opencode Makefile targets rely on explicit `--user dev` flags to run as dev. The opencode target uses a different pattern: it invokes the entrypoint as root so the entrypoint can repair any root-owned log file before dropping to dev. This is the confirmed self-healing model: root entrypoint performs narrow chown, then privilege drop via gosu. This is explicit, no new abstraction, and the Makefile is the single source of truth for dev commands.

**Alternatives considered:**

- `--user dev` for opencode target: Rejected — would bypass the entrypoint's self-healing chown, so if the log file is already root-owned, the opencode launch would still fail.
- Wrapper script (e.g., `scripts/dev-exec`): Rejected — YAGNI, no wrapper needed when we can add the flag directly. Developers will learn the pattern from Makefile targets.
- Compose override file: Rejected — not all compose implementations support this consistently.

### Decision 6: No automated bats test for entrypoint chown

**Choice:** No automated bats test for the entrypoint chown. Use manual verification via rootless Podman chown proof + startup/ownership/fresh-volume acceptance evidence.

**Rationale:** The failure mode is immediately visible (OpenCode won't start), so the feedback loop is tight. Testing would require root privileges in the test environment (bats tests run as dev user). The manual verification in the ticket is the minimum that fails if the logic breaks. Ponytail principle: "Lazy code without its check is unfinished" — the check here is manual verification, not an automated test.

**Alternatives considered:**

- Bats test for entrypoint chown: Rejected — requires root privileges in test environment, testing complexity outweighs benefit for a one-time fix.

### Decision 7: WSL compose merge defensive scaffold and regression test

**Choice:** Retain explicit `dev: {}` in docker-compose.wsl.yml (already applied) as a defensive clarity scaffold, and add a merge-presence regression test to scripts/**tests**/compose-overrides.bats.

**Rationale:** Empirical evidence (Docker Compose 29.7.2) shows that `dev: null` (bare/null with comments only) merges successfully and retains the dev service, so the prior claim that null necessarily deletes the service is not supported in the target runtime. The explicit `dev: {}` is retained for clarity and future-proofing against Compose version changes, but it is not a required fix. The regression test passes pre-landed (even without the `dev: {}` fix) because Compose 29.7.2 handles null correctly, but it guards against future Compose version regressions or behavioral changes.

**Alternatives considered:**

- Remove `dev: {}` and rely on Compose 29.7.2's null handling: Rejected — while the current version handles null correctly, explicit `{}` is clearer and provides defense-in-depth against future Compose version changes.
- No regression test: Rejected — while the current version handles null correctly, a defensive test provides early warning of future regressions at minimal cost.
- Test in a separate bats file: Rejected — YAGNI, the existing compose-overrides.bats already tests WSL overlay behavior, so the regression test belongs there.

### Decision 8: Route scripts/opencode-dev opencode mode through dev-entrypoint as root

**Choice:** Ensure scripts/opencode-dev uses `docker compose exec -it --user root dev /usr/local/bin/dev-entrypoint.sh opencode` for the opencode mode, so it benefits from the entrypoint's self-healing chown. Other modes (bash, test) use `--user dev` directly. scripts/dev-stack.sh uses `--user dev` for all commands (it does not invoke opencode directly).

**Rationale:** The real root cause is that running `opencode` as root re-owns the log file. If scripts/opencode-dev runs `opencode` without routing through the entrypoint, it will run as root (after the USER directive is removed) and re-own the log file, defeating the self-healing chown. Routing the opencode mode through the entrypoint as root ensures the entrypoint repairs ownership before dropping to dev. Other modes (bash, test) do not invoke opencode, so they use `--user dev` directly. scripts/dev-stack.sh does not invoke opencode, so all its commands use `--user dev`.

**Alternatives considered:**

- Leave scripts/opencode-dev unchanged: Rejected — it would run as root and re-own the log file, defeating the self-healing chown.
- Add `--user dev` to the opencode mode but not route through entrypoint: Rejected — the entrypoint's self-healing chown would not run, so if the log file is already root-owned, the script would still fail.
- Route all modes through entrypoint as root: Rejected — unnecessary for bash/test modes that do not invoke opencode; `--user dev` is simpler and sufficient.

### Decision 9: Healthcheck-as-dev defense in depth

**Choice:** Update Dockerfile.dev HEALTHCHECK to run as dev user (via `gosu dev` or `USER dev` before HEALTHCHECK) so the healthcheck cannot re-own the log file.

**Rationale:** The healthcheck runs periodically and could re-own the log file if it runs as root. By running the healthcheck as dev, we ensure it cannot re-own the log file. This is defense in depth — even if someone accidentally runs `opencode` as root, the healthcheck will not compound the problem.

**Alternatives considered:**

- Leave healthcheck as root: Rejected — the healthcheck runs periodically and could re-own the log file, compounding the problem if someone accidentally runs `opencode` as root.
- Remove healthcheck: Rejected — the healthcheck is useful for detecting container health, and running it as dev is a simple fix.

### Decision 10: Static regression guard for root opencode launchers

**Choice:** Add a static regression guard (grep-based test) to scripts/**tests**/opencode-launch-routing.bats that detects any `docker compose exec` commands that run `opencode` without `--user dev`.

**Rationale:** The real root cause is that running `opencode` as root re-owns the log file. A static guard prevents future regressions where someone adds a root opencode launcher. The guard is cheap (grep-based test) and runs in `make test-shell`. This is a structural guard, not a behavioral test — it catches the pattern before it causes a problem.

**Alternatives considered:**

- No static guard: Rejected — the real root cause is that running `opencode` as root re-owns the log file, so a structural guard is needed to prevent this pattern.
- Behavioral test that runs `opencode` as root and verifies it fails: Rejected — this would be complex and fragile. A static guard is simpler and catches the pattern before it causes a problem.

## Risks / Trade-offs

**[Risk] Container default user changes from dev to root** → **Mitigation:** All Makefile targets explicitly use `--user dev` to maintain current behavior. Manual `docker compose exec` commands (outside Makefile) will need `--user dev` to run as dev. This is a behavior change, but it's documented in the proposal and developers will learn the pattern from Makefile targets.

**[Risk] Rootless Podman keep-id compatibility** → **Mitigation:** Include rootless Podman keep-id manual verification in the ticket's verification checklist. The fix changes the container's default user from dev (UID 1000) to root (UID 0), which could affect how keep-id maps host UIDs to container UIDs. Manual testing on Fedora with rootless Podman will confirm compatibility.

**[Risk] gosu adds a new dependency (~100KB)** → **Mitigation:** gosu is from the Debian repo (trusted source), signal-safe, and the de facto standard for Docker privilege dropping. The 100KB is negligible compared to the existing packages (curl, wget, git, jq, etc.).

**[Risk] Manual `docker compose exec` commands run as root** → **Mitigation:** Documented in the proposal. Developers will learn the pattern from Makefile targets. If a developer runs `docker compose exec dev bash` without `--user dev`, they will run as root, but this is acceptable — the Makefile targets are the standard path. The self-healing chown in dev-entrypoint.sh will repair ownership on the next `make opencode` launch.

**[Risk] scripts/opencode-dev or scripts/dev-stack.sh run opencode as root** → **Mitigation:** Route scripts/opencode-dev opencode mode through dev-entrypoint as root (`--user root dev /usr/local/bin/dev-entrypoint.sh opencode`). The entrypoint performs the self-healing chown, then drops to dev via gosu. Other modes (bash, test) and scripts/dev-stack.sh use `--user dev` directly. Static regression guard in scripts/**tests**/opencode-launch-routing.bats detects any `docker compose exec` commands that run `opencode` without `--user dev` or entrypoint routing.

**[Risk] Healthcheck re-owns the log file** → **Mitigation:** Update Dockerfile.dev HEALTHCHECK to run as dev user (via `gosu dev` or `USER dev` before HEALTHCHECK). This is defense in depth — even if someone accidentally runs `opencode` as root, the healthcheck will not compound the problem.

**[Note] WSL compose merge behavior** → **Clarification:** Empirical evidence (Docker Compose 29.7.2) shows that `dev: null` merges successfully and retains the dev service, so there is no actual defect in the target runtime. The explicit `dev: {}` is retained as a defensive clarity scaffold, and the regression test provides early warning of future Compose version regressions. This is not a risk but a defensive measure.

**[Trade-off] Explicit `--user dev` flags vs wrapper script** → **Rationale:** Explicit flags are verbose but clear. A wrapper script would centralize the flag but add a new abstraction. YAGNI: no wrapper needed when we can add the flag directly.

**[Trade-off] Self-healing chown vs one-shot chown** → **Rationale:** Self-healing chown (before every command) is more robust than one-shot chown (at container start only) because it handles the case where someone runs `opencode` as root after the container has started. The cost is a small performance overhead (chown runs before every command), but this is negligible for the dev container use case.

## Migration Plan

**Deploy:**

1. Modify Dockerfile.dev: remove USER directive, add gosu to apt-get install, update HEALTHCHECK to run as dev user
2. Modify dev-entrypoint.sh: add self-healing chown + gosu dev before exec (chown runs before every command when running as root, not just at container start; fallback chain: gosu → runuser → su → warn)
3. Modify Makefile: add `--user dev` to non-opencode exec targets (shell, dev, install, test-python, test-harness); route `opencode` target through entrypoint as root (`--user root dev /usr/local/bin/dev-entrypoint.sh opencode`)
4. Modify scripts/opencode-dev: route opencode mode through entrypoint as root (`--user root dev /usr/local/bin/dev-entrypoint.sh opencode`); bash and test modes use `--user dev` directly
5. Verify scripts/dev-stack.sh uses `--user dev` for all commands (no opencode invocations; no changes needed)
6. Verify docker-compose.wsl.yml retains `dev: {}` (already applied; defensive clarity scaffold)
7. Add defensive merge-presence regression test to scripts/**tests**/compose-overrides.bats
8. Add static regression guard to scripts/**tests**/opencode-launch-routing.bats
9. Rebuild the dev image: `make build`
10. Restart containers: `make down && make up`
11. Verify: `make opencode` starts without PermissionDenied
12. Verify: `make test-shell` passes (includes WSL compose merge regression test and static regression guard)
13. Behavioral verification: run `opencode` as root (via manual `docker compose exec dev opencode` without `--user dev`), then verify that subsequent `make opencode` repairs the ownership and starts successfully

**Rollback:**

1. Revert the eight files (Dockerfile.dev, dev-entrypoint.sh, Makefile, scripts/opencode-dev, scripts/dev-stack.sh, docker-compose.wsl.yml, scripts/**tests**/compose-overrides.bats, scripts/**tests**/opencode-launch-routing.bats)
2. Rebuild the dev image: `make build`
3. Restart containers: `make down && make up`

## Open Questions

None. All decisions have been made during the interview.
