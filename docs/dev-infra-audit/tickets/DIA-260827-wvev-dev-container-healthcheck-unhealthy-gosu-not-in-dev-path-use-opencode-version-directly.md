# DIA-260827-wvev - dev container healthcheck unhealthy: gosu not in dev PATH, use opencode --version directly

---

id: DIA-260827-wvev
title: "dev container healthcheck unhealthy: gosu not in dev PATH, use opencode --version directly"
area: dev-infra
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: inventory
date: 2026-08-27
created: 2026-08-27
updated: 2026-08-27

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

Reaudit (DIA-260827-wfcx, 2026-08-31; W-M8) confirms Dockerfile.dev:349-350 runs 'gosu dev opencode --version'; the running container has Config.User=1000:1000, so gosu fails 'operation not permitted'; direct opencode --version returns 1.18.18. Real root cause: a repeated privilege drop (gosu) under an already-unprivileged user 1000:1000, not just a PATH issue. Impact: automation and developers read a healthy OpenCode as a broken stack. Correct fix: run the healthcheck directly as the configured user; after rebuild verify on Fedora Podman and WSL Docker.

## Verification

docker inspect shows Config.User 1000:1000; container health becomes healthy; direct 'opencode --version' returns exit 0.

## Fix

Run the healthcheck as the already-unprivileged configured user (drop the redundant gosu dev wrapper); after rebuild verify on Fedora Podman and WSL Docker.

## Re-verify

> To be filled at re-verify time.
