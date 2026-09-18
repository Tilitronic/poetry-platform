# DIA-260831-v1w2 - Atlas codegen fail-open scatters generated artifacts

---

id: DIA-260831-v1w2
title: "Atlas codegen fail-open scatters generated artifacts"
area: python-tooling
severity: Medium
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-M3) evidence: packages/phonetics-core/scripts/codegen.js:69-87 catches each language failure yet still exits success; TS is generated into dist/ts while runtime imports src/atlas/generated; Python has a third copy in scripts/generated/python; the build does not depend on codegen (turbo.json:12-19). Impact: stale/partial adapters are cached as successful generation; schema, code, and binary lack locality. Correct fix: one fail-closed generation Module with atomic canonical outputs and verification. The C++ target should be removed only after a design disposition.

## Verification

Force a language failure and assert codegen exits non-zero; confirm one canonical output location and that the build depends on codegen.

## Fix

Make codegen fail-closed (no per-language catch that masks failure), emit atomic canonical outputs to a single location, and make the build depend on codegen. Remove the C++ target only after a design decision.

## Re-verify

> To be filled at re-verify time.
