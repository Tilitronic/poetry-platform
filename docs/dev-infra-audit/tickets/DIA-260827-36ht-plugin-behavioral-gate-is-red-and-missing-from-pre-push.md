# DIA-260827-36ht - Plugin behavioral gate is red and missing from pre-push

---

id: DIA-260827-36ht
title: "Plugin behavioral gate is red and missing from pre-push"
area: plugins
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260827-wfcx
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-27
source: baseline
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

needs-input-observer.dia189.test.mjs:412-503 has six desktop-toast tests requiring a captured PowerShell spawn; production now skips that channel on pure Linux at needs-input-observer.ts:736-740, but the old harness never opens the WSL/Windows gate. Direct plugin suite exits 1 (145 pass, 6 fail, 1 skip). Plugin tests run only via test-harness at Makefile:298-300; pre-push runs config/Python/shell at scripts/verify-pre-push.sh:97-103, not test-harness. Impact: make test-infra is predictably red on pure Linux and ordinary pushes skip the plugin state-machine suite.

## Verification

Desktop-toast tests get the injected WSL marker used by needs-input-observer.platform-gate.test.mjs:89-105; a fast plugin-bun target added to pre-push/test-config; the skipped cleanup test at empty-result-detection.test.mjs:555 resolved; plugin suite green on Linux.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
