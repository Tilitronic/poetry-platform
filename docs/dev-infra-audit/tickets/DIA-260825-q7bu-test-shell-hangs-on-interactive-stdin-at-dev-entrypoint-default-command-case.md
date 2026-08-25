# DIA-260825-q7bu - test-shell hangs on interactive stdin at dev-entrypoint default-command case

---

id: DIA-260825-q7bu
title: "test-shell hangs on interactive stdin at dev-entrypoint default-command case"
area: scripts
severity: Medium
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-25
source: inventory
date: 2026-08-25
created: 2026-08-25
updated: 2026-08-25

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

- RED->GREEN probe: `sleep 30 | bats --filter "succeeds when no command is passed" scripts/__tests__/dev-entrypoint.bats` exit 124 -> 0.
- Full suite `bash scripts/__tests__/bats-wrapper.sh` exit 0, 527 ok / 0 fail / 1 skip.
- Residue check clean (`ls -d /var/tmp/poetry-nsbin.*` -> empty).
- Commit 77ae58d, pre-commit hook green (poetry-dev container Up).

### Known ceilings (falsification residuals, review-dispositioned as accepted - do not fix)

- Hardcoded `/dev/null` leaves no stdin seam for future stdin-handling tests on this path.
- No per-test timeout: other blocking syscalls on the ns path would still hang the suite.

## Fix

`< /dev/null` appended to the `run unshare ...` invocation in both
`run_entrypoint_ns` (test-helper.bash:503) and `run_entrypoint_xvfb_ns`
(:526), with WHY comments. Root cause: no-arg entrypoint test execs bare
interactive bash via `set -- bash` (dev-entrypoint.sh:59-61); bats run()
inherits stdin; live TTY -> block at case 166.

Closure note (review finding F2): verify-pre-commit-uid-mismatch.bats passes
an explicit command and was never at risk - it INHERITS the guard defensively
via the shared helper; it was not "fixed".

## Re-verify

> To be filled at re-verify time.
