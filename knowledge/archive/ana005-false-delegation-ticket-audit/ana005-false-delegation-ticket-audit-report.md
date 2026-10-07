---
# Analysis Report: False-Delegation Incidents & Tickets-System Connectivity Audit

**Report ID**: ana005
**Date**: 2026-08-04
**Campaign**: "Dev environment audit and testing" (2026-08-04, branch `further-dev-infrastructure-development`)
**Session logs**: `.opencode/session/messages.md` rows 190–232 + `.opencode/session/messages.jsonl` lines 67–109

## Executive Summary

**Incident count**: 3 confirmed false-delegation incidents + 5 additional row gaps (11 dangling JSONL result_refs, 25.6% of 43 campaign rows). Matches `.opencode/memory/failures.md` entry: "dispatched-but-not-executed task() when batching edits".

**Root cause**: OpenCode runtime silently drops `task()` calls when batched with `edit()` calls in a single agent message. Pure `task()` messages are reliable.

**Tickets-system connectivity**: Critical gaps — no `session_id`, `lane_id`, `files_touched`, or `research_artifacts` fields in the ticket template. Cannot trace ticket → subagent session → files → research.

## Task 1: False-Delegation Incident Forensics

### Evidence Inventory
| Source | Location | Content |
|--------|----------|---------|
| Campaign log | `.opencode/session/messages.md` rows 190–232 | Orchestrator narrative (43 rows present, 11 MISSING) |
| Telemetry sidecar | `.opencode/session/messages.jsonl` lines 67–109 | Machine-readable events |
| Documented failure | `.opencode/memory/failures.md` | "dispatched-but-not-executed task() when batching edits" |
| Campaign handoff | `.opencode/session/current-handoff.json` | Campaign summary + prognosis |

### Key Finding: JSONL References MISSING Rows
The JSONL sidecar's `result_ref` fields point to messages.md rows that DON'T EXIST: rows #192, #194, #198, #201, #204, #207, #209, #211, #214, #218, #221 — 11 dangling references out of 43 campaign rows (25.6% gap rate).

### Incident 1: ai--1 (rows 192, 194 missing)
Orchestrator claimed it dispatched cod-1 (inventory) AND ai--1 (critical review) in parallel. cod-1 rows written (191/193); ai--1 rows MISSING (192/194). JSONL shows ai--1 in-flight at 09:02 and done at 09:20 (retry). Root cause: task() for ai--1 batched with edit() calls dropped; owner intervened: "actually dispatch ai--1". Resolution: ai--1 ran 18 min, produced 22 findings (1 Blocker, 4 Critical, 7 Major, 7 Minor, 3 Suggestion).

### Incident 2: cod-4 (rows 198, 201 missing)
Orchestrator claimed dispatch of cod-2, cod-3, cod-4 in parallel. cod-2/cod-3 rows written; cod-4 rows MISSING. JSONL shows cod-4 in-flight 09:33 / done 09:55 (retry). Owner intervened: "actually dispatch cod-4". Resolution: cod-4 ran 22 min, created learnings file (34L/2425B).

### Incident 3: cod-6 (rows 204, 207 missing)
Orchestrator claimed dispatch of cod-5, ai--2, cod-6 in parallel. cod-5/ai--2 rows written; cod-6 rows MISSING. JSONL shows cod-6 in-flight 10:07 / done 10:30 (retry). Owner intervened: "actually dispatch cod-6". Resolution: cod-6 ran 23 min, validation loop 10/12 green + 2 real failures.

### Root-Cause Mechanics Diagram
Orchestrator turn (owner: "dispatch X, Y, Z parallel") → orchestrator batches task(X)+task(Y)+task(Z)+edit(write DISPATCHED rows) → runtime: task(X) ✓, task(Y) ✓, edit ✓, **task(Z) DROPPED** (no JSONL entry, no messages.md row) → orchestrator claims "I've dispatched X, Y, Z. Waiting." → owner notices Z silent → owner: "Actually call Z!" → orchestrator retries task(Z) alone (pure task message) ✓ → but no messages.md rows written for retry.

**Root cause**: OpenCode runtime silently drops task() when batched with edit() in a single agent message. Pure task() messages are reliable.

## Task 2: Tickets-System Connectivity Audit

### Current Ticket Schema (from `_TEMPLATE.md`)
```yaml
id: DIA-XXX
title: "<short title>"
area: <enum>
severity: <enum>
status: <enum>
blocked_by: []
discovered: {source, date}
created: YYYY-MM-DD
updated: YYYY-MM-DD
```

### Missing fields
- ❌ No `session_id` — can't link ticket to exact subagent instance
- ❌ No `lane_id` — can't trace which agent lane worked the ticket
- ❌ No `files_touched` — can't trace which files the work modified
- ❌ No `research_artifacts` — can't trace which learnings/conspects were consumed
- ❌ No `messages_md_rows` — can't trace which log rows document the work

### Connectivity Gaps (Severity-Ranked)
| # | Gap | Severity | Impact |
|---|-----|----------|--------|
| G1 | No `session_id` in ticket | Major | Can't resume exact subagent session; can't trace work to instance |
| G2 | No `lane_id` field (machine-readable) | Major | Lane mentioned only in prose; can't query |
| G3 | No `files_touched` in ticket | Major | Can't trace which files a ticket's work modified |
| G4 | No `research_artifacts` in ticket | Minor | Can't trace which learnings/conspects were consumed |
| G5 | HANDOFF references row ranges, not per-ticket | Minor | "rows 190-232" is a range, not per-ticket mapping |
| G6 | Session IDs inconsistent in messages.md | Minor | Some rows have `ses_037b...`, some don't |
| G7 | No schema field for subagent session ID | Major | Template doesn't support session tracking |

### Sample Ticket Analysis (DIA-041)
Records lane ids only in prose ("cod-12 + cod-14"); no session IDs, no file links, no research artifact links. messages.md row 216 records lane `cod-12` but no session id; some other rows DO carry session ids (e.g., row 208: `cod-4, ses_037b96983ffex0eQmuygh4lJBj`).

## Recommendations

### For False-Delegation Prevention
| Priority | Action | Effort | Impact |
|----------|--------|--------|--------|
| P0 | Enforce pure-task() messages — never batch task() with edit(); write DISPATCHED rows in a separate message AFTER task() calls succeed | Low | Prevents false delegation |
| P1 | Add DISPATCHED→RUNNING assertion — verify subagent actually started within N seconds; else alert | Medium | Detects dropped dispatches |
| P2 | Fix JSONL result_ref dangling references — validate result_ref rows exist in messages.md | Medium | Detects orphaned references |
| P2 | Document failure mode — orchestrator prompt: "Never batch task() with edit(). Pure task() messages are reliable." | Low | Prevents recurrence |

### For Tickets-System Connectivity
| Priority | Action | Effort | Impact |
|----------|--------|--------|--------|
| P0 | Add `session_id` field to ticket template (exact subagent session id, e.g. `ses_037b9709bffeHqFqa2dKxYi6GO`) | Low | Enables traceability |
| P0 | Add `lane_id` field (machine-readable) | Low | Enables traceability |
| P1 | Add `files_touched` section | Low | Enables file traceability |
| P2 | Add `research_artifacts` section | Low | Enables knowledge traceability |
| P2 | Enforce session ID consistency in messages.md delegation rows | Medium | Improves auditability |

## Sources
- `.opencode/session/messages.md` (campaign log rows 190–232)
- `.opencode/session/messages.jsonl` (telemetry sidecar lines 67–109)
- `.opencode/memory/failures.md` (documented failure mode)
- `.opencode/session/current-handoff.json` (campaign handoff)
- `docs/dev-infra-audit/tickets/_TEMPLATE.md` + sample tickets DIA-038/041/045/048/049
