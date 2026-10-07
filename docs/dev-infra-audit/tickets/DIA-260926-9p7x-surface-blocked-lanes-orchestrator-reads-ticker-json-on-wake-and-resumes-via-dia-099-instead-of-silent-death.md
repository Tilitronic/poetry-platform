# DIA-260926-9p7x - surface blocked lanes: orchestrator reads ticker.json on wake and resumes via DIA-099 instead of silent death

---

id: DIA-260926-9p7x
title: "surface blocked lanes: orchestrator reads ticker.json on wake and resumes via DIA-099 instead of silent death"
area: scripts
severity: Major
status: OPEN
blocked_by: [] # DIA-NNN refs, or empty
parent_epic: ""
gate_state: "skipped" # grilled | waived | bypassed | partial | skipped
gate_triggers: [] # new-module | cross-boundary | schema-state | new-public-api | cross-cutting | hard-to-reverse | new-ui-component
gate_waivers: [] # hotfix | incremental-to-grilled-module | spike-poc | refactor-no-behavior-change
gate_override: "" # free-text: developer signal + reason; empty = no override
discovered: 2026-09-26
source: inventory
date: 2026-09-26
created: 2026-09-26
updated: 2026-09-26

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

### Problem

- When a lane blocks on a permission ask and is auto-rejected, nobody is told afterwards: the lane ends with an empty result and the orchestrator sees only "no result". Six of nine such lanes had already done real work that survived on disk.
- THE QUEUE ALREADY EXISTS AND IS UNCONSUMED: .opencode/plugins/needs-input-observer.ts records every question/permission wait into .opencode/session/ticker.json -> `waiting[]` (session_id, reason question|permission, detail, since, optional permission_id); it persists across restarts (seedFromDisk) with a 24h TTL. NOTHING reads it automatically - no orchestrator path consumes it, and no registry/messages row is written for a wait.
- The system's documented design is deliberately FAIL-FAST, not auto-resume (comment in needs-input-observer.ts ~:408-410: the rejection fails the agent gracefully and the orchestrator re-routes). That is a legitimate policy - but the re-route never actually happens, because the orchestrator is never informed of the block.
- Consequence: the developer returns to silent failures, with no way to know which lanes were blocked, on what, or whether they can continue.

### Fix

- Minimal, no new machinery: on orchestrator wake, read .opencode/session/ticker.json `waiting[]` and report - N lanes blocked, on which questions/permissions, since when.
- Keep the report HONEST about expiry: a queued ask is only answerable while pending. Once the watchdog has auto-rejected it (5 minutes by default) the answer is moot and the correct action is a re-route, not a resume. Expired asks must be marked EXPIRED, not pending.
- Resume through the existing DIA-099 path: scripts/lane-resume plus the resume-truncated-lane skill, VERIFY-FIRST (git log, target files, ticket status) so landed work is never redone. Six of nine lanes already had work on disk.
- Reuse, do not duplicate: the P1 partial-results convention is the resume carrier, and the ORCHESTRATOR (not the plugin) writes it.
- Add a true answer path ONLY if the reduced form proves insufficient: today only `reject` is ever sent to the SDK permission endpoint (~:436); answering a pending permission_id later with `once`/`always` is NEW CODE.

### Acceptance criteria

- [ ] On wake, the orchestrator reports blocked lanes from ticker.json with their questions and ages.
- [ ] Expired (already auto-rejected) asks are distinguished from still-pending ones.
- [ ] A resumed lane is verify-first and does not redo landed work.
- [ ] The report reaches the developer without them having to inspect logs.

### Relations

- ADR candidate "Blocked-Lane Ask Handling": when a subagent tool call requires an interactive permission/question and no human answers within the stall threshold, does the system queue the ask and resume the same session, or auto-reject and re-route? Proposed decision: keep fail-fast auto-reject, surface blocked lanes from ticker.json on orchestrator wake, and resume via DIA-099 same-session verify-first. Persist next to ADRs 12/13/14 in .sdd/dev-infra/architecture.md.
- Companion ticket: the permission-ask death fix (ask -> deny). Related: DIA-099 and ADR 14 (execution-context contract).

## Verification

## Fix

> To be completed when the fix is implemented.
