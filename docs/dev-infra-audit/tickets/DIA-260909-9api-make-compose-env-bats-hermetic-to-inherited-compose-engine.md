# DIA-260909-9api - make compose-env.bats hermetic to inherited COMPOSE_ENGINE

---

id: DIA-260909-9api
title: "make compose-env.bats hermetic to inherited COMPOSE_ENGINE"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-09
source: inventory
date: 2026-09-09
created: 2026-09-09
updated: 2026-09-10

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

Symptom: an inherited `COMPOSE_ENGINE=podman` in the shell environment breaks
the default-docker cases in `compose-env.bats` (scripts/**tests**/compose-env.bats),
which expect the variable to be absent. The helper's Podman override itself
is correct -- env has top priority by design -- so the tests, not the
helper, need to change.

Fix direction: clear/unset `COMPOSE_ENGINE` in the default/no-client tests,
and set it explicitly only in the override cases.

Context: found during DIA-260909-zeik 'scenario-cleanup-gate' closure; out
of zeik scope. Zeik CLOSED at 5d9fc90.

## Verification

- [ ] Plain `make test-shell` is green on a Podman host
      (`COMPOSE_ENGINE=podman` inherited in the environment).
- [ ] Plain `make test-shell` is green on a docker host (var absent).

## Fix

Implemented 2026-09-10 (coder lane, campaign ticket DIA-260909-9api).

- `setup()` at scripts/**tests**/compose-env.bats:56-58 unsets inherited
  COMPOSE_ENGINE (`unset COMPOSE_ENGINE || true`), so the default-docker
  cases no longer see a caller-inherited `COMPOSE_ENGINE=podman`.
- Explicit exports only in the override cases at lines 210-219, 254-263,
  and 314-320 (`export COMPOSE_ENGINE=podman` before invoking the helper),
  covering the Podman-override contract paths.
- Helper contract unchanged: scripts/compose-env.sh:16 keeps override-wins
  by design (env has top priority); tests changed, not the helper.
- Path drift fixed in this ticket Description: stale relative test path
  corrected to `scripts/__tests__/compose-env.bats`.

## Re-verify

Re-verified and closed 2026-09-10 (developer accepted as ready-to-close).

- Focused `vendor/bats-core/bin/bats scripts/__tests__/compose-env.bats`:
  15/15 PASS, EXIT 0 each, in 3 variants: baseline (var unset),
  COMPOSE_ENGINE=podman inherited, and `env -u COMPOSE_ENGINE`.
- Full `make test-shell`: EXIT 0, 638 pass / 0 fail (host-side run;
  poetry-dev container DOWN at verify time).
- Reviewer rev-1 two-axis: 0 findings Standards + 0 Spec (falsification
  notes F1-F3 only, non-blocking).
- Close: status CLOSED 2026-09-10 per developer ready-to-close decision.
