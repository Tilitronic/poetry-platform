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
