## Why

`make opencode` fails with `PermissionDenied opening /home/dev/.local/share/opencode/log/opencode.log` because OpenCode creates the log directory lazily at runtime, and the parent directory tree is root-owned. This blocks OpenCode restart and therefore blocks the config smoke verification step of the OpenCode Configuration Changes workflow (AGENTS.md 2.5 step 5). The dev container is required by the Docker gate (DIA-094) for any implementation work, so this is a hard blocker on the config-change path.

## What Changes

- **Remove `USER ${USER_UID}:${USER_GID}` directive** from Dockerfile.dev (line 340) so the entrypoint runs as root and can chown root-owned directories
- **Add `gosu` package** to the apt-get install block in Dockerfile.dev (~100KB, signal-safe, standard Docker pattern for privilege dropping)
- **Add self-healing launch routing** to dev-entrypoint.sh: chown `/home/dev/.local/share/opencode` to dev:dev before every command (not just at container start), then `exec gosu dev "$@"` to drop privileges. This ensures that even if OpenCode was previously run as root (which re-owns the log file), subsequent launches repair the ownership.
- **Add explicit `--user dev` flags** to each `docker compose exec` command in the Makefile (shell, dev, install, test-python, test-harness) to ensure commands run as the dev user after removing the USER directive
- **Route the `opencode` target through the entrypoint as root**: use `docker compose exec -it --user root dev /usr/local/bin/dev-entrypoint.sh opencode` so the entrypoint performs the self-healing chown as root, then drops to dev via gosu. This is the confirmed self-healing pattern: root entrypoint repairs ownership, then privilege drop.
- **Route scripts/opencode-dev through dev-entrypoint as root**: ensure the wrapper script uses `docker compose exec -it --user root dev /usr/local/bin/dev-entrypoint.sh opencode` for the opencode mode, so it benefits from the entrypoint's self-healing chown. Other modes (bash, test) use `--user dev` directly.
- **scripts/dev-stack.sh uses `--user dev` for all commands**: the dev-stack script does not invoke opencode directly, so all its `docker compose exec` commands use `--user dev` (no root entrypoint routing needed)
- **Healthcheck-as-dev defense in depth**: update Dockerfile.dev HEALTHCHECK to run as dev user (via `gosu dev` or `USER dev` before HEALTHCHECK) so the healthcheck cannot re-own the log file
- **No changes to docker-compose.yml**: no `services.dev.user` override (ai-specialist validation: this would make PID1 entrypoint non-root, defeating the chown)
- **Retain explicit `dev: {}` in docker-compose.wsl.yml** (already applied): defensive clarity scaffold, not a required fix. Empirical evidence (Docker Compose 29.7.2) shows that `dev: null` (bare/null with comments only) merges successfully and retains the dev service, so the prior claim that null necessarily deletes the service is not supported in the target runtime. The explicit `{}` is retained for clarity and future-proofing against Compose version changes.
- **Add merge-presence regression test** to scripts/**tests**/compose-overrides.bats: defensive test that verifies merged WSL config retains dev service. This test passes pre-landed (even without the `dev: {}` fix) because Compose 29.7.2 handles null correctly, but it guards against future Compose version regressions or behavioral changes.
- **Add static regression guard** for root opencode launchers: a test or lint that detects any `docker compose exec` commands that run `opencode` without `--user dev` (prevents future regressions where someone adds a root opencode launcher)

## Capabilities

### New Capabilities

None. This is a pure infrastructure fix with no spec-level behavior changes.

### Modified Capabilities

None. No existing capabilities are changing their requirements.

**Note:** This change sets `skip_specs: true` in `.openspec.yaml` because it is a pure infrastructure fix (container lifecycle ownership) with no spec-level behavior changes. The fix does not alter any application logic, APIs, or user-facing behavior — it only fixes file ownership so OpenCode can start.

## Impact

**Files modified:**

- `Dockerfile.dev`: Remove USER directive (line 340), add gosu to apt-get install, update HEALTHCHECK to run as dev user
- `dev-entrypoint.sh`: Add self-healing chown + gosu dev before exec (chown runs before every command, not just at container start)
- `Makefile`: Add `--user dev` to exec targets (shell, dev, install, test-python, test-harness); route `opencode` target through entrypoint as root (`--user root dev /usr/local/bin/dev-entrypoint.sh opencode`)
- `scripts/opencode-dev`: Route opencode mode through entrypoint as root (`--user root dev /usr/local/bin/dev-entrypoint.sh opencode`); bash and test modes use `--user dev` directly
- `scripts/dev-stack.sh`: Uses `--user dev` for all commands (no opencode invocations; no root entrypoint routing needed)
- `docker-compose.wsl.yml`: Retain explicit `dev: {}` (already applied; defensive clarity scaffold, not a required fix)
- `scripts/__tests__/compose-overrides.bats`: Add defensive merge-presence regression test for WSL overlay (passes pre-landed; guards against future Compose version regressions)
- `scripts/__tests__/opencode-launch-routing.bats` (new): Static regression guard that detects any `docker compose exec` commands that run `opencode` without `--user dev`

**Files NOT modified:**

- `docker-compose.yml`: No `user:` directive (ai-specialist correction)
- OpenCode application logic
- Docker gate (DIA-094)
- Config-change workflow

**Behavioral changes:**

- Container default user changes from dev (UID 1000) to root (UID 0)
- All `docker compose exec` commands without `--user dev` or entrypoint routing will now run as root (behavior change from current)
- Makefile `opencode` target and scripts/opencode-dev opencode mode use `--user root` + explicit entrypoint invocation (self-healing pattern: root chown then gosu dev)
- Other Makefile targets and scripts/opencode-dev bash/test modes explicitly use `--user dev` to maintain current behavior
- Manual `docker compose exec` commands (outside Makefile) will need `--user dev` or entrypoint routing to run as dev

**Rollback plan:**

- Revert the eight files (Dockerfile.dev, dev-entrypoint.sh, Makefile, scripts/opencode-dev, scripts/dev-stack.sh, docker-compose.wsl.yml, scripts/**tests**/compose-overrides.bats, scripts/**tests**/opencode-launch-routing.bats)
- Rebuild the dev image: `make build`
- Restart containers: `make down && make up`

## Testing Decisions

**What makes a good test for this change:**

- Manual verification of container startup and OpenCode execution
- Ownership verification via `ls -ld` of the log path and parents
- Fresh-volume test: `make clean && make up && make opencode` should start without PermissionDenied
- Rootless Podman keep-id compatibility test (Fedora developers)
- Regression test for WSL compose merge: verify that merged WSL config retains dev service (prevents null-parsing defect from recurring)
- Static regression guard for root opencode launchers: detect any `docker compose exec` commands that run `opencode` without `--user dev`
- Behavioral verification: run `opencode` as root (via manual `docker compose exec dev opencode` without `--user dev`), then verify that subsequent `make opencode` repairs the ownership and starts successfully

**Modules tested:**

- Container lifecycle (Dockerfile.dev, dev-entrypoint.sh)
- Makefile exec commands
- Docker and rootless Podman compatibility
- WSL compose override merge behavior
- OpenCode launch routing (scripts/opencode-dev, scripts/dev-stack.sh)
- Healthcheck user context

**Prior art in the codebase:**

- No automated bats tests for entrypoint ownership (YAGNI: one-line chown with immediate visible failure)
- Manual verification is sufficient for a one-time ownership fix
- Ticket verification checklist (DIA-260824-a3mk) provides the acceptance criteria
- Existing compose-overrides.bats tests engine-specific overrides (Podman, rootless-Docker, WSL) but lack a merge-retention assertion for WSL

**Why no automated test for entrypoint chown:**

- The failure mode is immediately visible (OpenCode won't start)
- Testing would require root privileges in the test environment (bats tests run as dev user)
- The manual verification in the ticket is the minimum that fails if the logic breaks
- Ponytail principle: "Lazy code without its check is unfinished" — the check here is manual verification, not an automated test

**Why automated test for WSL compose merge:**

- The test is a defensive regression guard, not a fix for a broken behavior. Empirical evidence (Docker Compose 29.7.2) shows that `dev: null` merges successfully and retains the dev service, so the prior claim that null necessarily deletes the service is not supported in the target runtime.
- The test passes pre-landed (even without the `dev: {}` fix) because Compose 29.7.2 handles null correctly.
- The test guards against future Compose version regressions or behavioral changes.
- The test is cheap (one assertion in existing compose-overrides.bats) and runs in `make test-shell`.

**Why static regression guard for root opencode launchers:**

- The real root cause is that running `opencode` as root re-owns the log file, defeating the entrypoint's one-shot chown
- A static guard prevents future regressions where someone adds a root opencode launcher
- The guard is cheap (grep-based test) and runs in `make test-shell`
- This is a structural guard, not a behavioral test — it catches the pattern before it causes a problem

## Alternatives considered

**Privilege-dropping mechanism:**

- **gosu** (chosen): Standard Docker pattern, simple syntax, signal-safe, well-tested, ~100KB from Debian repo. Evidence: Docker best practices, widely used in production containers.
- `su -c`: No new dependency, but complex quoting, signal handling issues, not designed for this use case. Rejected: not signal-safe, verbose.
- `runuser`: No new dependency, designed for privilege dropping, but less common in Docker. Rejected: similar complexity to `su`, not the standard pattern.
- Remove USER directive + `su -s /bin/bash dev -c "$*"`: No new dependency, but verbose, error-prone, signal handling issues. Rejected: not signal-safe.

**Compose service user directive:**

- **No `services.dev.user` override** (chosen): AI-specialist validation confirmed this would make PID1 entrypoint non-root, defeating the chown. The validated minimal model is: remove Dockerfile USER, entrypoint runs as root, performs narrow chown, then `exec gosu dev "$@"`.
- `user: "1000:1000"` in docker-compose.yml: Rejected by ai-specialist — makes PID1 non-root, defeats chown.
- `user: "${UID}:${GID}"` in docker-compose.yml: Rejected — requires host UIDs to match container UIDs (pre-existing mismatch issue).

**Makefile exec commands:**

- **Explicit `--user dev` flags** (chosen): Explicit, no new abstraction, single source of truth. Each command is clear about what user it runs as.
- Wrapper script (e.g., `scripts/dev-exec`): Rejected — YAGNI, no wrapper needed when we can add the flag directly. Developers will learn the pattern from Makefile targets.
- Compose override file: Rejected — not all compose implementations support this consistently.

**Automated testing:**

- **No automated bats test for entrypoint chown** (chosen): YAGNI, one-line chown with immediate visible failure. Manual verification is sufficient.
- Bats test for entrypoint chown: Rejected — requires root privileges in test environment, testing complexity outweighs benefit for a one-time fix.
- **Defensive merge-presence regression test for WSL compose** (chosen): Guards against future Compose version regressions. Passes pre-landed because Compose 29.7.2 handles null correctly, but provides early warning if behavior changes.
- No test for WSL compose merge: Rejected — while the current Compose version handles null correctly, a defensive test provides early warning of future regressions at minimal cost.
- **Static regression guard for root opencode launchers** (chosen): Prevents future regressions where someone adds a root opencode launcher. Cheap grep-based test that catches the pattern before it causes a problem.
- No guard for root opencode launchers: Rejected — the real root cause is that running `opencode` as root re-owns the log file, so a structural guard is needed to prevent this pattern.

**Chosen option:** Self-healing launch routing + gosu dev + explicit Makefile `--user dev` + defensive WSL compose merge regression test + static regression guard for root opencode launchers — because it is the minimal fix that solves the permission issue while maintaining Docker/Podman compatibility and following established Docker patterns (gosu is the de facto standard for privilege dropping), plus defensive regression tests for future-proofing.
