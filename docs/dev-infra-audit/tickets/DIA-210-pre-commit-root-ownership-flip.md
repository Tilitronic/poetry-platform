---
id: DIA-210
title: 'Fix pre-commit root:root ownership flip in Docker container'
status: CLOSED
updated: 2026-08-19
area: dev-infra
severity: Medium
created: 2026-08-17
---

## Problem

docker-compose.yml line 30 has `user: '0:0'` (forces root), which overrides
Dockerfile.dev's `USER ${USER_UID}:${USER_GID}` (1000:1000). When
lint-staged runs via `docker compose exec -T dev`, it runs as root (UID 0),
and `prettier --write` rewrites staged files with root:root ownership on the
host bind mount.

This was a leftover from before DIA-185's `safe.directory` bake landed.
The safe.directory config already handles the git dubious-ownership concern.

## Fix

Remove `user: '0:0'` from docker-compose.yml line 30.

## Acceptance Criteria

1. `docker compose up -d` starts the dev container as UID 1000 (not root)
2. `docker compose exec dev id` shows uid=1000
3. Pre-commit hook runs lint-staged without flipping file ownership
4. `make test-infra` passes
5. `make test-shell` passes

## Verification

- `docker compose exec dev id` returns uid=1000 gid=1000
- `docker compose exec dev git config --get safe.directory` returns /workspace
- `make test-infra` exit 0
- `make test-shell` exit 0

## Implementation Complete

- **Change:** `user: '0:0'` removed from docker-compose.yml line 30
- **Effect:** dev container now runs as UID 1000 (Dockerfile.dev's `USER 1000:1000`)
- **Verified:** `docker compose config` shows no `user:` directive; config parses clean; services list unchanged

## Updates

- status DONE -> CLOSED 2026-08-19 (fix applied and verified, ticket closure administrative)
