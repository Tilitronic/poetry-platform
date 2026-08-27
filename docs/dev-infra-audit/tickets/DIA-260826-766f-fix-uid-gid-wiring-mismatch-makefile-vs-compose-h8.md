# DIA-260826-766f - fix UID/GID wiring mismatch Makefile vs compose (H8)

---

id: DIA-260826-766f
title: "fix UID/GID wiring mismatch Makefile vs compose (H8)"
area: dev-infra
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260825-wprb
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
date: 2026-08-26
created: 2026-08-26
updated: 2026-08-26

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

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

Acceptance criteria (RED -> GREEN):

- RED: tests 8/9/10 added to scripts/**tests**/compose-env.bats asserting the
  Fedora regression (separate docker CLI + COMPOSE_ENGINE=podman -> podman
  override), the ambiguous-autodetection stderr WARNING (mentioning
  COMPOSE_ENGINE) defaulting to docker, and the parity divergence.
- GREEN: `make test-shell` (bats, Docker mocked, host-runnable) -> 15/15 PASS,
  exit 0; tests 9/10 now GREEN. The warning no longer breaks the COMPOSE_FILE
  assertions (tests 2/4 use `run --separate-stderr`).
- design.md claims 4 (methods DIVERGE on Fedora) and 8 (.sdd/dev-infra/
  architecture.md exists) corrected; tasks.md all 7 checkboxes ticked;
  .env.example documents COMPOSE_ENGINE=podman|docker.

Secondary gate `make test-config` (docker compose config --quiet) validates the
merged engine-aware stack; BLOCKED if docker daemon is down (bats is
host-runnable and does not need it).

## Fix

Warning added in commit 07623ee8eae7a2b4c7ba41624840ad3c7a363532.

scripts/compose-env.sh: in the engine-detection block, when a docker CLI is
detected that is NOT a podman shim (readlink -f resolved path does not contain
"podman") and COMPOSE_ENGINE is unset, print a stderr WARNING mentioning
COMPOSE_ENGINE and default to docker. The helper stays docker-free: the probe
uses only command -v + readlink -f, never invoking the daemon.

This fixes the Fedora divergence: scripts/opencode-dev's `docker version` grep
sees a Podman server behind a docker CLI, but the helper's readlink-only probe
cannot, so it now warns (instead of silently defaulting) and the operator sets
COMPOSE_ENGINE=podman explicitly.

## Re-verify

make test-shell (scripts/**tests**/compose-env.bats, Docker mocked, host-runnable)
-> 15/15 PASS, exit 0.

Tests 8/9/10 GREEN:

- ok 8 FEDORA REGRESSION: separate docker CLI (not podman shim) +
  COMPOSE_ENGINE=podman -> podman override
- ok 9 AMBIGUOUS autodetection warns to stderr mentioning COMPOSE_ENGINE and
  defaults to docker
- ok 10 PARITY: ambiguous docker (podman-backed) diverges without
  COMPOSE_ENGINE, agrees with it

The warning no longer breaks the COMPOSE_FILE assertions: tests 2/4 use
`run --separate-stderr` so stderr is captured separately from stdout, keeping
the existing assertions identical.

Secondary gate `make test-config` (docker compose config --quiet) is BLOCKED:
docker daemon is down in this environment. bats is host-runnable and does not
require the daemon; the merged-stack validation must be re-run where a daemon
is available.
