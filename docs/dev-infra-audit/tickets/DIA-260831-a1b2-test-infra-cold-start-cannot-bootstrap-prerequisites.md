# DIA-260831-a1b2 - Test infra cold start cannot bootstrap prerequisites

---

id: DIA-260831-a1b2
title: "Test infra cold start cannot bootstrap prerequisites"
area: tests-infra
severity: High
status: OPEN
blocked_by: []
parent_epic: DIA-260827-wfcx
gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered: 2026-08-31
source: inventory
date: 2026-08-31
created: 2026-08-31
updated: 2026-08-31

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: []
artifacts: []
evidence: []

---

## Description

Reaudit (DIA-260827-wfcx, 2026-08-31; T-H2) evidence: Makefile:141-144,303-305 runs the container-dependent test-harness before scripts/test-docker-smoke.sh; scripts/**tests**/harness-scenario-replay.bats:30-37 calls 'docker compose exec'; a cold probe exited 2 with 3/3 scenarios failing on 'service dev is not running'. Impact: the documented full infra gate does not bootstrap its own prerequisites. Correct fix: bring the stack up before the harness, or run the harness after a single smoke bring-up; protect teardown with an EXIT trap.

## Verification

Run make test-infra from a cold state (no running dev container); assert it brings the stack up and all scenarios pass; verify teardown on failure.

## Fix

Reorder the test-infra recipe so the docker stack is brought up (single smoke bring-up) before the harness runs; wrap bring-up/test/teardown in one shell with an EXIT trap that always tears down.

## Re-verify

> To be filled at re-verify time.
