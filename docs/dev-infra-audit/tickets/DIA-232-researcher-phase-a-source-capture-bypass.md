# DIA-232 -- Researcher Phase A source capture bypass

---

id: DIA-232
title: "Researcher Phase A source capture bypass -- PERSISTENCE_RECOMMENDED evaluated before sources archived"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: []
parent_epic: ""

gate_state: "skipped"
gate_triggers: []
gate_waivers: []
gate_override: ""
discovered:
source: fix-lane
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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

Researcher agent was dispatched with a pre-allocated res ID but returned findings WITHOUT creating sources/ artifacts. The agent returned `PERSISTENCE_RECOMMENDED: false` instead of following the research-pipeline Phase A flow.

**Expected behavior:** When the orchestrator pre-allocates a res ID, Phase A is MANDATORY. The researcher must:

1. Create `sources/` directory artifacts
2. Archive URLs
3. Write `.source-urls.txt` with ratings
4. THEN evaluate persistence

**Root cause:** Agent instructions do not enforce Phase A when res ID is pre-allocated. The researcher sees the res ID, assumes it can skip directly to findings, and evaluates persistence without ever archiving sources.

## Verification

1. Dispatch researcher with a pre-allocated res ID
2. Check that `sources/` artifacts are created before any persistence evaluation
3. Verify `.source-urls.txt` exists with rated URLs

## Fix

Added hard checkpoint language to researcher.md: Phase A (source archiving) must complete before returning findings when a res ID is pre-allocated. Upgraded research-pipeline SKILL.md Phase 2 verification to a HARD GATE with re-dispatch on violation.

**Files:** `.opencode/agents/researcher.md`, `.opencode/skills/research-pipeline/SKILL.md`

## Re-verify

- `make test-config` passes (56 pass, 0 fail)
