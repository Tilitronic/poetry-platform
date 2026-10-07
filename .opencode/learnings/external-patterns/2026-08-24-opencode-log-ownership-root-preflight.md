# OpenCode log ownership / root preflight privilege model (2026-08-24)

- **Date:** 2026-08-24
- **Source:** ai-specialist read-only research (DIA-260824-a3mk gate step); developer grilling interview confirmed the decision.
- **Status:** REGISTERED - pre-implementation registration only; no implementation edits yet (Dockerfile.dev / dev-entrypoint.sh / Makefile / compose files untouched per DIA-260824-a3mk scope).
- **Outcome note:** privilege-model decision confirmed for the DIA-260824-a3mk fix; implementation deferred to the fix lane.

## Ticket

- **DIA-260824-a3mk** (Blocker, OPEN) - "make opencode fails: PermissionDenied opening /home/dev/.local/share/opencode/log/opencode.log".
- **Related:** DIA-104 (grilling gate - this change is cross-cutting + hard-to-reverse, gate grilled), DIA-094 (docker gate), DIA-260823-v9di (blocked by the log-permission defect), DIA-260822-oldn (same container-lifecycle / file-ownership class).

## Topic

- Container privilege model for the poetry-dev runtime: how the OpenCode log path becomes writable by the `dev` user without leaving the container running as root, and how to verify it under both Docker and Podman.

## Finding

- The OpenCode log path `/home/dev/.local/share/opencode/log/opencode.log` is created root-owned (image build as root, or a prior root run), so the runtime `dev` user cannot append and OpenCode aborts with `PermissionDenied`. Root cause is at the shared creation point, not per-invocation. The fix must re-own only the state dirs and drop to `dev` via the entrypoint; it must NOT set a compose `user:` field, and it MUST be verified under Podman (keep-id uid mapping), not only Docker.

## Pattern

- **Root-owned log evidence:** the log path / its parent dirs are owned by a different uid/gid than the runtime `dev` user (created during image build as root, or by a prior root run); the append open fails because of that ownership mismatch, not because of missing dirs.
- **Narrow state chown:** `chown` ONLY the specific state directories (`/home/dev/.local/share/opencode` and its `log/` subdir) to the `dev` uid/gid - NOT the whole home tree.
- **Root entrypoint then gosu dev:** the entrypoint runs as root only long enough to chown the state dirs, then drops to `dev` via `gosu` for the rest of the process lifetime. No persistent root.
- **No compose service user:** do NOT set a `user:` service field in docker-compose.yml; drop privilege in the entrypoint instead.
- **Makefile --user dev:** `make opencode` already execs OpenCode inside the container as `--user dev` - confirmed correct, keep it.
- **Podman keep-id verification requirement:** under Podman the host uid is mapped via `--userns=keep-id`, so the chown target uid differs from Docker; the chown/entrypoint strategy MUST be verified under Podman (not only Docker) before merge.
- **Q4 correction:** an earlier Q4 audit note implied a compose `user:` field was acceptable - that is wrong; privilege drop belongs in the entrypoint only.

## Outcome

- Decision confirmed via developer grilling (DIA-104 gate, gate_state: grilled, gate_triggers: cross-cutting + hard-to-reverse). Implementation deferred to the fix lane; this registration captures the ai-specialist findings so the fix lane implements against a confirmed model.

## Reusable lesson

- When a runtime log/config path is root-owned but the app runs as a non-root user, fix ownership at the single shared creation point (entrypoint chown) and drop privilege there - never scatter sudo into every invocation, never set a compose `user:` as a substitute, and always verify uid mapping under both Docker and Podman (keep-id) before merge.

## Tags

DIA-260824-a3mk, DIA-104, DIA-094, DIA-260823-v9di, DIA-260822-oldn, privilege-model, root-owned-log, gosu, chown, podman-keep-id, compose-user, docker-gate
