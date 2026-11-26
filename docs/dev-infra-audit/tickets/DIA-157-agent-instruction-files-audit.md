# DIA-157 — audit agent instruction/prompt files for inaccuracies, duplications, vague wording

<!-- RENUMBERED 2026-08-14 (phase 1, remote lineage canonical, DIA-153): local DIA-114 collided with origin/omo-slim-changes ticket DIA-138-agent-instruction-files-audit.md (different ticket). Renumbered to DIA-157. This ticket duplicates remote DIA-138-agent-instruction-files-audit.md (same work, renumbered on the remote lineage via bab080c); SUPERSEDED by the remote ticket. -->

<!-- CLOSED 2026-08-15 as same-scope duplicate of DIA-138 (CLOSED). Superseded; do not implement. -->

<!-- Analysis ticket (baseline): systematic audit of the agent instruction surface.
     Filed 2026-08-12, cod-lane. -->

---

id: DIA-157
title: "Audit agent instruction/prompt files (.ts and .md) for inaccuracies, duplications, vague wording"
area: opencode-config
severity: Medium
status: CLOSED
blocked_by: []
discovered: 2026-08-12
source: baseline
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-15

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
lane_id: "cod-lane"
agent: "coder"
model: ""
parent_session_id: "ses_00b5f2f4affeavJUt86vac4dn6"
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-157-agent-instruction-files-audit.md"]
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
