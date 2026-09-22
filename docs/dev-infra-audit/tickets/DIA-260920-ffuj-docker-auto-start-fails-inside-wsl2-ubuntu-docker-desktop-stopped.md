# DIA-260920-ffuj - docker auto-start fails inside WSL2 Ubuntu - docker-desktop Stopped

---

id: DIA-260920-ffuj
title: "docker auto-start fails inside WSL2 Ubuntu - docker-desktop Stopped"
area: docker
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-20
source: inventory
date: 2026-09-20
created: 2026-09-20
updated: 2026-09-20

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
evidence:

- ses_f41c4d5e7ffeShqAPaxG9z5l5y: wsl.exe -l -v Ubuntu Running v2, docker-desktop Running v2 (was Stopped)
- ses_f41c4d5e7ffeShqAPaxG9z5l5y: /mnt/wsl/docker-desktop present, cli-tools binary exists, /usr/bin/docker symlinks valid
- ses_f41c4d5e7ffeShqAPaxG9z5l5y: docker --version exit 0 (29.6.1 build 890f1d), docker info exit 0, docker context ls exit 0
- ses_f41c4d5e7ffeShqAPaxG9z5l5y: make up exit 0, compose ps poetry-dev Up healthy (29s, DIA-174 R3), poetry-postgres Up healthy
- ses_f4170446dffeC7GGs2UXWq1G6G: make test-config exit 0 (1168-line log; compose config leg that failed at Makefile:220 when docker absent now PASSES)
- ses_f4170446dffeC7GGs2UXWq1G6G: make test-infra exit 2 at test-shell prerequisite: 698 ok / 19 not ok; smoke + test-python legs never ran
- ses_f4170446dffeC7GGs2UXWq1G6G: docker compose ps: poetry-dev + poetry-postgres both Up healthy (2h uptime)
- ses_f4170446dffeC7GGs2UXWq1G6G: Bats delta vs 694/23 baseline: tests 195,196,197,198 (docker compose config merges) now PASS; remaining 19 are host-tooling (podman override files, bun missing, preset store)
- ses_f4170446dffeC7GGs2UXWq1G6G: Status stays OPEN until merge-gate consumer confirms; close decision belongs to developer

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Symptom: every docker invocation prints The command docker could not be found in this WSL 2 distro, enable WSL integration. make up fails Makefile:48 Error 1.

Evidence from ses_f42232feaffecbGGs5TesMQjWb: which docker resolves to Windows shim, docker --version/info/compose ps exit 1, /usr/bin/docker symlinks dangling to missing /mnt/wsl/docker-desktop/cli-tools, /mnt/wsl has only resolv.conf, wsl.exe -l -v shows docker-desktop Stopped, no systemd docker.service, no podman fallback, companion drift rust-analyzer 1.83.0 and bun missing 127.

Root cause: Docker Desktop WSL backend stopped plus orchestrator bash deny by design so no lane can start Windows-side service.

Fix: developer starts Docker Desktop, enables WSL integration for Ubuntu, verifies docker --version exit 0 and docker compose ps, then make up and record compose ps Up evidence per DIA-174 R3.

Severity: Major, blocked verification and merge gate.

## Re-verify

Recovery evidence from ses_f41c4d5e7ffeShqAPaxG9z5l5y (2026-09-20):

1. wsl.exe -l -v: Ubuntu Running v2, docker-desktop Running v2 (was Stopped).
2. /mnt/wsl/: docker-desktop mount present; cli-tools docker binary exists; /usr/bin/docker\* symlinks valid (was dangling).
3. docker --version exit 0: 29.6.1 build 890f1d.
4. docker info exit 0: Server Docker Desktop, Kernel 6.18.33.2-microsoft-standard-WSL2.
5. docker context ls exit 0: default + desktop-linux endpoints present.
6. make up (timeout 120) exit 0: poetry-postgres Healthy, poetry-dev Started.
7. docker compose ps post-up exit 0: poetry-dev Up healthy, poetry-postgres Up healthy. DIA-174 R3: poetry-dev Up 29 seconds (healthy).

Status: keep OPEN until merge-gate consumer confirms; merge phase unblocked.
