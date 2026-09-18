## 1. Dockerfile.dev Modifications

- [ ] 1.1 Remove `USER ${USER_UID}:${USER_GID}` directive (line 340) so the entrypoint runs as root
- [ ] 1.2 Add `gosu` to the apt-get install block (after `dbus`, before `&& rm -rf /var/lib/apt/lists/*`)
- [ ] 1.3 Update HEALTHCHECK to run as dev user (via `gosu dev opencode --version` or add `USER dev` before HEALTHCHECK)
- [ ] 1.4 Verify the Dockerfile builds successfully: `docker compose build dev`

## 2. dev-entrypoint.sh Modifications

- [ ] 2.1 Add self-healing chown: chown `/home/dev/.local/share/opencode` to dev:dev before every command (use `chown -R 1000:1000 /home/dev/.local/share/opencode 2>/dev/null || true`)
- [ ] 2.2 Replace final `exec "$@"` with `exec gosu 1000:1000 "$@"` to drop privileges before running the command
- [ ] 2.3 Verify the entrypoint script is syntactically correct: `bash -n dev-entrypoint.sh`

## 3. Makefile Modifications

- [ ] 3.1 Add `--user dev` to the `shell` target: `docker compose exec -it --user dev dev bash`
- [ ] 3.2 Add `--user dev` to the `opencode` target: `docker compose exec -it --user dev dev opencode`
- [ ] 3.3 Add `--user dev` to the `dev` target: `docker compose exec -it --user dev dev pnpm dev`
- [ ] 3.4 Add `--user dev` to the `install` target: `docker compose exec -it --user dev dev pnpm install`
- [ ] 3.5 Add `--user dev` to all `docker compose exec -T dev` commands in the `test-python` target (4 occurrences)
- [ ] 3.6 Add `--user dev` to the `docker compose exec -T dev` command in the `test-harness` target

## 4. scripts/opencode-dev Modifications

- [ ] 4.1 Route scripts/opencode-dev through dev-entrypoint with `--user dev` flag (ensure it uses `docker compose exec --user dev dev opencode` or equivalent)
- [ ] 4.2 Verify scripts/opencode-dev runs OpenCode as dev user

## 5. scripts/dev-stack.sh Modifications

- [ ] 5.1 Route any OpenCode invocations in scripts/dev-stack.sh through dev-entrypoint with `--user dev` flag
- [ ] 5.2 Verify scripts/dev-stack.sh runs OpenCode as dev user (if it invokes OpenCode)

## 6. WSL Compose Merge Defensive Regression Test

- [ ] 6.1 Verify docker-compose.wsl.yml retains `dev: {}` (explicit empty object; defensive clarity scaffold, not a required fix) — already applied
- [ ] 6.2 Add defensive merge-presence regression test to scripts/**tests**/compose-overrides.bats: verify that merged WSL config retains dev service (use `docker compose config` and assert dev service is present). This test passes pre-landed because Compose 29.7.2 handles null correctly, but guards against future Compose version regressions.
- [ ] 6.3 Run `make test-shell` to verify the regression test passes

## 7. Static Regression Guard for Root OpenCode Launchers

- [ ] 7.1 Create scripts/**tests**/opencode-launch-routing.bats: static regression guard that detects any `docker compose exec` commands that run `opencode` without `--user dev`
- [ ] 7.2 Wire the new test into `make test-shell` (via batswrapper.sh auto-discovery)
- [ ] 7.3 Run `make test-shell` to verify the static guard passes

## 8. Verification (Manual)

- [ ] 8.1 Rebuild the dev image: `make build`
- [ ] 8.2 Restart containers: `make down && make up`
- [ ] 8.3 Verify `make opencode` starts OpenCode without PermissionDenied
- [ ] 8.4 Verify ownership: `docker compose exec --user dev dev bash -c 'ls -ld /home/dev/.local/share/opencode /home/dev/.local/share/opencode/log 2>/dev/null || echo "log dir does not exist"'` — should show dev:dev ownership
- [ ] 8.5 Verify fresh-volume test: `make clean && make up && make opencode` — should start without PermissionDenied
- [ ] 8.6 Verify `make shell` runs as dev user: `docker compose exec --user dev dev id` — should show uid=1000(dev) gid=1000(dev)
- [ ] 8.7 Verify `make test-python` runs as dev user (check pytest output for dev user context)
- [ ] 8.8 Behavioral verification: run `opencode` as root (via manual `docker compose exec dev opencode` without `--user dev`), then verify that subsequent `make opencode` repairs the ownership and starts successfully

## 9. Rootless Podman Verification (Fedora)

- [ ] 9.1 On a Fedora machine with rootless Podman, run `podman compose up` and verify the entrypoint runs as root and chowns successfully
- [ ] 9.2 Verify `podman compose exec --user dev dev bash` runs as dev user
- [ ] 9.3 Verify `make opencode` (via `podman compose exec --user dev dev opencode`) starts OpenCode without PermissionDenied
- [ ] 9.4 Document any Podman-specific issues or workarounds in the ticket's Fix section

## 10. Ticket Update

- [ ] 10.1 Update DIA-260824-a3mk ticket frontmatter: `gate_state: "grilled"`, `gate_triggers: [cross-cutting, hard-to-reverse]`
- [ ] 10.2 Fill in the ticket's Fix section with the implementation details
- [ ] 10.3 Fill in the ticket's Re-verify section with the verification evidence
- [ ] 10.4 Mark all verification checkboxes as complete
