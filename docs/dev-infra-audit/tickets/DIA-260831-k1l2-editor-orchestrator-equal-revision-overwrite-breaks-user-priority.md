# DIA-260831-k1l2 - Editor orchestrator equal-revision overwrite breaks user priority

---

id: DIA-260831-k1l2
title: "Editor orchestrator equal-revision overwrite breaks user priority"
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

Reaudit (DIA-260827-wfcx, 2026-08-31; C-H2) evidence: packages/editor-engine/src/orchestrator/Orchestrator.ts:24-33 rejects only a lower revision and stores no provenance/priority; Orchestrator.test.ts:46-59 pins the equal-overwrite behavior. Impact: a user or MarkPoetry write at revision N can be overwritten by a worker result at the same revision. Correct fix: deepen the Orchestrator Module so its interface takes revision + source/priority and compares (revision, priority); add an equal-revision user-vs-worker test.

## Verification

Add a test where a user write and a worker result share a revision; assert the higher-priority (user) write wins.

## Fix

Extend the Orchestrator interface to accept revision plus source/priority and compare (revision, priority); add an equal-revision user-vs-worker test that asserts user priority.

## Re-verify

> To be filled at re-verify time.
