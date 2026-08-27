# DIA-260827-7mtr - Product test coverage concentrated in two narrow modules

---

id: DIA-260827-7mtr
title: "Product test coverage concentrated in two narrow modules"
area: tests
severity: Medium
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

apps/api-server/tests/test_auth.py:4-9 and packages/analytics-pipeline/tests/test_smoke.py:4-11 test scaffold imports only; apps/author-studio/src/stores/example-store.test.ts:1-3 warns it is template coverage. Editor tests omit CommandBus scheduling/error (command-bus.ts:16-40), tokenizer Unicode (tokenizer.ts:102-117), editor/view integration (OpusEditorView.ts:56-108), decoration dispatch (opusDecorator.ts:12-45), state duplicate/index (PoetryState.ts:16-31). Visualizer packages have DOM/WebGL lifecycle code but no test scripts (visualizer-2d/package.json:16-19, visualizer-3d/package.json:8-11).

## Verification

Tests added for command ordering, tokenizer Unicode/property, view lifecycle, visualizer destroy/unmount, and one mounted author-studio integration test.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
