# DIA-114 — audit agent instruction/prompt files for inaccuracies, duplications, vague wording

<!-- Analysis ticket (baseline): systematic audit of the agent instruction surface.
     Filed 2026-08-12, cod-lane. -->

---

id: DIA-114
title: "Audit agent instruction/prompt files (.ts and .md) for inaccuracies, duplications, vague wording"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: []
discovered: 2026-08-12
source: baseline
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
lane_id: "cod-lane"
agent: "coder"
model: ""
parent_session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-114-agent-instruction-files-audit.md"]
artifacts: []
evidence: []

---

## Description

Agent instruction surface (AGENTS.md, .opencode/agents/_.md, .opencode/skills/_/SKILL.md, prompt-bearing .ts plugin sources, agent blocks in .opencode/opencode.jsonc and .opencode/oh-my-opencode-slim.jsonc) has never been systematically audited. Risk of stale cross-references (renamed agents, moved paths), duplicated instruction blocks, and unmeasurable/ambiguous directives that degrade agent execution quality.

## Verification

Dispatch @analyzer to produce knowledge/ana<id>-agent-instruction-audit report with file:line evidence for each finding class (inaccuracies, duplications, vague formulations, improvement advice); report registered in memory-shelf.yaml shelf.analyses.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
