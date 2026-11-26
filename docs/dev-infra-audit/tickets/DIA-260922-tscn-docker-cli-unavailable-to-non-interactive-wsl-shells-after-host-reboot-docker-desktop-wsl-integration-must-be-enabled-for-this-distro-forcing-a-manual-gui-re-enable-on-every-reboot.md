# DIA-260922-tscn - Docker CLI unavailable to non-interactive WSL shells after host reboot: Docker Desktop WSL integration must be enabled for THIS distro, forcing a manual GUI re-enable on every reboot

---

id: DIA-260922-tscn
title: "Docker CLI unavailable to non-interactive WSL shells after host reboot: Docker Desktop WSL integration must be enabled for THIS distro, forcing a manual GUI re-enable on every reboot"
area: dev-infra
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-22
source: inventory
date: 2026-09-22
created: 2026-09-22
updated: 2026-09-22

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: []
artifacts: []
evidence: []

---

## Description

After a Windows host reboot the docker CLI is missing from non-interactive WSL
shells because Docker Desktop WSL integration is not enabled for this distro,
so the only remedy in the repo today is a manual GUI re-enable on every reboot.

## Problem

- Failure text (recorded verbatim in DIA-094): `docker --version` in the WSL
  distro prints `The command 'docker' could not be found in this WSL 2 distro.
We recommend to activate the WSL integration in Docker Desktop settings.` and
  exits 1 (`docs/dev-infra-audit/tickets/DIA-094-husky-precommit-wsl-docker-unavailable.md:105`).
  The same symptom and message are recorded in DIA-260920-ffuj's Fix block.
- The only documented remedy is manual and GUI-only:
  `Enable Docker Desktop WSL integration for this Ubuntu distro (Settings >
Resources > WSL integration, then start Docker Desktop)`
  (`docs/dev-infra-audit/tickets/DIA-094-husky-precommit-wsl-docker-unavailable.md:186-188`).
- No repo-side code re-enables integration or diagnoses the state:
  `scripts/compose-env.sh:64-65` only detects WSL and appends
  `docker-compose.wsl.yml`; `Makefile:48-49` (`up:` target) just runs
  `$(COMPOSE) up -d` and surfaces the raw docker-not-found failure.
- Impact: the DIA-094 pre-commit gate hard-fails without a reachable engine, so
  commits block until someone opens the Docker Desktop GUI (recorded impact in
  DIA-260920-ffuj: the gate blocked three commits on 2026-09-20/21).
- Reporter context for the "every reboot / non-interactive shell" recurrence is
  carried by the ticket title alone; commit `742c6e53` added only this ticket
  file plus the README rollup. Corroborating symptom and remedy evidence comes
  from DIA-094 and DIA-260920-ffuj as cited above.

## Verification

- [ ] On an affected host, running `make up` prints an actionable message that
      names the exact Docker Desktop GUI path (Settings > Resources > WSL
      integration) instead of only the raw compose failure.
- [ ] On a healthy host (integration enabled), `make up` behaviour is unchanged:
      `docker info --format '{{.ServerVersion}}'` exits 0 and both services come
      Up healthy.
- [ ] `docs/docker-dev.md` documents the post-reboot WSL step and names
      `docker info` (not `wsl.exe -l -v`) as the readiness signal, per the
      DIA-260920-ffuj quirk.
- [ ] No code path claims to re-enable WSL integration from inside the distro.

## Fix

Smallest concrete change (repo-side diagnosis, not automation - the GUI toggle
is outside repo control and no code today touches it):

1. `scripts/container-engine.sh` - when WSL is detected and `docker` is absent
   while Docker Desktop is present (dangling `/usr/bin/docker*` symlinks into
   `/mnt/wsl/docker-desktop/cli-tools`, per the DIA-260920-ffuj symptom list),
   fail early with the exact GUI path instead of letting compose fail opaquely.
2. `docs/docker-dev.md` - add a short "after host reboot (WSL)" note carrying
   the same instruction and the `docker info` readiness rule.

Relationship to DIA-260920-ffuj: from inside WSL the two states look identical
(dangling symlinks either way), and DIA-094:119-121 lists both causes for the
same error text. DIA-260920-ffuj's fix starts the stopped engine; this ticket
covers the residual state where the engine is up but integration is off for this
distro, so the message should name both steps in order: start Docker Desktop,
then re-enable WSL integration for this distro in Settings > Resources > WSL
integration.

Acceptance behaviour: the same host failure now names the manual re-enable step
in the first error line; healthy hosts see no change.

## Re-verify

Host-side, on the affected WSL distro:

    docker --version                 # exit 0 after the GUI re-enable
    docker info --format '{{.ServerVersion}}'   # readiness signal (NOT wsl.exe -l -v)
    make up                          # exit 0, poetry-dev + poetry-postgres Up healthy

Repo-side, that the diagnosis landed:

    grep -n "WSL integration" docs/docker-dev.md scripts/container-engine.sh
    bash scripts/container-engine.sh compose ps   # healthy host: exit 0
