# DIA-260831-t9u0 - Atlas sha256 sidecar not raw binary digest

---

id: DIA-260831-t9u0
title: "Atlas sha256 sidecar not raw binary digest"
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-M2) evidence: generate_phonetic_atlas.py:110-135,442-445 writes a semantic content hash; load-atlas.test.ts:266-282 compares the sidecar only against metadata inside the binary. The actual binary SHA starts 7e59bf37 while the sidecar is e8e96f21. Impact: tampering with arbitrary feature bytes may not change either the metadata or the sidecar comparison; the name and comments promise a guarantee that does not exist. Correct fix: make the sidecar the digest of the raw bytes; keep the semantic provenance hash as a separate clearly named field.

## Verification

Mutate a feature byte, recompute, and assert the sidecar digest changes; confirm the sidecar equals the raw-binary SHA-256.

## Fix

Store the raw-binary SHA-256 in the sidecar; move the semantic provenance hash to a separate, clearly named field; update tests to compare the sidecar against the real binary digest.

## Re-verify

> To be filled at re-verify time.

## Audit correction (DIA-261022-5n2v)

Verdict: UNSAFE_AS_SPECIFIED - the repo over-engineering audit's P2 proposal (delete the whole phonetic-atlas loader chain) self-breaks; blocking prerequisites before any deletion:

- packages/phonetics-core/package.json:6-27 makes src/atlas/load-atlas.ts the package main/types/exports and packages/editor-engine/package.json:20 + tsconfig.json:6 depend on it; scripts/gen-jsconfig.sh:119 hard-errors inside make test-infra on a missing declared entry.
- scripts/generate_phonetic_atlas.py:138-139,323-330,485-494 imports the generated Python bindings the proposal deletes (plus flatbuffers/pandas/panphon); test_parity.py/test_load_atlas.py are the only FlatBuffers schema-drift guard.
- The two .bin copies are not redundant (package.json:23-24 vs load_atlas.py:331 vs turbo.json:10 vs .gitignore:13).
  Honest cost: ~3,095 lines, but every part is load-bearing today (package main, test-infra gate, schema-drift guard); net zero until the prerequisites land.
