# DIA-260912-y2uo - Podman support for DIA-094: container-engine adapter with engine-neutral checks, hard-fail preserved

---

id: DIA-260912-y2uo
title: "Podman support for DIA-094: container-engine adapter with engine-neutral checks, hard-fail preserved"
area: scripts
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-12
source: inventory
date: 2026-09-12
created: 2026-09-12
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

Host operations and DIA-094 assumed Docker even when the supported runtime was
Podman. This produced false daemon-unavailable blockers and let direct engine
calls drift across Makefile and shell entry points. The accepted design uses
one Bash-3 adapter with explicit `COMPOSE_ENGINE=docker|podman`, safe
autodetection when unset, native compose for the selected engine, and no
cross-engine fallback.

## Verification

- [x] Explicit Docker and Podman selection plus daemon-free autodetection.
- [x] Host compose config/up/down/exec and readiness checks route through one
      adapter; in-container behavior stays unchanged.
- [x] DIA-094 requires engine reachability, running `dev`, and
      `compose exec -T dev true`, with distinct hard-fail diagnostics.
- [x] Focused adapter/pre-commit/pre-push Bats pass and a real Podman gate sees
      the current dev service.
- [x] Independent review and closure bookkeeping complete.

## Fix

Commit `0594094` introduced `scripts/container-engine.sh`, migrated all scoped
host-side callers, and added the command-recording Bats matrix. The selected
engine is authoritative and failures never switch engines automatically.

## Re-verify

- Focused adapter/pre-commit/pre-push matrix: 46/46 pass before the current
  follow-up; expanded related matrix: 65/65 pass on 2026-09-13.
- Real Podman gate: selected engine ready, dev running, non-mutating exec
  succeeds.
- `make test-config`: exit 0, 57/57.
- Full `make test-shell`: exit 0, 683/683 Bats passed. The rebuilt container
  supplies the pinned rust-analyzer, and the remaining scenario replay harness
  now uses the selected engine adapter instead of a direct Docker call.
- Initial independent review found three remaining direct host callers:
  `scripts/opencode-dev`, `scripts/eval-lite.sh`, and
  `scripts/check-host-lsp.sh`. The fix routes all three through the adapter
  while preserving soft-unavailable and host-fallback behavior.
- Targeted re-review cycle 1/2: PASS; prior finding verified closed. Expanded
  exact Bats matrix: 56/56; `bash -n`: exit 0; live Podman reachability,
  running-service, and exec gate: PASS; reviewed `git diff --check`: exit 0.
