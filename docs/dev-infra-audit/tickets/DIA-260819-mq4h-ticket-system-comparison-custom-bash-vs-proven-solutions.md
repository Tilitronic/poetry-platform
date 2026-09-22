# DIA-260819-mq4h - ticket system comparison: custom bash vs proven solutions

---

id: DIA-260819-mq4h
title: "ticket system comparison: custom bash vs proven solutions"
area: dev-infra
severity: Medium
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-08-19
source: inventory
date: 2026-08-19
created: 2026-08-19
updated: 2026-08-19

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
evidence: []

---

## Description

Compare ticket management system options for the poetry-platform project.
The current DIA ticket system is a custom bash ledger (~1700+ lines across
scripts/tickets, scripts/validate-ticket-\*.sh, and delegation-observer
ticket gates). Evaluate whether replacing it with an established tool
would reduce maintenance burden while preserving the agent-integration
properties that make it work.

**Candidates:**

1. **git-bug** — git-native, offline-first distributed issue tracker
2. **Plane** — self-hosted project management with MCP server potential
3. **Linear** — cloud-based, MCP integration, polished UX
4. **taskwarrior** — single binary, powerful CLI filtering, local-first
5. **Custom (current)** — scripts/tickets CLI, markdown frontmatter, README index

**Analysis dimensions:**

1. Integration with existing workflow (DIA tickets, delegation-observer, agent dispatch)
2. Local-first constraint (offline, WSL2+Docker, no cloud dependency)
3. Agent accessibility (CLI, JSON output, MCP server)
4. Migration cost (120+ tickets, evidence citations, agent prompts)
5. Maintenance burden (custom debugging vs upstream support)
6. Feature parity (current features, missing features, future needs)

**Output:** Analysis report at
knowledge/ana030-ticket-system-comparison/ana030-ticket-system-comparison-report.md

## Verification

- [x] Comparison matrix completed for all 5 candidates across all 6 dimensions
- [x] Migration cost estimate per candidate (hours, risk, data loss potential)
- [x] Recommendation with rationale
- [x] Risk assessment for recommended option
- [x] Report committed at knowledge/ana030-ticket-system-comparison/ana030-ticket-system-comparison-report.md

## Fix

Analysis complete. Recommendation: keep custom solution (architecturally correct, 0h migration vs 136-284h for alternatives). Report: knowledge/ana030-ticket-system-comparison/

## Re-verify

> To be filled at re-verify time.
