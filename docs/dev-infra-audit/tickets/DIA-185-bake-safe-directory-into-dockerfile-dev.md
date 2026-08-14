# DIA-185 - bake safe.directory=/workspace into Dockerfile.dev (container gitconfig ephemeral repair)

<!-- Filed 2026-08-15 (ticket-filing lane, agent: coder, session
     ses_ffd82bed7ffeyOGA03b2t3D4Hg). DOCUMENTATION-ONLY: defect filed from
     evidence gathered during this session's reconciliation work (cod-7
     ses_ffde3ced9ffe5Yx7IcgsJEvBLa reconciliation report anomaly 2). Fix is
     queued for the next session. ASCII-only per DIA-079. -->

---

id: DIA-185
title: "bake safe.directory=/workspace into Dockerfile.dev (container gitconfig ephemeral repair)"
area: docker
severity: Low
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-15
source: test-lane
date: 2026-08-15
created: 2026-08-15
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_ffd82bed7ffeyOGA03b2t3D4Hg"
lane_id: "tf-1"
agent: "coder"
model: ""
parent_session_id: "ses_ffe359d8bffegJun06OC9Wg749"
attempts: 0
lease_expires_at: "" # ISO-8601; set on DISPATCHED, cleared on COMPLETE
files_touched: ["docs/dev-infra-audit/tickets/DIA-185-bake-safe-directory-into-dockerfile-dev.md"]
artifacts: []
evidence: ["cod-7 reconciliation report anomaly 2 (ses_ffde3ced9ffe5Yx7IcgsJEvBLa): test-shell 2/325 failures, bats 280/289", "Dockerfile.dev:298 existing `RUN git config --global --add safe.directory /workspace` pattern (committed)"]

---

## Description

The dev container runs as root (user '0:0') against a dev-owned repo, so
git's dubious-ownership check (`git config --global --add safe.directory` in
the container's user gitconfig) does not cover repos where the owner differs
from the container user. Observed failures occur inside bats tests that drop
the global safe.directory into a temp HOME: `make test-shell` failed 2/325,
bats 280/289 (cod-7 reconciliation report anomaly 2).

Cod-7 repaired the CONTAINER ENVIRONMENT (ephemeral) by adding
`safe.directory = /workspace` to `/etc/gitconfig`, which survives until the
container is RECREATED - it is not durable. The durable fix is to bake the
config line into `Dockerfile.dev`, which already carries an analogous
system-gitconfig setup at line 298:

    Dockerfile.dev:298
    RUN git config --global --add safe.directory /workspace

Note: the existing line uses `--global` (per-user gitconfig), which is
precisely what the bats temp-HOME tests bypass. The durable fix should target
the system-level gitconfig (mirroring the /etc/gitconfig repair cod-7 made)
so the setting survives HOME swaps AND container recreation.

## Verification

Reproduce the bats failure inside the container (before fix):

    docker compose exec dev make test-shell

Expected (bug): 2/325 failures / bats 280/289 from dubious-ownership in
temp-HOME bats tests.

Confirm the repair is currently ephemeral (holds until recreation):

    docker compose exec dev git config --system --list   # shows safe.directory
    docker compose restart dev
    docker compose exec dev git config --system --list   # entry gone after recreate

Proves the setting only exists via the runtime /etc/gitconfig repair, not the
image.

## Fix

<What changed — fill at fix time. Leave blank with this note until then.>

> To be filled at fix time.

Suggested direction (owned by the next session): add the safe.directory line
to the Dockerfile.dev system-gitconfig setup so the image carries it (e.g.
system-level `git config --system --add safe.directory /workspace` or an
/etc/gitconfig block, mirroring the Dockerfile.dev:298 pattern). The exact
placement, image rebuild, and gate re-verification are queued for the next
session.

## Re-verify

<Result of re-running Verification after the fix — fill at re-verify time.
Must include the actual gate output/exit code that proves VERIFIED.>

> To be filled at re-verify time.
