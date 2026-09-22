# WSL compose override: empty `services.dev: {}` mapping preserves base merge (2026-08-24)

- **Date:** 2026-08-24
- **Source:** ai-specialist read-only research (DIA-260824-a3mk gate step); validated against the existing `docker-compose.wsl.yml` (line 14 `dev: {}`) and `scripts/__tests__/compose-overrides.bats` (WSL merge test at lines 160-164).
- **Status:** REGISTERED - learning-registration only; no implementation edits (docker-compose.wsl.yml / bats / Dockerfile / entrypoint / Makefile / ticket / changelog untouched per DIA-260824-a3mk scope).
- **Outcome note:** PENDING - implementation deferred to the fix lane; this entry captures the validated WSL compose-override finding so the fix lane implements against a confirmed model.

## Ticket

- **DIA-260824-a3mk** (Blocker, OPEN) - "make opencode fails: PermissionDenied opening /home/dev/.local/share/opencode/log/opencode.log". This entry covers the WSL compose-override sub-finding of that ticket (Slice 2 / engine-specific override design, DIA-260821-x5nj lineage).

## Finding

- The WSL overlay must declare the `dev` service as an **empty mapping** (`services: dev: {}`), NOT as a bare `dev: null`. A bare `null` value drops/empties the service key in the merged model and can break the base merge; the empty mapping is a no-op overlay that preserves every base `docker-compose.yml` field (volumes/ports/environment/secrets/command) for the `dev` service.
- The WSL overlay stays **engine-agnostic**: it declares NO `user`, `userns_mode`, or `security_opt` flags. Those are engine-specific and belong only to the Podman (`userns_mode: keep-id` + `security_opt: [label=disable]`) and rootless-Docker (`user: "0:0"`) overrides. The WSL file is a pure runtime-tuning overlay applied on top of the base.
- The **combined Docker + Podman keep-id merge must be verified**: `docker compose config -f docker-compose.yml -f docker-compose.podman.yml -f docker-compose.wsl.yml` must succeed AND the merged model must still contain the `dev` service. keep-id changes the uid mapping under Podman, so the merge must be exercised under Podman (not only Docker) before merge.
- The **merge test should assert `dev` service presence without over-constraining output**: the bats `docker compose config` test should confirm the merged config contains the `dev` service (e.g. grep the rendered config for `dev:`) rather than only asserting exit 0, but it must NOT pin exact formatting/ordering of the merged YAML (that over-constrains GREEN and is daemon-version-fragile). Assert presence, not shape.

## Pattern

- WSL overlay = `services: dev: {}` (empty mapping, base merge preserved).
- WSL overlay = engine-agnostic (no `user` / `userns_mode` / `security_opt`).
- Verify the 3-file merge (base + podman + wsl) under Podman keep-id; assert `dev` service presence, not exact output shape.

## Outcome

- PENDING - registration only; implementation (if any WSL-override change is needed) deferred to the fix lane. The current `docker-compose.wsl.yml` already uses `dev: {}` and the bats merge test already exists (exit-0 only) - the fix lane should add the `dev`-presence assertion per the pattern above.

## Reusable lesson

- For a compose override that must NOT alter a base service, use an empty mapping (`dev: {}`), never `dev: null` - null can drop the key and break the merge. Keep engine-specific flags (user/userns/security) out of engine-agnostic overlays, and make merge tests assert service presence without pinning rendered YAML shape.

## Tags

DIA-260824-a3mk, DIA-260821-x5nj, wsl, compose-override, dev-empty-mapping, base-merge, engine-agnostic, podman-keep-id, compose-merge-test, docker-gate
