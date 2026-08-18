---
id: DIA-215
title: 'ticket numbering sequential ID conflicts in parallel creation'
area: dev-infra
severity: Major
status: OPEN
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

DIA ticket numbering uses sequential integers (DIA-001, DIA-002, ...). When multiple team members create tickets concurrently, the next-number allocation conflicts -- two agents may pick the same number.

**Developer report (2026-08-18):** "We create tickets by adding next number and it creates conflicts with teammate."

## Impact

Merge conflicts on tickets/README.md, duplicate ticket IDs, lost tracking.

## Proposed Direction

Replace sequential numbering with globally-unique short IDs derived from datetime:

- Format: `DIA-YYMMDD-<short-suffix>` (e.g., `DIA-260818-a1b2`)
- Suffix: 4-char base36 or random letters for collision avoidance within same day
- Eliminates merge conflicts (datetime-based, not counter-based)
- Backward-compatible: old sequential IDs remain valid, new tickets use new format

## Research Needed

- Minimum suffix length for zero collisions at team scale
- Migration path (can old tickets be renumbered? or just new ones?)
- scripts/validate-tickets.sh update for new format
- Cross-reference with DIA-189 (session naming uses similar short-id approach)
