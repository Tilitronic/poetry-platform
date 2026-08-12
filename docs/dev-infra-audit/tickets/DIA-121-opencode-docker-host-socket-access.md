# DIA-121 — Give opencode-docker container host docker/podman socket access so pre-commit hooks work from inside OpenCode

<!-- Fix ticket (fix-lane): restores the DIA-094 pre-commit gate for sessions
     running inside the opencode-docker container. Filed 2026-08-12,
     cod-lane. -->

---

id: DIA-121
title: "Give opencode-docker container host docker/podman socket access so pre-commit hooks work from inside OpenCode"
area: docker
severity: Major
status: OPEN
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

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
