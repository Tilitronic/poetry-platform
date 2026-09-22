# DIA-260831-m3n4 - PoetryDataContract types schema not payload instance

---

id: DIA-260831-m3n4
title: "PoetryDataContract types schema not payload instance"
area: js-tooling
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-H3) evidence: packages/data-contracts/src/index.ts:9-13 uses typeof contract, so the resulting type has $schema, properties, required rather than instance fields; index.test.ts:8-59 only checks the schema object. Impact: the central cross-app seam gives no compile-time type for real poems; consumers fall back to any or duplication. Correct fix: separately export the schema document and a generated/inferred instance type plus validator/serializer. Design-gated: architecture.md:736-808 describes a Protobuf/Canonical-JSON target while the implementation is Draft-07 JSON Schema.

## Verification

Add a test asserting a typed poem instance compiles and validates; confirm consumers get a real instance type.

## Fix

Export both the schema document and a generated/inferred instance type with a validator/serializer. Note design gate: architecture.md targets Protobuf/Canonical JSON; reconcile the Draft-07 JSON Schema implementation before finalizing.

## Re-verify

> To be filled at re-verify time.
