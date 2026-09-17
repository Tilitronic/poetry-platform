# DIA-171 - Install docker CLI + compose plugin in poetry-dev image (pre-push test-config gate)

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-131 collided with origin/omo-slim-changes ticket DIA-152-install-docker-cli-poetry-dev-image.md (different ticket). Renumbered to DIA-171. This ticket duplicates remote DIA-152-install-docker-cli-poetry-dev-image.md (same work, renumbered on the remote lineage via bab080c); SUPERSEDED by the remote ticket. -->

<!-- Ticket authored 2026-08-13 during the omo-slim-changes rebase push (DIA-159
     trail): the pre-push hook (scripts/verify-pre-push.sh) delegates the
     host-runnable gates into poetry-dev via `docker compose exec -T dev`, and
     `make test-config` inside the container fails because the Makefile's
     `docker compose config --quiet` step needs the docker binary, which
     Dockerfile.dev (debian:13-slim) does not ship. -->

---

id: DIA-171
title: "Install docker CLI + compose plugin in poetry-dev image (pre-push test-config gate)"
area: docker
severity: Major
status: IMPLEMENTED
blocked_by: [] # none; client-only install, no daemon/socket involved
discovered: 2026-08-13
source: test-lane
date: 2026-08-13
created: 2026-08-13
updated: 2026-08-13

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: [docs/dev-infra-audit/tickets/DIA-171-install-docker-cli-poetry-dev-image.md, docs/dev-infra-audit/tickets/README.md, Dockerfile.dev]
artifacts: []
evidence: []

---

## Description

The pre-push hook (scripts/verify-pre-push.sh, DIA-161) delegates every
verification gate into the poetry-dev container via
`docker compose -f docker-compose.yml exec -T dev bash -lc "... && make test-config"`.
The Makefile `test-config` target includes `docker compose config --quiet`
(client-side YAML validation of docker-compose.yml), which invokes the `docker`
binary. poetry-dev is built from Dockerfile.dev (`FROM debian:13-slim`), which
ships NO docker CLI, so the delegated gate fails with:

    make: docker: No such file or directory

The full pre-push chain is therefore blocked: make test-shell passes (bats,
no docker needed), but make test-config cannot complete inside the container.
Observed 2026-08-13 while pushing the omo-slim-changes rebase branch (DIA-159
trail) — the hook aborts the push at the test-config step.

`docker compose config` is purely client-side (parses + validates the compose
file; needs no daemon), so the fix is to install the docker CLI + compose
plugin in the image. No docker socket/daemon is mounted for the dev service
(docker-compose.yml has none), and none is needed for `compose config`.

## Verification

1. `docker compose build dev` succeeds on the host (or `make up` with rebuild).
2. Inside poetry-dev: `command -v docker` and `command -v docker compose`
   both resolve.
3. `docker compose -f /workspace/docker-compose.yml config --quiet` exits 0
   inside the container (client-side validation, no daemon).
4. `make test-config` passes when delegated into the container via the
   pre-push path: `docker compose exec -T dev bash -lc "cd /workspace && make test-config"`.

## Fix

Applied 2026-08-13 (uncommitted, working tree; DIA-171 implementation + 6
reviewer findings):

1. Dockerfile.dev: new "=== Docker CLI + compose plugin (client only; no
   daemon) ===" RUN block after the base-packages RUN — installs docker-ce-cli
   - docker-compose-plugin from the Docker apt repo (download.docker.com),
     Debian suite `trixie` (matches the debian:13-slim base; verified via the
     repo Packages listing 2026-08-13).
2. Versions pinned to the exact pool versions:
   `docker-ce-cli=5:29.7.2-1~debian.13~trixie`,
   `docker-compose-plugin=5.4.0-1~debian.13~trixie` (floating apt versions
   contradict the image's pinned-version posture, line 17).
3. `--no-install-recommends` (matches the base-packages RUN; drops only
   recommendations — buildx/containerd/runc are not needed, client-only).
4. Client-only: no docker socket/daemon mounted (docker-compose.yml dev
   service has none) and none is needed for `docker compose config --quiet`
   (pure client-side YAML validation).
5. TLS-failure fallback procedure (documented, not a shell fallback — YAGNI
   until the failure occurs): if the image build fails at `apt-get update`
   against download.docker.com with a TLS cert error (documented for
   tools/opencode-docker, DIA-164), replace this apt install with the
   static-bundle path from tools/opencode-docker/Dockerfile (curl
   docker-<ver>.tgz + docker-compose binary from GitHub releases, SHA256-pinned,
   client-only extraction). The RUN block's `|| echo` diagnostic names the
   failure in the build log pointing here.

Status IMPLEMENTED — VERIFIED pending the host rebuild (`docker compose build
dev && docker compose up -d dev` or `make up`) and the in-container
`make test-config` proof (orchestrator).

## Re-verify

> To be filled at re-verify time.
