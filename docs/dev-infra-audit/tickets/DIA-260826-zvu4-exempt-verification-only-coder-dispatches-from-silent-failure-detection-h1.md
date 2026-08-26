# DIA-260826-zvu4 - exempt verification-only coder dispatches from SILENT_FAILURE detection (H1)

---

id: DIA-260826-zvu4
title: "exempt verification-only coder dispatches from SILENT_FAILURE detection (H1)"
area: delegation-observer
severity: Major
status: VALIDATE
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: DIA-260825-wprb
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-26
source: inventory
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
evidence:

- commit 201e2da

---

## Description

<To be filled at creation time: what is wrong / what to build, with exact
files and line references where known.>

## Verification

<Acceptance criteria as checkboxes - how to prove the ticket is done.>

## Fix

Implemented in delegation-observer.ts (commit 201e2da): verificationOnlySessions
Set populated at task-dispatch capture via marker-phrase regex on
description+prompt; exemption added to the session.idle empty-result check;
cleanup on both terminal paths (session.idle completion + session.error).
Convention documented in oh-my-opencode-slim/orchestrator_append.md.
Tests: 8 pass / 1 skip / 0 fail incl. case-insensitivity and
description-channel cases. Review: ai-auditor re-review cycle 1/2 APPROVE
(5/5 verified-closed). Restart-verify pending: plugin change loads on next
opencode launch - confirm a marker-bearing zero-edit coder lane writes no
empty_result_detected row in the live registry.

## Re-verify

> To be filled at re-verify time.
