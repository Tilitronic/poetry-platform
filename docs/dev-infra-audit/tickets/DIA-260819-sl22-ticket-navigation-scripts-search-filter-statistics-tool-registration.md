# DIA-260819-sl22 - ticket navigation scripts: search, filter, statistics, tool registration

---

id: DIA-260819-sl22
title: "ticket navigation scripts: search, filter, statistics, tool registration"
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

Agents need better tools for navigating, searching, and filtering tickets. Currently:

- README index requires manual sync (status drift problem - we just fixed 8 tickets with stale status)
- No dedicated scripts for ticket search/filter/navigation
- Orchestrator must read entire README or individual ticket files to find tickets
- Ticket statistics are computed manually by reading README

### Requirements

1. **Ticket navigation scripts**: search by status, area, severity, date, keywords
2. **Ticket statistics script**: generate status counts, area breakdown, age analysis
3. **Register as tools**: consider making ticket scripts available as orchestrator tools (so orchestrator can query without reading full files)
4. **Alternatives to README sync**: script-based stats instead of manual index maintenance
5. **Possible SQL layer**: readonly SQLite over tickets (like session logs DIA-136/156) if pragmatic

### Design considerations

- Scripts should be fast and agent-friendly (JSON output option for programmatic use)
- Should integrate with existing ticket workflow (scripts/tickets)
- Orchestrator should be able to query tickets without reading full files
- Consider both CLI scripts and potential tool registration
- Must be actually used by agents (not just exist) - orchestrator delegates to coder which must know and use these scripts

### Research questions

- What ticket operations do agents perform most often? (grep registry.jsonl for ticket-related reads)
- Can we register scripts as tools for the orchestrator? (check opencode tool registration)
- Is SQL layer worth the complexity vs simple grep/jq scripts?
- How to ensure agents actually use the scripts (prompt integration, skill registration)?

## Verification

- [ ] `scripts/tickets list` shows all tickets with optional filters (status, area, severity)
- [ ] `scripts/tickets stats` generates status/area/severity breakdown
- [ ] `scripts/tickets search <query>` finds tickets by keyword in title/description
- [ ] JSON output option for programmatic use (`--json` flag)
- [ ] Scripts are fast (<1s for full ticket directory)
- [ ] Orchestrator can use scripts without reading full ticket files
- [ ] Consider tool registration for orchestrator (if feasible)
- [ ] README sync becomes optional (scripts can generate stats on-demand)

## Strategic Concern (2026-08-19)

The scripts/tickets implementation has grown to 1700+ lines of bash. We are effectively building our own ticket management system instead of using reliable, ready-made solutions. This is "vibecoded" infrastructure that requires constant debugging and maintenance.

**The question:** Should we continue extending our custom bash implementation, or migrate to a proven ticket management system?

**Candidate systems to evaluate:**

- git-bug (git-native, offline-first, 10k+ stars)
- Plane (self-hosted, MCP server available, modern UI)
- Linear (cloud-based, excellent MCP integration)
- taskwarrior (single binary, powerful filtering)

**Decision needed:** Evaluate migration cost vs. continued maintenance of custom solution. This may supersede the current implementation work.

## Fix

Implementation complete. Added frontier --json, show <id> [--json], temporal filters (--since/--before). All tests passing.

## Re-verify

> To be filled at re-verify time.
