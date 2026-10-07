---
id: DIA-214
title: 'orchestrator dev-infra dispatch without ticket (DIA-063 gate violation)'
area: orchestrator-workflow
severity: Critical
status: CLOSED
blocked_by: []
discovered: 2026-08-18
source: session-observation (developer report, 2026-08-18)
date: 2026-08-18
created: 2026-08-18
updated: 2026-08-18

# --- Session Attribution (v2 schema, optional) ---

session_id: ''
lane_id: ''
agent: 'orchestrator'
model: ''
parent_session_id: ''
attempts: 0
lease_expires_at: ''
files_touched: []
artifacts: []
evidence: []
---

## Description

Orchestrator started dev-infra research (session naming = OpenCode config change, routes AGENTS.md section 2.5) WITHOUT first creating a DIA ticket. This is a DIA-063 gate violation.

The ai-specialist dispatch for "session naming research" was launched before a ticket existed. The task was cancelled by the developer.

## Root Cause

Orchestrator recognized the user's request as research-worthy but skipped the ticket gate check. The DIA-063 gate should have fired before any @ai-specialist dispatch for config work.

## Impact

Workflow violation -- no audit trail for dev-infra research. If the dispatch had completed, work would exist without a tracking ticket.

## Fix

Add a hard pre-dispatch check: before ANY @ai-specialist or config-work dispatch, verify an OPEN ticket exists with DIA-063 correlation. If no ticket, create one FIRST, then dispatch.

## Verification

- Orchestrator refuses to dispatch @ai-specialist without an OPEN ticket
- Test: attempt dispatch without ticket -> blocked with "create ticket first"
