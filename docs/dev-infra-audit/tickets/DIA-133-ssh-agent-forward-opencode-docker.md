# DIA-133 - Forward host SSH agent socket into opencode-docker so git push works from the container (SSH agent forwarding)

<!-- Docs-lane ticket (no implementation in this dispatch). Research recipe
     (2026-08-13, two researcher lanes, 20+ sources) produced the exact fix
     steps in the Fix section; implementation is a separate dispatch. -->

---

id: DIA-133
title: "Forward host SSH agent socket into opencode-docker so git push works from the container (SSH agent forwarding)"
area: docker
severity: Major
status: OPEN
blocked_by: []
discovered: 2026-08-13
source: research-lane
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
files_touched: [docs/dev-infra-audit/tickets/DIA-133-ssh-agent-forward-opencode-docker.md, docs/dev-infra-audit/tickets/README.md]
artifacts: []
evidence: []

---

## Description

The developer works inside `tools/opencode-docker` and wants to `git push` FROM
the container. Today the container has no SSH agent access, so any push that
needs SSH auth (private GitHub repos, the repo's SSH remotes) fails.

The wrapper (`tools/opencode-docker/bin/opencode-docker`) already runs with
`--userns=keep-id` and `--security-opt label=disable` (DIA-121), which satisfy
the two blockers for socket forwarding on Fedora + SELinux:

1. unix-socket permissions (host uid 1000 -> container uid 1000 via keep-id);
2. the SELinux connectto denial (label=disable).

Research (2026-08-13, two researcher lanes, 20+ sources) confirmed the recipe:

- Add an SSH_MOUNT detection loop mirroring the existing SOCKET_MOUNT block in
  `bin/opencode-docker`.
- Detect `$SSH_AUTH_SOCK` (or `${XDG_RUNTIME_DIR}/keyring/ssh`, `/gcr/ssh`),
  mount it read-only at `/tmp/ssh-agent.sock` (the rootfs is `--read-only` but
  `/tmp` is a writable tmpfs), set `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` via
  EXTRA_ENV, warn-and-continue when no socket is found.
- Keys never leave the host: agent forwarding only, no `~/.ssh` mount.

Only opencode-docker needs this: poetry-dev's delegated gates (make
test-shell/test-config via `docker compose exec`) need no git auth.

Security profile is identical to the already-accepted DIA-121 docker-socket
risk (a host socket forwarded into the container; the container already holds
host container-management rights via the DIA-121 docker.sock mount).

## Verification

1. Rebuild + relaunch: `make build` then `bin/opencode-docker`.
2. Inside the container: `echo $SSH_AUTH_SOCK` resolves to `/tmp/ssh-agent.sock`
   and `ssh-add -l` lists the host's keys.
3. `git push` of a test branch from inside the container succeeds (SSH remote).
4. `ssh -T git@github.com` returns the authenticated greeting.
5. When the host has no agent running, the wrapper prints the documented
   no-agent warning and still starts the container (warn-and-continue).

## Fix

> Research-produced recipe (2026-08-13), implementation is a separate dispatch:

1. `bin/opencode-docker`: add an SSH_MOUNT detection loop after the
   SOCKET_MOUNT block (~line 153) — detect `$SSH_AUTH_SOCK` (fallbacks:
   `${XDG_RUNTIME_DIR}/keyring/ssh`, `/gcr/ssh`), mount read-only at
   `/tmp/ssh-agent.sock`, wire `"${SSH_MOUNT[@]}"` into the podman run line
   (~line 179). Set `SSH_AUTH_SOCK=/tmp/ssh-agent.sock` via EXTRA_ENV. Warn
   and continue when no socket is found. Mirror the SOCKET_MOUNT loop's
   structure (detect -> mount -> env -> warn-and-continue).
2. Optionally: `GIT_SSH_COMMAND="-o StrictHostKeyChecking=accept-new"` env
   (known_hosts on the read-only `/app` cannot be written) — decide during
   implementation.
3. Docs: `tools/opencode-docker/AGENTS.md` option header + README note about
   the no-agent warning and the requirement that the host GNOME
   keyring/ssh-agent must be unlocked.

## Re-verify

> To be filled at re-verify time.
