# DIA-260929-yhmd - make test-harness: skip the engine-dependent phase in-container instead of exiting 2

---

id: DIA-260929-yhmd
title: "make test-harness: skip the engine-dependent phase in-container instead of exiting 2"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-29
source: inventory
date: 2026-09-29
created: 2026-09-29
updated: 2026-09-29

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

- Symptom: `make test-harness` exits non-zero when run inside the dev container.
- Evidence: the bats phase completes (6 ok / 0 not ok / 3 skipped, each skip
  reading "selected container engine unavailable"), then the engine-dependent
  phase fails with `scripts/container-engine.sh: line 91: docker: command not
found` and `make: *** [Makefile:372: test-harness] Error 127`.
- Root cause class: the dev session runs INSIDE the `poetry-dev` container and
  neither the container-engine CLI nor its socket is mounted into it. Per
  AGENTS.md section 6 and DIA-094, a daemon or socket must never be probed
  from inside the container.
- Required behaviour: when the engine is genuinely unavailable AND we are
  inside the dev container, `make test-harness` must SKIP the engine-dependent
  phase with an explicit notice naming the reason and exit 0 - a correct,
  passing result. Reuse the skip mechanism the bats scenarios already use
  ("selected container engine unavailable") rather than inventing a second one.
- Must NOT weaken the gate: on the host, where docker or podman IS available,
  the engine-dependent checks must still run and must still fail on a real
  engine-side failure. Detection must key off the established in-container
  detection (scripts/in-container.sh) plus engine availability, never a
  blanket waiver.
- Boundary: `make test-infra` is the separate host-run target that requires a
  live container engine. This change must not blur the two targets or make
  test-infra pass in-container.
- Reference: AGENTS.md section 6 (gates table), DIA-094.

## Verification

- [ ] In-container (engine absent, in-container detection true): `make test-harness` exits 0 with an explicit skip notice naming the reason.
- [ ] Host-side (engine present): the engine-dependent checks still execute, and a genuine engine-side failure still fails the target.
- [ ] The skip path is covered by a test - a bats case asserting the skip is taken and the exit code is 0 when the engine is unavailable from inside the container.
- [ ] `make test-config` and `make test-shell` still exit 0.
- [ ] No container-engine binary is required at config-validation time.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
