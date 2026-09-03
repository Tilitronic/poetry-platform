# DIA-164 — Give opencode-docker container host docker/podman socket access so pre-commit hooks work from inside OpenCode

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-121 collided with origin/omo-slim-changes ticket DIA-145-opencode-docker-host-socket-access.md (different ticket). Renumbered to DIA-164. This ticket duplicates remote DIA-145-opencode-docker-host-socket-access.md (same work, renumbered on the remote lineage via bab080c); SUPERSEDED by the remote ticket. -->

<!-- Fix ticket (fix-lane): restores the DIA-094 pre-commit gate for sessions
     running inside the opencode-docker container. Filed 2026-08-12,
     cod-lane. -->

---

id: DIA-164
title: "Give opencode-docker container host docker/podman socket access so pre-commit hooks work from inside OpenCode"
area: docker
severity: Major
status: VERIFIED
blocked_by: []
discovered: 2026-08-12
source: fix-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
lane_id: "cod-lane"
agent: "coder"
model: ""
parent_session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

The opencode-docker container (tools/opencode-docker/, launched via bin/opencode-docker) cannot run the poetry-platform pre-commit hook (scripts/verify-pre-commit.sh) because it has no docker CLI and no host container socket mounted. The hook's container_running() calls 'docker compose -f docker-compose.yml ps --services --status running' and delegates lint-staged via 'docker compose exec -T dev ...'. Inside the container neither works, so every commit from an opencode-docker session is blocked by DIA-094. Root cause: the wrapper (bin/opencode-docker) mounts only homebase/config/secrets/workspace volumes; the Dockerfile installs no docker client.

Fix scope:

1. Dockerfile - install docker CLI client + compose plugin (docker-ce-cli + docker-compose-plugin via Docker apt repo, version-pinned per project F3/TODO pinning convention, or the lightest viable equivalent; Debian 13 slim base).
2. bin/opencode-docker - detect the host's container socket (candidates: $XDG_RUNTIME_DIR/podman/podman.sock, /run/user/<uid>/podman/podman.sock, /var/run/docker.sock; the host runs rootless podman per storage paths /home/mimic/.local/share/containers/storage) and mount the first found read-only as /var/run/docker.sock in the container, plus set DOCKER_HOST=unix:///var/run/docker.sock via EXTRA_ENV.
3. Document the rebuild+relaunch requirement (make build then bin/opencode-docker) and the fact that the current session ends on relaunch - handoff file .opencode/session/current-handoff.json covers resumption.

Security tradeoff: the socket grants the container the host user's container-management rights (docker socket = host root equivalent in rootful setups; with rootless podman it is the user's own podman socket - document this in the ticket).

## Verification

After rebuild + relaunch, inside the container:

- 'docker compose -f /workspace/docker-compose.yml ps --services --status running' returns 'dev' (poetry-dev running).
- 'bash /workspace/scripts/verify-pre-commit.sh' exits 0.
- 'make test-config' and 'make test-shell' pass.
- Then the 7-commit plan (handoff OT-001) can be executed with hooks running.

## Fix

3-part fix applied 2026-08-12, landed in commit 4d34211:

1. Dockerfile - docker CLI 29.7.2 + compose v2.39.1 installed via static
   curl download, SHA256-pinned (docker tgz 803d433f..., compose verified
   against the release checksums.txt), client-only (no dockerd/containerd/
   runc extracted).
2. bin/opencode-docker - socket detection loop (XDG_RUNTIME_DIR/podman/
   podman.sock -> /run/user/$(id -u)/podman/podman.sock ->
   /var/run/docker.sock), mounts the first found socket read-only as
   /var/run/docker.sock, sets DOCKER_HOST=unix:///var/run/docker.sock via
   EXTRA_ENV.
3. README docs added + 'name: poetry-platform' added to docker-compose.yml
   (fixes compose project-name mismatch when the repo is mounted at
   /workspace).

SELinux saga (recorded concisely): the socket was blocked by SELinux
type-enforcement - container_t cannot connectto a user_tmp_t socket; the
:z relabel to container_file_t still denies connectto; chcon to
container_runtime_t is policy-denied. Applied fix:
--security-opt=label=disable in the wrapper + workspace mount changed
:Z -> :z (the :Z relabel was privatizing /workspace MCS labels, locking
out poetry-dev). Host one-time restore: sudo chcon -Rv
"system_u:object_r:container_file_t:s0"
/home/mimic/Documents/Coddding/poetry-platform.

## Re-verify

Re-verified 2026-08-12 after rebuild + relaunch (commit 4d34211 landed the
fix). All checks run inside the rebuilt opencode-docker container unless
noted:

- docker compose -f /workspace/docker-compose.yml ps --services --status
  running -> outputs 'dev' and 'postgres', exit 0.
- docker ps (inside container) -> lists all host containers, exit 0.
- bash scripts/verify-pre-commit.sh -> exit 0, prints '== poetry-platform
  pre-commit: delegating to dev container ==' and 'autofix passed'.
- Poetry-dev read /workspace: 'READ_OK' after the host chcon restore (see
  Fix, SELinux saga).
- Config validators: all 10 test-config validators exit 0 (run directly;
  make is absent in the opencode container).

Honest caveat: 'make test-config && make test-shell' INSIDE poetry-dev
exits 2 due to TWO pre-existing environment gaps, not DIA-164 regressions:
(a) check-host-lsp - rust-analyzer 1.83.0 on PATH, expected 1.97.1
(dev-image LSP drift); (b) test-skills - global skills directory not found
at /home/dev/.config/opencode/skills (poetry-dev HOME=/home/dev lacks the
global skills dir the validator expects). Tracked as a follow-up; the
pre-commit commit gate itself passes (it delegates lint-staged only, not
these gates). The pre-push gate wiring (test-shell/test-config) is
DIA-161's scope and its bats suite passed 9/9.

Status: OPEN -> VERIFIED.
