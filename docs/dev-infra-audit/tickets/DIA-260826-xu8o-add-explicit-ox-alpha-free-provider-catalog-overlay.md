# DIA-260826-xu8o - Add explicit Ox Alpha Free provider catalog overlay

---

id: DIA-260826-xu8o
title: "Add explicit Ox Alpha Free provider catalog overlay"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: fix-lane
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

OpenCode Go's live `/v1/models` endpoint exposes `ox-alpha-free`, and the
`cebula-ox-alpha` OMO preset selects it, but OpenCode 1.18.18's refreshed
models.dev cache omits it. OpenCode therefore raises
`ProviderModelNotFoundError` before making a provider request and OMO persists
the next fallback model in its project-scoped TUI state.

The explicit provider workaround was implemented and runtime-proven, then
rejected after the developer confirmed Ox Alpha was no longer available under
the intended free-access terms. The repository instead returns to its existing
`cebula-openai-hy3` preset. No provider alias or credential bridge remains.

## Verification

- [x] Explicit Ox workaround removed after developer disposition.
- [x] Active preset is `cebula-openai-hy3`.
- [x] Repository config validation passes.

## Fix

- Developer disposition: do not retain the Ox Alpha workaround; return to the
  existing Hy3-based preset.
- Set top-level OMO `preset` to `cebula-openai-hy3`.
- Removed the temporary provider alias, preset rewrites, and auth bridge.

## Re-verify

- `make test-config`: exit 0; 57 tests passed, 0 failed.
- Static inspection: active preset is `cebula-openai-hy3`; its coder and
  supporting low-cost lanes resolve to `opencode-go/hy3` with MiMo fallback.
- No `opencode-go-ox` or `OPENCODE_GO_API_KEY` references remain.
