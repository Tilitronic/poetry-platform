# DIA-260821-mzk7 - diagnose active OpenCode preset routing mismatch after restart

---

id: DIA-260821-mzk7
title: "diagnose active OpenCode preset routing mismatch after restart"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-21
source: inventory
date: 2026-08-21
created: 2026-08-21
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
evidence:

- ticket:DIA-260912-dean
- runtime-smoke:2026-09-14

---

## Description

The project previously restarted into an older preset/model route and `/preset`
was unavailable, indicating that OMO Slim or the intended project config had not
loaded. The mismatch risk came from stale runtime pins, container recreation,
and project-level preset precedence.

## Verification

- [x] Active project pointer names the intended preset.
- [x] OMO Slim 2.2.19 is installed and loaded after Podman rebuild/restart.
- [x] `/preset` is available and the TUI reports the OpenAI orchestrator route.
- [x] Every distinct configured OpenAI model/variant returns a non-empty runtime
      marker through a real agent dispatch.
- [x] `make test-config` passes 57/57.

## Fix

Resolved by the OMO 2.2.19 runtime alignment and Podman recreation work, followed
by activation of `openai-first-cost-balanced` under DIA-260912-dean. The
project-level pointer is authoritative and the old environment/runtime mismatch
no longer reproduces.

## Re-verify

- Restarted TUI: `orchestrator · gpt-5.6-luna · OpenAI`; `/preset` available.
- `make test-config`: 8 suites, 57 passed, 0 failed.
- Runtime smoke on 2026-09-14 returned non-empty markers for Luna medium/high,
  Terra medium/high, and Sol medium/high.
- Superseding implementation commits: OMO/runtime stabilization and
  `DIA-260912-dean 'add OpenAI-first cost-balanced preset with Luna Terra Sol routing'`.
