# DIA-260914-4s66 - Avoid rootless Podman remap of host git ownership during entrypoint startup

---

id: DIA-260914-4s66
title: "Avoid rootless Podman remap of host git ownership during entrypoint startup"
area: docker
severity: Critical
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-14
source: fix-lane
date: 2026-09-14
created: 2026-09-14
updated: 2026-09-14

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

Calling `scripts/container-engine.sh compose ...` directly did not populate
`COMPOSE_FILE`, unlike Makefile callers. A Podman rebuild/recreate therefore
omitted `docker-compose.podman.yml`, ran without `keep-id`, and the root
entrypoint's `chown dev:dev /workspace/.git` mapped the host repository to
subuid 525287. Host Git then failed with `dubious ownership`.

The adapter must resolve the same engine/OS compose overlay when a direct CLI
caller has not already supplied `COMPOSE_FILE`. The entrypoint ownership repair
remains valid under the intended keep-id mapping.

## Verification

- [x] Direct `COMPOSE_ENGINE=podman container-engine.sh compose` exports the
      Podman compose overlay when `COMPOSE_FILE` is initially unset.
- [x] Makefile behavior and explicit caller-provided `COMPOSE_FILE` remain
      unchanged.
- [x] Recreated Podman container reports host/container user `dev`, and host
      `.git` remains owned by UID/GID 1000:1000.
- [x] Focused adapter tests and full shell suite pass.

## Fix

Added a direct-call fallback inside `container_engine_compose`: resolve
`COMPOSE_FILE` through the existing Docker-free `compose-env.sh` only when the
caller did not provide it. Added a regression probe for the Podman overlay.

## Re-verify

- Restored `.git` from host subuid 525287 to host 1000:1000 via
  `podman unshare chown -R 0:0 .git`.
- Correct `COMPOSE_ENGINE=podman make up` recreation reports
  `userns=private`, configured user `1000:1000`, and `podman top` maps the
  process to host user `dev`; `.git` remains 1000:1000.
- Post-fix adapter/pre-commit suite: 31/31; full `make test-shell`: 684/684;
  `bash -n` and `git diff --check`: exit 0.
- Independent review: PASS. Caller-provided `COMPOSE_FILE` is preserved,
  `compose-env.sh` introduces no recursion, live Podman config contains
  `keep-id`, the container is healthy, and host `.git` remains 1000:1000.
